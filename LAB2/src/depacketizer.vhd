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
        m_axis_tlast : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC
    );

END ENTITY depacketizer;

ARCHITECTURE rtl OF depacketizer IS

    TYPE state_type IS (IDLE, RECEIVING);
    SIGNAL state : state_type := IDLE;

    SIGNAL data_buffer : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL s_axis_tready_int : STD_LOGIC;
    SIGNAL m_axis_tvalid_int : STD_LOGIC;

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

                CASE state IS
                    WHEN IDLE =>
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            IF data_buffer = STD_LOGIC_VECTOR(to_unsigned(HEADER, 8)) THEN
                                state <= RECEIVING;
                            END IF;
                        END IF;

                    WHEN RECEIVING =>
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            IF s_axis_tdata = STD_LOGIC_VECTOR(to_unsigned(FOOTER, 8)) THEN
                                m_axis_tlast <= '1';
                                state <= IDLE;
                            ELSE
                                m_axis_tlast <= '0';
                            END IF;

                            trigger := '1';
                        END IF;

                END CASE;

                -- Output data - master
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

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

END ARCHITECTURE;