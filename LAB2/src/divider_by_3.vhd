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
    -- Constant to calculate the multiplier for approximating division by 3
    CONSTANT DIVISION_MULTIPLIER : INTEGER := INTEGER(floor(real(2 ** (BIT_DEPTH + 2)) / 3.0));

    -- Constant to calculate the length of the result signal
    CONSTANT RESULT_WIDTH : INTEGER := (2 * BIT_DEPTH) + 2; -- 16 bit

    -- Signals to hold the sum of the RGB channels and the intermediate results
    SIGNAL sum_extended : UNSIGNED(BIT_DEPTH + 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL scaled_result : UNSIGNED(RESULT_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN

    -- Explanation of how the division by 3 is performed:
    -- 1. The sum of the RGB channels (R + G + B) is calculated and extended to avoid overflow.
    -- 2. The sum is multiplied by a precomputed constant (DIVISION_MULTIPLIER), which is approximately equal to (2^(BIT_DEPTH + 2)) / 3.
    --    This scales the value up to prepare for the division.
    -- 3. The result of the multiplication is then right-shifted by a specific number of bits.
    --    This operation effectively scales the value back down, approximating the division by 3.
    -- 4. The final grayscale value is extracted from the result and converted back to a std_logic_vector.

    -- Calculate the sum of the RGB channels
    -- The addition of 2 is used to implement rounding when dividing by 3.
    -- This is a common technique: adding half of the divisor (3/2 ? 2) before division
    -- ensures that the result is rounded to the nearest integer instead of truncated.
    sum_extended <= dividend + TO_UNSIGNED(2, BIT_DEPTH + 2);

    -- Multiply the sum by the precomputed multiplier
    scaled_result <= RESIZE(sum_extended * TO_UNSIGNED(DIVISION_MULTIPLIER, BIT_DEPTH + 1), RESULT_WIDTH);

    -- Extract the grayscale value from the scaled result by right-shifting
    result <= scaled_result(RESULT_WIDTH - 1 DOWNTO RESULT_WIDTH - BIT_DEPTH);

END Behavioral;