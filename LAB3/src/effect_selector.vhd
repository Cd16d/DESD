LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY effect_selector IS
    GENERIC (
        JOYSTICK_LENGHT : INTEGER := 10
    );
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        effect : IN STD_LOGIC;
        jstck_x : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);
        jstck_y : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);
        volume : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);
        balance : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);
        lfo_period : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0)
    );
END effect_selector;

ARCHITECTURE Behavioral OF effect_selector IS

BEGIN

    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                volume <= (OTHERS => '0');
                balance <= (OTHERS => '0');
                lfo_period <= (OTHERS => '0');

            ELSE
                balance <= jstck_x;

                IF effect = '1' THEN
                    -- LFO control
                    lfo_period <= jstck_y;

                ELSE
                    -- volume/balance control
                    volume <= jstck_y;
                    
                END IF;

            END IF;

        END IF;

    END PROCESS;

END Behavioral;