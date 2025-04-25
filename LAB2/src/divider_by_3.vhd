---------- DEFAULT LIBRARIES -------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;
------------------------------------

ENTITY divider_by_3 IS
    GENERIC (
        BIT_DEPTH : INTEGER := 7
    );
    PORT (
        dividend : IN UNSIGNED(BIT_DEPTH + 1 DOWNTO 0);
        result : OUT UNSIGNED(BIT_DEPTH - 1 DOWNTO 0)
    );
END divider_by_3;

ARCHITECTURE Behavioral OF divider_by_3 IS
    CONSTANT N : INTEGER := BIT_DEPTH + 3;
    CONSTANT DIVISION_MULTIPLIER : INTEGER := INTEGER(round(real(2 ** N) / 3.0));
    CONSTANT OFFSET : INTEGER := 2 ** (N - 1);

    CONSTANT MULT_WIDTH : INTEGER := BIT_DEPTH + 1 + N;

    SIGNAL mult_result : UNSIGNED(MULT_WIDTH - 1 DOWNTO 0);
    SIGNAL sum_with_offset : UNSIGNED(MULT_WIDTH - 1 DOWNTO 0);
BEGIN
    -- Multiplication without loss of bits
    mult_result <= dividend * TO_UNSIGNED(DIVISION_MULTIPLIER, N - 1);

    -- Addition with offset, no loss of bits
    sum_with_offset <= mult_result + TO_UNSIGNED(OFFSET, MULT_WIDTH);

    -- Extract rounded result
    result <= sum_with_offset(MULT_WIDTH - 2 DOWNTO MULT_WIDTH - BIT_DEPTH -1);
 
END Behavioral;