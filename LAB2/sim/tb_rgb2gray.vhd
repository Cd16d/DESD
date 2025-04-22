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

    -- Stimulus memory for RGB triplets (R, G, B)
    TYPE rgb_mem_type IS ARRAY(0 TO 8, 0 TO 2) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL rgb_mem : rgb_mem_type := (
        (x"10", x"20", x"30"),
        (x"40", x"50", x"60"),
        (x"70", x"80", x"90"),
        (x"A0", x"B0", x"C0"),
        (x"D0", x"E0", x"F0"),
        (x"01", x"02", x"03"),
        (x"04", x"05", x"06"),
        (x"07", x"08", x"09"),
        (x"0A", x"0B", x"0C")
    );

    SIGNAL tready_block_req : STD_LOGIC := '0';

    CONSTANT clk_period : TIME := 10 ns;

BEGIN

    clk <= NOT clk AFTER clk_period / 2; -- Clock generation

    -- Asynchronous tready block process (simulate downstream backpressure)
    PROCESS (clk)
        VARIABLE block_counter : INTEGER := 0;
        VARIABLE tready_blocked : BOOLEAN := FALSE;
    BEGIN
        IF rising_edge(clk) THEN
            IF tready_block_req = '1' AND NOT tready_blocked THEN
                tready_blocked := TRUE;
                block_counter := 0;
            END IF;

            IF tready_blocked THEN
                IF block_counter < 6 THEN
                    m_axis_tready <= '0';
                    block_counter := block_counter + 1;
                ELSE
                    m_axis_tready <= '1';
                    tready_blocked := FALSE;
                    block_counter := 0;
                END IF;
            ELSE
                m_axis_tready <= '1';
            END IF;
        END IF;
    END PROCESS;

    -- Instantiate the Device Under Test (DUT)
    DUT : rgb2gray
    PORT MAP(
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
    BEGIN
        -- Reset
        resetn <= '0';
        WAIT FOR 20 ns;
        resetn <= '1';
        WAIT UNTIL rising_edge(clk);

        -- Start tready block asynchronously after 40 ns
        WAIT FOR 40 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        -- Send 3 RGB pixels (9 bytes)
        FOR i IN 0 TO 2 LOOP
            FOR j IN 0 TO 2 LOOP
                s_axis_tdata <= rgb_mem(i, j);
                s_axis_tvalid <= '1';
                IF i = 2 AND j = 2 THEN
                    s_axis_tlast <= '1';
                ELSE
                    s_axis_tlast <= '0';
                END IF;
                -- Wait for handshake
                WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
                s_axis_tvalid <= '0';
            END LOOP;
        END LOOP;
        s_axis_tlast <= '0';

        -- Wait, then send 2 more RGB pixels
        WAIT FOR 30 ns;
        FOR i IN 3 TO 4 LOOP
            FOR j IN 0 TO 2 LOOP
                s_axis_tdata <= rgb_mem(i, j);
                s_axis_tvalid <= '1';
                IF i = 4 AND j = 2 THEN
                    s_axis_tlast <= '1';
                ELSE
                    s_axis_tlast <= '0';
                END IF;
                WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
                s_axis_tvalid <= '0';
            END LOOP;
        END LOOP;
        s_axis_tlast <= '0';

        -- Start another tready block asynchronously
        WAIT FOR 30 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        -- Send 2 more RGB pixels
        WAIT FOR 20 ns;
        FOR i IN 5 TO 6 LOOP
            FOR j IN 0 TO 2 LOOP
                s_axis_tdata <= rgb_mem(i, j);
                s_axis_tvalid <= '1';
                IF i = 6 AND j = 2 THEN
                    s_axis_tlast <= '1';
                ELSE
                    s_axis_tlast <= '0';
                END IF;
                WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
                s_axis_tvalid <= '0';
            END LOOP;
        END LOOP;
        s_axis_tlast <= '0';

        -- Send last 2 RGB pixels
        FOR i IN 7 TO 8 LOOP
            FOR j IN 0 TO 2 LOOP
                s_axis_tdata <= rgb_mem(i, j);
                s_axis_tvalid <= '1';
                IF i = 8 AND j = 2 THEN
                    s_axis_tlast <= '1';
                ELSE
                    s_axis_tlast <= '0';
                END IF;
                WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
                s_axis_tvalid <= '0';
            END LOOP;
        END LOOP;
        s_axis_tlast <= '0';

        WAIT;
    END PROCESS;

END Behavioral;