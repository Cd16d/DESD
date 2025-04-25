----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/16/2025 04:23:36 PM
-- Design Name: 
-- Module Name: img_conv_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY img_conv_tb IS
    --  Port ( );
END img_conv_tb;

ARCHITECTURE Behavioral OF img_conv_tb IS

    COMPONENT img_conv IS
        GENERIC (
            LOG2_N_COLS : POSITIVE := 8;
            LOG2_N_ROWS : POSITIVE := 8
        );
        PORT (

            clk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;

            m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tready : IN STD_LOGIC;
            m_axis_tlast : OUT STD_LOGIC;

            conv_addr : OUT STD_LOGIC_VECTOR(LOG2_N_COLS + LOG2_N_ROWS - 1 DOWNTO 0);
            conv_data : IN STD_LOGIC_VECTOR(6 DOWNTO 0);

            start_conv : IN STD_LOGIC;
            done_conv : OUT STD_LOGIC

        );
    END COMPONENT;

    CONSTANT LOG2_N_COLS : POSITIVE := 2;
    CONSTANT LOG2_N_ROWS : POSITIVE := 2;

    TYPE mem_type IS ARRAY(0 TO (2 ** LOG2_N_COLS) * (2 ** LOG2_N_ROWS) - 1) OF STD_LOGIC_VECTOR(6 DOWNTO 0);

    -- Fill memory with more varied values
    SIGNAL mem : mem_type := (
        0 => "0000001",
        1 => "0101010",
        2 => "0011100",
        3 => "1110001",
        4 => "0001011",
        5 => "0110110",
        6 => "1001001",
        7 => "1111111",
        8 => "0000111",
        9 => "0010010",
        10 => "0100101",
        11 => "0111000",
        12 => "1001100",
        13 => "1011011",
        14 => "1100110",
        15 => "1010101"
    );

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL aresetn : STD_LOGIC := '0';

    SIGNAL m_axis_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL m_axis_tvalid : STD_LOGIC;
    SIGNAL m_axis_tready : STD_LOGIC;
    SIGNAL m_axis_tlast : STD_LOGIC;

    SIGNAL conv_addr : STD_LOGIC_VECTOR(LOG2_N_COLS + LOG2_N_ROWS - 1 DOWNTO 0);
    SIGNAL conv_data : STD_LOGIC_VECTOR(6 DOWNTO 0);

    SIGNAL start_conv : STD_LOGIC;
    SIGNAL done_conv : STD_LOGIC;

    SIGNAL tready_block_req : STD_LOGIC := '0';

BEGIN

    -- m_axis_tready logic with blocking step
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
                IF block_counter < 19 THEN
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

    clk <= NOT clk AFTER 5 ns;

    PROCESS (clk)
    BEGIN
        IF (rising_edge(clk)) THEN
            conv_data <= mem(to_integer(unsigned(conv_addr)));
        END IF;
    END PROCESS;

    img_conv_inst : img_conv
    GENERIC MAP(
        LOG2_N_COLS => LOG2_N_COLS,
        LOG2_N_ROWS => LOG2_N_ROWS
    )
    PORT MAP(
        clk => clk,
        aresetn => aresetn,
        m_axis_tdata => m_axis_tdata,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tready => m_axis_tready,
        m_axis_tlast => m_axis_tlast,
        conv_addr => conv_addr,
        conv_data => conv_data,
        start_conv => start_conv,
        done_conv => done_conv
    );

    PROCESS
    BEGIN
        WAIT FOR 10 ns;
        aresetn <= '1';
        WAIT UNTIL rising_edge(clk);
        start_conv <= '1';
        WAIT UNTIL rising_edge(clk);
        start_conv <= '0';

        -- Wait some cycles, then request tready block for 10 cycles
        WAIT FOR 200 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        WAIT FOR 300 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        WAIT FOR 200 ns;
        tready_block_req <= '1';
        WAIT UNTIL rising_edge(clk);
        tready_block_req <= '0';

        WAIT;
    END PROCESS;
END Behavioral;