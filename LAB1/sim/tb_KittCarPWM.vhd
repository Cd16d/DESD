LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_KittCarPWM IS
END tb_KittCarPWM;

ARCHITECTURE testbench OF tb_KittCarPWM IS
    -- Test constants
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    CONSTANT RESET_TIME : TIME := 10*CLK_PERIOD;

    CONSTANT PERIOD : TIME := 10 ms;

    -- Signals
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL sw : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL led : STD_LOGIC_VECTOR(15 DOWNTO 0);

    -- Device Under Test (DUT) instance
    COMPONENT KittCarPWM
        GENERIC (
            CLK_PERIOD_NS : POSITIVE := 10;
            MIN_KITT_CAR_STEP_MS : POSITIVE := 1;
            NUM_OF_SWS : INTEGER := 16;
            NUM_OF_LEDS : INTEGER := 16;
            TAIL_LENGTH : INTEGER := 4
        );
        PORT (
            reset : IN STD_LOGIC;
            clk : IN STD_LOGIC;
            sw : IN STD_LOGIC_VECTOR(NUM_OF_SWS - 1 DOWNTO 0);
            led : OUT STD_LOGIC_VECTOR(NUM_OF_LEDS - 1 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    -- Connect DUT
    dut_KittCarPWM : KittCarPWM
    GENERIC MAP (
        CLK_PERIOD_NS => 10,
        MIN_KITT_CAR_STEP_MS => 1,
        NUM_OF_SWS => 16,
        NUM_OF_LEDS => 16,
        TAIL_LENGTH => 4
    )
    PORT MAP (
        reset => reset,
        clk => clk,
        sw => sw,
        led => led
    );

    -- Clock generation process
    clk <= not clk after CLK_PERIOD/2;

    -- Reset Process
    reset_wave :process
	begin
		reset <= '1';
		wait for RESET_TIME;
		
		reset <= not reset;
		wait;
    end process;

    -- Test process
    stim_proc : PROCESS
    BEGIN
        -- wait for reset
        sw <= "0000000000000000";
        WAIT FOR RESET_TIME;

        -- Start
        for I in 0 to 2**16-1 loop
            sw <= std_logic_vector(to_unsigned(I, 16));
            WAIT FOR PERIOD;
        end loop;

        -- End simulation
        WAIT;
    END PROCESS;
END testbench;
