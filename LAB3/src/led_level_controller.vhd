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

    signal volume_value      : signed(CHANNEL_LENGHT-1 downto 0) := (others => '0');
    signal abs_audio_left    : unsigned(CHANNEL_LENGHT-2 downto 0) := (others => '0');
    signal abs_audio_right   : unsigned(CHANNEL_LENGHT-2 downto 0) := (others => '0');
    signal leds_int          : std_logic_vector(NUM_LEDS-1 downto 0) := (others => '0');
    signal led_update        : std_logic := '0';
    signal refresh_counter   : natural range 0 to REFRESH_CYCLES-1 := 0;

begin
    led <= leds_int;
    s_axis_tready <= '1';

    -- Registrazione del valore audio assoluto
    process(aclk)
        variable sdata_signed : signed(CHANNEL_LENGHT-1 downto 0);
        variable abs_value    : unsigned(CHANNEL_LENGHT-1 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                volume_value   <= (others => '0');
                abs_audio_left <= (others => '0');
                abs_audio_right<= (others => '0');
            elsif s_axis_tvalid = '1' then
                sdata_signed := signed(s_axis_tdata);
                volume_value <= sdata_signed;
                -- Calcolo valore assoluto
                if sdata_signed(CHANNEL_LENGHT-1) = '1' then
                    abs_value := unsigned(-sdata_signed);
                else
                    abs_value := unsigned(sdata_signed);
                end if;
                -- Assegna al canale corretto
                if s_axis_tlast = '1' then -- Canale sinistro
                    abs_audio_left <= abs_value(CHANNEL_LENGHT-2 downto 0);
                else -- Canale destro
                    abs_audio_right <= abs_value(CHANNEL_LENGHT-2 downto 0);
                end if;
            end if;
        end if;
    end process;

    -- Contatore di refresh
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                refresh_counter <= 0;
                led_update <= '0';
            elsif refresh_counter = REFRESH_CYCLES-1 then
                refresh_counter <= 0;
                led_update <= '1';
            else
                refresh_counter <= refresh_counter + 1;
                led_update <= '0';
            end if;
        end if;
    end process;

    -- Scaling lineare e aggiornamento LED
    process(aclk)
        variable leds_on        : natural range 0 to NUM_LEDS;
        variable temp_led_level : integer range 0 to NUM_LEDS;
        variable abs_audio_sum  : unsigned(CHANNEL_LENGHT-1 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                leds_int <= (others => '0');
            elsif led_update = '1' then
                abs_audio_sum := resize(abs_audio_left, CHANNEL_LENGHT) + resize(abs_audio_right, CHANNEL_LENGHT);

                if (abs_audio_left = 0 and abs_audio_right = 0) then
                    temp_led_level := 0;
                else
                    -- Scaling automatico: puoi regolare la costante di shift per la sensibilità
                    temp_led_level := 1 + to_integer(shift_right(abs_audio_sum, CHANNEL_LENGHT-4));
                end if;

                -- Limita al massimo numero di LED
                if temp_led_level > NUM_LEDS then
                    leds_on := NUM_LEDS;
                else
                    leds_on := temp_led_level;
                end if;

                -- Aggiorna i LED
                leds_int <= (others => '0');
                if leds_on > 0 then
                    leds_int(leds_on-1 downto 0) <= (others => '1');
                end if;
            end if;
        end if;
    end process;
end Behavioral;
