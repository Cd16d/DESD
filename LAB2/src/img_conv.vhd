library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity img_conv is
    generic(
        LOG2_N_COLS: POSITIVE :=8;
        LOG2_N_ROWS: POSITIVE :=8
    );
    port (

        clk   : in std_logic;
        aresetn : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic; 
        m_axis_tlast : out std_logic;
        
        conv_addr: out std_logic_vector(LOG2_N_COLS+LOG2_N_ROWS-1 downto 0);
        conv_data: in std_logic_vector(6 downto 0);

        start_conv: in std_logic;
        done_conv: out std_logic
        
    );
end entity img_conv;

architecture rtl of img_conv is


    type conv_mat_type is array(0 to 2, 0 to 2) of integer;
    constant conv_mat : conv_mat_type := ((-1,-1,-1),(-1,8,-1),(-1,-1,-1));

   

begin



end architecture;
