library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity led_blinker is
    generic (
        CLK_PERIOD_NS: POSITIVE :=10;
        BLINK_PERIOD_MS : POSITIVE :=1000;
        N_BLINKS : POSITIVE := 4
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;
        start_blink : in std_logic;
        led: out std_logic
    );
end entity led_blinker;

architecture rtl of led_blinker is

  
begin

  
    

end architecture;
