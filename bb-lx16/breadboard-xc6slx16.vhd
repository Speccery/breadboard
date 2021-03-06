--
-- FPGA breadboard for the XC6SLX16 board
--
-- This source code is public domain
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity system is
generic (
	use_sdram : boolean := true	-- SDRAM as main memory
);
port (
   CLKIN    : in  std_logic;  -- 50Mhz clock
   RESET_n  : in  std_logic;  -- reset (SW3), middle button
	LED1     : out std_logic;
	LED3     : out std_logic;
	
	-- SDRAM interface pins
   SDRAM_CLK   : out  STD_LOGIC;
   SDRAM_CKE   : out  STD_LOGIC;
   SDRAM_CS    : out  STD_LOGIC;
   SDRAM_nRAS  : out  STD_LOGIC;
   SDRAM_nCAS  : out  STD_LOGIC;
   SDRAM_nWE   : out  STD_LOGIC;
   SDRAM_DQM   : out  STD_LOGIC_VECTOR( 1 downto 0);
   SDRAM_ADDR  : out  STD_LOGIC_VECTOR (12 downto 0);
   SDRAM_BA    : out  STD_LOGIC_VECTOR( 1 downto 0);
   SDRAM_DQ    : inout STD_LOGIC_VECTOR (15 downto 0);
	
	-- debug pins
	--
	RXDEBUG  : out std_logic_vector(9 downto 0);
	
	-- serial data
	--
   XOUT     : out std_logic;  -- serial out
   RIN      : in  std_logic   -- serial in
   );
end system;

architecture system_arch of system is

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

   signal ram_nCS   : std_logic;
   signal rom_nCS   : std_logic;
	signal SDRAM_nCS : std_logic;
   signal acc_nCE   : std_logic;
	signal debug_nCS : std_logic;

   signal DO1 : std_logic_vector(15 downto 0);
   signal DO2 : std_logic_vector(15 downto 0);

   signal rts_to_cts : std_logic; -- connect 9902 nRTS to nCTS
   signal nWE        : std_logic;
   signal xout2      : std_logic;
	
	signal clk 			: std_logic;
	signal clkin_buf	: std_logic;	-- buffered input clock 50MHz
	
	signal debug_bus : std_logic_vector(9 downto 0);
	
	signal RESET		: std_logic;
	signal MEM_READY  : std_logic;
	
	-- SDRAM controller interface
	--
	COMPONENT SDRAM_Controller
    generic (
      sdram_address_width : natural;
      sdram_column_bits   : natural;
      sdram_startup_cycles: natural;
      cycles_per_refresh  : natural
    );
    PORT(
		clk             : IN std_logic;
		reset           : IN std_logic;
      
      -- Interface to issue commands
		cmd_ready       : OUT std_logic;
		cmd_enable      : IN  std_logic;
		cmd_wr          : IN  std_logic;
      cmd_address     : in  STD_LOGIC_VECTOR(sdram_address_width-2 downto 0); -- address to read/write
		cmd_byte_enable : IN  std_logic_vector(3 downto 0);
		cmd_data_in     : IN  std_logic_vector(31 downto 0);    
      
      -- Data being read back from SDRAM
		data_out        : OUT std_logic_vector(31 downto 0);
		data_out_ready  : OUT std_logic;

      -- SDRAM signals
		SDRAM_CLK       : OUT   std_logic;
		SDRAM_CKE       : OUT   std_logic;
		SDRAM_CS        : OUT   std_logic;
		SDRAM_RAS       : OUT   std_logic;
		SDRAM_CAS       : OUT   std_logic;
		SDRAM_WE        : OUT   std_logic;
		SDRAM_DQM       : OUT   std_logic_vector(1 downto 0);
		SDRAM_ADDR      : OUT   std_logic_vector(12 downto 0);
		SDRAM_BA        : OUT   std_logic_vector(1 downto 0);
		SDRAM_DATA      : INOUT std_logic_vector(15 downto 0)     
		);
	END COMPONENT;
	
	-- SDRAM parameters
	--
   constant sdram_address_width : natural := 22;
   constant sdram_column_bits   : natural := 8;
   constant sdram_startup_cycles: natural := 10100; -- 100us, plus a little more
   constant cycles_per_refresh  : natural := (64000*100)/4196-1;
	
	-- SDRAM interface signals
	--
   -- signals to interface with the memory controller
   signal cmd_address     : std_logic_vector(sdram_address_width-2 downto 0) := (others => '0');
   signal cmd_wr          : std_logic := '1';
   signal cmd_enable      : std_logic := '0';
   signal cmd_byte_enable : std_logic_vector(3 downto 0);
   signal cmd_data_in     : std_logic_vector(31 downto 0);
   signal cmd_ready       : std_logic;
   signal sdr_data_out        : std_logic_vector(31 downto 0);
   signal sdr_data_out_ready  : std_logic;	
	
	--
	signal sdram_data_reg	: std_logic_vector(15 downto 0); -- capture the data output from SDRAM here
	signal cmd_enable_d 		: std_logic;
	signal sdram_cycle_ready_d : std_logic := '0';
	signal sdram_cycle_ready_q : std_logic := '0';
	type sdram_states is ( idle, read_cycle, write_cycle, wait_read_end,  wait_write_end);
	signal sdram_cycle_state_q, sdram_cycle_state_d : sdram_states := idle;
	
	signal cmd_ready_counter : unsigned(25 downto 0) := (others => '0');
	signal cpu_reset			: std_logic := '1';
	
	signal debug_capt1, debug_capt2, debug_capt3		: std_logic_vector(31 downto 0);
	signal sdr_data_out_ready_last : std_logic;

begin

	RESET <= not RESET_n;

	RXDEBUG <= (others => 'Z');
	
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
   acc: entity work.tms9902 
		generic map (
			div_to_1MHz => 50-- clock frequency provided to the 9902
		)
		port map (
		CLK    => CLK,		-- clock generated by PLL
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
      RESET          => cpu_reset, -- RESET,
      ADDR_OUT       => ADDR_OUT,
      DATA_IN        => DATA_IN,
      DATA_OUT       => DATA_OUT,
      RD             => RD,
      WR             => WR,
		READY				=> MEM_READY,
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
		
	-- SDRAM interface
	-- 
	Inst_SDRAM_Controller: SDRAM_Controller GENERIC MAP (
      sdram_address_width => sdram_address_width,
      sdram_column_bits   => sdram_column_bits,
      sdram_startup_cycles=> sdram_startup_cycles,
      cycles_per_refresh  => cycles_per_refresh
   ) PORT MAP(
      clk             => clk,
      reset           => RESET,

      cmd_address     => cmd_address,
      cmd_wr          => cmd_wr,
      cmd_enable      => cmd_enable,
      cmd_ready       => cmd_ready,
      cmd_byte_enable => cmd_byte_enable,
      cmd_data_in     => cmd_data_in,
      
      data_out        => sdr_data_out,
      data_out_ready  => sdr_data_out_ready,
   
      SDRAM_CLK       => SDRAM_CLK,
      SDRAM_CKE       => SDRAM_CKE,
      SDRAM_CS        => SDRAM_CS,
      SDRAM_RAS       => SDRAM_nRAS,
      SDRAM_CAS       => SDRAM_nCAS,
      SDRAM_WE        => SDRAM_nWE,
      SDRAM_DQM       => SDRAM_DQM,
      SDRAM_BA        => SDRAM_BA,
      SDRAM_ADDR      => SDRAM_ADDR,
      SDRAM_DATA      => SDRAM_DQ
   );

   -- define the glue logic
   rom_nCS   <= ADDR_OUT(15);
   acc_nCE   <= '0' when (ADDR_OUT(15 downto 6)="0000000000") else '1';
   nWE     <= not WR;
	
	process(ADDR_OUT)
	begin
		ram_nCS <= '1';
		sdram_nCS <= '1';
		debug_nCS <= '1';
		if use_sdram then
			sdram_nCS <= not ADDR_OUT(15);
		else
			if ADDR_OUT(15 downto 8) = x"F1" then
				sdram_nCS <= '0';
			elsif ADDR_OUT(15 downto 8) = x"F2" then
				debug_nCS <= '0';
			elsif ADDR_OUT(15)='1' then
				ram_nCS <= '0';
			end if;
		end if;
	end process;
   
   -- define the DATA_IN muxer (no tri-state on a FPGA)
   DATA_IN <= DO1 when rom_nCS='0' else
              DO2 when ram_nCS='0' else
				  sdram_data_reg when sdram_nCS='0' else
				  -- Line below is for debugging. Requires block RAM as working RAM.
				  -- x"76" & std_logic_vector(sdram_read_count_q) when sdram_nCS='0' and ADDR_OUT(2 downto 1)="11" else
				  debug_capt1(15 downto  0) when debug_nCS='0' and ADDR_OUT(3 downto 1) = "000" else
				  debug_capt1(31 downto 16) when debug_nCS='0' and ADDR_OUT(3 downto 1) = "001" else
				  debug_capt2(15 downto  0) when debug_nCS='0' and ADDR_OUT(3 downto 1) = "010" else
				  debug_capt2(31 downto 16) when debug_nCS='0' and ADDR_OUT(3 downto 1) = "011" else
				  debug_capt3(15 downto  0) when debug_nCS='0' and ADDR_OUT(3 downto 1) = "100" else
				  debug_capt3(31 downto 16) when debug_nCS='0' and ADDR_OUT(3 downto 1) = "101" else
              x"0000";

	XOUT <= xout2; -- to RS232 port
	
	-- interface logic to SDRAM, 32-bit bus interfacing to SDRAM
	cmd_data_in <= DATA_OUT & DATA_OUT; 	-- broadcast CPU write data to both upper and lower part of 32-bit word
	cmd_address <= "0000000" & ADDR_OUT(15 downto 2);	-- 32-bit interface
	cmd_byte_enable <= "0011" when ADDR_OUT(1)='0' else "1100";
	cmd_wr <= WR;
	
	MEM_READY <= '1' when ram_nCS='0' or rom_nCS='0' or debug_nCS='0' else sdram_cycle_ready_q;

	process(sdram_cycle_state_q, sdram_nCS, cmd_ready, RD, WR, sdr_data_out_ready)
	begin
		cmd_enable_d <= '0';
		sdram_cycle_state_d <= sdram_cycle_state_q;	-- init with previous state 
		sdram_cycle_ready_d <= sdram_cycle_ready_q;	-- init with previous state 
		
		case sdram_cycle_state_q is 
			when idle =>
				sdram_cycle_ready_d <= '0';			
				if sdram_nCS='0' and cmd_ready='1' then
					-- controller read for new commands and address matches SDRAM
					if RD='1' then
						-- CPU wants to read something.
						cmd_enable_d <= '1';
						sdram_cycle_state_d <= read_cycle;
					elsif WR='1' then
						-- CPU wants to write something.
						cmd_enable_d <= '1';
						sdram_cycle_state_d <= write_cycle;
					end if;
				end if;
			when read_cycle =>
				if sdr_data_out_ready='1' then
					sdram_cycle_ready_d <= '1';		-- this terminates memory cycle from CPU
					sdram_cycle_state_d <= wait_read_end;
				end if;
			when wait_read_end =>
				if RD='0' then
					sdram_cycle_state_d <= idle;
				end if;
			when write_cycle =>
				if cmd_ready='1' then
					sdram_cycle_ready_d <= '1';		-- this terminates memory cycle from CPU
					sdram_cycle_state_d <= wait_write_end;
				end if;
			when wait_write_end =>
				if WR='0' then
					sdram_cycle_state_d <= idle;
				end if;
		end case;
	end process;


	-- synchronous block
	process(clk)
	begin
		if rising_edge(clk) then 
			if RESET='1' then
				cmd_enable     	 <= '0';
				sdram_cycle_ready_q      <= '0';
				cpu_reset 			 <= '1';	-- CPU reset on
				sdram_cycle_state_q <= idle;
				sdr_data_out_ready_last <= '0';
			else
				cmd_enable     	 <= cmd_enable_d;
				sdram_cycle_ready_q      <= sdram_cycle_ready_d;
				sdram_cycle_state_q <= sdram_cycle_state_d;
				
				
				-- debugging stuff
				sdr_data_out_ready_last <= sdr_data_out_ready;
				if sdr_data_out_ready='1' and sdr_data_out_ready_last='0' then
					debug_capt2 <= sdr_data_out;
				end if;
				if sdr_data_out_ready='0' and sdr_data_out_ready_last='1' then
					debug_capt3 <= sdr_data_out;
				end if;
				
				if sdr_data_out_ready='1' then
					if ADDR_OUT(1)='0' then
						sdram_data_reg <= sdr_data_out(15 downto 0);	
					else
						sdram_data_reg <= sdr_data_out(31 downto 16);	
					end if;
					debug_capt1 <= sdr_data_out;
				end if;
				if cmd_ready='1' then
					-- release CPU only after SDRAM controller is ready. This helps
					-- debugging the signals on an oscilloscope.
					cpu_reset <= '0';	
				end if;
			end if;
		end if;
	end process;
	
	process(clk, cmd_ready)
	begin
		if rising_edge(clk) then
			if cmd_ready='1' then 
				cmd_ready_counter <= cmd_ready_counter + 1;
			end if;
		end if;
	end process;
	
	LED1 <= '1' when sdram_cycle_state_q /= idle else '0'; -- std_logic(cmd_ready_counter(cmd_ready_counter'length-1));
	LED3 <= '1' when sdram_cycle_state_q = wait_read_end else '0';
	
	RXDEBUG(0) <= sdram_nCS;
	RXDEBUG(1) <= sdram_cycle_ready_q; -- cmd_enable;
	RXDEBUG(2) <= cmd_ready; -- sdr_data_out_ready; -- read_pending_q;
	RXDEBUG(3) <= cmd_enable;
	RXDEBUG(4) <= RD;
	RXDEBUG(5) <= sdr_data_out_ready;
	RXDEBUG(6) <= '1' when sdram_cycle_state_q = read_cycle    else '0';
	RXDEBUG(7) <= '1' when sdram_cycle_state_q = wait_read_end else '0';


end system_arch;
