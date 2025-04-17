library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE :=16
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end entity bram_writer;

architecture rtl of bram_writer is

    component bram_controller is
        generic (
            ADDR_WIDTH: POSITIVE :=16
        );
        port (
            clk   : in std_logic;
            aresetn : in std_logic;
    
            addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
            dout: out std_logic_vector(7 downto 0);
            din: in std_logic_vector(7 downto 0);
            we: in std_logic
        );
    end component;

    TYPE state_type is (IDLE, RECEIVING, CONVOLUTION);
    SIGNAL state : state_type := IDLE;

    SIGNAL s_axis_tready_int : std_logic := '0';

    SIGNAL bram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0'); -- Indirizzo BRAM
    SIGNAL bram_we : std_logic := '0'; -- Segnale di scrittura per il BRAM

    SIGNAL wr_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0'); -- Indirizzo di scrittura BRAM

begin
    
    BRAM_CTRL: bram_controller
        generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk => clk,
            aresetn => aresetn,
            addr => bram_addr,
            dout => conv_data,
            din => s_axis_tdata,
            we => bram_we
        );

    -- AXIS
    s_axis_tready <= s_axis_tready_int

    -- Gestione addr BRAM
    with state select bram_addr <=  conv_addr   when CONVOLUTION,
                                    wr_addr     when Others;

    process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                state <= IDLE;

                s_axis_tready_int <= '0';

                bram_we <= '0';
                wr_addr <= (others => '0');
                
                start_conv <= '0';
                write_ok <= '0';
                overflow <= '0';
                underflow <= '0';
            else
                start_conv <= '0';
                write_ok <= '0';
                overflow <= '0';
                underflow <= '0';

                case state is
                    when IDLE =>
                        s_axis_tready_int <= '1';


                    when RECEIVING =>


                    when CONVOLUTION =>

                end case;
            end if;
        end if;
    end process; 

end architecture;
