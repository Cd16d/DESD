--Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
--Date        : Mon May 12 18:14:19 2025
--Host        : Davide-Samsung running 64-bit major release  (build 9200)
--Command     : generate_target loopback_I2S_wrapper.bd
--Design      : loopback_I2S_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity loopback_I2S_wrapper is
  port (
    reset : in STD_LOGIC;
    rx_lrck_0 : out STD_LOGIC;
    rx_mclk_0 : out STD_LOGIC;
    rx_sclk_0 : out STD_LOGIC;
    rx_sdin_0 : in STD_LOGIC;
    sys_clock : in STD_LOGIC;
    tx_lrck_0 : out STD_LOGIC;
    tx_mclk_0 : out STD_LOGIC;
    tx_sclk_0 : out STD_LOGIC;
    tx_sdout_0 : out STD_LOGIC
  );
end loopback_I2S_wrapper;

architecture STRUCTURE of loopback_I2S_wrapper is
  component loopback_I2S is
  port (
    reset : in STD_LOGIC;
    sys_clock : in STD_LOGIC;
    rx_sdin_0 : in STD_LOGIC;
    tx_mclk_0 : out STD_LOGIC;
    tx_lrck_0 : out STD_LOGIC;
    tx_sclk_0 : out STD_LOGIC;
    tx_sdout_0 : out STD_LOGIC;
    rx_mclk_0 : out STD_LOGIC;
    rx_lrck_0 : out STD_LOGIC;
    rx_sclk_0 : out STD_LOGIC
  );
  end component loopback_I2S;
begin
loopback_I2S_i: component loopback_I2S
     port map (
      reset => reset,
      rx_lrck_0 => rx_lrck_0,
      rx_mclk_0 => rx_mclk_0,
      rx_sclk_0 => rx_sclk_0,
      rx_sdin_0 => rx_sdin_0,
      sys_clock => sys_clock,
      tx_lrck_0 => tx_lrck_0,
      tx_mclk_0 => tx_mclk_0,
      tx_sclk_0 => tx_sclk_0,
      tx_sdout_0 => tx_sdout_0
    );
end STRUCTURE;
