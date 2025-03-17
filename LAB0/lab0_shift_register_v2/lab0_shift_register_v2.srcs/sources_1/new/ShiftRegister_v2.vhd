----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.03.2025 15:35:08
-- Design Name: 
-- Module Name: ShiftRegister_v2 - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ShiftRegister_v2 is
    Generic (
        SR_WIDTH : NATURAL := 8;
        SR_DEPTH : POSITIVE := 4;
        SR_INIT : STD_LOGIC := '0'
    );
    Port (
        reset : in STD_LOGIC;
        clk : in STD_LOGIC;
        din : in STD_LOGIC_VECTOR(SR_WIDTH-1 downto 0);
        dout : out STD_LOGIC_VECTOR(SR_WIDTH-1 downto 0)
    );
end ShiftRegister_v2;

architecture Behavioral of ShiftRegister_v2 is
    type sr_type is array (SR_DEPTH-1 downto 0) of std_logic_vector(SR_WIDTH-1 downto 0);

    signal sr : sr_type := (others => (others => SR_INIT));
begin

    process(reset,clk)
    begin
        if reset = '1' then
            sr <= (others => (others => SR_INIT));
        elsif rising_edge(clk) then
            sr <= sr(SR_DEPTH-2 downto 0) & din;
        end if;
    end process;
    
    dout <= sr(SR_DEPTH-1);

end Behavioral;
