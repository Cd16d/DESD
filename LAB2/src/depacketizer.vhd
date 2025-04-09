library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity depacketizer is
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

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic; 
        m_axis_tlast : out std_logic
    );
end entity depacketizer;

architecture rtl of depacketizer is

    -- Enumeration for the state machine
    -- IDLE: Waiting for the start of a new packet
    -- STREAMING: Actively processing and forwarding packet data
    type state_type is (IDLE, STREAMING);
    signal state : state_type := IDLE;

    -- Buffer to handle backpressure
    signal buffer_in : std_logic_vector(7 downto 0) := (others => '0');
    signal buffer_valid  : std_logic := '0'; -- Indicates if buffer_in contains valid data
begin

    depacketizer_fsm: process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                -- Reset: back to idle and clear everything
                state         <= IDLE;
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';
                m_axis_tlast  <= '0';
                m_axis_tdata  <= (others => '0');
                buffer_in    <= (others => '0');
                buffer_valid  <= '0';

            else
                -- Defaults for each clock cycle
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
                m_axis_tlast  <= '0';

                case state is

                    when IDLE =>
                        -- Wait for start of a new packet
                        if s_axis_tvalid = '1' then
                            if s_axis_tdata = std_logic_vector(to_unsigned(HEADER, 8)) then
                                state <= STREAMING;
                            end if;
                        end if;

                    when STREAMING =>
                        if s_axis_tvalid = '1' then
                            -- End of packet detected
                            if s_axis_tdata = std_logic_vector(to_unsigned(FOOTER, 8)) then
                                state        <= IDLE;
                                m_axis_tlast <= '1';  -- Let receiver know packet ends
                            else
                                -- Valid payload: send to output
                                if buffer_valid = '1' then
                                    if m_axis_tready = '1' then
                                        m_axis_tdata  <= buffer_in;
                                        m_axis_tvalid <= '1';
                                        buffer_valid  <= '0'; -- Clear the buffer
                                    end if;
                                else
                                    if m_axis_tready = '1' then
                                        m_axis_tdata  <= s_axis_tdata;
                                        m_axis_tvalid <= '1';
                                    else
                                        buffer_in    <= s_axis_tdata;
                                        buffer_valid  <= '1'; -- Mark buffer as valid
                                    end if;
                                end if;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;
