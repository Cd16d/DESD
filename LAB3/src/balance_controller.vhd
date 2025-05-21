LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY balance_controller IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24;
		BALANCE_WIDTH : POSITIVE := 10;
		BALANCE_STEP_2 : POSITIVE := 6 -- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	PORT (
		aclk : IN STD_LOGIC;
		aresetn : IN STD_LOGIC;

		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		s_axis_tready : OUT STD_LOGIC;
		s_axis_tlast : IN STD_LOGIC;

		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		m_axis_tready : IN STD_LOGIC;
		m_axis_tlast : OUT STD_LOGIC;

		balance : IN STD_LOGIC_VECTOR(BALANCE_WIDTH - 1 DOWNTO 0)
	);
END balance_controller;

ARCHITECTURE Behavioral OF balance_controller IS
	
	CONSTANT CENTER_VALUE : INTEGER := 2 ** (BALANCE_WIDTH - 1) - 1; -- 511 per BALANCE_WIDTH=10
	CONSTANT DEADZONE : INTEGER := 32; -- Deadzone da -32 a +32
	CONSTANT MAX_SHIFT : INTEGER := TDATA_WIDTH - 1; -- Massimo shift possibile

	SIGNAL balance_signed : signed(BALANCE_WIDTH - 1 DOWNTO 0);
	SIGNAL shift_amount_left, shift_amount_right : NATURAL RANGE 0 TO MAX_SHIFT;

	-- Registri di pipeline
	SIGNAL audio_in_reg : signed(TDATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tlast_reg : STD_LOGIC;
	SIGNAL valid_reg : STD_LOGIC;

	-- Segnali di controllo
	SIGNAL ready_int : STD_LOGIC;
	SIGNAL processing_active : STD_LOGIC;

BEGIN
	-- Convert balance input to signed (-512 to +511)
	balance_signed <= signed(balance);

	-- Calcolo dello shift amount con deadzone e scaling esponenziale
	PROCESS (balance_signed)
		VARIABLE centered_value : signed(BALANCE_WIDTH - 1 DOWNTO 0);
		VARIABLE abs_value : unsigned(BALANCE_WIDTH - 2 DOWNTO 0);
		VARIABLE exp_shift : INTEGER;
	BEGIN
		-- Centra il valore intorno a 0 (da -512 a +511 -> da -511 a +511)
		centered_value := balance_signed - to_signed(CENTER_VALUE, BALANCE_WIDTH);

		-- Inizializzazione
		shift_amount_left <= 0;
		shift_amount_right <= 0;

		-- Calcola il valore assoluto
		IF centered_value(BALANCE_WIDTH - 1) = '1' THEN -- negativo
			abs_value := unsigned(-centered_value(BALANCE_WIDTH - 2 DOWNTO 0));
		ELSE
			abs_value := unsigned(centered_value(BALANCE_WIDTH - 2 DOWNTO 0));
		END IF;

		-- Applica deadzone e calcola shift
		IF centered_value > DEADZONE THEN
			-- Calcola lo shift per il canale sinistro (valori positivi)
			exp_shift := (to_integer(abs_value) - DEADZONE) / 2 ** BALANCE_STEP_2 + 1;

			IF exp_shift > MAX_SHIFT THEN
				shift_amount_left <= MAX_SHIFT;
			ELSE
				shift_amount_left <= exp_shift;
			END IF;

		ELSIF centered_value <- DEADZONE THEN
			-- Calcola lo shift per il canale destro (valori negativi)
			exp_shift := (to_integer(abs_value) - DEADZONE) / 2 ** BALANCE_STEP_2 + 1;

			IF exp_shift > MAX_SHIFT THEN
				shift_amount_right <= MAX_SHIFT;
			ELSE
				shift_amount_right <= exp_shift;
			END IF;
		END IF;
	END PROCESS;

	-- Il resto del codice rimane IDENTICO alla versione originale
	-- Logica di controllo AXI
	PROCESS (aclk)
		VARIABLE temp : signed(TDATA_WIDTH + MAX_SHIFT - 1 DOWNTO 0);
	BEGIN
		IF rising_edge(aclk) THEN
			IF aresetn = '0' THEN
				-- Reset asincrono
				valid_reg <= '0';
				audio_in_reg <= (OTHERS => '0');
				tlast_reg <= '0';
				processing_active <= '0';
			ELSE
				-- Gestione del flusso dati
				IF ready_int = '1' THEN
					valid_reg <= '0';

					IF s_axis_tvalid = '1' THEN
						-- Registrazione degli ingressi
						audio_in_reg <= signed(s_axis_tdata);
						tlast_reg <= s_axis_tlast;
						valid_reg <= '1';
						processing_active <= '1';
					ELSE
						processing_active <= '0';
					END IF;
				END IF;

				-- Elaborazione del dato (sempre attiva)
				IF processing_active = '1' OR valid_reg = '1' THEN
					temp := resize(audio_in_reg, temp'length);

					IF tlast_reg = '0' THEN
						temp := shift_right(temp, shift_amount_left);
					ELSE
						temp := shift_right(temp, shift_amount_right);
					END IF;

					-- Saturazione
					IF temp > 2 ** (TDATA_WIDTH - 1) - 1 THEN
						m_axis_tdata <= STD_LOGIC_VECTOR(to_signed(2 ** (TDATA_WIDTH - 1) - 1, TDATA_WIDTH));
					ELSIF temp <- 2 ** (TDATA_WIDTH - 1) THEN
						m_axis_tdata <= STD_LOGIC_VECTOR(to_signed(-2 ** (TDATA_WIDTH - 1), TDATA_WIDTH));
					ELSE
						m_axis_tdata <= STD_LOGIC_VECTOR(temp(TDATA_WIDTH - 1 DOWNTO 0));
					END IF;

					m_axis_tlast <= tlast_reg;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- Logica combinazionale per tready
	ready_int <= m_axis_tready OR NOT valid_reg;
	s_axis_tready <= ready_int;

	-- Assegnazione del valid in uscita
	m_axis_tvalid <= valid_reg;

END Behavioral;