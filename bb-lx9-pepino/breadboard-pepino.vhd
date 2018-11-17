--
-- FPGA breadboard
--
-- This source code is public domain
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity system is
port (
   CLKIN    : in  std_logic;  -- 50Mhz clock
   RESET    : in  std_logic;  -- reset (SW1)
   XOUT     : out std_logic;  -- serial out
   RIN      : in  std_logic;  -- serial in
	LED		: out std_logic_vector(7 downto 0); -- LEDs
	
	-- Pepino specific ports
	SRAM_CE0 : out std_logic := '1';
	SRAM_CE1 : out std_logic := '1';
	SRAM_WE  : out std_logic := '1';
	SRAM_OE  : out std_logic := '1';
	SRAM_BE  : out std_logic_vector(3 downto 0);
	SRAM_ADR : out std_logic_vector(18 downto 0);
	SRAM_DAT : inout std_logic_vector(31 downto 0);
	
	ALATCH		: out std_logic := '0';
	BUS_OE_n    : out std_logic := '0';
	CTRL_RD_n   : out std_logic := '0';
	RD_n        : out std_logic := '0';
	CTRL_CP     : out std_logic := '0';
	BUSDIR      : out std_logic := '0';
	INDATA		: inout std_logic_vector(15 downto 0) := (others => 'Z');
	DEBUG1		: in std_logic;
	DEBUG2		: in std_logic;
	MEM_n_ext	: in std_logic;
	WE_n_ext		: in std_logic;
	
	VGA_RED		: out std_logic_vector(2 downto 0);
	VGA_GREEN	: out std_logic_vector(2 downto 0);
	VGA_BLUE		: out std_logic_vector(1 downto 0);
	VGA_HSYNC 	: out std_logic := '0';
	VGA_VSYNC 	: out std_logic := '0';
		
	AUDIO_L		: out std_logic := '0';
	AUDIO_R		: out std_logic := '0';
	
	
   TEST     : out std_logic   -- serial out
   );
end system;

architecture system_arch of system is


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
	
begin
	mypll: entity work.xc6pll port map(CLKIN => CLKIN, CLKIN_BUF => clkin_buf, CLKOUT => CLK, LOCKED => open);


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
   acc: entity work.tms9902 port map (
      -- CLK    => clkin_buf,	-- using 50MHz clock
		CLK    => CLK,	-- 160MHz clock
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
		READY				=> '1',
      IAQ            => open,
      AS             => open,
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

	TEST <= xout2; -- to hook up analyzer
	XOUT <= xout2; -- to RS232 port
	
	LED <= ADDR_OUT(15 downto 8);
	
	VGA_RED  <= "000";
	VGA_BLUE <= "00";
	VGA_GREEN <= "000";
	VGA_HSYNC <= '0';
	VGA_VSYNC <= '0';
	SRAM_ADR <= (others => '0');
	SRAM_BE <= "1111";
	SRAM_DAT <= "ZZZZZZZZ" & "ZZZZZZZZ" & "ZZZZZZZZ" & "ZZZZZZZZ";
	SRAM_CE0 <= '1';
	SRAM_CE1 <= '1';
	SRAM_OE <= '1';
	SRAM_WE <= '1';

end system_arch;
