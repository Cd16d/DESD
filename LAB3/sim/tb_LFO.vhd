-- filepath: c:\DESD\LAB3\sim\tb_LFO.vhd
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_LFO IS
END tb_LFO;

ARCHITECTURE sim OF tb_LFO IS

    CONSTANT CHANNEL_LENGHT           : INTEGER := 24;
    CONSTANT JOYSTICK_LENGHT          : INTEGER := 10;
    CONSTANT TRIANGULAR_COUNTER_LENGHT: INTEGER := 10;
    CONSTANT CLK_PERIOD_NS            : INTEGER := 10;

    SIGNAL aclk           : STD_LOGIC := '0';
    SIGNAL aresetn        : STD_LOGIC := '0';

    SIGNAL lfo_period     : STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL lfo_enable     : STD_LOGIC := '0';

    SIGNAL s_axis_tvalid  : STD_LOGIC := '0';
    SIGNAL s_axis_tdata   : STD_LOGIC_VECTOR(CHANNEL_LENGHT-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tlast   : STD_LOGIC := '0';
    SIGNAL s_axis_tready  : STD_LOGIC;

    SIGNAL m_axis_tvalid  : STD_LOGIC;
    SIGNAL m_axis_tdata   : STD_LOGIC_VECTOR(CHANNEL_LENGHT-1 DOWNTO 0);
    SIGNAL m_axis_tlast   : STD_LOGIC;
    SIGNAL m_axis_tready  : STD_LOGIC := '1';

    -- DUT
    COMPONENT LFO
        GENERIC (
            CHANNEL_LENGHT : INTEGER := 24;
            JOYSTICK_LENGHT : INTEGER := 10;
            CLK_PERIOD_NS : INTEGER := 10;
            TRIANGULAR_COUNTER_LENGHT : INTEGER := 10
        );
        PORT (
            aclk           : IN  STD_LOGIC;
            aresetn        : IN  STD_LOGIC;
            lfo_period     : IN  STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 DOWNTO 0);
            lfo_enable     : IN  STD_LOGIC;
            s_axis_tvalid  : IN  STD_LOGIC;
            s_axis_tdata   : IN  STD_LOGIC_VECTOR(CHANNEL_LENGHT-1 DOWNTO 0);
            s_axis_tlast   : IN  STD_LOGIC;
            s_axis_tready  : OUT STD_LOGIC;
            m_axis_tvalid  : OUT STD_LOGIC;
            m_axis_tdata   : OUT STD_LOGIC_VECTOR(CHANNEL_LENGHT-1 DOWNTO 0);
            m_axis_tlast   : OUT STD_LOGIC;
            m_axis_tready  : IN  STD_LOGIC
        );
    END COMPONENT;

BEGIN

    -- Clock generation
    clk_proc : PROCESS
    BEGIN
        aclk <= '0';
        WAIT FOR 5 ns;
        aclk <= '1';
        WAIT FOR 5 ns;
    END PROCESS;

    -- DUT instantiation
    dut: LFO
        GENERIC MAP (
            CHANNEL_LENGHT => CHANNEL_LENGHT,
            JOYSTICK_LENGHT => JOYSTICK_LENGHT,
            CLK_PERIOD_NS => CLK_PERIOD_NS,
            TRIANGULAR_COUNTER_LENGHT => TRIANGULAR_COUNTER_LENGHT
        )
        PORT MAP (
            aclk           => aclk,
            aresetn        => aresetn,
            lfo_period     => lfo_period,
            lfo_enable     => lfo_enable,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tlast   => s_axis_tlast,
            s_axis_tready  => s_axis_tready,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tlast   => m_axis_tlast,
            m_axis_tready  => m_axis_tready
        );

    -- Stimulus process
    stim_proc : PROCESS
        VARIABLE data_cnt : INTEGER := 0;
    BEGIN
        -- Reset
        aresetn <= '0';
        WAIT FOR 20 ns;
        aresetn <= '1';
        WAIT FOR 10 ns;

        -- Imposta parametri iniziali
        lfo_enable <= '1'; -- o '0' se vuoi testare la modalità bypass
        lfo_period <= std_logic_vector(to_unsigned(512, JOYSTICK_LENGHT)); -- Valore fisso

        -- Loop infinito: invia dati ad ogni ciclo di clock
        WHILE TRUE LOOP
            WAIT UNTIL rising_edge(aclk);
            s_axis_tdata  <= std_logic_vector(to_signed(data_cnt, CHANNEL_LENGHT));
            s_axis_tvalid <= '1';
            s_axis_tlast  <= '0'; -- Puoi impostare a '1' ogni N campioni se vuoi testare tlast

            IF s_axis_tready = '1' THEN
                data_cnt := data_cnt + 1;
            END IF;
        END LOOP;
    END PROCESS;

END sim;