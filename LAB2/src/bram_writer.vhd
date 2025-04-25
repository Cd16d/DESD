---------- DEFAULT LIBRARIES -------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
------------------------------------

ENTITY bram_writer IS
    GENERIC (
        ADDR_WIDTH : POSITIVE := 16;
        IMG_SIZE : POSITIVE := 256 -- Image size (256x256)
    );
    PORT (
        clk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tlast : IN STD_LOGIC;

        conv_addr : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
        conv_data : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

        start_conv : OUT STD_LOGIC;
        done_conv : IN STD_LOGIC;

        write_ok : OUT STD_LOGIC;
        overflow : OUT STD_LOGIC;
        underflow : OUT STD_LOGIC

    );
END ENTITY bram_writer;

ARCHITECTURE rtl OF bram_writer IS

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

    TYPE state_type IS (IDLE, RECEIVING, CHECK_DATA, CONVOLUTION);
    SIGNAL state : state_type := IDLE;

    SIGNAL s_axis_tready_int : STD_LOGIC := '0';

    SIGNAL bram_data_out : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- BRAM data output
    SIGNAL bram_data_in : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- BRAM data input
    SIGNAL bram_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- BRAM address
    SIGNAL bram_we : STD_LOGIC := '0'; -- Write enable signal for BRAM

    SIGNAL wr_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Write address for BRAM

    SIGNAL overflow_flag : STD_LOGIC := '0'; -- Overflow flag for BRAM write

BEGIN

    -- Instantiate BRAM controller
    BRAM_CTRL : bram_controller
    GENERIC MAP(
        ADDR_WIDTH => ADDR_WIDTH
    )
    PORT MAP(
        clk => clk,
        aresetn => aresetn,
        addr => bram_addr,
        dout => bram_data_out,
        din => bram_data_in,
        we => bram_we
    );

    -- Assign AXIS ready signal
    s_axis_tready <= s_axis_tready_int;

    -- Output only the lower 7 bits of BRAM data
    conv_data <= bram_data_out(6 DOWNTO 0);

    -- Select BRAM address based on state
    WITH state SELECT bram_addr <= conv_addr WHEN CONVOLUTION,
        wr_addr WHEN OTHERS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN
                -- Reset all signals and state
                state <= IDLE;

                s_axis_tready_int <= '0';

                bram_we <= '0';
                wr_addr <= (OTHERS => '0');

                start_conv <= '0';
                write_ok <= '0';
                overflow <= '0';
                underflow <= '0';

                overflow_flag <= '0';
            ELSE
                -- Default assignments for each clock cycle
                start_conv <= '0';
                bram_we <= '0';
                write_ok <= '0';
                overflow <= '0';
                underflow <= '0';
                s_axis_tready_int <= '1';

                -- State machine for data handling
                CASE state IS
                    WHEN IDLE =>
                        -- Wait for valid input data to start writing
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            wr_addr <= (OTHERS => '0');
                            bram_we <= '1'; -- Enable write to BRAM
                            bram_data_in <= s_axis_tdata; -- Write data to BRAM
                            state <= RECEIVING;
                        END IF;

                    WHEN RECEIVING =>
                        -- Receiving data, increment write address
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            -- Check for overflow: if address reaches max image size
                            IF unsigned(wr_addr) = (IMG_SIZE ** 2 - 1) THEN
                                overflow_flag <= '1';
                            END IF;

                            -- Increment write address and write data to BRAM
                            wr_addr <= STD_LOGIC_VECTOR(unsigned(wr_addr) + 1);
                            bram_we <= '1'; -- Enable write to BRAM
                            bram_data_in <= s_axis_tdata; -- Write data to BRAM

                            -- Check for last data signal
                            IF s_axis_tlast = '1' THEN
                                state <= CHECK_DATA;
                            END IF;
                        END IF;

                    WHEN CHECK_DATA =>
                        -- Check for overflow/underflow after data reception
                        IF overflow_flag = '1' THEN
                            overflow <= '1';
                            overflow_flag <= '0';
                            state <= IDLE;
                        ELSIF unsigned(wr_addr) < (IMG_SIZE ** 2 - 1) THEN
                            underflow <= '1';
                            state <= IDLE;
                        ELSE
                            -- Data reception complete, start convolution
                            write_ok <= '1';
                            s_axis_tready_int <= '0';
                            start_conv <= '1';
                            state <= CONVOLUTION;
                        END IF;

                    WHEN CONVOLUTION =>
                        -- Wait for convolution to finish
                        s_axis_tready_int <= '0';

                        IF done_conv = '1' THEN
                            state <= IDLE;
                        END IF;

                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;