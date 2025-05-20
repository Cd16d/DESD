----------------------------------------------------------------------------------
-- Testbench for volume_multiplier
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_volume_multiplier IS
END tb_volume_multiplier;

ARCHITECTURE Behavioral OF tb_volume_multiplier IS

    CONSTANT TDATA_WIDTH   : POSITIVE := 24;
    CONSTANT VOLUME_WIDTH  : POSITIVE := 10;
    CONSTANT VOLUME_STEP_2 : POSITIVE := 6;
    CONSTANT N_SAMPLES     : INTEGER  := 8;

    -- Output width calculation (as in DUT)
    CONSTANT TDATA_OUT_WIDTH : INTEGER := TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) + 1;

    COMPONENT volume_multiplier IS
        GENERIC (
            TDATA_WIDTH   : POSITIVE := 24;
            VOLUME_WIDTH  : POSITIVE := 10;
            VOLUME_STEP_2 : POSITIVE := 6
        );
        PORT (
            aclk           : IN  STD_LOGIC;
            aresetn        : IN  STD_LOGIC;
            s_axis_tvalid  : IN  STD_LOGIC;
            s_axis_tdata   : IN  STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
            s_axis_tlast   : IN  STD_LOGIC;
            s_axis_tready  : OUT STD_LOGIC;
            m_axis_tvalid  : OUT STD_LOGIC;
            m_axis_tdata   : OUT STD_LOGIC_VECTOR(TDATA_OUT_WIDTH - 1 DOWNTO 0);
            m_axis_tlast   : OUT STD_LOGIC;
            m_axis_tready  : IN  STD_LOGIC;
            volume         : IN  STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL aclk          : STD_LOGIC := '0';
    SIGNAL aresetn       : STD_LOGIC := '0';
    SIGNAL s_axis_tvalid : STD_LOGIC := '0';
    SIGNAL s_axis_tdata  : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tlast  : STD_LOGIC := '0';
    SIGNAL s_axis_tready : STD_LOGIC;
    SIGNAL m_axis_tvalid : STD_LOGIC;
    SIGNAL m_axis_tdata  : STD_LOGIC_VECTOR(TDATA_OUT_WIDTH - 1 DOWNTO 0);
    SIGNAL m_axis_tlast  : STD_LOGIC;
    SIGNAL m_axis_tready : STD_LOGIC := '1';
    SIGNAL volume        : STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');

    -- Test input samples
    TYPE sample_mem_type IS ARRAY(0 TO N_SAMPLES-1) OF STD_LOGIC_VECTOR(TDATA_WIDTH-1 DOWNTO 0);
    SIGNAL sample_mem : sample_mem_type := (
        x"000100", -- +256
        x"FFFE00", -- -512
        x"000001", -- +1
        x"FFFFFF", -- -1 (2's comp)
        x"7FFFFF", -- max positive
        x"800000", -- max negative
        x"000A00", -- +2560
        x"FFF600"  -- -2560
    );

BEGIN

    -- Clock generation
    aclk <= NOT aclk AFTER 5 ns;

    -- DUT instantiation
    uut: volume_multiplier
    GENERIC MAP (
        TDATA_WIDTH   => TDATA_WIDTH,
        VOLUME_WIDTH  => VOLUME_WIDTH,
        VOLUME_STEP_2 => VOLUME_STEP_2
    )
    PORT MAP (
        aclk           => aclk,
        aresetn        => aresetn,
        s_axis_tvalid  => s_axis_tvalid,
        s_axis_tdata   => s_axis_tdata,
        s_axis_tlast   => s_axis_tlast,
        s_axis_tready  => s_axis_tready,
        m_axis_tvalid  => m_axis_tvalid,
        m_axis_tdata   => m_axis_tdata,
        m_axis_tlast   => m_axis_tlast,
        m_axis_tready  => m_axis_tready,
        volume         => volume
    );

    -- Stimulus process
    stimulus : PROCESS
    BEGIN
        -- Reset
        WAIT FOR 10 ns;
        aresetn <= '1';
        WAIT UNTIL rising_edge(aclk);

        -- Set volume to mid (no gain/loss)
        volume <= std_logic_vector(to_unsigned(511, VOLUME_WIDTH));
        WAIT UNTIL rising_edge(aclk);

        -- Send all samples
        FOR i IN 0 TO N_SAMPLES-1 LOOP
            s_axis_tdata  <= sample_mem(i);
            s_axis_tvalid <= '1';
            IF i = N_SAMPLES-1 THEN
                s_axis_tlast <= '1';
            ELSE
                s_axis_tlast <= '0';
            END IF;
            -- Wait for handshake
            WAIT UNTIL rising_edge(aclk);
            WHILE s_axis_tready = '0' LOOP
                WAIT UNTIL rising_edge(aclk);
            END LOOP;
        END LOOP;
        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';

        -- Change volume (attenuate)
        WAIT FOR 20 ns;
        volume <= std_logic_vector(to_unsigned(256, VOLUME_WIDTH)); -- attenuate

        -- Send one more sample
        WAIT UNTIL rising_edge(aclk);
        s_axis_tdata  <= x"000100";
        s_axis_tvalid <= '1';
        s_axis_tlast  <= '1';
        WAIT UNTIL rising_edge(aclk);
        WHILE s_axis_tready = '0' LOOP
            WAIT UNTIL rising_edge(aclk);
        END LOOP;
        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';

        -- Wait and finish
        WAIT FOR 100 ns;
        WAIT;
    END PROCESS;

    -- Optionally, block m_axis_tready to test backpressure
    PROCESS
    BEGIN
        WAIT FOR 60 ns;
        WAIT UNTIL rising_edge(aclk);
        m_axis_tready <= '0';
        WAIT FOR 20 ns;
        WAIT UNTIL rising_edge(aclk);
        m_axis_tready <= '1';
        WAIT;
    END PROCESS;

END Behavioral;