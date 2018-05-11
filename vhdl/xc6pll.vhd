----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:01:31 05/03/2018 
-- Design Name: 
-- Module Name:    xc6pll - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity xc6pll is
    Port ( CLKIN : in  STD_LOGIC;
			  CLKIN_BUF : out STD_LOGIC;
           CLKOUT : out  STD_LOGIC;
           LOCKED : out  STD_LOGIC);
end xc6pll;

architecture Behavioral of xc6pll is
	-- PLL clock wires
	--
	signal clk_ref_ibuf : std_logic;
	signal clk0			  : std_logic;
	signal clkfb		  : std_logic;
	signal clkfx		  : std_logic;

begin

	CLKIN_BUF <= clk_ref_ibuf;

	clkin1_buf : IBUFG port map (O => clk_ref_ibuf, I => CLKIN);
  
  dcm_sp_inst: DCM_SP
  generic map
   (CLKDV_DIVIDE          => 2.000,
    CLKFX_DIVIDE          => 16,			-- try to multiply by 2 overall to get to 100MHz
    CLKFX_MULTIPLY        => 32,
    CLKIN_DIVIDE_BY_2     => FALSE,
    CLKIN_PERIOD          => 20.00,
    CLKOUT_PHASE_SHIFT    => "NONE",
    CLK_FEEDBACK          => "1X",
    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
    PHASE_SHIFT           => 0,
    STARTUP_WAIT          => FALSE)
  port map
   -- Input clock
   (CLKIN                 => clk_ref_ibuf,
    CLKFB                 => clkfb,
    -- Output clocks
    CLK0                  => clk0,
    CLK90                 => open,
    CLK180                => open,
    CLK270                => open,
    CLK2X                 => open,
    CLK2X180              => open,
    CLKFX                 => clkfx,
    CLKFX180              => open,
    CLKDV                 => open,
   -- Ports for dynamic phase shift
    PSCLK                 => '0',
    PSEN                  => '0',
    PSINCDEC              => '0',
    PSDONE                => open,
   -- Other control and status signals
    LOCKED                => open, -- locked_internal,
    STATUS                => open, -- status_internal,
    RST                   => '0',
   -- Unused pin, tie low
    DSSEN                 => '0');

	-- Output buffering
	-------------------------------------
	clkf_buf    : BUFG   port map (O => clkfb, I => clk0);
	clkout1_buf : BUFG   port map (O => clkout,   I => clkfx);
	-------------------------------------

end Behavioral;

