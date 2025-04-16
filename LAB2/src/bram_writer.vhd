LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bram_writer IS
    GENERIC (
        ADDR_WIDTH : POSITIVE := 16;
        IMG_SIZE : POSITIVE := 256 -- Dimensione immagine NxN
    );
    PORT (
        clk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        -- Interfaccia AXI Stream per ricezione dati
        s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tlast : IN STD_LOGIC;

        -- Interfaccia di lettura BRAM per il modulo di convoluzione
        conv_addr : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
        conv_data : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- solo 7 bit usati

        -- Controllo avvio/fine convoluzione
        start_conv : OUT STD_LOGIC;
        done_conv : IN STD_LOGIC;

        -- LED di stato (come da immagine)
        write_ok : OUT STD_LOGIC;
        overflow : OUT STD_LOGIC;
        underflow : OUT STD_LOGIC
    );
END ENTITY bram_writer;

ARCHITECTURE rtl OF bram_writer IS

    -- Componente BRAM (controller)
    COMPONENT bram_controller IS
        GENERIC (
            ADDR_WIDTH : POSITIVE := 16
        );
        PORT (
            clk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;

            addr : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
            dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            we : IN STD_LOGIC
        );
    END COMPONENT;

    CONSTANT total_px_expected : unsigned(ADDR_WIDTH - 1 DOWNTO 0) := to_unsigned(IMG_SIZE ** 2 - 1, ADDR_WIDTH); -- IMG_SIZE * IMG_SIZE

    TYPE state_type IS (IDLE, RECEIVING, CHECK_START_CONV, CONVOLUTION);
    SIGNAL state : state_type := IDLE;

    -- Registri di stato e segnale interno
    signal addr_write : UNSIGNED(ADDR_WIDTH DOWNTO 0) := (OTHERS => '0'); -- Indirizzo BRAM
    SIGNAL addr_bram : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Indirizzo BRAM

    SIGNAL wr_enable : STD_LOGIC := '0'; -- Segnale di scrittura BRAM
    SIGNAL din_reg : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- Dato da scrivere in BRAM
    SIGNAL flag_of : STD_LOGIC := '0'; -- Flag overflow (se addr_count > total_px_expected)

    SIGNAL dout_bram : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Dato letto dalla BRAM

    SIGNAL s_axis_tready_int : STD_LOGIC;

BEGIN

    -- Instanziazione BRAM (scrive e legge)
    BRAM_CTRL : bram_controller
    GENERIC MAP(
        ADDR_WIDTH => ADDR_WIDTH
    )
    PORT MAP(
        clk => clk,
        aresetn => aresetn,
        addr => addr_bram,
        dout => dout_bram,
        din => din_reg,
        we => wr_enable
    );

    -- AXIS
    s_axis_tready <= s_axis_tready_int;

    -- Segnale di lettura BRAM per il modulo di convoluzione
    conv_data <= dout_bram(6 DOWNTO 0);

    -- FSM principale
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN
                -- Reset sincrono
                state <= IDLE;
                addr_bram <= (OTHERS => '0');
                addr_write <= (OTHERS => '0');
                wr_enable <= '0';
                write_ok <= '0';
                overflow <= '0';
                underflow <= '0';
                start_conv <= '0';
                flag_of <= '0';

                s_axis_tready_int <= '0';

            ELSE
                -- Valori di default ogni ciclo
                wr_enable <= '0';
                start_conv <= '0';

                write_ok <= '0';
                overflow <= '0';
                underflow <= '0';

                addr_bram <= conv_addr; -- Passa indirizzo al modulo di convoluzione

                CASE state IS

                    WHEN IDLE =>
                        addr_write <= (OTHERS => '0');
                        flag_of <= '0'; -- Reset flag overflow
                        s_axis_tready_int <= '1'; -- Pronto a ricevere dati

                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            -- Registra dato ricevuto e scrive in BRAM
                            din_reg <= s_axis_tdata;
                            addr_bram <= STD_LOGIC_VECTOR(addr_write(ADDR_WIDTH - 1 DOWNTO 0));
                            wr_enable <= '1';

                            s_axis_tready_int <= '1'; -- Pronto a ricevere nuovi dati

                            state <= RECEIVING;
                        END IF;

                    WHEN RECEIVING => -- Stato RICEZIONE (legge dati da AXIS)
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            -- Registra dato ricevuto e scrive in BRAM
                            din_reg <= s_axis_tdata;
                            addr_bram <= STD_LOGIC_VECTOR(addr_write(ADDR_WIDTH - 1 DOWNTO 0));
                            wr_enable <= '1';
                            addr_write <= addr_write + 1;

                            s_axis_tready_int <= '1'; -- Pronto a ricevere nuovi dati

                            -- Se è l'ultimo pixel del pacchetto
                            IF s_axis_tlast = '1' THEN
                                state <= CHECK_START_CONV;
                            END IF;
                        END IF;

                    WHEN CHECK_START_CONV => -- Controllo overflow/underflow
                        s_axis_tready_int <= '0';

                        IF flag_of = '1' THEN
                            overflow <= '1'; -- LED overflow

                            state <= IDLE; -- Torna a stato IDLE
                        ELSIF addr_write < total_px_expected THEN
                            underflow <= '1'; -- LED underflow

                            state <= IDLE; -- Torna a stato IDLE
                        ELSIF addr_write = total_px_expected THEN
                            write_ok <= '1'; -- LED OK

                            start_conv <= '1'; -- Segnale per far partire modulo Conv
                            state <= CONVOLUTION; -- Vai a start convoluzione
                        END IF;

                    WHEN CONVOLUTION => -- Avvia convoluzione
                        s_axis_tready_int <= '0';

                        IF done_conv = '1' THEN
                            state <= IDLE;
                            s_axis_tready_int <= '1';
                        END IF;
                END CASE;

                -- il controllo viene eseguito qui nel caso in cui addr_write vada in overflow e risulti quindi minore di total_px_expected
                IF addr_write > total_px_expected AND flag_of = '0' THEN
                    flag_of <= '1';
                END IF;

            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;