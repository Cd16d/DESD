LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: LFO (Low Frequency Oscillator)
-- Purpose: Applies tremolo effect to audio by modulating amplitude with a triangular wave
--          Creates classic audio effects like vibrato, tremolo, and amplitude modulation
--          Implements a 3-stage pipeline for efficient real-time audio processing
ENTITY LFO IS
    GENERIC (
        CHANNEL_LENGHT : INTEGER := 24;              -- Bit width of audio samples (24-bit signed)
        JOYSTICK_LENGHT : INTEGER := 10;             -- Bit width of joystick input (10-bit = 0-1023 range)
        CLK_PERIOD_NS : INTEGER := 10;               -- Clock period in nanoseconds (10ns = 100MHz)
        TRIANGULAR_COUNTER_LENGHT : INTEGER := 10    -- Bit width of triangular wave counter (affects modulation depth)
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

    -- Constants for LFO timing configuration
    CONSTANT BASE_PERIOD_MICROSECONDS : INTEGER := 1000;  -- Base period: 1ms (1kHz base frequency)
    CONSTANT FREQUENCY_ADJUSTMENT_FACTOR : INTEGER := 90;  -- Frequency adjustment sensitivity (clock cycles per joystick unit)
    CONSTANT JOYSTICK_CENTER_VALUE : INTEGER := 2 ** (JOYSTICK_LENGHT - 1);  -- Joystick center position (512 for 10-bit)

    -- Calculate base clock cycles for 1ms period at current clock frequency
    CONSTANT BASE_CLOCK_CYCLES : INTEGER := BASE_PERIOD_MICROSECONDS * 1000 / CLK_PERIOD_NS;

    -- Calculate frequency range limits based on joystick range
    -- Minimum frequency (fastest LFO): occurs when joystick is at minimum position
    CONSTANT MIN_CLOCK_CYCLES : INTEGER := BASE_CLOCK_CYCLES - FREQUENCY_ADJUSTMENT_FACTOR * (2 ** (JOYSTICK_LENGHT - 1));
    -- Maximum frequency (slowest LFO): occurs when joystick is at maximum position
    CONSTANT MAX_CLOCK_CYCLES : INTEGER := BASE_CLOCK_CYCLES + FREQUENCY_ADJUSTMENT_FACTOR * (2 ** (JOYSTICK_LENGHT - 1) - 1);

    -- Internal signals for LFO control
    -- Period adjustment based on joystick input (positive = slower, negative = faster)
    SIGNAL period_adjustment_delta : INTEGER RANGE - 2 ** (JOYSTICK_LENGHT - 1) * FREQUENCY_ADJUSTMENT_FACTOR 
        TO (2 ** (JOYSTICK_LENGHT - 1) - 1) * FREQUENCY_ADJUSTMENT_FACTOR := 0;
    SIGNAL current_period_cycles : INTEGER RANGE MIN_CLOCK_CYCLES TO MAX_CLOCK_CYCLES := BASE_CLOCK_CYCLES;

    -- Pipeline stage 1 registers - Input processing and period calculation
    SIGNAL audio_data_stage1 : STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0'); -- Registered audio input
    SIGNAL enable_flag_stage1 : STD_LOGIC := '0';                                                 -- Registered LFO enable
    SIGNAL valid_flag_stage1 : STD_LOGIC := '0';                                                  -- Valid data in stage 1
    SIGNAL last_flag_stage1 : STD_LOGIC := '0';                                                   -- Registered channel indicator

    -- Pipeline stage 2 registers - Triangular wave generation
    SIGNAL triangular_wave_value : unsigned(TRIANGULAR_COUNTER_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');  -- Current triangular wave amplitude
    SIGNAL wave_direction_up : STD_LOGIC := '1';                              -- Triangle wave direction: '1' = ascending, '0' = descending
    SIGNAL timing_counter : NATURAL RANGE 0 TO MAX_CLOCK_CYCLES := 0;        -- Clock cycle counter for LFO timing
    SIGNAL enable_flag_stage2 : STD_LOGIC := '0';                             -- LFO enable flag for stage 2
    SIGNAL valid_flag_stage2 : STD_LOGIC := '0';                              -- Valid data in stage 2
    SIGNAL last_flag_stage2 : STD_LOGIC := '0';                               -- Channel indicator for stage 2
    SIGNAL audio_data_stage2 : STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0'); -- Audio data for stage 2

    -- Pipeline stage 3 registers - Modulation and output
    -- Extended width to accommodate multiplication result before scaling
    SIGNAL multiplication_result : STD_LOGIC_VECTOR(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');

    -- Internal AXI4-Stream control signals
    SIGNAL master_valid_internal : STD_LOGIC := '0';  -- Internal output valid signal
    SIGNAL slave_ready_internal : STD_LOGIC := '1';   -- Internal input ready signal

BEGIN

    -- Direct connection: tlast passes through unchanged (maintains channel timing)
    m_axis_tlast <= last_flag_stage1;

    -- Pipeline stage 1: Input registration and LFO period calculation
    -- This stage captures input data and calculates the LFO period based on joystick position
    input_processing_stage : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                -- Reset all stage 1 registers to safe initial states
                audio_data_stage1 <= (OTHERS => '0');         -- Clear audio data
                current_period_cycles <= BASE_CLOCK_CYCLES;   -- Set to base frequency
                enable_flag_stage1 <= '0';                    -- Disable LFO
                valid_flag_stage1 <= '0';                     -- No valid data
                last_flag_stage1 <= '0';                      -- Clear channel indicator
            ELSE
                -- Calculate LFO period based on joystick y-axis input
                -- Joystick mapping:
                -- 0-511: Faster than base frequency (shorter period)
                -- 512: Base frequency (1kHz)
                -- 513-1023: Slower than base frequency (longer period)
                period_adjustment_delta <= (to_integer(unsigned(lfo_period)) - JOYSTICK_CENTER_VALUE) * FREQUENCY_ADJUSTMENT_FACTOR;
                current_period_cycles <= BASE_CLOCK_CYCLES - period_adjustment_delta;

                -- AXI4-Stream handshake: accept new data when both valid and ready
                IF s_axis_tvalid = '1' AND slave_ready_internal = '1' THEN
                    audio_data_stage1 <= s_axis_tdata;      -- Register input audio sample
                    enable_flag_stage1 <= lfo_enable;       -- Register enable control
                    valid_flag_stage1 <= '1';               -- Mark data as valid for next stage
                    last_flag_stage1 <= s_axis_tlast;       -- Register channel boundary signal
                ELSE
                    valid_flag_stage1 <= '0';               -- No valid data to pass to next stage
                END IF;
            END IF;
        END IF;
    END PROCESS input_processing_stage;

    -- Pipeline stage 2: Triangular wave generation
    -- This stage generates the triangular wave that will modulate the audio amplitude
    triangular_wave_generator : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                -- Reset triangular wave generator to initial state
                timing_counter <= 0;                           -- Clear timing counter
                triangular_wave_value <= (OTHERS => '0');      -- Start at zero amplitude
                wave_direction_up <= '1';                      -- Start counting up
                enable_flag_stage2 <= '0';                     -- Disable LFO
                valid_flag_stage2 <= '0';                      -- No valid data
                last_flag_stage2 <= '0';                       -- Clear channel indicator
                audio_data_stage2 <= (OTHERS => '0');          -- Clear audio data
            ELSE
                -- Pass through pipeline registers from stage 1 to stage 2
                enable_flag_stage2 <= enable_flag_stage1;      -- Forward enable flag
                valid_flag_stage2 <= valid_flag_stage1;        -- Forward valid flag
                last_flag_stage2 <= last_flag_stage1;          -- Forward channel indicator
                audio_data_stage2 <= audio_data_stage1;        -- Forward audio data

                -- Generate triangular wave when LFO is enabled
                IF enable_flag_stage1 = '1' THEN
                    -- Clock divider: update triangular counter based on calculated period
                    IF timing_counter < current_period_cycles THEN
                        timing_counter <= timing_counter + 1;    -- Count towards period target
                    ELSE
                        timing_counter <= 0;                     -- Reset counter for next period

                        -- Update triangular wave: count up or down based on current direction
                        -- This creates the classic triangular waveform shape
                        IF wave_direction_up = '1' THEN
                            -- Ascending phase: check if we reached maximum amplitude
                            IF triangular_wave_value = (2 ** TRIANGULAR_COUNTER_LENGHT) - 1 THEN
                                wave_direction_up <= '0';           -- Switch to descending phase
                                triangular_wave_value <= triangular_wave_value - 1;  -- Start decreasing
                            ELSE
                                triangular_wave_value <= triangular_wave_value + 1;  -- Continue increasing
                            END IF;
                        ELSE
                            -- Descending phase: check if we reached minimum amplitude
                            IF triangular_wave_value = 0 THEN
                                wave_direction_up <= '1';           -- Switch to ascending phase
                                triangular_wave_value <= triangular_wave_value + 1;  -- Start increasing
                            ELSE
                                triangular_wave_value <= triangular_wave_value - 1;  -- Continue decreasing
                            END IF;
                        END IF;
                    END IF;
                ELSE
                    -- LFO disabled: reset triangular wave generator to idle state
                    timing_counter <= 0;                        -- Clear timing counter
                    triangular_wave_value <= (OTHERS => '0');   -- Reset to zero amplitude
                    wave_direction_up <= '1';                   -- Reset to ascending direction
                END IF;
            END IF;
        END IF;
    END PROCESS triangular_wave_generator;

    -- Pipeline stage 3: Audio modulation and output control
    -- This stage applies the LFO effect by multiplying audio samples with the triangular wave
    modulation_and_output : PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                -- Reset output stage to safe initial state
                m_axis_tdata <= (OTHERS => '0');              -- Clear output data
                master_valid_internal <= '0';                 -- No valid output
                slave_ready_internal <= '1';                  -- Ready to accept input
            ELSE
                -- Output flow control: handle backpressure from downstream modules
                IF master_valid_internal = '1' AND m_axis_tready = '0' THEN
                    -- Downstream not ready: maintain current output valid state
                    -- This implements proper AXI4-Stream backpressure handling
                    master_valid_internal <= '1';
                ELSIF valid_flag_stage2 = '1' THEN
                    -- New data available from stage 2: apply LFO effect or bypass
                    IF enable_flag_stage2 = '1' THEN
                        -- Apply LFO tremolo effect: multiply audio sample by triangular wave
                        -- This creates amplitude modulation (tremolo effect)
                        multiplication_result <= STD_LOGIC_VECTOR(
                            resize(
                                signed(audio_data_stage2) * signed('0' & triangular_wave_value),
                                multiplication_result'length
                            )
                        );
                        -- Scale down result by removing lower bits (equivalent to division by 2^TRIANGULAR_COUNTER_LENGHT)
                        -- This maintains proper audio amplitude range after multiplication
                        m_axis_tdata <= multiplication_result(multiplication_result'high DOWNTO TRIANGULAR_COUNTER_LENGHT);
                    ELSE
                        -- LFO disabled: pass audio through unchanged (bypass mode)
                        -- This allows seamless switching between effect and clean audio
                        m_axis_tdata <= audio_data_stage2;
                    END IF;
                    master_valid_internal <= '1';               -- Mark output as valid
                ELSE
                    -- No new data available: clear output valid flag
                    master_valid_internal <= '0';
                END IF;

                -- AXI4-Stream ready signal management for proper flow control
                IF master_valid_internal = '1' AND m_axis_tready = '1' THEN
                    -- Successful output handshake: ready for new input data
                    slave_ready_internal <= '1';
                ELSIF s_axis_tvalid = '1' AND slave_ready_internal = '1' THEN
                    -- Accepted new input: not ready until current output is consumed
                    -- This prevents data loss in the pipeline
                    slave_ready_internal <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS modulation_and_output;

    -- Output signal assignments
    s_axis_tready <= slave_ready_internal;    -- Connect internal ready to output port
    m_axis_tvalid <= master_valid_internal;   -- Connect internal valid to output port

    -- LFO Effect Summary:
    -- 1. Stage 1: Calculates LFO frequency based on joystick position
    -- 2. Stage 2: Generates triangular wave at calculated frequency
    -- 3. Stage 3: Multiplies audio samples by triangular wave (tremolo effect)
    --
    -- Audio Effect Characteristics:
    -- - Tremolo: Periodic amplitude modulation creates "shaking" sound
    -- - Frequency range: Approximately 0.1Hz to 10Hz (typical for audio LFO)
    -- - Modulation depth: Controlled by TRIANGULAR_COUNTER_LENGHT generic
    -- - Bypass capability: Clean audio passthrough when disabled
    --
    -- Pipeline Benefits:
    -- - Maintains real-time audio processing with no dropouts
    -- - Allows complex calculations without affecting audio timing
    -- - Provides proper AXI4-Stream flow control and backpressure handling

END ARCHITECTURE Behavioral;