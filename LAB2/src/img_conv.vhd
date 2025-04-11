LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY img_conv IS
    GENERIC (
        LOG2_N_COLS : POSITIVE := 8;
        LOG2_N_ROWS : POSITIVE := 8
    );
    PORT (

        clk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC;
        m_axis_tlast : OUT STD_LOGIC;

        conv_addr : OUT STD_LOGIC_VECTOR(LOG2_N_COLS + LOG2_N_ROWS - 1 DOWNTO 0);
        conv_data : IN STD_LOGIC_VECTOR(6 DOWNTO 0);

        start_conv : IN STD_LOGIC;
        done_conv : OUT STD_LOGIC

    );
END ENTITY img_conv;

ARCHITECTURE rtl OF img_conv IS

    TYPE conv_mat_type IS ARRAY(0 TO 2, 0 TO 2) OF INTEGER;
    CONSTANT conv_mat : conv_mat_type := ((-1, -1, -1),(-1, 8, -1),(-1, -1, -1));

    -- Definizione della finestra 3x3; ogni pixel è rappresentato da 8 bit
    TYPE window_array IS ARRAY(0 TO 2, 0 TO 2) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL window : window_array := (OTHERS => (OTHERS => (OTHERS => '0')));

    -- Parametri immagine
    CONSTANT IMG_WIDTH : INTEGER := 2 ** LOG2_N_COLS; -- Larghezza dell'immagine
    CONSTANT IMG_HEIGHT : INTEGER := 2 ** LOG2_N_ROWS; -- Altezza dell'immagine

    -- Indirizzo corrente per la lettura dei pixel
    SIGNAL current_addr : STD_LOGIC_VECTOR(LOG2_N_COLS + LOG2_N_ROWS - 1 DOWNTO 0);

    -- Variabili per il calcolo della convoluzione
    SIGNAL conv_sum : INTEGER := 0; -- Somma dei prodotti
    SIGNAL conv_out : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Risultato della convoluzione

    -- Stato della macchina a stati
    TYPE state_type IS (IDLE, LOAD_PIXEL, COMPUTE, OUTPUT);
    SIGNAL state : state_type := IDLE;

    -- Contatori per riga e colonna
    SIGNAL row, col : INTEGER RANGE 0 TO IMG_HEIGHT - 1 := 0;

BEGIN

    -- Aggiornamento dell'indirizzo di lettura (mapping riga-colonna)
    conv_addr <= STD_LOGIC_VECTOR(to_unsigned(row * IMG_WIDTH + col, conv_addr'length));

    -- Processo principale: macchina a stati per la gestione della convoluzione
    PROCESS (clk, aresetn)
    BEGIN
        IF aresetn = '0' THEN
            -- Reset asincrono: inizializza tutti i segnali
            state <= IDLE;
            row <= 0;
            col <= 0;
            window <= (OTHERS => (OTHERS => (OTHERS => '0')));
            conv_sum <= 0;
            conv_out <= (OTHERS => '0');
            m_axis_tdata <= (OTHERS => '0');
            m_axis_tvalid <= '0';
            m_axis_tlast <= '0';
            done_conv <= '0';
            current_addr <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            CASE state IS

                    -- Stato IDLE: attende il segnale di start per iniziare la convoluzione
                WHEN IDLE =>
                    m_axis_tvalid <= '0';
                    m_axis_tlast <= '0';
                    IF start_conv = '1' THEN
                        row <= 0;
                        col <= 0;
                        done_conv <= '0';
                        -- Inizializza la finestra a zero per gestire il padding superiore
                        window <= (OTHERS => (OTHERS => (OTHERS => '0')));
                        state <= LOAD_PIXEL;
                    END IF;

                    -- Stato LOAD_PIXEL: carica un nuovo pixel e aggiorna la finestra
                WHEN LOAD_PIXEL =>
                    -- Aggiorna la finestra con il nuovo pixel (conv_data)
                    -- Lo shifting viene realizzato per spostare i dati verso sinistra
                    IF col = 0 THEN
                        -- Per ogni riga della finestra si forza la colonna sinistra a zero
                        FOR i IN 0 TO 2 LOOP
                            window(i)(0) <= (OTHERS => '0');
                        END LOOP;
                    ELSE
                        FOR i IN 0 TO 2 LOOP
                            window(i)(0) <= window(i)(1);
                            window(i)(1) <= window(i)(2);
                        END LOOP;
                    END IF;

                    -- Aggiorna la colonna destra della finestra con il nuovo pixel
                    FOR i IN 0 TO 2 LOOP
                        window(i)(2) <= conv_data;
                    END LOOP;

                    -- Aggiorna i contatori per scorrere l'immagine
                    IF col = IMG_WIDTH - 1 THEN
                        col <= 0;
                        IF row = IMG_HEIGHT - 1 THEN
                            state <= COMPUTE;
                        ELSE
                            row <= row + 1;
                        END IF;
                    ELSE
                        col <= col + 1;
                    END IF;

                    state <= COMPUTE;

                    -- Stato COMPUTE: esegue il calcolo della convoluzione
                WHEN COMPUTE =>
                    -- Gestione dei bordi: imposta il risultato a zero se la finestra non è completa
                    IF (row = 0) OR (row = IMG_HEIGHT - 1) OR (col = 0) OR (col = IMG_WIDTH - 1) THEN
                        conv_sum <= 0;
                    ELSE
                        conv_sum <= 0;
                        -- Moltiplica cella per cella e somma i prodotti
                        FOR i IN 0 TO 2 LOOP
                            FOR j IN 0 TO 2 LOOP
                                conv_sum <= conv_sum + conv_mat(i, j) * to_integer(unsigned(window(i)(j)));
                            END LOOP;
                        END LOOP;
                    END IF;

                    -- Saturazione del risultato
                    IF conv_sum < 0 THEN
                        conv_out <= STD_LOGIC_VECTOR(to_unsigned(0, 8));
                    ELSIF conv_sum >= 256 THEN
                        conv_out <= STD_LOGIC_VECTOR(to_unsigned(255, 8));
                    ELSE
                        conv_out <= STD_LOGIC_VECTOR(to_unsigned(conv_sum, 8));
                    END IF;

                    state <= OUTPUT;

                    -- Stato OUTPUT: invia il risultato tramite l'interfaccia AXIS
                WHEN OUTPUT =>
                    IF m_axis_tready = '1' THEN
                        m_axis_tdata <= conv_out;
                        m_axis_tvalid <= '1';
                        -- Se siamo sull'ultimo pixel dell'immagine, segnaliamo TLAST e il completamento
                        IF (row = IMG_HEIGHT - 1) AND (col = IMG_WIDTH - 1) THEN
                            m_axis_tlast <= '1';
                            done_conv <= '1';
                            state <= IDLE;
                        ELSE
                            m_axis_tlast <= '0';
                            state <= LOAD_PIXEL;
                        END IF;
                    END IF;

                    -- Stato di default: ritorna a IDLE
                WHEN OTHERS =>
                    state <= IDLE;
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE;