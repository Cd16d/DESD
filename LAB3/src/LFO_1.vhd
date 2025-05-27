LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE IEEE.NUMERIC_STD.ALL;

-- Entity: LFO (Low Frequency Oscillator) - Alternative Implementation
-- Purpose: Applies tremolo effect to audio by modulating amplitude with a triangular wave
--          This is a simplified, single-process implementation compared to the pipelined version
--          Provides real-time audio amplitude modulation for musical effects
ENTITY LFO IS
    GENERIC (
        CHANNEL_LENGHT : INTEGER := 24;              -- Bit width of audio samples (24-bit signed)
        JOYSTICK_LENGHT : INTEGER := 10;             -- Bit width of joystick input (10-bit = 0-1023 range)
        CLK_PERIOD_NS : INTEGER := 10;               -- Clock period in nanoseconds (10ns = 100MHz)
        TRIANGULAR_COUNTER_LENGHT : INTEGER := 10    -- Triangular wave counter length (affects modulation depth)
    );
    PORT (
        -- Clock and Reset
        aclk : IN STD_LOGIC;        -- Main system clock
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- LFO Control inputs
        lfo_period : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);  -- Controls LFO frequency (joystick Y-axis)
        lfo_enable : IN STD_LOGIC;                                       -- Enable/bypass LFO effect

        -- Slave AXI Stream interface (audio input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);  -- Audio sample input
        s_axis_tlast : IN STD_LOGIC;                                       -- Channel indicator (0=left, 1=right)
        s_axis_tready : OUT STD_LOGIC;                                     -- Ready to accept input data

        -- Master AXI Stream interface (audio output)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0); -- Modulated audio sample output
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC                                       -- Downstream ready signal
    );
END ENTITY LFO;

ARCHITECTURE Behavioral OF LFO IS

    -- LFO timing configuration constants
    CONSTANT LFO_COUNTER_BASE_PERIOD_US : INTEGER := 1000; -- Base period: 1ms (1kHz base frequency)
    CONSTANT ADJUSTMENT_FACTOR : INTEGER := 90;             -- Frequency adjustment sensitivity (clock cycles per joystick unit)
    CONSTANT JSTK_CENTER_VALUE : INTEGER := 2 ** (JOYSTICK_LENGHT - 1); -- Joystick center position (512 for 10-bit)

    -- Calculate base clock cycles for 1ms period at current clock frequency
    CONSTANT LFO_COUNTER_BASE_CLK_CYCLES : INTEGER := LFO_COUNTER_BASE_PERIOD_US * 1000 / CLK_PERIOD_NS; -- 1ms = 100,000 clk cycles

    -- Calculate frequency range limits based on joystick range
    CONSTANT LFO_CLK_CYCLES_MIN : INTEGER := LFO_COUNTER_BASE_CLK_CYCLES - ADJUSTMENT_FACTOR * (2 ** (JOYSTICK_LENGHT - 1)); -- 53,920 clk cycles (faster)
    CONSTANT LFO_CLK_CYCLES_MAX : INTEGER := LFO_COUNTER_BASE_CLK_CYCLES + ADJUSTMENT_FACTOR * (2 ** (JOYSTICK_LENGHT - 1) - 1); -- 145,990 clk cycles (slower)

    -- LFO timing control signals
    SIGNAL step_clk_cycles_delta : INTEGER RANGE - 2 ** (JOYSTICK_LENGHT - 1) * ADJUSTMENT_FACTOR TO (2 ** (JOYSTICK_LENGHT - 1) - 1) * ADJUSTMENT_FACTOR := 0;
    SIGNAL step_clk_cycles : INTEGER RANGE LFO_CLK_CYCLES_MIN TO LFO_CLK_CYCLES_MAX := LFO_COUNTER_BASE_CLK_CYCLES;
    SIGNAL step_counter : NATURAL RANGE 0 TO LFO_CLK_CYCLES_MAX := 0;

    -- Triangular wave generation signals
    -- Note: Using signed counter with extra bit to handle full range calculations
    SIGNAL tri_counter : SIGNED(TRIANGULAR_COUNTER_LENGHT DOWNTO 0) := (OTHERS => '0');  -- Triangular wave amplitude
    SIGNAL direction_up : STD_LOGIC := '1';                                               -- Wave direction: '1' = ascending, '0' = descending

    -- AXI4-Stream control signals
    SIGNAL trigger : STD_LOGIC := '0';                     -- Trigger to indicate new processed data is ready
    SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';            -- Registered version of tlast for output synchronization
    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';           -- Internal output valid signal

    -- Audio processing signal with extended width for multiplication
    -- Width accommodates: audio sample + triangular counter to prevent overflow
    SIGNAL m_axis_tdata_temp : SIGNED(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT DOWNTO 0) := (OTHERS => '0');

BEGIN

    -- Output signal assignments with proper AXI4-Stream flow control
    m_axis_tvalid <= m_axis_tvalid_int;
    -- Input ready logic: Ready when downstream is ready OR no valid data pending, AND not in reset
    s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

    -- Optimized single process for LFO timing and triangular waveform generation
    -- This process handles both the frequency control and wave shape generation
    triangular_wave_lfo_generator : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset LFO generator to initial state
                step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES;  -- Set to base frequency
                step_counter <= 0;                               -- Clear timing counter
                tri_counter <= (OTHERS => '0');                 -- Start triangular wave at zero
                direction_up <= '1';                            -- Start counting up

            ELSE
                -- Calculate LFO period based on joystick input
                -- Joystick mapping:
                -- 0-511: Faster than base frequency (shorter period, higher frequency)
                -- 512: Base frequency (1kHz)
                -- 513-1023: Slower than base frequency (longer period, lower frequency)
                step_clk_cycles_delta <= (to_integer(unsigned(lfo_period)) - JSTK_CENTER_VALUE) * ADJUSTMENT_FACTOR;
                step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES - step_clk_cycles_delta;

                -- Generate triangular wave when LFO is enabled
                IF lfo_enable = '1' THEN

                    -- Clock divider: Update triangular wave at calculated rate
                    IF step_counter >= step_clk_cycles THEN
                        step_counter <= 0;  -- Reset counter for next period

                        -- Check for triangular wave direction changes at extremes
                        -- Note: Using (2^n - 2) and 1 instead of (2^n - 1) and 0 to avoid edge cases
                        IF tri_counter = (2 ** TRIANGULAR_COUNTER_LENGHT) - 2 THEN
                            direction_up <= '0';  -- Switch to descending at near-maximum

                        ELSIF tri_counter = 1 THEN
                            direction_up <= '1';  -- Switch to ascending at near-minimum

                        END IF;

                        -- Update triangular wave value based on current direction
                        -- This creates the classic triangular waveform shape
                        IF direction_up = '1' THEN
                            tri_counter <= tri_counter + 1;  -- Ascending: increment
                        ELSE
                            tri_counter <= tri_counter - 1;  -- Descending: decrement
                        END IF;

                    ELSE
                        step_counter <= step_counter + 1;  -- Continue counting towards next update

                    END IF;

                END IF;

            END IF;

        END IF;

    END PROCESS triangular_wave_lfo_generator;

    -- AXI4-Stream handshake logic and audio processing
    -- This process handles input/output data flow and applies the LFO modulation
    AXIS : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset AXI4-Stream interface and audio processing
                s_axis_tlast_reg <= '0';                  -- Clear registered channel indicator
                m_axis_tdata_temp <= (OTHERS => '0');     -- Clear temporary audio data
                m_axis_tvalid_int <= '0';                 -- No valid output data
                m_axis_tlast <= '0';                      -- Clear output channel indicator

            ELSE
                -- Output handshake management:
                -- Clear valid flag when downstream accepts data
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data output logic: Send processed audio when trigger is active and output is available
                IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                    -- Scale down the multiplication result to original audio bit width
                    -- Right shift by TRIANGULAR_COUNTER_LENGHT effectively divides by 2^TRIANGULAR_COUNTER_LENGHT
                    -- This maintains proper audio amplitude after modulation
                    m_axis_tdata <= STD_LOGIC_VECTOR(
                        resize(
                            shift_right(
                                m_axis_tdata_temp,                -- Wide multiplication result
                                TRIANGULAR_COUNTER_LENGHT         -- Scale factor
                            ),
                            CHANNEL_LENGHT                        -- Final audio sample width
                        )
                    );
                    m_axis_tlast <= s_axis_tlast_reg;             -- Output registered channel indicator

                    m_axis_tvalid_int <= '1';                     -- Mark output as valid
                    trigger <= '0';                               -- Clear trigger - data has been output
                    
                END IF;

                -- Data input logic: Process new audio samples when available and output is ready
                IF s_axis_tvalid = '1' AND (m_axis_tready = '1' OR m_axis_tvalid_int = '0') THEN	
                    IF lfo_enable = '1' THEN
                        -- Apply LFO tremolo effect: multiply audio sample by triangular wave
                        -- This creates amplitude modulation (tremolo effect)
                        m_axis_tdata_temp <= signed(s_axis_tdata) * tri_counter;
                        s_axis_tlast_reg <= s_axis_tlast;         -- Register channel indicator

                    ELSE
                        -- LFO disabled: pass audio through unchanged but maintain bit width
                        -- Left shift compensates for the right shift that occurs during output
                        -- This ensures unity gain when LFO is bypassed
                        m_axis_tdata_temp <= shift_left(
                            resize(
                                signed(s_axis_tdata),             -- Convert input to signed
                                m_axis_tdata_temp'length          -- Extend to full processing width
                            ),
                            TRIANGULAR_COUNTER_LENGHT             -- Compensate for output scaling
                        );
                        s_axis_tlast_reg <= s_axis_tlast;         -- Register channel indicator

                    END IF;

                    trigger <= '1';  -- Set trigger to indicate new processed data is ready

                END IF;

            END IF;

        END IF;

    END PROCESS AXIS;

    -- LFO Implementation Summary:
    -- 1. Generates triangular wave at frequency controlled by joystick input
    -- 2. When enabled: multiplies audio samples by triangular wave (tremolo effect)
    -- 3. When disabled: passes audio through unchanged (bypass mode)
    -- 4. Uses proper AXI4-Stream handshaking for real-time audio processing
    --
    -- Tremolo Effect Characteristics:
    -- - Frequency range: Approximately 0.1Hz to 10Hz (typical for audio LFO)
    -- - Modulation depth: Controlled by TRIANGULAR_COUNTER_LENGHT generic
    -- - Waveform: Triangular (linear amplitude changes, smooth transitions)
    -- - Bypass capability: Clean audio passthrough when disabled

END ARCHITECTURE Behavioral;