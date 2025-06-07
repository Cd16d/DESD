----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/20/2025
-- Design Name: 
-- Module Name: tb_volume_saturator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: Vivado 2020.2
-- Description: Testbench for volume_saturator (stereo, L->R, tlast on R)
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_volume_saturator IS
END tb_volume_saturator;

ARCHITECTURE Behavioral OF tb_volume_saturator IS

    CONSTANT TDATA_WIDTH : POSITIVE := 24;
    CONSTANT VOLUME_WIDTH : POSITIVE := 10;
    CONSTANT VOLUME_STEP_2 : POSITIVE := 6;
    CONSTANT STEREO_SAMPLES : INTEGER := 8;

    -- Calculate s_axis_tdata width
    CONSTANT TDATA_IN_WIDTH : INTEGER := TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) + 1;

    COMPONENT volume_saturator IS
        GENERIC (
            TDATA_WIDTH : POSITIVE := 24;
            VOLUME_WIDTH : POSITIVE := 10;
            VOLUME_STEP_2 : POSITIVE := 6; -- i.e., number_of_steps = 2**(VOLUME_STEP_2)
            HIGHER_BOUND : INTEGER := 2 ** 15 - 1; -- Inclusive
            LOWER_BOUND : INTEGER := - 2 ** 15 -- Inclusive
        );
        PORT (
            aclk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;

            s_axis_tvalid : IN STD_LOGIC;
            s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0);
            s_axis_tlast : IN STD_LOGIC;
            s_axis_tready : OUT STD_LOGIC;

            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
            m_axis_tlast : OUT STD_LOGIC;
            m_axis_tready : IN STD_LOGIC
        );
    END COMPONENT;

    SIGNAL aclk : STD_LOGIC := '0';
    SIGNAL aresetn : STD_LOGIC := '0';
    SIGNAL s_axis_tvalid : STD_LOGIC := '0';
    SIGNAL s_axis_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tlast : STD_LOGIC := '0';
    SIGNAL s_axis_tready : STD_LOGIC;
    SIGNAL m_axis_tvalid : STD_LOGIC;
    SIGNAL m_axis_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
    SIGNAL m_axis_tlast : STD_LOGIC;
    SIGNAL m_axis_tready : STD_LOGIC := '1';

    -- Example stereo audio: L, R, L, R, ... (tlast on R)
    TYPE stereo_mem_type IS ARRAY(0 TO 2 * STEREO_SAMPLES - 1) OF STD_LOGIC_VECTOR(TDATA_IN_WIDTH - 1 DOWNTO 0);
    SIGNAL stereo_mem : stereo_mem_type := (
        x"00009C40", -- +40000   (clipping positivo)
        x"00007FFF", -- +32767   (HIGHER_BOUND)
        x"00007FFE", -- +32766   (appena sotto HIGHER_BOUND)
        x"00000000", -- 0
        x"FFFF8001", -- -32767   (appena sopra LOWER_BOUND)
        x"FFFF8000", -- -32768   (LOWER_BOUND)
        x"FFFF63C0", -- -40000   (clipping negativo)
        x"00003039", -- +12345   (valore positivo intermedio)
        x"FFFFCFC7", -- -12345   (valore negativo intermedio)
        x"00007FFF", -- +32767   (HIGHER_BOUND, ripetuto)
        x"FFFF8000", -- -32768   (LOWER_BOUND, ripetuto)
        x"00009C40", -- +40000   (clipping positivo, ripetuto)
        x"FFFF63C0", -- -40000   (clipping negativo, ripetuto)
        x"00000001", -- +1
        x"FFFFFFFF", -- -1
        x"00000000"  -- 0 (ripetuto)
    );

BEGIN

    -- Clock generation
    aclk <= NOT aclk AFTER 5 ns;

    -- DUT instantiation
    uut : volume_saturator
    GENERIC MAP(
        TDATA_WIDTH => TDATA_WIDTH,
        VOLUME_WIDTH => VOLUME_WIDTH,
        VOLUME_STEP_2 => VOLUME_STEP_2,
        HIGHER_BOUND => 2 ** 15 - 1,
        LOWER_BOUND => - 2 ** 15
    )
    PORT MAP(
        aclk => aclk,
        aresetn => aresetn,
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tdata => s_axis_tdata,
        s_axis_tlast => s_axis_tlast,
        s_axis_tready => s_axis_tready,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tdata => m_axis_tdata,
        m_axis_tlast => m_axis_tlast,
        m_axis_tready => m_axis_tready
    );

    -- Stimulus process: send stereo samples, tlast on R
    stimulus : PROCESS
    BEGIN
        -- Reset
        WAIT FOR 10 ns;
        aresetn <= '1';
        WAIT UNTIL rising_edge(aclk);

        FOR i IN 0 TO stereo_mem'high LOOP
            s_axis_tdata <= stereo_mem(i);
            s_axis_tvalid <= '1';
            -- tlast asserted on every R channel (odd index)
            IF (i MOD 2) = 1 THEN
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
        s_axis_tlast <= '0';

        -- Wait and finish
        WAIT FOR 100 ns;
        WAIT;
    END PROCESS;

    -- Optionally, block m_axis_tready for a few cycles to test backpressure
    PROCESS
    BEGIN
        WAIT FOR 80 ns;
        WAIT UNTIL rising_edge(aclk);
        m_axis_tready <= '0';
        WAIT FOR 30 ns;
        WAIT UNTIL rising_edge(aclk);
        m_axis_tready <= '1';
        WAIT;
    END PROCESS;

END Behavioral;