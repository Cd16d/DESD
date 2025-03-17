----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.03.2025 14:21:16
-- Design Name: 
-- Module Name: shift_register_v0 - Behavioral
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

entity shift_register_v0 is
    Port ( reset : in STD_LOGIC;
           clk : in STD_LOGIC;
           din : in STD_LOGIC;
           dout : out STD_LOGIC);
end shift_register_v0;

architecture Behavioral of shift_register_v0 is
    signal sr : std_logic := '0';
begin

    process(clk, reset)
    begin
        if reset = '1' then
            sr <= '0';
        elsif rising_edge(clk) then
            sr <= din;
        end if;
    end process;
    
    dout <= sr;

end Behavioral;
