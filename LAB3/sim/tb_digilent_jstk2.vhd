----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/13/2025
-- Design Name: 
-- Module Name: tb_digilent_jstk2 - sim
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testbench for digilent_jstk2, sends data only after CMDSETLEDRGB is received
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_digilent_jstk2 IS
END tb_digilent_jstk2;

ARCHITECTURE sim OF tb_digilent_jstk2 IS

    -- Testbench constants
    CONSTANT CLKFREQ : INTEGER := 100_000_000;
    CONSTANT DELAY_US : INTEGER := 25;
    CONSTANT SPI_SCLKFREQ : INTEGER := 66_666;
    CONSTANT CMDSETLEDRGB : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"84";

    -- Component declaration for digilent_jstk2
    COMPONENT digilent_jstk2 IS
        GENERIC (
            DELAY_US : INTEGER;
            CLKFREQ : INTEGER;
            SPI_SCLKFREQ : INTEGER
        );
        PORT (
            aclk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;
            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axis_tready : IN STD_LOGIC;
            s_axis_tvalid : IN STD_LOGIC;
            s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            jstk_x : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            jstk_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            btn_jstk : OUT STD_LOGIC;
            btn_trigger : OUT STD_LOGIC;
            led_r : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            led_g : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            led_b : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    END COMPONENT;

    -- Signals for DUT
    SIGNAL aclk : STD_LOGIC := '0';
    SIGNAL aresetn : STD_LOGIC := '0';
    SIGNAL m_axis_tvalid : STD_LOGIC;
    SIGNAL m_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL m_axis_tready : STD_LOGIC := '1'; -- Always ready in TB
    SIGNAL s_axis_tvalid : STD_LOGIC := '0';
    SIGNAL s_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL jstk_x : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL jstk_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL btn_jstk : STD_LOGIC;
    SIGNAL btn_trigger : STD_LOGIC;
    SIGNAL led_r : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"AA";
    SIGNAL led_g : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"55";
    SIGNAL led_b : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"FF";

    -- Stimulus memory for SPI responses (simulate JSTK2 module)
    TYPE spi_mem_type IS ARRAY(0 TO 4) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL spi_mem : spi_mem_type := (
        0 => x"34", -- JSTK_X_LOW
        1 => x"02", -- JSTK_X_HIGH (2 LSBs used)
        2 => x"56", -- JSTK_Y_LOW
        3 => x"01", -- JSTK_Y_HIGH (2 LSBs used)
        4 => "00000011" -- BUTTONS: btn_jstk='1', btn_trigger='1'
    );

BEGIN

    -- Clock generation
    aclk <= NOT aclk AFTER 5 ns;

    -- DUT instantiation
    uut : digilent_jstk2
    GENERIC MAP(
        DELAY_US => DELAY_US,
        CLKFREQ => CLKFREQ,
        SPI_SCLKFREQ => SPI_SCLKFREQ
    )
    PORT MAP(
        aclk => aclk,
        aresetn => aresetn,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tdata => m_axis_tdata,
        m_axis_tready => m_axis_tready,
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tdata => s_axis_tdata,
        jstk_x => jstk_x,
        jstk_y => jstk_y,
        btn_jstk => btn_jstk,
        btn_trigger => btn_trigger,
        led_r => led_r,
        led_g => led_g,
        led_b => led_b
    );

    -- Stimulus process
    stimulus : PROCESS
        VARIABLE send_data : BOOLEAN := FALSE;
        VARIABLE mem_idx : INTEGER := 0;
    BEGIN
        -- Reset
        aresetn <= '0';
        WAIT FOR 20 ns;
        aresetn <= '1';
        WAIT UNTIL rising_edge(aclk);

        -- Wait for the DUT to start sending SPI packets
        WAIT FOR 1000 ns;

        -- Main loop: wait for CMDSETLEDRGB, then send mem bytes for each byte received
        WHILE TRUE LOOP
            WAIT UNTIL rising_edge(aclk);

            -- Default: s_axis_tvalid low unless sending
            s_axis_tvalid <= '0';

            IF m_axis_tvalid = '1' THEN
                IF m_axis_tdata = CMDSETLEDRGB THEN
                    send_data := TRUE;
                    mem_idx := 0;
                END IF;

                IF send_data AND mem_idx <= 4 THEN
                    -- Present data for one cycle when master is ready
                    s_axis_tdata <= spi_mem(mem_idx);
                    s_axis_tvalid <= '1';
                    WAIT UNTIL rising_edge(aclk); -- handshake
                    s_axis_tvalid <= '0';
                    mem_idx := mem_idx + 1;
                    -- Simula il tempo di risposta reale del JSTK2 (1,6 ms per byte)
                    WAIT FOR 1600 us;
                    IF mem_idx > 4 THEN
                        send_data := FALSE;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END PROCESS;

END sim;