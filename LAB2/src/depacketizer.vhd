LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY depacketizer IS
    GENERIC (
        HEADER : INTEGER := 16#FF#;
        FOOTER : INTEGER := 16#F1#
    );
    PORT (
        clk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;

        m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC;
        m_axis_tlast : OUT STD_LOGIC
    );
END ENTITY depacketizer;

ARCHITECTURE rtl OF depacketizer IS

    -- Enumeration for the state machine
    -- IDLE: Waiting for the start of a new packet
    -- STREAMING: Actively processing and forwarding packet data
    TYPE state_type IS (IDLE, STREAMING);
    SIGNAL state : state_type := IDLE;

    -- Buffer to handle backpressure
    SIGNAL buffer_in : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL buffer_valid : STD_LOGIC := '0'; -- Indicates if buffer_in contains valid data
BEGIN

    depacketizer_fsm : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN
                -- Reset: back to idle and clear everything
                state <= IDLE;
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';
                m_axis_tlast <= '0';
                m_axis_tdata <= (OTHERS => '0');
                buffer_in <= (OTHERS => '0');
                buffer_valid <= '0';

            ELSE
                -- Defaults for each clock cycle
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
                m_axis_tlast <= '0';

                CASE state IS

                    WHEN IDLE =>
                        -- Wait for start of a new packet
                        IF s_axis_tvalid = '1' THEN
                            m_axis_tvalid <= '0';
                            IF s_axis_tdata = STD_LOGIC_VECTOR(to_unsigned(HEADER, 8)) THEN
                                state <= STREAMING;
                            END IF;
                        END IF;

                    WHEN STREAMING =>
                        IF s_axis_tvalid = '1' THEN

                            -- End of packet detected
                            IF s_axis_tdata = STD_LOGIC_VECTOR(to_unsigned(FOOTER, 8)) THEN
                                -- Send the last data and transition to IDLE
                                m_axis_tdata <= buffer_in; -- Send the last buffered data
                                state <= IDLE;
                                m_axis_tlast <= '1'; -- Let receiver know packet ends
                            ELSE
                                -- Valid payload: send to output
                                IF buffer_valid = '1' AND m_axis_tready = '1' THEN
                                    m_axis_tdata <= buffer_in;
                                    m_axis_tvalid <= '1';
                                    buffer_valid <= '0'; -- Clear the buffer
                                END IF;

                                buffer_in <= s_axis_tdata;
                                buffer_valid <= '1';
                            END IF;
                        END IF;

                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;