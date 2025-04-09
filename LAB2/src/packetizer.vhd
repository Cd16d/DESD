library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity packetizer is
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic 
        
    );
end entity packetizer;

architecture rtl of packetizer is

    type state_type is (IDLE, SEND_HEADER, FORWARD_PAYLOAD, SEND_FOOTER);
    signal state : state_type := IDLE;

    signal payload_buffer : std_logic_vector(7 downto 0);
    signal last_seen      : std_logic := '0';  -- Tracks s_axis_tlast
    signal data_valid     : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                -- Reset all states and outputs
                state          <= IDLE;
                s_axis_tready  <= '0';
                m_axis_tvalid  <= '0';
                m_axis_tdata   <= (others => '0');
                data_valid     <= '0';
                last_seen      <= '0';

            else
                -- Defaults
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';

                case state is

                    when IDLE =>
                        -- Wait for input data to start a new packet
                        if s_axis_tvalid = '1' then
                            state         <= SEND_HEADER;
                            payload_buffer <= s_axis_tdata;
                            data_valid     <= '1';
                            last_seen      <= s_axis_tlast;
                        end if;

                    when SEND_HEADER =>
                        -- Send HEADER byte
                        if m_axis_tready = '1' then
                            m_axis_tdata  <= std_logic_vector(to_unsigned(HEADER, 8));
                            m_axis_tvalid <= '1';
                            state         <= FORWARD_PAYLOAD;
                        end if;

                    when FORWARD_PAYLOAD =>
                        -- Send buffered payload from IDLE phase
                        if m_axis_tready = '1' and data_valid = '1' then
                            m_axis_tdata  <= payload_buffer;
                            m_axis_tvalid <= '1';
                            data_valid    <= '0';

                            -- Ready to receive next payload byte
                            s_axis_tready <= '1';
                        end if;

                        -- Check for new data while output is valid
                        if s_axis_tready = '1' and s_axis_tvalid = '1' then
                            payload_buffer <= s_axis_tdata;
                            data_valid     <= '1';
                            last_seen      <= s_axis_tlast;

                            -- If last payload byte, next state is FOOTER
                            if s_axis_tlast = '1' then
                                state <= SEND_FOOTER;
                            end if;
                        end if;

                    when SEND_FOOTER =>
                        if m_axis_tready = '1' and data_valid = '1' then
                            -- Send last payload byte
                            m_axis_tdata  <= payload_buffer;
                            m_axis_tvalid <= '1';
                            data_valid    <= '0';
                        elsif m_axis_tready = '1' then
                            -- Send FOOTER byte after last payload
                            m_axis_tdata  <= std_logic_vector(to_unsigned(FOOTER, 8));
                            m_axis_tvalid <= '1';
                            state         <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;