---------- DEFAULT LIBRARY ---------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;
------------------------------------

ENTITY KittCarPWM IS
    GENERIC (
        CLK_PERIOD_NS : POSITIVE RANGE 1 TO 100 := 10; -- clk period in nanoseconds
        MIN_KITT_CAR_STEP_MS : POSITIVE RANGE 1 TO 2000 := 1; -- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

        NUM_OF_SWS : INTEGER RANGE 1 TO 16 := 16; -- Number of input switches
        NUM_OF_LEDS : INTEGER RANGE 1 TO 16 := 16; -- Number of output LEDs

        TAIL_LENGTH : INTEGER RANGE 1 TO 16 := 4 -- Tail length
    );
    PORT (

        ------- Reset/Clock --------
        reset : IN STD_LOGIC;
        clk : IN STD_LOGIC;
        ----------------------------

        -------- LEDs/SWs ----------
        sw : IN STD_LOGIC_VECTOR(NUM_OF_SWS - 1 DOWNTO 0); -- Switches avaiable on Basys3
        led : OUT STD_LOGIC_VECTOR(NUM_OF_LEDS - 1 DOWNTO 0) -- LEDs avaiable on Basys3
        ----------------------------

    );
END KittCarPWM;

ARCHITECTURE Behavioral OF KittCarPWM IS
    COMPONENT PulseWidthModulator
        GENERIC (
            BIT_LENGTH : INTEGER
        );
        PORT (
            reset : IN STD_LOGIC;
            clk : IN STD_LOGIC;

            Ton : IN STD_LOGIC_VECTOR(BIT_LENGTH - 1 DOWNTO 0);
            Period : IN STD_LOGIC_VECTOR(BIT_LENGTH - 1 DOWNTO 0);
            PWM : OUT STD_LOGIC
        );
    END COMPONENT;

    TYPE leds_sr_type IS ARRAY (TAIL_LENGTH - 1 DOWNTO 0) OF INTEGER RANGE led'LOW TO led'HIGH;

    CONSTANT COUNTER_BIT_LENGTH : INTEGER := INTEGER(ceil(log2(real(MIN_KITT_CAR_STEP_MS * 1000000 * 2 ** NUM_OF_SWS - 1))));
    CONSTANT PERIOD_BIT_LENGTH : INTEGER := INTEGER(ceil(log2(real(TAIL_LENGTH))));
    CONSTANT MIN_KITT_CAR_STEP_NS : UNSIGNED(COUNTER_BIT_LENGTH - 1 DOWNTO 0) := to_unsigned(MIN_KITT_CAR_STEP_MS * 1000000, COUNTER_BIT_LENGTH);

    SIGNAL pwms : STD_LOGIC_VECTOR(TAIL_LENGTH - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL leds_sig : STD_LOGIC_VECTOR(NUM_OF_LEDS - 1 DOWNTO 0) := (OTHERS => '0');

BEGIN

    -- Instantiate the PWM modules
    pwms(pwms'HIGH) <= '1'; -- First LED always on

    PWM : FOR i IN 1 TO TAIL_LENGTH - 1 GENERATE
    BEGIN
        PWM : PulseWidthModulator
        GENERIC MAP(
            BIT_LENGTH => PERIOD_BIT_LENGTH - 1
        )
        PORT MAP(
            reset => reset,
            clk => clk,
            Ton => STD_LOGIC_VECTOR(to_unsigned(i, PERIOD_BIT_LENGTH)),
            Period => STD_LOGIC_VECTOR(to_unsigned(TAIL_LENGTH - 1, PERIOD_BIT_LENGTH)),
            PWM => pwms(i - 1)
        );
    END GENERATE;

    -- Synchronous logic for LED control
    PROCESS (clk, reset)
        VARIABLE up : STD_LOGIC := '1'; -- Direction of LED movement
        VARIABLE leds_sr : leds_sr_type := (OTHERS => 0); -- Shift register for LED positions
        VARIABLE counter : UNSIGNED(COUNTER_BIT_LENGTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Timing counter
        VARIABLE n_period : UNSIGNED(NUM_OF_SWS DOWNTO 0) := to_unsigned(1, NUM_OF_SWS + 1); -- Period multiplier
    BEGIN
        IF reset = '1' THEN
            leds_sig <= (OTHERS => '0'); -- Turn off all LEDs
            leds_sr := (OTHERS => 0); -- Reset shift register
            counter := (OTHERS => '0'); -- Reset counter
            up := '1'; -- Set initial direction
        ELSIF rising_edge(clk) THEN
            -- Update period multiplier based on switches
            n_period := unsigned('0' & sw) + 1;

            -- Increment counter
            counter := counter + to_unsigned(CLK_PERIOD_NS, counter'LENGTH);

            -- Check if counter exceeds threshold
            IF counter >= (MIN_KITT_CAR_STEP_NS * n_period) THEN
                -- Update direction
                IF leds_sr(leds_sr'HIGH) = led'high THEN
                    up := '0'; -- Change to backward
                ELSIF leds_sr(leds_sr'HIGH) = led'low THEN
                    up := '1'; -- Change to forward
                END IF;

                -- Shift LEDs based on direction
                IF up = '1' THEN
                    leds_sr := (leds_sr(leds_sr'HIGH) + 1) & leds_sr(leds_sr'HIGH DOWNTO 1);
                ELSE
                    leds_sr := (leds_sr(leds_sr'HIGH) - 1) & leds_sr(leds_sr'HIGH DOWNTO 1);
                END IF;

                counter := (OTHERS => '0'); -- Reset counter
            END IF;

            -- Assign PWM signals to LEDs
            leds_sig <= (OTHERS => '0');
            FOR i IN leds_sr'REVERSE_RANGE LOOP
                leds_sig(leds_sr(i)) <= pwms(i);
            END LOOP;
        END IF;
    END PROCESS;

    -- Assign LED signals to output
    led <= leds_sig;

END Behavioral;