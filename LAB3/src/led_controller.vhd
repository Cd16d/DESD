LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY led_controller IS
	GENERIC (
		LED_WIDTH : POSITIVE := 8
	);
	PORT (
		mute_enable : IN STD_LOGIC;
		filter_enable : IN STD_LOGIC;

		led_r : OUT STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0);
		led_g : OUT STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0);
		led_b : OUT STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0)
	);
END led_controller;

ARCHITECTURE Behavioral OF led_controller IS

	-- constant for "ON" and "OFF"
	CONSTANT ALL_ON : STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0) := (OTHERS => '1');
	CONSTANT ALL_OFF : STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');

BEGIN

	-- If mute_enable = '1'       Red LEDs on, others off
	-- Else if filter_enable='1'  Blue LEDs on, others off
	-- Else                       Green LEDs on, others off

	led_r <= ALL_ON WHEN mute_enable = '1' ELSE
		ALL_OFF;
	led_b <= ALL_ON WHEN (mute_enable = '0' AND filter_enable = '1') ELSE
		ALL_OFF;
	led_g <= ALL_ON WHEN (mute_enable = '0' AND filter_enable = '0') ELSE
		ALL_OFF;

END Behavioral;