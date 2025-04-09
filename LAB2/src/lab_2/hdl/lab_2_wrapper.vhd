--Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
--Date        : Wed Apr  9 11:36:10 2025
--Host        : Davide-Samsung running 64-bit major release  (build 9200)
--Command     : generate_target lab_2_wrapper.bd
--Design      : lab_2_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity lab_2_wrapper is
  port (
    led_of : out STD_LOGIC;
    led_ok : out STD_LOGIC;
    led_uf : out STD_LOGIC;
    reset : in STD_LOGIC;
    sys_clock : in STD_LOGIC;
    usb_uart_rxd : in STD_LOGIC;
    usb_uart_txd : out STD_LOGIC
  );
end lab_2_wrapper;

architecture STRUCTURE of lab_2_wrapper is
  component lab_2 is
  port (
    led_of : out STD_LOGIC;
    led_ok : out STD_LOGIC;
    led_uf : out STD_LOGIC;
    sys_clock : in STD_LOGIC;
    reset : in STD_LOGIC;
    usb_uart_txd : out STD_LOGIC;
    usb_uart_rxd : in STD_LOGIC
  );
  end component lab_2;
begin
lab_2_i: component lab_2
     port map (
      led_of => led_of,
      led_ok => led_ok,
      led_uf => led_uf,
      reset => reset,
      sys_clock => sys_clock,
      usb_uart_rxd => usb_uart_rxd,
      usb_uart_txd => usb_uart_txd
    );
end STRUCTURE;
