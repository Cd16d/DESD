---------- DEFAULT LIBRARIES -------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
------------------------------------

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
    -- 3x3 convolution matrix (kernel)
    TYPE conv_mat_type IS ARRAY(0 TO 2, 0 TO 2) OF INTEGER;
    CONSTANT conv_mat : conv_mat_type := ((-1, -1, -1), (-1, 8, -1), (-1, -1, -1));

    -- Offset arrays for kernel position relative to current pixel
    TYPE offset_array IS ARRAY(0 TO 2) OF INTEGER;
    CONSTANT offset : offset_array := (-1, 0, 1);

    -- State machine for convolution process
    TYPE state_type IS (IDLE, START_CONVOLUTING, CONVOLUTING, WAIT_READY);
    SIGNAL state : state_type := IDLE;

    -- Current column and row in the image
    SIGNAL col : UNSIGNED(LOG2_N_COLS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL row : UNSIGNED(LOG2_N_ROWS - 1 DOWNTO 0) := (OTHERS => '0');

    -- Indices for kernel matrix position (previous, current, next)
    SIGNAL col_mat_idx_prv : INTEGER := 0;
    SIGNAL row_mat_idx_prv : INTEGER := 0;

    SIGNAL col_mat_idx : INTEGER := 0;
    SIGNAL row_mat_idx : INTEGER := 0;

    SIGNAL col_mat_idx_nxt : INTEGER := 0;
    SIGNAL row_mat_idx_nxt : INTEGER := 0;

    -- Accumulators for convolution result
    SIGNAL conv_data_out, conv_data_int, conv_data_mul : SIGNED(10 DOWNTO 0) := (OTHERS => '0');

    SIGNAL m_axis_tvalid_int : STD_LOGIC;

    -- Control signals for data flow and pipelining
    SIGNAL trigger, prepare_data, ready_data, send_data : STD_LOGIC := '0';
    SIGNAL tlast : STD_LOGIC := '0';
    SIGNAL save_data : STD_LOGIC := '0';

BEGIN

    m_axis_tvalid <= m_axis_tvalid_int;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN

                -- Reset all signals and state
                state <= IDLE;

                col <= (OTHERS => '0');
                row <= (OTHERS => '0');

                col_mat_idx_nxt <= 0;
                row_mat_idx_nxt <= 0;

                col_mat_idx_prv <= 0;
                row_mat_idx_prv <= 0;

                col_mat_idx <= 0;
                row_mat_idx <= 0;

                conv_data_out <= (OTHERS => '0');
                conv_data_int <= (OTHERS => '0');
                conv_data_mul <= (OTHERS => '0');

                m_axis_tvalid_int <= '0';
                m_axis_tdata <= (OTHERS => '0');
                m_axis_tlast <= '0';

                done_conv <= '0';

                trigger <= '0';
                prepare_data <= '0';
                ready_data <= '0';
                send_data <= '0';
                tlast <= '0';
                save_data <= '0';

                conv_addr <= (OTHERS => '0');

            ELSE
                -- Default values for signals at each clock
                done_conv <= '0';
                m_axis_tlast <= '0';

                CASE state IS
                    WHEN IDLE =>
                        -- Wait for start_conv signal to begin convolution
                        done_conv <= '0';
                        m_axis_tlast <= '0';
                        m_axis_tvalid_int <= '0';
                        m_axis_tdata <= (OTHERS => '0');
                        conv_data_out <= (OTHERS => '0');
                        conv_data_int <= (OTHERS => '0');
                        conv_data_mul <= (OTHERS => '0');
                        trigger <= '0';
                        prepare_data <= '0';
                        ready_data <= '0';
                        send_data <= '0';
                        tlast <= '0';
                        save_data <= '0';
                        conv_addr <= (OTHERS => '0');

                        IF start_conv = '1' THEN
                            state <= START_CONVOLUTING;

                            -- Reset image pointers
                            row <= (OTHERS => '0');
                            col <= (OTHERS => '0');

                            -- Request the first pixel and set pointer to second pixel
                            row_mat_idx_prv <= 0;
                            col_mat_idx_prv <= 0;

                            row_mat_idx <= 1;
                            col_mat_idx <= 1;

                            row_mat_idx_nxt <= 1;
                            col_mat_idx_nxt <= 2;

                            conv_addr <= (OTHERS => '0');
                            conv_data_out <= (OTHERS => '0');
                            conv_data_int <= (OTHERS => '0');
                            conv_data_mul <= (OTHERS => '0');
                            trigger <= '0';
                            prepare_data <= '0';
                            ready_data <= '0';
                            send_data <= '0';
                            tlast <= '0';
                            save_data <= '0';
                            m_axis_tvalid_int <= '0';
                            m_axis_tdata <= (OTHERS => '0');
                            m_axis_tlast <= '0';
                            done_conv <= '0';
                        END IF;

                    WHEN START_CONVOLUTING =>
                        -- Start the convolution process or resume from the previous state
                        conv_addr <= STD_LOGIC_VECTOR(
                            TO_UNSIGNED(
                            (TO_INTEGER(col) + offset(col_mat_idx_nxt)) +
                            (TO_INTEGER(row) + offset(row_mat_idx_nxt)) * (2 ** LOG2_N_COLS),
                            conv_addr'length
                            )
                            );

                        state <= CONVOLUTING;

                    WHEN CONVOLUTING =>
                        -- Perform convolution: multiply input by kernel coefficient and accumulate
                        conv_addr <= STD_LOGIC_VECTOR(
                            TO_UNSIGNED(
                            (TO_INTEGER(col) + offset(col_mat_idx_nxt)) +
                            (TO_INTEGER(row) + offset(row_mat_idx_nxt)) * (2 ** LOG2_N_COLS),
                            conv_addr'length
                            )
                            );

                        conv_data_mul <= RESIZE(
                            SIGNED('0' & conv_data) * TO_SIGNED(conv_mat(col_mat_idx_prv, row_mat_idx_prv), 5),
                            conv_data_mul'length
                            );

                        IF ready_data = '1' THEN
                            conv_data_out <= conv_data_int + conv_data_mul;
                            conv_data_int <= (OTHERS => '0');
                        ELSE
                            conv_data_int <= conv_data_int + conv_data_mul;
                        END IF;

                        trigger <= '0';

                    WHEN WAIT_READY =>
                        -- Wait for m_axis_tready signal before sending data and continuing
                        IF m_axis_tready = '1' THEN
                            conv_addr <= STD_LOGIC_VECTOR(
                                TO_UNSIGNED(
                                (TO_INTEGER(col) + offset(col_mat_idx_nxt)) +
                                (TO_INTEGER(row) + offset(row_mat_idx_nxt)) * (2 ** LOG2_N_COLS),
                                conv_addr'length
                                )
                                );

                            save_data <= '0';
                            state <= CONVOLUTING;
                        END IF;

                        -- Save convolution result only once per WAIT_READY state
                        IF save_data = '0' THEN
                            conv_data_mul <= RESIZE(
                                SIGNED('0' & conv_data) * TO_SIGNED(conv_mat(col_mat_idx_prv, row_mat_idx_prv), 5),
                                conv_data_mul'length
                                );

                            IF ready_data = '1' THEN
                                conv_data_out <= conv_data_int + conv_data_mul;
                                conv_data_int <= (OTHERS => '0');
                            ELSE
                                conv_data_int <= conv_data_int + conv_data_mul;
                            END IF;

                            save_data <= '1';
                        END IF;

                END CASE;

                -- Output data - master
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- If output not ready, wait before continuing
                IF m_axis_tready = '0' AND m_axis_tvalid_int = '1' THEN
                    state <= WAIT_READY;
                END IF;

                -- Send data when ready and output interface is available
                IF send_data = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                    m_axis_tvalid_int <= '1';

                    IF tlast = '1' THEN
                        state <= IDLE;
                        done_conv <= '1';
                        m_axis_tlast <= '1';
                        tlast <= '0';
                    END IF;

                    -- Clamp output to 0..127 range
                    IF conv_data_out < 0 THEN
                        m_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(0, m_axis_tdata'length));
                    ELSIF conv_data_out > 127 THEN
                        m_axis_tdata <= STD_LOGIC_VECTOR(TO_UNSIGNED(127, m_axis_tdata'length));
                    ELSE
                        m_axis_tdata <= STD_LOGIC_VECTOR(conv_data_out(7 DOWNTO 0));
                    END IF;

                    -- Reset accumulator and trigger
                    conv_data_out <= (OTHERS => '0');
                    send_data <= '0';
                END IF;

                -- Main kernel/image sweep logic
                IF state = CONVOLUTING OR state = START_CONVOLUTING OR (state = WAIT_READY AND m_axis_tready = '1') THEN
                    -- Update kernel and image indices, handle zero padding and end conditions
                    IF col_mat_idx_nxt = 1 AND col = (2 ** LOG2_N_COLS - 1) THEN
                        IF row_mat_idx_nxt = 1 AND row = (2 ** LOG2_N_ROWS - 1) THEN
                            -- Last pixel and last kernel position: finish convolution
                            IF tlast = '0' THEN
                                trigger <= '1'; -- Send last data
                                tlast <= '1';
                            END IF;

                        ELSIF row_mat_idx_nxt = 2 THEN
                            -- End of kernel, move to next image row
                            col <= (OTHERS => '0');
                            row <= row + 1;

                            row_mat_idx_nxt <= 0;
                            col_mat_idx_nxt <= 1; -- new row adding padding

                            trigger <= '1'; -- Send data

                        ELSE
                            -- Move to next kernel row
                            row_mat_idx_nxt <= row_mat_idx_nxt + 1;
                            col_mat_idx_nxt <= 0;

                        END IF;

                    ELSIF col_mat_idx_nxt = 2 THEN
                        IF row_mat_idx_nxt = 1 AND row = (2 ** LOG2_N_ROWS - 1) THEN
                            -- End of kernel column at last image row, move to next image column
                            col <= col + 1;

                            row_mat_idx_nxt <= 0;
                            col_mat_idx_nxt <= 0;

                            trigger <= '1'; -- Send data

                        ELSIF row_mat_idx_nxt = 2 THEN
                            -- End of kernel column and row, move to next image column
                            col <= col + 1;

                            IF row = 0 THEN
                                row_mat_idx_nxt <= 1; -- first row adding padding
                            ELSE
                                row_mat_idx_nxt <= 0;
                            END IF;
                            col_mat_idx_nxt <= 0;

                            trigger <= '1'; -- Send data

                        ELSE
                            -- Move to next kernel column
                            IF col = 0 THEN
                                col_mat_idx_nxt <= 1; -- first column adding padding
                            ELSE
                                col_mat_idx_nxt <= 0;
                            END IF;
                            row_mat_idx_nxt <= row_mat_idx_nxt + 1;

                        END IF;

                    ELSE
                        -- Continue kernel sweep: increment kernel column index
                        col_mat_idx_nxt <= col_mat_idx_nxt + 1;

                    END IF;

                    -- Pipeline control for output data
                    prepare_data <= trigger;
                    ready_data <= prepare_data;
                    send_data <= ready_data;

                    -- Update previous and current kernel indices
                    row_mat_idx_prv <= row_mat_idx;
                    col_mat_idx_prv <= col_mat_idx;

                    row_mat_idx <= row_mat_idx_nxt;
                    col_mat_idx <= col_mat_idx_nxt;
                END IF;

            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;