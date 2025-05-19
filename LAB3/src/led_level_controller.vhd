library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_level_controller is
    generic(
        NUM_LEDS : positive := 16;
        CHANNEL_LENGHT  : positive := 24;
        refresh_time_ms: positive :=1;
        clock_period_ns: positive :=10
    );
    Port (
        
        aclk			: in std_logic;
        aresetn			: in std_logic;
        
        led    : out std_logic_vector(NUM_LEDS-1 downto 0);

        s_axis_tvalid	: in std_logic;
        s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready	: out std_logic

    );
end led_level_controller;

architecture Behavioral of led_level_controller is
    constant REFRESH_CYCLES : natural := (refresh_time_ms * 1_000_000) / clock_period_ns;

    signal volume_value : signed(CHANNEL_LENGHT-1 downto 0) := (others => '0');
    signal abs_audio    : unsigned(CHANNEL_LENGHT-2 downto 0) := (others => '0');
    signal leds_int     : std_logic_vector(NUM_LEDS-1 downto 0) := (others => '0');
    signal led_update   : std_logic := '0';
    signal refresh_counter : natural range 0 to REFRESH_CYCLES-1 := 0;

begin
    led <= leds_int;
    s_axis_tready <= '1';

    -- Register the audio absolute value

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                volume_value <= (others => '0');
            elsif s_axis_tvalid = '1' then
                volume_value <= signed(s_axis_tdata);
                if volume_value(volume_value'high) = '1' then
                    abs_audio <= unsigned(-volume_value(CHANNEL_LENGHT-2 downto 0));
                else
                    abs_audio <= unsigned(volume_value(CHANNEL_LENGHT-2 downto 0));
                end if;
            end if;
        end if;
    end process;

    -- Refresh counter
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                refresh_counter <= 0;
                led_update <= '0';
            else
                if refresh_counter = REFRESH_CYCLES-1 then
                    refresh_counter <= 0;
                    led_update <= '1';
                else
                    refresh_counter <= refresh_counter + 1;
                    led_update <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Linear scaling of the audio signal to LED levels
    process(aclk)
        variable leds_on : natural range 0 to NUM_LEDS;
        variable temp_led_level : integer range 0 to NUM_LEDS;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                leds_int <= (others => '0');
            elsif led_update = '1' then
                -- Automatic linear scaling calculation:
                if to_integer(abs_audio) = 0 then
                    temp_led_level := 0;
                else  -- -1 bit for sign, -4 to get 15+1 levels
                    temp_led_level := to_integer(shift_right(abs_audio,CHANNEL_LENGHT-4-1))+1; 
                end if;

                -- Limit to maximum number of LEDs
                if temp_led_level > NUM_LEDS then
                    leds_on := NUM_LEDS;
                else
                    leds_on := temp_led_level;
                end if;

                leds_int <= (others => '0');
                if leds_on > 0 then
                    leds_int(leds_on-1 downto 0) <= (others => '1');
                end if;
            end if;
        end if;
    end process;
end Behavioral;
