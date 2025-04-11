-- Testbench for rgb2gray
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY rgb2gray_tb IS
END rgb2gray_tb;

ARCHITECTURE Behavioral OF rgb2gray_tb IS

    -- Component Declaration
    COMPONENT rgb2gray
        PORT (
            clk : IN STD_LOGIC;
            resetn : IN STD_LOGIC;

            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axis_tready : IN STD_LOGIC;
            m_axis_tlast : OUT STD_LOGIC;

            s_axis_tvalid : IN STD_LOGIC;
            s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_tready : OUT STD_LOGIC;
            s_axis_tlast : IN STD_LOGIC
        );
    END COMPONENT;

    -- Signals
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL resetn : STD_LOGIC := '0';

    SIGNAL m_axis_tvalid : STD_LOGIC;
    SIGNAL m_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL m_axis_tready : STD_LOGIC := '1';
    SIGNAL m_axis_tlast : STD_LOGIC;

    SIGNAL s_axis_tvalid : STD_LOGIC := '0';
    SIGNAL s_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tready : STD_LOGIC;
    SIGNAL s_axis_tlast : STD_LOGIC := '0';

    -- Clock generation
    CONSTANT clk_period : TIME := 10 ns;

BEGIN

    m_axis_tready<='1';

    clk <= not clk AFTER clk_period / 2; -- Clock generation

    -- Instantiate the Device Under Test (DUT)
    DUT: rgb2gray
        PORT MAP (
            clk => clk,
            resetn => resetn,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata => s_axis_tdata,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast
        );

    -- Stimulus process
    stimulus_process : PROCESS
        VARIABLE pixel_value : INTEGER := 1; -- Variable to increment pixel values
    BEGIN
        wait for 10 ns;
        resetn<='1';
        s_axis_tvalid <= '1';

        -- Send multiple RGB pixels with incrementing values
        FOR i IN 0 TO 10 LOOP -- Send 10 pixels
            -- R component
            s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(pixel_value, 8));
            WAIT FOR clk_period;

            -- G component
            pixel_value := pixel_value + 5;
            s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(pixel_value, 8));
            WAIT FOR clk_period;

            -- B component
            pixel_value := pixel_value + 1;
            s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(pixel_value, 8));
            WAIT FOR clk_period;

            -- Reset last signal
            pixel_value := pixel_value + 1;
        END LOOP;

        -- Deassert valid signal
        s_axis_tlast <= '1'; -- Indicate end of pixel
        s_axis_tvalid <= '0';

        WAIT;
    END PROCESS;

END Behavioral;