----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/17/2025
-- Design Name: 
-- Module Name: tb_bram_writer - sim
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testbench for bram_writer, rewritten in the style of tb_packetizer.vhd
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

ENTITY tb_bram_writer IS
END tb_bram_writer;

ARCHITECTURE sim OF tb_bram_writer IS

    -- Testbench constants
    CONSTANT ADDR_WIDTH : POSITIVE := 4;
    CONSTANT IMG_SIZE   : POSITIVE := 4; -- Increased size for more memory

    -- Component declaration for bram_writer
    COMPONENT bram_writer IS
        GENERIC (
            ADDR_WIDTH : POSITIVE;
            IMG_SIZE   : POSITIVE
        );
        PORT (
            clk           : IN  STD_LOGIC;
            aresetn       : IN  STD_LOGIC;
            s_axis_tdata  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_tvalid : IN  STD_LOGIC;
            s_axis_tready : OUT STD_LOGIC;
            s_axis_tlast  : IN  STD_LOGIC;
            conv_addr     : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1 DOWNTO 0);
            conv_data     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
            start_conv    : OUT  STD_LOGIC;
            done_conv     : IN  STD_LOGIC;
            write_ok      : OUT STD_LOGIC;
            overflow      : OUT STD_LOGIC;
            underflow     : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Signals for DUT
    SIGNAL clk           : STD_LOGIC := '0';
    SIGNAL aresetn       : STD_LOGIC := '0';
    SIGNAL s_axis_tdata  : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tvalid : STD_LOGIC := '0';
    SIGNAL s_axis_tready : STD_LOGIC;
    SIGNAL s_axis_tlast  : STD_LOGIC := '0';
    SIGNAL conv_addr     : STD_LOGIC_VECTOR(ADDR_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL conv_data     : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL start_conv    : STD_LOGIC;
    SIGNAL done_conv     : STD_LOGIC := '0';
    SIGNAL write_ok      : STD_LOGIC;
    SIGNAL overflow      : STD_LOGIC;
    SIGNAL underflow     : STD_LOGIC;

    -- Stimulus memory for input data
    TYPE mem_type IS ARRAY(0 TO (IMG_SIZE*IMG_SIZE)-1) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mem : mem_type := (
         0  => x"3A",
         1  => x"7F",
         2  => x"12",
         3  => x"9C",
         4  => x"55",
         5  => x"2B",
         6  => x"81",
         7  => x"04",
         8  => x"6E",
         9  => x"F2",
         10 => x"1D",
         11 => x"C7",
         12 => x"99",
         13 => x"0A",
         14 => x"B3",
         15 => x"5D"
    );

BEGIN

    -- Clock generation
    clk <= NOT clk AFTER 5 ns;

    -- DUT instantiation
    uut: bram_writer
        GENERIC MAP (
            ADDR_WIDTH => ADDR_WIDTH,
            IMG_SIZE   => IMG_SIZE
        )
        PORT MAP (
            clk           => clk,
            aresetn       => aresetn,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast  => s_axis_tlast,
            conv_addr     => conv_addr,
            conv_data     => conv_data,
            start_conv    => start_conv,
            done_conv     => done_conv,
            write_ok      => write_ok,
            overflow      => overflow,
            underflow     => underflow
        );

    -- Stimulus process
    stimulus : PROCESS
    BEGIN
        -- Reset
        aresetn <= '0';
        WAIT FOR 20 ns;
        aresetn <= '1';
        WAIT UNTIL rising_edge(clk);

        -- Send IMG_SIZE*IMG_SIZE data words
        FOR i IN 0 TO IMG_SIZE*IMG_SIZE-1 LOOP
            s_axis_tdata  <= mem(i);
            s_axis_tvalid <= '1';
            IF i = IMG_SIZE*IMG_SIZE-1 THEN
                s_axis_tlast <= '1';
            ELSE
                s_axis_tlast <= '0';
            END IF;
            -- Wait for handshake
            WAIT UNTIL s_axis_tvalid = '1' AND s_axis_tready = '1' AND rising_edge(clk);
            s_axis_tvalid <= '0';
        END LOOP;
        s_axis_tlast <= '0';

        -- Wait for write_ok and start_conv
        WAIT UNTIL write_ok = '1';
        WAIT UNTIL rising_edge(clk);

        -- Read out data using conv_addr
        FOR i IN 0 TO IMG_SIZE*IMG_SIZE-1 LOOP
            conv_addr <= std_logic_vector(to_unsigned(i, ADDR_WIDTH));
            WAIT UNTIL rising_edge(clk);
        END LOOP;

        -- Simulate convolution done
        done_conv <= '1';
        WAIT UNTIL rising_edge(clk);
        done_conv <= '0';

        -- Wait and finish
        WAIT;
    END PROCESS;

END sim;