--
-- FPGA breadboard for the XC6SLX16 board
--
-- This source code is public domain
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity system is
port (
   CLKIN    : in  std_logic;  -- 50Mhz clock
   RESET_n  : in  std_logic;  -- reset (SW1)
	
	RXDEBUG  : out std_logic_vector(9 downto 0);
	
   XOUT     : out std_logic;  -- serial out
   RIN      : in  std_logic   -- serial in
   );
end system;

architecture system_arch of system is

   -- Declare components
   --
   
   component rom is
   port (
      CLK  : in  std_logic;
      nCS  : in  std_logic;
      -- ADDR : in  std_logic_vector (11 downto 0);	-- EVM-BUG
		ADDR : in  std_logic_vector (14 downto 0);
      DO   : out std_logic_vector (15 downto 0)
      );
   end component;

   component ram is
   port (
      CLK  : in  std_logic;
      nCS  : in  std_logic;
      nWE  : in  std_logic;
      ADDR : in  std_logic_vector (13 downto 0);
      DI   : in  std_logic_vector (15 downto 0);
      DO   : out std_logic_vector (15 downto 0)
      );
   end component;

   component tms9902
   port(
      CLK    : in   std_logic;
      nRTS   : out  std_logic;
      nDSR   : in   std_logic;
      nCTS   : in   std_logic;
      nINT   : out  std_logic;
      nCE    : in   std_logic;
      CRUOUT : in   std_logic;
      CRUIN  : out  std_logic;
      CRUCLK : in   std_logic;
      XOUT   : out  std_logic;
      RIN    : in   std_logic;
		RXDEBUG  : out std_logic_vector(9 downto 0);
      S      : in   std_logic_vector(4 downto 0)
      );
   end component;

   component tms9900
   port(
      CLK            : in   std_logic;
      RESET          : in   std_logic;
      ADDR_OUT       : out  std_logic_vector(15 downto 0);
      DATA_IN        : in   std_logic_vector(15 downto 0);
      DATA_OUT       : out  std_logic_vector(15 downto 0);
      RD             : out  std_logic;
      WR             : out  std_logic;
      IAQ            : out  std_logic;
      AS             : out  std_logic;
      ALU_DEBUG_ARG1 : out  std_logic_vector(15 downto 0);
      ALU_DEBUG_ARG2 : out  std_logic_vector(15 downto 0);
      INT_REQ	      : in   std_logic;		                  -- interrupt request, active high
      IC03           : in   std_logic_vector(3 downto 0);	-- interrupt priority for the request, 0001 is the highest (0000 is reset)
      INT_ACK	      : out  std_logic;		                  -- does not exist on the tms9900, when high cpu vectors to interrupt
      CPU_DEBUG_OUT  : out  std_logic_vector (95 downto 0);	
      CRUIN		      : in   std_logic;
      CRUOUT         : out  std_logic;
      CRUCLK         : out  std_logic;
      HOLD           : in   std_logic;
      HOLDA          : out  std_logic;
      WAITS          : in   std_logic_vector(7 downto 0);
      STUCK          : out  std_logic
      );
   end component;
	
	component xc6pll
    Port ( CLKIN 		: in  STD_LOGIC;
			  CLKIN_BUF : out STD_LOGIC;
           CLKOUT 	: out  STD_LOGIC;
           LOCKED 	: out  STD_LOGIC);
	end component;

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
begin

	RESET <= not RESET_n;

	RXDEBUG <= debug_bus;
	
	mypll: xc6pll port map(CLKIN => CLKIN, CLKIN_BUF => clkin_buf, CLKOUT => CLK, LOCKED => open);

   -- instantiate & connect up the ROM 'chip'
   rom1: rom port map (
      CLK  => CLK,
      nCS  => rom_nCS,
      ADDR => ADDR_OUT(15 downto 1),
      DO   => DO1
   );

   -- instantiate & connect up the RAM 'chip'
   ram1: ram port map (
      CLK  => CLK,
      nCS  => ram_nCS,
      nWE  => nWE,
      ADDR => ADDR_OUT(14 downto 1),
      DI   => DATA_OUT,
      DO   => DO2
   );

   -- instantiate & connect up the 9902 UART
   acc: tms9902 port map (
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
		RXDEBUG => debug_bus,
      S      => addr_out(5 downto 1)
   );

   -- instantiate & connect up the 9900 CPU
   cpu: tms9900 port map (
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
