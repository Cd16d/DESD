----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.03.2025 15:23:11
-- Design Name: 
-- Module Name: PulseWidthModulator - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PulseWidthModulator is
    Generic(
        BIT_LENGTH  : INTEGER RANGE 1 to 16 := 8;
        T_ON_INIT   : POSITIVE := 64;   
        PERIOD_INIT : POSITIVE := 128;             
        PWM_INIT    : STD_LOGIC := '0'
    );
    Port (
        reset   : IN STD_LOGIC;
        clk     : IN STD_LOGIC;
        
        Ton     : IN std_logic_vector(BIT_LENGTH-1 downto 0);
        Period  : IN std_logic_vector(BIT_LENGTH-1 downto 0);
        PWM     : OUT std_logic
    );
 end PulseWidthModulator;

architecture Behavioral of PulseWidthModulator is
    signal counter : unsigned(BIT_LENGTH-1 downto 0) := (others => '0');
    signal pwm_out : std_logic;
begin

    process(clk, reset)
    begin
        if reset = '1' then
            counter  <= (others => '0');
            pwm_out  <= '0';  -- Assicura PWM spento al reset
        elsif rising_edge(clk) then
            if counter = unsigned(period) then
                counter <= (others => '0');  -- Reset counter
            else
                counter <= counter + 1;  -- Incrementa il counter
            end if;

            -- Accendi il PWM all'inizio di ogni ciclo
            if counter = 0 then
                pwm_out <= '1';  
            end if;

            -- Spegni il PWM quando il contatore raggiunge Ton
            if counter = unsigned(Ton) then
                pwm_out <= '0';
            end if;
        end if;
    end process;

    PWM <= pwm_out; -- Output PWM

end Behavioral;

