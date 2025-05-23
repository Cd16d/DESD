---------- DEFAULT LIBRARIES -------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
------------------------------------

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
        m_axis_tready : IN STD_LOGIC
    );
END ENTITY packetizer;

ARCHITECTURE rtl OF packetizer IS

    TYPE state_type IS (SENDING_HEADER, STREAMING, SENDING_FOOTER);
    SIGNAL state : state_type := SENDING_HEADER;

    SIGNAL data_buffer : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL s_axis_tready_int : STD_LOGIC;
    SIGNAL m_axis_tvalid_int : STD_LOGIC;

    SIGNAL trigger : STD_LOGIC := '0'; -- Used to control when to send data

BEGIN

    s_axis_tready <= s_axis_tready_int;
    m_axis_tvalid <= m_axis_tvalid_int;

    PROCESS (clk)
    BEGIN

        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN
                state <= SENDING_HEADER;
                data_buffer <= (OTHERS => '0');
                m_axis_tdata <= (OTHERS => '0');
                s_axis_tready_int <= '0';
                m_axis_tvalid_int <= '0';

            ELSE

                -- Input data - slave
                IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                    data_buffer <= s_axis_tdata;
                END IF;

                -- Clear valid flag when master interface is ready
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Send data when triggered
                IF trigger = '1' THEN
                    IF (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                        m_axis_tvalid_int <= '1';
                        m_axis_tdata <= data_buffer;
                        s_axis_tready_int <= '1'; -- Enable slave interface

                        trigger <= '0';
                    ELSE
                        s_axis_tready_int <= '0'; -- Block slave interface to avoid data loss
                    END IF;
                END IF;

                -- State machine for packetization
                CASE state IS

                    WHEN SENDING_HEADER =>
                        s_axis_tready_int <= '1'; -- Enable slave interface
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            m_axis_tdata <= STD_LOGIC_VECTOR(to_unsigned(HEADER, 8)); -- Send header
                            m_axis_tvalid_int <= '1';
                            s_axis_tready_int <= m_axis_tready;

                            IF s_axis_tlast = '1' THEN
                                s_axis_tready_int <= '0'; -- Block slave interface if last
                                state <= SENDING_FOOTER;
                            ELSE
                                state <= STREAMING;
                            END IF;

                            trigger <= '1';
                        END IF;

                    WHEN STREAMING =>
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            s_axis_tready_int <= m_axis_tready;

                            IF s_axis_tlast = '1' THEN
                                s_axis_tready_int <= '0'; -- Block slave interface if last
                                state <= SENDING_FOOTER;
                            END IF;

                            trigger <= '1';
                        END IF;

                    WHEN SENDING_FOOTER =>
                        IF m_axis_tvalid_int = '0' OR m_axis_tready = '1' THEN
                            s_axis_tready_int <= '0'; -- Block slave interface

                            data_buffer <= STD_LOGIC_VECTOR(to_unsigned(FOOTER, 8)); -- Send footer
                            m_axis_tvalid_int <= '1';

                            trigger <= '1';
                            state <= SENDING_HEADER;
                        END IF;

                END CASE;
            END IF;
        END IF;

    END PROCESS;

END ARCHITECTURE;