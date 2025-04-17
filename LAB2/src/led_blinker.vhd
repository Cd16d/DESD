library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity led_blinker is
    generic (
        CLK_PERIOD_NS   : positive := 10;
        BLINK_PERIOD_MS : positive := 1000;
        N_BLINKS        : positive := 4
    );
    port (
        clk         : in  std_logic;
        aresetn     : in  std_logic;
        start_blink : in  std_logic;
        led         : out std_logic
    );
end entity;

architecture rtl of led_blinker is
    -- Calcoli per larghezze e valori massimi
    constant CLK_PER_MS  : integer := 1_000_000 / CLK_PERIOD_NS;
    constant MAX_COUNT   : integer := CLK_PER_MS * BLINK_PERIOD_MS;
    constant CNT_WIDTH   : integer := integer(ceil(log2(real(MAX_COUNT))));
    constant BLINK_WIDTH : integer := integer(ceil(log2(real(N_BLINKS + 1))));

    signal counter       : unsigned(CNT_WIDTH-1 downto 0) := (others => '0');
    signal blink_cnt     : unsigned(BLINK_WIDTH-1 downto 0) := (others => '0');
    signal blinking      : std_logic := '0';
    signal led_reg       : std_logic := '0';

    signal start_prev    : std_logic := '0';
    signal start_edge    : std_logic;

begin
    led <= led_reg;

    process(clk, aresetn)
    begin
        if aresetn = '0' then
            counter    <= (others => '0');
            blink_cnt  <= (others => '0');
            blinking   <= '0';
            led_reg    <= '0';
            start_prev <= '0';
            start_edge <= '0';

        elsif rising_edge(clk) then
            -- Rileva fronte di salita di start_blink
            start_edge <= start_blink and not start_prev;
            start_prev <= start_blink;

            if blinking = '0' then
                if start_edge = '1' then
                    blinking   <= '1';
                    counter    <= (others => '0');
                    blink_cnt  <= (others => '0');
                    led_reg    <= '1';
                end if;
            else  -- blinking = '1'
                if counter = to_unsigned(MAX_COUNT - 1, counter'length) then
                    counter <= (others => '0');
                    led_reg <= not led_reg;

                    if led_reg = '1' then  -- fine fase ON
                        blink_cnt <= blink_cnt + 1;
                        if blink_cnt + 1 = to_unsigned(N_BLINKS, blink_cnt'length) then
                            blinking <= '0';
                            led_reg  <= '0';
                        end if;
                    end if;
                else
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;