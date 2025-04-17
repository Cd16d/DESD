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
-- Description: Testbench for bram_writer, stimulus and timing inspired by tb_img_conv.vhd
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
END ENTITY;

ARCHITECTURE sim OF tb_bram_writer IS

    -- Testbench constants
    CONSTANT ADDR_WIDTH : POSITIVE := 4;
    CONSTANT IMG_SIZE   : POSITIVE := 2; -- Small size for quick simulation

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

    -- Instantiate DUT
    COMPONENT bram_writer IS
        GENERIC (
            ADDR_WIDTH : POSITIVE := 4;
            IMG_SIZE   : POSITIVE := 2
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
            start_conv    : OUT STD_LOGIC;
            done_conv     : IN  STD_LOGIC;
            write_ok      : OUT STD_LOGIC;
            overflow      : OUT STD_LOGIC;
            underflow     : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN

    -- Clock generation
    clk <= not clk after 5 ns;

    -- Instantiate DUT
    bram_writer_inst: bram_writer
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
    stimulus : process
    begin
        -- Initial reset
        aresetn <= '0';
        wait for 10 ns;
        aresetn <= '1';
        wait until rising_edge(clk);

        -- Send IMG_SIZE*IMG_SIZE data words
        for i in 0 to IMG_SIZE*IMG_SIZE-1 loop
            s_axis_tdata  <= std_logic_vector(to_unsigned(i, 8));
            s_axis_tvalid <= '1';
            if i = IMG_SIZE*IMG_SIZE-1 then
                s_axis_tlast <= '1';
            else
                s_axis_tlast <= '0';
            end if;
            wait until rising_edge(clk);
            -- Wait for ready
            while s_axis_tready /= '1' loop
                wait until rising_edge(clk);
            end loop;
        end loop;
        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';

        -- Wait for write_ok and start_conv
        wait until write_ok = '1';
        wait until rising_edge(clk);

        -- Simulate convolution done
        done_conv <= '1';
        wait until rising_edge(clk);
        done_conv <= '0';

        -- Wait and finish
        wait for 20 ns;
        assert false report "Simulation finished." severity note;
        wait;
    end process;

END ARCHITECTURE;