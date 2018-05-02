--
-- Simplistic 128x16 RAM module
--
-- (change ADDR vector length to change size of ram)
--
-- This source code is public domain
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram is
port (
   CLK  : in  std_logic;
   nCS  : in  std_logic;
   nWE  : in  std_logic;
   ADDR : in  std_logic_vector (13 downto 0);    -- note: word address!
   DI   : in  std_logic_vector (15 downto 0);
   DO   : out std_logic_vector (15 downto 0)
   );
end ram;

architecture ram_arch of ram is

   constant size : integer := (2 ** ADDR'length) - 1;
	type mem_array is array(0 to size) of std_logic_vector(15 downto 0);

begin

	process(CLK, nCS)
	variable ram : mem_array;
	variable idx : integer range 0 to size;
	begin
		if rising_edge(CLK) and nCS='0' then
			idx := to_integer( unsigned( ADDR ));
         if nWE='0' then
            ram( idx ) := DI;
         end if;
			DO <= ram( idx );
		end if;
	end process;

end ram_arch;
  