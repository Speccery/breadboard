--
-- FPGA breadboard for the EP4CE22 Core board board
--
-- EP 2018-05-19
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity breadboard is
port (
   CLKIN    : in  std_logic;  -- 50Mhz clock
   RESET_n  : in  std_logic;  -- reset (SW1)	KEY0
	KEY1 		: in  std_logic;
	KEY2		: in  std_logic;
	
	SEG  		: out std_logic_vector(7 downto 0); -- 7 segment display
	LED  		: out std_logic_vector(3 downto 0);
	
   XOUT     : out std_logic;  -- serial out
   RIN      : in  std_logic   -- serial in
   );
end breadboard;

architecture system_arch of breadboard is

   -- Components directly referenced to work library, not declared.
   --

   -- buses and wires on the breadboard
   --
   signal ADDR_OUT : std_logic_vector(15 downto 0);
   signal DATA_IN  : std_logic_vector(15 downto 0);
   signal DATA_OUT : std_logic_vector(15 downto 0);
   signal RD       : std_logic;
   signal WR       : std_logic;
   signal CRUIN    : std_logic;
   signal CRUOUT   : std_logic;
   signal CRUCLK   : std_logic;

   signal ram_nCS : std_logic;
   signal rom_nCS : std_logic;
   signal acc_nCE : std_logic;

   signal DO1 : std_logic_vector(15 downto 0);
   signal DO2 : std_logic_vector(15 downto 0);

   signal rts_to_cts : std_logic; -- connect 9902 nRTS to nCTS
   signal nWE        : std_logic;
   signal xout2      : std_logic;
	
	signal clk 			: std_logic;
	signal clkin_buf	: std_logic;	-- buffered input clock 50MHz
	
	signal debug_bus : std_logic_vector(9 downto 0);
	
	signal RESET		: std_logic;
	
	--Copyright (C) 1991-2013 Altera Corporation
	--Your use of Altera Corporation's design tools, logic functions 
	--and other software and tools, and its AMPP partner logic 
	--functions, and any output files from any of the foregoing 
	--(including device programming or simulation files), and any 
	--associated documentation or information are expressly subject 
	--to the terms and conditions of the Altera Program License 
	--Subscription Agreement, Altera MegaCore Function License 
	--Agreement, or other applicable license agreement, including, 
	--without limitation, that your use is for the sole purpose of 
	--programming logic devices manufactured by Altera and sold by 
	--Altera or its authorized distributors.  Please refer to the 
	--applicable agreement for further details.
	component mypll
		PORT
		(
			areset		: IN STD_LOGIC  := '0';
			inclk0		: IN STD_LOGIC  := '0';
			c0		: OUT STD_LOGIC ;
			locked		: OUT STD_LOGIC 
		);
	end component;
	
	signal pll_locked : std_logic;
	
begin

	RESET <= not RESET_n;

	SEG(6 downto 0)<="1111001";
	SEG(7) <= '0';
	
	LED <= "000" & pll_locked;
	
	-- CLK <= CLKIN;	-- 50MHz external oscillator
	mypll_inst: mypll port map(areset => RESET, inclk0 => CLKIN, c0 => CLK, locked => pll_locked);
	-- mypll: entity work.xc6pll port map(CLKIN => CLKIN, CLKIN_BUF => clkin_buf, CLKOUT => CLK, LOCKED => open);

   -- instantiate & connect up the ROM 'chip'
   rom1: entity work.rom port map (
      CLK  => CLK,
      nCS  => rom_nCS,
      ADDR => ADDR_OUT(15 downto 1),
      DO   => DO1
   );

   -- instantiate & connect up the RAM 'chip'
   ram1: entity work.ram port map (
      CLK  => CLK,
      nCS  => ram_nCS,
      nWE  => nWE,
      ADDR => ADDR_OUT(14 downto 1),
      DI   => DATA_OUT,
      DO   => DO2
   );

   -- instantiate & connect up the 9902 UART
   acc: entity work.tms9902 
		generic map (
			div_to_1MHz => 100	-- clock frequency provided to the 9902
		)
		port map (
      -- CLK    => clkin_buf,	-- using 50MHz clock
		CLK    => CLK,	-- 100MHz clock
      nRTS   => rts_to_cts,
      nDSR   => '0',
      nCTS   => rts_to_cts,
      nINT   => open,
      nCE    => acc_nCE,
      CRUOUT => CRUOUT,
      CRUIN  => CRUIN,
      CRUCLK => CRUCLK,
      XOUT   => xout2,
      RIN    => RIN,
      S      => addr_out(5 downto 1)
   );

   -- instantiate & connect up the 9900 CPU
   cpu: entity work.tms9900 port map (
      CLK            => CLK,
      RESET          => RESET,
      ADDR_OUT       => ADDR_OUT,
      DATA_IN        => DATA_IN,
      DATA_OUT       => DATA_OUT,
      RD             => RD,
      WR             => WR,
      IAQ            => open,
      AS             => open,
      ALU_DEBUG_ARG1 => open,
      ALU_DEBUG_ARG2 => open,
      INT_REQ	      => '0',
      IC03           => "0000",
      INT_ACK	      => open,
      CPU_DEBUG_OUT  => open,
      CRUIN		      => CRUIN,
      CRUOUT         => CRUOUT,
      CRUCLK         => CRUCLK,
      HOLD           => '0',
      HOLDA          => open,
      WAITS          => x"00", -- x"03",
      STUCK          => open
      );

   -- define the glue logic
   rom_nCS <= ADDR_OUT(15);
   ram_nCS <= not ADDR_OUT(15);
   acc_nCE <= '0' when (ADDR_OUT(15 downto 6)="0000000000") else '1';
   nWE     <= not wr;
   
   -- define the DATA_IN muxer (no tri-state on a FPGA)
   DATA_IN <= DO1 when rom_nCS='0' else
              DO2 when ram_nCS='0' else
              x"0000";

	XOUT <= xout2; -- to RS232 port
	

end system_arch;
