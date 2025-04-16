library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE :=16
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end entity bram_writer;

architecture rtl of bram_writer is

    component bram_controller is
        generic (
            ADDR_WIDTH: POSITIVE :=16
        );
        port (
            clk   : in std_logic;
            aresetn : in std_logic;
    
            addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
            dout: out std_logic_vector(7 downto 0);
            din: in std_logic_vector(7 downto 0);
            we: in std_logic
        );
    end component;

    -- Registri di stato e segnale interno
    signal addr_cnt   : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');  -- Contatore indirizzo BRAM
    signal wr_enable  : std_logic := '0';                                    -- Segnale di scrittura BRAM
    signal din_reg    : std_logic_vector(7 downto 0) := (others => '0');     -- Dato da scrivere in BRAM
    signal fsm_state  : integer range 0 to 3 := 0;                            -- Stato FSM
    signal pixel_count: unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');  -- Pixel ricevuti
    signal total_px_expected : unsigned(ADDR_WIDTH-1 downto 0);              -- IMG_SIZE * IMG_SIZE

    signal dout_bram : std_logic_vector(7 downto 0);  -- Dato letto dalla BRAM

begin

    -- Calcolo totale pixel attesi = N x N
    total_px_expected <= to_unsigned(IMG_SIZE * IMG_SIZE, ADDR_WIDTH);

    -- Instanziazione BRAM (scrive e legge)
    BRAM_CTRL : bram_controller
        generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk   => clk,
            aresetn => aresetn,
            addr  => conv_addr,
            dout  => dout_bram,
            din   => din_reg,
            we    => wr_enable
        );

    -- Usiamo solo i primi 7 bit del dato letto per conv_data
    conv_data <= dout_bram(6 downto 0);

    -- FSM principale
    process(clk, aresetn)
    begin
        if aresetn = '0' then
            -- Reset asincrono
            fsm_state <= 0;
            addr_cnt <= (others => '0');
            pixel_count <= (others => '0');
            wr_enable <= '0';
            s_axis_tready <= '0';
            write_ok <= '0';
            overflow <= '0';
            underflow <= '0';
            start_conv <= '0';

        elsif rising_edge(clk) then
            -- Valori di default ogni ciclo
            wr_enable <= '0';
            start_conv <= '0';
            write_ok <= '0';
            overflow <= '0';
            underflow <= '0';

            case fsm_state is

                when 0 => -- Stato IDLE/RICEZIONE (legge dati da AXIS)
                    s_axis_tready <= '1';  -- pronto a ricevere

                    if s_axis_tvalid = '1' then
                        -- Registra dato ricevuto e scrive in BRAM
                        din_reg <= s_axis_tdata;
                        wr_enable <= '1';
                        addr_cnt <= addr_cnt + 1;
                        pixel_count <= pixel_count + 1;

                        -- Se è l'ultimo pixel del pacchetto
                        if s_axis_tlast = '1' then
                            fsm_state <= 1;
                        end if;
                    end if;

                when 1 => -- Controllo overflow/underflow
                    s_axis_tready <= '0';

                    if pixel_count = total_px_expected then
                        write_ok <= '1';       -- LED OK
                    elsif pixel_count < total_px_expected then
                        underflow <= '1';      -- LED underflow
                    else
                        overflow <= '1';       -- LED overflow
                    end if;

                    fsm_state <= 2;  -- Vai a start convoluzione

                when 2 => -- Avvia convoluzione
                    start_conv <= '1';  -- Segnale per far partire modulo Conv

                    if done_conv = '1' then
                        -- Reset e torna a ricevere nuovi dati
                        fsm_state <= 0;
                        addr_cnt <= (others => '0');
                        pixel_count <= (others => '0');
                    end if;

                when others =>
                    fsm_state <= 0;
            end case;
        end if;
    end process;

end architecture;
