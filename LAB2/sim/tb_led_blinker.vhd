library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_led_blinker is
end entity;

architecture behavior of tb_led_blinker is
    -- Constants
    constant CLK_PERIOD_NS   : time := 10 ns;
    constant BLINK_PERIOD_MS : integer := 1000;
    constant N_BLINKS        : integer := 4;

    -- DUT signals
    signal clk         : std_logic := '0';
    signal aresetn     : std_logic := '0';
    signal start_blink : std_logic := '0';
    signal led         : std_logic;

begin
    -- Clock process
    clk_process : process
    begin
        while true loop
            clk <= not clk;
            wait for CLK_PERIOD_NS / 2;
        end loop;
    end process;

    -- Instantiate DUT
    uut: entity work.led_blinker
        generic map (
            CLK_PERIOD_NS   => 10,
            BLINK_PERIOD_MS => BLINK_PERIOD_MS,
            N_BLINKS        => N_BLINKS
        )
        port map (
            clk         => clk,
            aresetn     => aresetn,
            start_blink => start_blink,
            led         => led
        );

    -- Stimulus process
    stimulus : process
    begin
        -- Reset
        aresetn <= '0';
        wait for 50 ns;
        aresetn <= '1';
        wait for 50 ns;

        -- Primo impulso di start_blink
        start_blink <= '1';
        wait for 10 ns;
        start_blink <= '0';

        -- Aspetta metà blinking, poi rilancia start_blink
        wait for 3 sec;

        -- Secondo impulso (durante blinking)
        start_blink <= '1';
        wait for 10 ns;
        start_blink <= '0';

        -- Aspetta che finisca tutto
        wait for 10 sec;

        -- Fine simulazione
        assert false report "Test completed." severity failure;
    end process;

end architecture;

