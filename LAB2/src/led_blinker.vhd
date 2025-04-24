---------- DEFAULT LIBRARIES -------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;
------------------------------------

ENTITY led_blinker IS
    GENERIC (
        CLK_PERIOD_NS : POSITIVE := 10;
        BLINK_PERIOD_MS : POSITIVE := 1000;
        N_BLINKS : POSITIVE := 4
    );
    PORT (
        clk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        start_blink : IN STD_LOGIC;
        led : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl OF led_blinker IS
    -- Calculations for widths and maximum values
    CONSTANT CLK_PER_MS : INTEGER := 1_000_000 / CLK_PERIOD_NS; -- Clock cycles per millisecond
    CONSTANT MAX_COUNT : INTEGER := CLK_PER_MS * BLINK_PERIOD_MS; -- Counter max value for one blink period
    CONSTANT CNT_WIDTH : INTEGER := INTEGER(ceil(log2(real(MAX_COUNT)))); -- Bit width for counter
    CONSTANT BLINK_WIDTH : INTEGER := INTEGER(ceil(log2(real(N_BLINKS + 1)))); -- Bit width for blink counter

    SIGNAL counter : unsigned(CNT_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Main blink period counter
    SIGNAL blink_cnt : unsigned(BLINK_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Number of completed blinks
    SIGNAL blinking : STD_LOGIC := '0'; -- Indicates if blinking is active
    SIGNAL led_reg : STD_LOGIC := '0'; -- Register for LED output

    SIGNAL start_prev : STD_LOGIC := '0'; -- Previous value of start_blink
    SIGNAL start_edge : STD_LOGIC; -- Rising edge detector for start_blink

BEGIN
    -- Output assignment
    led <= led_reg;

    -- Main process: handles blinking logic and state
    PROCESS (clk, aresetn)
    BEGIN
        IF aresetn = '0' THEN
            -- Asynchronous reset: clear all registers and outputs
            counter <= (OTHERS => '0');
            blink_cnt <= (OTHERS => '0');
            blinking <= '0';
            led_reg <= '0';
            start_prev <= '0';
            start_edge <= '0';

        ELSIF rising_edge(clk) THEN
            -- Detect rising edge on start_blink input
            start_edge <= start_blink AND NOT start_prev;
            start_prev <= start_blink;

            IF blinking = '0' THEN
                -- Idle state: wait for start_blink rising edge to begin blinking
                IF start_edge = '1' THEN
                    blinking <= '1';
                    counter <= (OTHERS => '0');
                    blink_cnt <= (OTHERS => '0');
                    led_reg <= '1'; -- Start with LED ON
                END IF;
            ELSE -- blinking = '1'
                -- Blinking state: count clock cycles for ON/OFF periods
                IF counter = to_unsigned(MAX_COUNT - 1, counter'length) THEN
                    counter <= (OTHERS => '0');
                    led_reg <= NOT led_reg; -- Toggle LED state

                    IF led_reg = '1' THEN -- End of ON phase
                        blink_cnt <= blink_cnt + 1;
                        -- Check if required number of blinks is reached
                        IF blink_cnt + 1 = to_unsigned(N_BLINKS, blink_cnt'length) THEN
                            blinking <= '0'; -- Stop blinking
                            led_reg <= '0'; -- Ensure LED is OFF at end
                        END IF;
                    END IF;
                ELSE
                    counter <= counter + 1; -- Increment counter
                END IF;
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE;