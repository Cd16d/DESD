----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.03.2025 15:06:26
-- Design Name: 
-- Module Name: ShiftRegister_v1 - Behavioral
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

entity ShiftRegister_v1 is
    Generic (
        SR_DEPTH : POSITIVE := 4;
        SR_INIT : STD_LOGIC := '0'
    );
    Port (
        reset : in STD_LOGIC;
        clk : in STD_LOGIC;
        din : in STD_LOGIC;
        dout : out STD_LOGIC
    );
end ShiftRegister_v1;

architecture Behavioral of ShiftRegister_v1 is
    signal sr : STD_LOGIC_VECTOR(SR_DEPTH-1 DOWNTO 0) := (others => '0');
begin

    process(clk, reset)
    begin
        if reset = '1' then
            sr <= (others => SR_INIT);
        elsif rising_edge(clk) then
            sr <= sr(SR_DEPTH-2 DOWNTO 0) & din;
        end if;
    end process;
    
    dout <= sr(SR_DEPTH-1);

end Behavioral;
