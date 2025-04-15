LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY packetizer IS
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
        s_axis_tlast : IN STD_LOGIC;

        m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC;
        m_axis_tlast : OUT STD_LOGIC
    );
END ENTITY packetizer;

ARCHITECTURE rtl OF packetizer IS

    TYPE state_type IS (IDLE, SENDING_HEADER, SENDING_DATA, SENDING_FOOTER);
    SIGNAL state : state_type := IDLE;

    SIGNAL data_buffer : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL s_axis_tready_int : STD_LOGIC;
    SIGNAL m_axis_tvalid_int : STD_LOGIC;

    SIGNAL last_seen : STD_LOGIC := '0';

BEGIN

    s_axis_tready <= s_axis_tready_int;
    m_axis_tvalid <= m_axis_tvalid_int;

    PROCESS (clk)
        VARIABLE trigger : STD_LOGIC := '0';
    BEGIN

        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN

                data_buffer <= (OTHERS => '0');

                s_axis_tready_int <= '0';
                m_axis_tvalid_int <= '0';
                m_axis_tlast <= '0';

            ELSE

                m_axis_tlast <= '0';

                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                CASE state IS
                    WHEN IDLE =>
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            state <= SENDING_HEADER;
                        END IF;

                    WHEN SENDING_HEADER =>
                        IF m_axis_tvalid_int = '0' OR m_axis_tready = '1' THEN
                            m_axis_tvalid_int <= '1';
                            m_axis_tdata <= STD_LOGIC_VECTOR(to_unsigned(HEADER, 8));

                            state <= SENDING_DATA;
                        END IF;

                    WHEN SENDING_DATA =>
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            IF s_axis_tlast = '1' THEN
                                last_seen <= '1';
                            END IF;

                            trigger := '1';
                        END IF;

                        IF last_seen = '1' THEN
                            state <= SENDING_FOOTER;
                            last_seen <= '0';

                            trigger := '1';
                        END IF;

                    WHEN SENDING_FOOTER =>
                        IF m_axis_tvalid_int = '0' OR m_axis_tready = '1' THEN
                            m_axis_tvalid_int <= '1';
                            m_axis_tlast <= '1';
                            m_axis_tdata <= STD_LOGIC_VECTOR(to_unsigned(FOOTER, 8));

                            state <= IDLE;
                        END IF;

                END CASE;

                -- Output data - master
                IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                    m_axis_tvalid_int <= '1';
                    m_axis_tdata <= data_buffer;

                    trigger := '0';
                END IF;

                -- Input data - slave
                s_axis_tready_int <= m_axis_tready;

                IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                    data_buffer <= s_axis_tdata;
                END IF;

            END IF;
        END IF;

    END PROCESS;

END ARCHITECTURE rtl;