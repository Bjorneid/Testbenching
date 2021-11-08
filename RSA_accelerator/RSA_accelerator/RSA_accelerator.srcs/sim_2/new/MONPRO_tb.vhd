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
	   A <= "100001";
	   B <= "100001";
	   n <= "0";
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