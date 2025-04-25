---------- DEFAULT LIBRARIES -------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
------------------------------------

ENTITY rgb2gray IS
    PORT (
        clk : IN STD_LOGIC;
        resetn : IN STD_LOGIC;

        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_tready : IN STD_LOGIC;
        m_axis_tlast : OUT STD_LOGIC;

        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tlast : IN STD_LOGIC
    );
END rgb2gray;

ARCHITECTURE Behavioral OF rgb2gray IS

    COMPONENT divider_by_3
        GENERIC (
            BIT_DEPTH : INTEGER := 7
        );
        PORT (
            dividend : IN UNSIGNED(BIT_DEPTH + 1 DOWNTO 0);
            result : OUT UNSIGNED(BIT_DEPTH - 1 DOWNTO 0)
        );
    END COMPONENT;

    TYPE state_type IS (IDLE, ACCUMULATE, WAIT_DIV, SEND);
    SIGNAL state : state_type := IDLE;

    SIGNAL sum : UNSIGNED(8 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rgb_sum : UNSIGNED(8 DOWNTO 0) := (OTHERS => '0');
    SIGNAL gray : UNSIGNED(6 DOWNTO 0);
    SIGNAL count : INTEGER RANGE 0 TO 2 := 0;

    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';
    SIGNAL m_axis_tdata_int : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL m_axis_tlast_int : STD_LOGIC := '0';
    SIGNAL s_axis_tready_int : STD_LOGIC := '1';

    SIGNAL last_seen : STD_LOGIC := '0';

BEGIN

    -- Connect internal signals to output ports
    s_axis_tready <= s_axis_tready_int;
    m_axis_tvalid <= m_axis_tvalid_int;
    m_axis_tdata <= m_axis_tdata_int;
    m_axis_tlast <= m_axis_tlast_int;

    -- Divider instance: divides the sum of RGB by 3 to obtain grayscale value
    DIVIDER : divider_by_3
    GENERIC MAP(
        BIT_DEPTH => 7
    )
    PORT MAP(
        dividend => rgb_sum,
        result => gray
    );

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF resetn = '0' THEN
                -- Asynchronous reset: initialize all signals and state
                state <= IDLE;
                sum <= (OTHERS => '0');
                rgb_sum <= (OTHERS => '0');
                count <= 0;
                m_axis_tvalid_int <= '0';
                m_axis_tdata_int <= (OTHERS => '0');
                m_axis_tlast_int <= '0';
                s_axis_tready_int <= '1';
                last_seen <= '0';
            ELSE
                -- Default assignments for each clock cycle
                m_axis_tlast_int <= '0';

                CASE state IS
                    WHEN IDLE =>
                        -- Wait for the first valid input sample
                        m_axis_tdata_int <= (OTHERS => '0');
                        sum <= (OTHERS => '0');
                        count <= 0;
                        m_axis_tvalid_int <= '0';
                        s_axis_tready_int <= '1';
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            sum <= unsigned('0' & s_axis_tdata);
                            count <= 1;
                            IF s_axis_tlast = '1' THEN
                                last_seen <= '1';
                            END IF;
                            state <= ACCUMULATE;
                        END IF;

                    WHEN ACCUMULATE =>
                        -- Accumulate the next two color components (expecting 3 total: R, G, B)
                        IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
                            sum <= sum + unsigned(s_axis_tdata);
                            IF count = 2 THEN
                                rgb_sum <= sum + unsigned(s_axis_tdata);
                                s_axis_tready_int <= '0';
                                IF s_axis_tlast = '1' THEN
                                    last_seen <= '1';
                                END IF;
                                state <= WAIT_DIV;
                            ELSE
                                count <= count + 1;
                                IF s_axis_tlast = '1' THEN
                                    last_seen <= '1';
                                END IF;
                            END IF;
                        END IF;

                    WHEN WAIT_DIV =>
                        -- Now gray is valid (output from divider)
                        m_axis_tdata_int <= '0' & STD_LOGIC_VECTOR(gray);
                        m_axis_tvalid_int <= '1';
                        s_axis_tready_int <= '0';
                        IF last_seen = '1' THEN
                            m_axis_tlast_int <= '1';
                            last_seen <= '0';
                        END IF;
                        state <= SEND;

                    WHEN SEND =>
                        -- Hold the data until it is accepted by the downstream module
                        IF m_axis_tvalid_int = '1' AND m_axis_tready = '1' THEN
                            m_axis_tvalid_int <= '0';
                            s_axis_tready_int <= '1';
                            state <= IDLE;
                        END IF;

                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;