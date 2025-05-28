LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Entity: digilent_jstk2
-- Purpose: Interface controller for the Digilent JSTK2 joystick module via SPI
--          Sends LED color commands and receives joystick/button data
ENTITY digilent_jstk2 IS
    GENERIC (
        DELAY_US : INTEGER := 25;           -- Delay (in microseconds) between two SPI packets
        CLKFREQ : INTEGER := 100_000_000;   -- Frequency of the aclk signal (in Hz)
        SPI_SCLKFREQ : INTEGER := 5_000     -- Frequency of the SPI SCLK clock signal (in Hz)
    );
    PORT (
        aclk : IN STD_LOGIC;        -- Main clock input
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- AXI4-Stream Master Interface: Data going TO the SPI IP-Core (and so, to the JSTK2 module)
        m_axis_tvalid : OUT STD_LOGIC;                      -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);   -- 8-bit data to send via SPI
        m_axis_tready : IN STD_LOGIC;                       -- SPI IP-Core ready to accept data

        -- AXI4-Stream Slave Interface: Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
        -- Note: There is no tready signal, so you must be always ready to accept incoming data, or it will be lost!
        s_axis_tvalid : IN STD_LOGIC;                       -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);    -- 8-bit data received via SPI

        -- Joystick and button values read from the JSTK2 module
        jstk_x : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);         -- X-axis joystick position (10-bit, 0-1023)
        jstk_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);         -- Y-axis joystick position (10-bit, 0-1023)
        btn_jstk : OUT STD_LOGIC;                           -- Joystick button state (1=pressed)
        btn_trigger : OUT STD_LOGIC;                        -- Trigger button state (1=pressed)

        -- LED color values to send to the JSTK2 module
        led_r : IN STD_LOGIC_VECTOR(7 DOWNTO 0);           -- Red LED intensity (0-255)
        led_g : IN STD_LOGIC_VECTOR(7 DOWNTO 0);           -- Green LED intensity (0-255)
        led_b : IN STD_LOGIC_VECTOR(7 DOWNTO 0)            -- Blue LED intensity (0-255)
    );
END digilent_jstk2;

ARCHITECTURE Behavioral OF digilent_jstk2 IS

    -- Command code for the SetLEDRGB command, see the JSTK2 datasheet
    CONSTANT CMDSETLEDRGB : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"84";

    -- Calculate delay in clock cycles: (delay_period + 1_SPI_clock_period) * clock_frequency
    -- Uses integer arithmetic optimized to avoid truncation by performing multiplications before divisions
    -- Formula: ((DELAY_US * SPI_SCLKFREQ + 1_000_000) * CLKFREQ) / (SPI_SCLKFREQ * 1_000_000)
    -- This ensures proper timing between SPI packets as required by JSTK2 datasheet
    CONSTANT DELAY_CLK_CYCLES : INTEGER := ((DELAY_US * SPI_SCLKFREQ + 1_000_000) * CLKFREQ) / (SPI_SCLKFREQ * 1_000_000);

    -- State machine type definitions
    TYPE tx_state_type IS (DELAY, SEND_CMD, SEND_RED, SEND_GREEN, SEND_BLUE, SEND_DUMMY);
    TYPE rx_state_type IS (JSTK_X_LOW, JSTK_X_HIGH, JSTK_Y_LOW, JSTK_Y_HIGH, BUTTONS);

    -- State machine signals
    SIGNAL tx_state : tx_state_type := DELAY;           -- Transmit state machine current state
    SIGNAL rx_state : rx_state_type := JSTK_X_LOW;      -- Receive state machine current state

    -- Timing and data storage signals
    SIGNAL tx_delay_counter : INTEGER := 0;             -- Counter for inter-packet delay timing
    SIGNAL rx_cache : STD_LOGIC_VECTOR(7 DOWNTO 0);     -- Temporary storage for multi-byte data reception

BEGIN

    -- Output valid signal control: Set to '1' when we want to send data to SPI IP-Core
    -- Only inactive during DELAY state when waiting between packets
    WITH tx_state SELECT m_axis_tvalid <=
        '0' WHEN DELAY,         -- No transmission during delay
        '1' WHEN SEND_CMD,      -- Send command byte
        '1' WHEN SEND_RED,      -- Send red LED value
        '1' WHEN SEND_GREEN,    -- Send green LED value
        '1' WHEN SEND_BLUE,     -- Send blue LED value
        '1' WHEN SEND_DUMMY;    -- Send dummy byte to complete transaction

    -- Output data multiplexer: Select what data to send based on current TX state
    WITH tx_state SELECT m_axis_tdata <=
        (OTHERS => '0') WHEN DELAY,         -- No data during delay
        CMDSETLEDRGB WHEN SEND_CMD,         -- SetLEDRGB command (0x84)
        led_r WHEN SEND_RED,                -- Red LED intensity value
        led_g WHEN SEND_GREEN,              -- Green LED intensity value
        led_b WHEN SEND_BLUE,               -- Blue LED intensity value
        "01101001" WHEN SEND_DUMMY;         -- Dummy byte to complete 5-byte transaction

    -- TX State Machine: Sends LED color commands to JSTK2 module
    -- Protocol: Command(1) + Red(1) + Green(1) + Blue(1) + Dummy(1) = 5 bytes total
    TX : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                -- Reset: Start in delay state with counter cleared
                tx_state <= DELAY;
                tx_delay_counter <= 0;

            ELSE

                CASE tx_state IS

                    WHEN DELAY =>
                        -- Wait for required delay period between SPI transactions
                        IF tx_delay_counter >= DELAY_CLK_CYCLES THEN
                            tx_delay_counter <= 0;     -- Reset counter
                            tx_state <= SEND_CMD;      -- Start new transmission
                        ELSE
                            tx_delay_counter <= tx_delay_counter + 1;  -- Continue counting
                        END IF;

                    WHEN SEND_CMD =>
                        -- Send SetLEDRGB command byte
                        IF m_axis_tready = '1' THEN
                            tx_state <= SEND_RED;      -- Move to red LED transmission
                        END IF;

                    WHEN SEND_RED =>
                        -- Send red LED intensity value
                        IF m_axis_tready = '1' THEN
                            tx_state <= SEND_GREEN;    -- Move to green LED transmission
                        END IF;

                    WHEN SEND_GREEN =>
                        -- Send green LED intensity value
                        IF m_axis_tready = '1' THEN
                            tx_state <= SEND_BLUE;     -- Move to blue LED transmission
                        END IF;

                    WHEN SEND_BLUE =>
                        -- Send blue LED intensity value
                        IF m_axis_tready = '1' THEN
                            tx_state <= SEND_DUMMY;    -- Move to dummy byte transmission
                        END IF;

                    WHEN SEND_DUMMY =>
                        -- Send dummy byte to complete 5-byte transaction
                        IF m_axis_tready = '1' THEN
                            tx_state <= DELAY;         -- Return to delay state
                        END IF;

                END CASE;
            END IF;
        END IF;
    END PROCESS TX;

    -- RX State Machine: Receives 5 bytes of response data and updates outputs
    -- Protocol: X_low(1) + X_high(1) + Y_low(1) + Y_high(1) + Buttons(1) = 5 bytes total
    RX : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Start waiting for X-axis low byte
                rx_state <= JSTK_X_LOW;
                rx_cache <= (OTHERS => '0');

            ELSE

                CASE rx_state IS

                    WHEN JSTK_X_LOW =>
                        -- Receive X-axis low byte (bits 7:0)
                        IF s_axis_tvalid = '1' THEN
                            rx_cache <= s_axis_tdata;      -- Store low byte temporarily
                            rx_state <= JSTK_X_HIGH;       -- Wait for high byte
                        END IF;

                    WHEN JSTK_X_HIGH =>
                        -- Receive X-axis high byte (bits 9:8) and assemble complete X value
                        IF s_axis_tvalid = '1' THEN
                            -- Combine: high_byte(1:0) & low_byte(7:0) = 10-bit X position
                            jstk_x <= s_axis_tdata(1 DOWNTO 0) & rx_cache;
                            rx_state <= JSTK_Y_LOW;        -- Move to Y-axis reception
                        END IF;

                    WHEN JSTK_Y_LOW =>
                        -- Receive Y-axis low byte (bits 7:0)
                        IF s_axis_tvalid = '1' THEN
                            rx_cache <= s_axis_tdata;      -- Store low byte temporarily
                            rx_state <= JSTK_Y_HIGH;       -- Wait for high byte
                        END IF;

                    WHEN JSTK_Y_HIGH =>
                        -- Receive Y-axis high byte (bits 9:8) and assemble complete Y value
                        IF s_axis_tvalid = '1' THEN
                            -- Combine: high_byte(1:0) & low_byte(7:0) = 10-bit Y position
                            jstk_y <= s_axis_tdata(1 DOWNTO 0) & rx_cache;
                            rx_state <= BUTTONS;           -- Move to button reception
                        END IF;

                    WHEN BUTTONS =>
                        -- Receive button states byte
                        IF s_axis_tvalid = '1' THEN
                            btn_jstk <= s_axis_tdata(0);   -- Joystick button (bit 0)
                            btn_trigger <= s_axis_tdata(1); -- Trigger button (bit 1)
                            rx_state <= JSTK_X_LOW;        -- Return to start for next packet
                        END IF;

                END CASE;
            END IF;
        END IF;
    END PROCESS RX;

END ARCHITECTURE;