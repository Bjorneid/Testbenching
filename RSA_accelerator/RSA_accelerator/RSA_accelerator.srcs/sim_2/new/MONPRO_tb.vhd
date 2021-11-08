-- *****************************************************************************
-- Name:     MONPRO_tb.vhd
-- Project:  TFE4141 Term project 2021
-- Created:  08.11.2021
-- Author:   Bjørn Kristian Eid
-- Purpose:  Testbench for MonProBit
-- *****************************************************************************
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MONPRO_tb is
end MONPRO_tb;


architecture Behavioral of MONPRO_tb is

	-----------------------------------------------------------------------------
	-- Constant declarations
	-----------------------------------------------------------------------------
	constant C_BLOCK_SIZE   : integer := 256 + 2;

	-----------------------------------------------------------------------------
	-- Clocks and reset
	-----------------------------------------------------------------------------
	signal clk              : std_logic;
	signal reset_n          : std_logic;

    -----------------------------------------------------------------------------
    -- Signals required for testing
    -----------------------------------------------------------------------------
    signal outputReady     : std_logic := '0';			-- this module/entity has the new value for u ready to be put out on the bus
    signal running         : std_logic := '0';					-- this module/entity has started the calculations
    signal extRecvReady    : std_logic;				-- The external circuit/logic is ready to receive the new value for u.
    signal extDataReady    : std_logic;				-- Data recieved from an external circuit is ready to be read on the inputs.
    signal A               : unsigned (C_BLOCK_SIZE - 1 downto 0);
    signal B               : unsigned (C_BLOCK_SIZE - 1 downto 0);
    signal n               : std_logic_vector (C_BLOCK_SIZE - 1 downto 0);
           
    signal u               : unsigned (C_BLOCK_SIZE - 1 downto 0) := (others => '0');	-- The end result after the algorithm completes.

	-----------------------------------------------------------------------------
	-- Function for converting from hex strings to std_logic_vector.
	-----------------------------------------------------------------------------
	function str_to_stdvec(inp: string) return unsigned is
		variable temp: unsigned(4*inp'length-1 downto 0) := (others => 'X');
		variable temp1 : unsigned(3 downto 0);
	begin
		for i in inp'range loop
			case inp(i) is
				 when '0' =>	 temp1 := x"0";
				 when '1' =>	 temp1 := x"1";
				 when '2' =>	 temp1 := x"2";
				 when '3' =>	 temp1 := x"3";
				 when '4' =>	 temp1 := x"4";
				 when '5' =>	 temp1 := x"5";
				 when '6' =>	 temp1 := x"6";
				 when '7' =>	 temp1 := x"7";
				 when '8' =>	 temp1 := x"8";
				 when '9' =>	 temp1 := x"9";
				 when 'A'|'a' => temp1 := x"a";
				 when 'B'|'b' => temp1 := x"b";
				 when 'C'|'c' => temp1 := x"c";
				 when 'D'|'d' => temp1 := x"d";
				 when 'E'|'e' => temp1 := x"e";
				 when 'F'|'f' => temp1 := x"f";
				 when others =>  temp1 := "XXXX";
			end case;
			temp(4*(i-1)+3 downto 4*(i-1)) := temp1;
		end loop;
		return temp;
	end function str_to_stdvec;


begin

	-----------------------------------------------------------------------------
	-- Clock and reset generation
	-----------------------------------------------------------------------------
	-- Generates a 50MHz clk
	clk_gen: process is
	begin
		clk <= '1';
		wait for 6 ns;
		clk <= '0';
		wait for 6 ns;
	end process;

	-----------------------------------------------------------------------------
	-- Testing
	-----------------------------------------------------------------------------
	testing: process
	   begin
	   extRecvReady <= '1';
	end process;

---------------------------------------------------------------------------------
-- Instantiate the design under test (DUT)
---------------------------------------------------------------------------------
MONPRO1 : entity work.MonProBit
	generic map (
		C_BLOCK_SIZE => C_block_size
	)
	port map (
		-----------------------------------------------------------------------------
		-- Clocks and reset
		-----------------------------------------------------------------------------
		clk              => clk,
		reset_n          => reset_n,
		
		-----------------------------------------------------------------------------
		-- Signals
		-----------------------------------------------------------------------------
		outputReady      => outputReady,
		running          => running,
		extRecvReady     => extRecvReady,
		extDataReady     => extDataReady,
		A                => A,
		B                => B,
		n                => n,
		u                => u
	);

end Behavioral;