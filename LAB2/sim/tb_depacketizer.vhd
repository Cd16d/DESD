----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/21/2025
-- Design Name: 
-- Module Name: tb_depacketizer - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testbench for depacketizer
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_depacketizer IS
END tb_depacketizer;

ARCHITECTURE Behavioral OF tb_depacketizer IS

    COMPONENT depacketizer IS
        GENERIC (
            HEADER : INTEGER := 16#FF#;
            FOOTER : INTEGER := 16#F1#
        );
        PORT (
            clk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;

            s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_tvalid : IN STD_LOGIC;
            s_axis_tready : OUT STD_LOGIC;

            m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tready : IN STD_LOGIC;
            m_axis_tlast : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Constants
    CONSTANT HEADER : INTEGER := 16#FF#;
    CONSTANT FOOTER : INTEGER := 16#F1#;

    -- Signals
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL aresetn : STD_LOGIC := '0';

    SIGNAL s_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tvalid : STD_LOGIC := '0';
    SIGNAL s_axis_tready : STD_LOGIC;

    SIGNAL m_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL m_axis_tvalid : STD_LOGIC;
    SIGNAL m_axis_tready : STD_LOGIC := '1';
    SIGNAL m_axis_tlast : STD_LOGIC;

    -- Stimulus memory
    TYPE mem_type IS ARRAY(0 TO 7) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mem : mem_type := (
        0 => x"10",
        1 => x"20",
        2 => x"30",
        3 => x"04",
        4 => x"54",
        5 => x"65",
        6 => x"73",
        7 => x"50"
    );

    SIGNAL tready_block_req : STD_LOGIC := '0';

BEGIN

    -- Clock generation
    clk <= NOT clk AFTER 5 ns;

    -- Asynchronous tready block process
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
                IF block_counter < 9 THEN
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

    -- DUT instantiation
    uut: depacketizer
        PORT MAP (
            clk => clk,
            aresetn => aresetn,

            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,

            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast
        );

    -- Stimulus process
    PROCESS
    BEGIN
        -- Reset
        aresetn <= '0';
        WAIT FOR 20 ns;
        aresetn <= '1';
        WAIT UNTIL rising_edge(clk);

        -- Start tready block asynchronously after 60 ns
        WAIT FOR 60 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        -- Send 4 data words as a packet with Header and Footer
        -- Header
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(HEADER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Data
        FOR i IN 0 TO 3 LOOP
            s_axis_tdata <= mem(i);
            s_axis_tvalid <= '1';
            WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
            s_axis_tvalid <= '0';
        END LOOP;

        -- Footer
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(FOOTER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Wait a bit, then send another packet of 2 words with Header and Footer
        WAIT FOR 50 ns;

        -- Header
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(HEADER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Data
        FOR i IN 4 TO 5 LOOP
            s_axis_tdata <= mem(i);
            s_axis_tvalid <= '1';
            WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
            s_axis_tvalid <= '0';
        END LOOP;

        -- Footer
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(FOOTER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Start another tready block asynchronously
        WAIT FOR 40 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        -- Send packet of 3 words with Header and Footer
        WAIT FOR 30 ns;

        -- Header
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(HEADER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Data
        FOR i IN 5 TO 7 LOOP
            s_axis_tdata <= mem(i);
            s_axis_tvalid <= '1';
            WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
            s_axis_tvalid <= '0';
        END LOOP;

        -- Footer
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(FOOTER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Send packet of 4 words without initial waiting, with Header and Footer
        -- Header
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(HEADER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        -- Data
        FOR i IN 2 TO 6 LOOP
            s_axis_tdata <= mem(i);
            s_axis_tvalid <= '1';
            WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
            s_axis_tvalid <= '0';
        END LOOP;

        -- Footer
        s_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(FOOTER, 8));
        s_axis_tvalid <= '1';
        WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
        s_axis_tvalid <= '0';

        WAIT;
    END PROCESS;

END Behavioral;