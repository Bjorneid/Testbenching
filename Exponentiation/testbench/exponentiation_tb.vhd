library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity exponentiation_tb is
	generic (
		-- Add 2 to the desired amount of bits to satisfy the Walter optimization 
		C_block_size : positive := 256 + 2	
	);
end exponentiation_tb;


architecture expBehave of exponentiation_tb is

	constant CLK_PERIOD    : time := 10 ns;

	signal message 		: std_logic_vector ( C_block_size-1 downto 0 ) := (others => '0');
	signal key 			: std_logic_vector ( C_block_size-1 downto 0 ) := (others => '0');
	signal key_r 		: std_logic_vector ( C_block_size+29 downto 0 ) := (others => '0');
	signal valid_in 	: STD_LOGIC := '0';
	signal ready_in 	: STD_LOGIC;
	signal ready_out 	: STD_LOGIC := '0';
	signal valid_out 	: STD_LOGIC;
	signal result 		: std_logic_vector(C_block_size-3 downto 0) := (others => '0');
	signal modulus 		: std_logic_vector(C_block_size-1 downto 0) := (others => '0');
	signal clk 			: STD_LOGIC := '0';
	signal restart 		: STD_LOGIC := '0';
	signal reset_n 		: STD_LOGIC := '0';

begin
	-- Clock generation
    clk <= not clk after CLK_PERIOD/2;

	MODEXP1 : entity work.exponentiation
		generic map (C_block_size => C_block_size)
		port map (
			message   => message  ,
			key       => key      ,
			key_r     => key_r    ,
			valid_in  => valid_in ,
			ready_in  => ready_in ,
			ready_out => ready_out,
			valid_out => valid_out,
			result    => result   ,
			modulus   => modulus  ,
			clk       => clk      ,
			reset_n   => reset_n
		);

	-- Stimuli generation
    stimuli_proc: process
    begin
    	-- Make sure that the MODEXP1 module is ready by 
    	-- keeping it in reset state until it should be used.
    	reset_n <= '0';
    	
    	-- "START" the MODEXPT1 module
        wait for 2*CLK_PERIOD;
        reset_n <= '1';
        
        -- Wait until it is ready to receive data
        wait until ready_in = '1';
        message <= "00" & x"2756B38D5A992FD24908CCA7F8A644C9AB5FFB9C2592FD27E6D2A4E93DF06764";
        key <= "00" & x"1A403CFF0BCE3591FCBC539A0D3FB6AF5C6093F1E9DC7427BFDE2B121695089B";
        modulus <= "00" & x"512CA4B8E5FD5D793AFBFDD18793E1DCE98ABBBEE7E5F94A89C05AC5EE1A2319";
        key_r <= 288x"047e4cdedbc494994fd35f61830eb71a09e440a5ac670359603191fd336943049";
        
        -- START ENCRYPTING DATA by telling the MODEXP1 module that data is ready on the input
        wait for 2*CLK_PERIOD;
        valid_in <= '1';
		wait for 2*CLK_PERIOD;
        valid_in <= '0';
        
        -- Tell MODEXP1 that we are ready to recieve data on the output.
        ready_out <= '1';
        
        -- DATA HAS BEEN ENCRYPTED -> PREPARE DATA ON THE BUSES FOR DECRYPTION
        wait until valid_out = '1';
        wait for 2*CLK_PERIOD;
        ready_out <= '0';
        
        -- Wait until it is ready to receive data
        wait until ready_in = '1';
        message <= "00" & result;
        key <= "000000" & x"386E49AA88C3ACE20A94E2844626859440ECCE6D7F2F183CF3EE2468409693F"; -- d
        
        -- START DECRYPTING DATA by telling the MODEXP1 module that data is ready on the input
        wait for 2*CLK_PERIOD;
        valid_in <= '1';
		wait for 2*CLK_PERIOD;
        valid_in <= '0';
        
        -- Tell MODEXP1 that we are ready to recieve data on the output.
        ready_out <= '1';
        
        -- DATA HAS BEEN DECRYPTED
        wait until valid_out = '1';
        wait for 2*CLK_PERIOD;
        ready_out <= '0';

        wait;
    end process; 

end expBehave;
