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

    TYPE state_type IS (WAITING_HEADER, RECEIVING, SEND);
    SIGNAL state : state_type := WAITING_HEADER;

    SIGNAL s_axis_tready_int : STD_LOGIC := '1';
    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';
    SIGNAL m_axis_tdata_int : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL m_axis_tlast_int : STD_LOGIC := '0';

    SIGNAL data_buffer : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_ready : STD_LOGIC := '0';

BEGIN

    s_axis_tready <= s_axis_tready_int;
    m_axis_tvalid <= m_axis_tvalid_int;
    m_axis_tdata <= m_axis_tdata_int;
    m_axis_tlast <= m_axis_tlast_int;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF aresetn = '0' THEN
                state <= WAITING_HEADER;
                m_axis_tdata_int <= (OTHERS => '0');
                m_axis_tlast_int <= '0';
                s_axis_tready_int <= '1';
                m_axis_tvalid_int <= '0';
                data_buffer <= (OTHERS => '0');
                data_ready <= '0';
            ELSE
                m_axis_tlast_int <= '0';

                CASE state IS
                    WHEN WAITING_HEADER =>
                        s_axis_tready_int <= '1';
                        m_axis_tvalid_int <= '0';
                        data_ready <= '0';
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            IF s_axis_tdata = STD_LOGIC_VECTOR(to_unsigned(HEADER, 8)) THEN
                                state <= RECEIVING;
                            END IF;
                        END IF;

                    WHEN RECEIVING =>
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            IF data_ready = '1' THEN
                                m_axis_tdata_int <= data_buffer;
                                m_axis_tvalid_int <= '1';

                                IF s_axis_tdata = STD_LOGIC_VECTOR(to_unsigned(FOOTER, 8)) THEN
                                    m_axis_tlast_int <= '1';
                                    state <= WAITING_HEADER;
                                    s_axis_tready_int <= '0';
                                    data_ready <= '0';
                                ELSE
                                    state <= SEND;
                                    s_axis_tready_int <= '0';
                                END IF;
                            END IF;
                            data_buffer <= s_axis_tdata;
                            data_ready <= '1';
                        END IF;

                    WHEN SEND =>
                        IF m_axis_tvalid_int = '1' AND m_axis_tready = '1' THEN
                            m_axis_tvalid_int <= '0';
                            s_axis_tready_int <= '1';
                            state <= RECEIVING;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;