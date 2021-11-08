library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity exponentiation is
	generic (
		C_block_size : positive := 256 + 2
	);
	port (
		--input controll
		valid_in	: in STD_LOGIC;								-- Data on input is ready to be read
		ready_in	: out STD_LOGIC := '0';						-- Ready to receive new data on input

		--input data
		message 	: in std_logic_vector ( C_block_size-1 downto 0 ); 	-- M
		key 		: in std_logic_vector ( C_block_size-1 downto 0 );	-- e or d
		key_r       : in std_logic_vector ( C_block_size+29 downto 0 );	-- r

		--ouput controll
		ready_out	: in STD_LOGIC;								-- External logic ready to receive data on output
		valid_out	: out STD_LOGIC := '0';						-- Data on output is ready to be read

		--output data
		result 		: out std_logic_vector(C_block_size-3 downto 0);	-- x

		--modulus
		modulus 	: in std_logic_vector(C_block_size-1 downto 0);		-- n

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end exponentiation;


architecture expBehave of exponentiation is	
	-- MODEXP - REGISTERS
	signal M_r : unsigned(C_block_size - 1 downto 0);
	signal x_r : unsigned(C_block_size - 1 downto 0);
	signal result_nxt : unsigned(C_block_size - 1 downto 0) := (others => '0');
	
	-- MONPRO1 - MONTGOMERY PRODUCT UNIT 1
    signal outputReady_MP1 : std_logic;				-- the MONPRO1 has the new value for u_MP1 ready to be put out on the bus
    signal running_MP1 : std_logic;					-- the MONPRO1 is performing calculations
    signal extRecvReady_MP1 : std_logic := '0';		-- This entity is ready to receive the new value for u_MP1 from MONPRO1.
    signal extDataReady_MP1 : std_logic := '0';		-- The data from this entity is ready on the buses of MONPRO1
    signal inner_loop_counter : unsigned(10 - 1 downto 0) := (others => '0');	-- Used in what would be the for-loop in the high-level code.

    signal A_MP1 : unsigned(C_block_size - 1 downto 0);
    signal B_MP1 : unsigned(C_block_size - 1 downto 0);
    signal u_MP1 : unsigned(C_block_size - 1 downto 0);
    signal reset_MP1 : std_logic := '1';
	
    -- MODEXP - STATE MACHINE
    type states is (IDLE, STARTUP, CALC_MR, CALC_XR, CALC_LP, FINAL, ENDED, CLEAR);
	signal state : states := IDLE;
    signal next_state : states := IDLE;
    
    signal flag_Mr_set : std_ulogic := '0';
    signal flag_calc_Mr_done : std_ulogic := '0';
    
    signal flag_xr_set : std_ulogic := '0';
    signal flag_calc_xr_done : std_ulogic := '0';
    
    signal flag_looop_Ready : std_ulogic := '0';
    signal flag_looop_xr : std_ulogic := '0';
    signal flag_looop_xr_set : std_ulogic := '0';
    signal flag_looop_xr_done : std_ulogic := '0';
    signal flag_looop_e : std_ulogic := '0';
    signal flag_looop_e_set : std_ulogic := '0';
    signal flag_looop_e_done : std_ulogic := '0';
    signal flag_looop_e_skipped : std_ulogic := '0';
    
    signal flag_final_xr_set : std_ulogic := '0';
    signal flag_final_done : std_ulogic := '0';
    
begin

	-- The suffix MP1 indicates that this is a signal dedicated to MONPRO entity 1
	MONPRO1: entity work.MonProBit
		generic map (C_block_size => C_block_size)
        port map (
            clk => clk,
            reset_n => reset_MP1,
            outputReady => outputReady_MP1,
            running => running_MP1,
            extRecvReady => extRecvReady_MP1,
            extDataReady => extDataReady_MP1,
            A => A_MP1,
            B => B_MP1,
            n => modulus,
            u => u_MP1
        );
        
	-- In this process we determine if the state should be changed, 
	-- and which state it should be changed to.
	state_change: process (clk, reset_n)
    begin
        if (reset_n = '0') then
			state <= IDLE;
			next_state <= IDLE;
						
    	elsif (rising_edge(clk)) then
    		state <= next_state;

			if (((state = IDLE) or (state = ENDED)) and valid_in = '1') then
				next_state <= STARTUP;
				
			elsif (state = STARTUP) then
				next_state <= CALC_MR;
				state <= CLEAR;
				
			elsif (state = CALC_MR and flag_calc_Mr_done = '1') then
				next_state <= CALC_XR;
				state <= CLEAR;
				
			elsif (state = CALC_XR and flag_calc_xr_done = '1') then
				next_state <= CALC_LP;
				state <= CLEAR;
				
			elsif (state = CALC_LP and flag_looop_Ready = '1' and inner_loop_counter = 0 and (flag_looop_e_done = '1' or flag_looop_e_skipped = '1')) then
				next_state <= FINAL;
				state <= CLEAR;
			
			elsif (state = FINAL and flag_final_done = '1') then
				next_state <= ENDED;
				state <= CLEAR;
			
			elsif (state = ENDED) then
				next_state <= IDLE;
				state <= CLEAR;
				
			end if;
		end if;
		
		
        
    end process state_change;

	-- Here we simply set the different main flags that are associated with the current state.
    state_machine: process (clk, reset_n)
    begin
        -- The reset is active low
        if (reset_n = '0') then
			reset_MP1 <= '0';
			ready_in <= '0';
			valid_out <= '0';
			extDataReady_MP1 <= '0';
			
			A_MP1 <= (others => '0');
			B_MP1 <= (others => '0');
			M_r <= (others => '0');
			x_r <= (others => '0');
			result_nxt <= (others => '0');
			
			flag_Mr_set <= '0';
			flag_calc_Mr_done <= '0';
			flag_xr_set <= '0';
			flag_calc_xr_done <= '0';
			
			-- FOR-LOOP
			flag_looop_Ready <= '0';
			flag_looop_xr  <= '0';
			flag_looop_xr_set <= '0';
			flag_looop_xr_done <= '0';
			flag_looop_e <= '0';
			flag_looop_e_set <= '0';
			flag_looop_e_done <= '0';
			flag_looop_e_skipped <= '0';
			inner_loop_counter <= (others => '0');

			flag_final_xr_set <= '0';
			flag_final_done <= '0';
			
			result <= (others => '0');
    
    	elsif (rising_edge(clk)) then
    		if running_MP1 = '1' then
				extRecvReady_MP1 <= '1';
			end if;
    	
			case state is
				when IDLE =>
					reset_MP1 <= '0';
					ready_in <= '1';
			
				when STARTUP =>
					reset_MP1 <= '0';
					ready_in <= '0';
					valid_out <= '0';
					
				when CALC_MR =>
					-- Make sure MONPRO is active
					reset_MP1 <= '1';
					
					-- Clear flags and signals from previous state
					-- None to clear
					
					-- If MONPRO is running and we have put data on the bus, we can stop telling
					-- MONPRO that the data is ready since it has started working with the data.
					if (running_MP1 = '1' and flag_Mr_set = '1') then
						extDataReady_MP1 <= '0';
					
					-- If we have not given MONPRO the data, put the data on the bus, and
					-- set a flag indicating that data has been put on the bus.
					elsif (flag_Mr_set = '0') then
						A_MP1 <= unsigned(message);
						B_MP1 <= unsigned(key_r(C_block_size-1 downto 0));
						flag_Mr_set <= '1';
					
					-- If the data has been put on the bus, we have not told MONPRO that the data is ready,
					-- and MONPRO does not have data ready to put out on the output, tell MONPRO
					-- that the data on the bus is ready.
					elsif (flag_Mr_set = '1' and extDataReady_MP1 = '0' and outputReady_MP1 = '0') then
						extDataReady_MP1 <= '1';
					end if;
					
					-- If MONPRO has data ready to be put out on the output bus, we are signaling that we are
					-- ready to read, and MONPRO is currently not conducting any calcualtions, indicate that
					-- calculation of Mr is complete, indicate that we are not ready to receive any new data,
					-- and store the output in the M_r register.
					if (outputReady_MP1 = '1' and extRecvReady_MP1 = '1' and running_MP1 = '0') then
						flag_calc_Mr_done <= '1';
						extRecvReady_MP1 <= '0';
						M_r <= u_MP1;
					end if;

				when CALC_XR =>
					-- Make sure MONPRO is active
					reset_MP1 <= '1';
					
					-- Clear flags and signals from previous state
					flag_Mr_set <= '0';
					flag_calc_Mr_done <= '0';

					-- If MONPRO is running and we have put data on the bus, we can stop telling
					-- MONPRO that the data is ready since it has started working with the data.
					if (running_MP1 = '1' and flag_xr_set = '1') then
						extDataReady_MP1 <= '0';
				
					-- If we have not given MONPRO the data, put the data on the bus, and
					-- set a flag indicating that data has been put on the bus.
					elsif (flag_xr_set = '0') then
						A_MP1 <= (0 => '1', others => '0'); -- First bit is 1, the rest is zero => decimal value = 1
						B_MP1 <= unsigned(key_r(C_block_size-1 downto 0));
						flag_xr_set <= '1';
					
					-- If the data has been put on the bus, we have not told MONPRO that the data is ready,
					-- and MONPRO does not have data ready to put out on the output, tell MONPRO
					-- that the data on the bus is ready.
					elsif (flag_xr_set = '1' and extDataReady_MP1 = '0' and outputReady_MP1 = '0') then
						extDataReady_MP1 <= '1';
					end if;
					
					-- If MONPRO has data ready to be put out on the output bus, we are signaling that we are
					-- ready to read, and MONPRO is currently not conducting any calcualtions, indicate that
					-- calculation of Mr is complete, indicate that we are not ready to receive any new data,
					-- and store the output in the x_r register.
					if (outputReady_MP1 = '1' and extRecvReady_MP1 = '1' and running_MP1 = '0') then
						flag_calc_xr_done <= '1';
						extRecvReady_MP1 <= '0';
						x_r <= u_MP1;
					end if;
					
				when CALC_LP =>
					-- Make sure MONPRO is active
					reset_MP1 <= '1';
					
					-- Clear flags and signals from previous state
					flag_xr_set <= '0';
					flag_calc_xr_done <= '0';
					
					-- If the loop counter is 0 and the loop is not ready to run
					if (inner_loop_counter = 0 and flag_looop_Ready = '0') then
						inner_loop_counter <= to_unsigned(C_block_size, 10);	-- set the counter value
						extDataReady_MP1 <= '0';								-- tell MONPRO that there is no data ready on the bus
						flag_looop_xr  <= '1';									-- falg to indicate which part of loop to run
						flag_looop_Ready <= '1';								-- the loop is now ready.
					end if;
				
					
					-- If MONPRO is running and we have put data on the bus, we can stop telling
					-- MONPRO that the data is ready since it has started working with the data.
					if (running_MP1 = '1' and (flag_looop_xr_set = '1' or flag_looop_e_set = '1')) then
						extDataReady_MP1 <= '0';
				
					-- If we have not given MONPRO the data, put the data on the bus, and
					-- set a flag indicating that data has been put on the bus.
					elsif (flag_looop_xr  = '1' and flag_looop_xr_set  = '0') then		
						A_MP1 <= x_r;
						B_MP1 <= x_r;
						flag_looop_xr_set <= '1';
					
					-- If the data has been put on the bus, we have not told MONPRO that the data is ready,
					-- and we are not waiting for results from MONPRO, tell MONPRO that the data on the bus is ready.
					elsif (flag_looop_xr_set  = '1' and flag_looop_xr_done = '0' and extRecvReady_MP1 = '0') then								
						extDataReady_MP1 <= '1';
					
					-- If we have not given MONPRO the data, 
					elsif (flag_looop_e  = '1' and flag_looop_e_set  = '0' and flag_looop_e_skipped = '0') then
						-- if True, put the data on the bus, and
						-- set a flag indicating that data has been put on the bus.
						if (key(to_integer(inner_loop_counter - 1)) = '1') then
							A_MP1 <= M_r;
							B_MP1 <= x_r;
							flag_looop_e_set <= '1';
							
						-- If key(0) = 0, do not put data on the bus, and indicate that we skipped this
						else
							flag_looop_e_skipped <= '1';
						end if;
						
						-- Decrement the loop counter.
						inner_loop_counter <= inner_loop_counter - 1;
					
					-- If the data has been put on the bus, we have not told MONPRO that the data is ready,
					-- and we are not waiting for results from MONPRO, tell MONPRO that the data on the bus is ready.
					elsif (flag_looop_e_set  = '1' and flag_looop_e_done = '0' and extRecvReady_MP1 = '0') then
						extDataReady_MP1 <= '1';
				
					-- We are done with calcualting with x_r and x_r
					-- next we will calculate with M_r and x_r
					elsif flag_looop_xr_set = '1' and flag_looop_xr_done = '1' then
						flag_looop_xr  <= '0';
						flag_looop_xr_set <= '0';
						flag_looop_xr_done <= '0';
						flag_looop_e <= '1';		-- Calculate x_r based on M_r and x_r
						flag_looop_e_set <= '0';
						flag_looop_e_done <= '0';
						flag_looop_e_skipped <= '0';

					-- We are done with calcualting with M_r and x_r
					-- next we will calculate with x_r and x_r
					elsif flag_looop_e_set = '1' and flag_looop_e_done = '1' then
						flag_looop_xr  <= '1';		-- Calculate x_r based on x_r and x_r
						flag_looop_xr_set <= '0';
						flag_looop_xr_done <= '0';
						flag_looop_e <= '0';
						flag_looop_e_set <= '0';
						flag_looop_e_done <= '0';
						flag_looop_e_skipped <= '0';
					
					-- key(inner_loop_counter - 1) was 0, so we skipped calculating M_r and x_r.
					-- Next, calculate with x_r and x_r again
					elsif flag_looop_e_skipped = '1' then
						flag_looop_xr  <= '1';		-- Calculate x_r based on x_r and x_r
						flag_looop_xr_set <= '0';
						flag_looop_xr_done <= '0';
						flag_looop_e <= '0';
						flag_looop_e_set <= '0';
						flag_looop_e_done <= '0';
						flag_looop_e_skipped <= '0';
					end if;
					
					-- If MONPRO has data ready to be put out on the output bus, we are signaling that we are
					-- ready to read, MONPRO is currently not conducting any calcualtions, and xr_set-flag is set, 
					-- indicate that calculation of x_r based on x_r and x_r is complete, 
					-- indicate that we are not ready to receive any new data, and store the output in the x_r register.
					if (outputReady_MP1 = '1' and extRecvReady_MP1 = '1' and running_MP1 = '0' and flag_looop_xr_set = '1') then
						flag_looop_xr_done <= '1';
						extRecvReady_MP1 <= '0';
						x_r <= u_MP1;
					
					-- If MONPRO has data ready to be put out on the output bus, we are signaling that we are
					-- ready to read, MONPRO is currently not conducting any calcualtions, and e_set-flag is set, 
					-- indicate that calculation of x_r based on M_r and x_r is complete, 
					-- indicate that we are not ready to receive any new data, and store the output in the x_r register.
					elsif (outputReady_MP1 = '1' and extRecvReady_MP1 = '1' and running_MP1 = '0' and flag_looop_e_set = '1') then
						flag_looop_e_done <= '1';
						extRecvReady_MP1 <= '0';
						x_r <= u_MP1;
					end if;
					
				when FINAL =>
					-- Make sure MONPRO is active
					reset_MP1 <= '1';
					
					-- Clear flags and signals from previous state
					flag_looop_Ready <= '0';
					flag_looop_xr  <= '0';
					flag_looop_xr_set <= '0';
					flag_looop_xr_done <= '0';
					flag_looop_e <= '0';
					flag_looop_e_set <= '0';
					flag_looop_e_done <= '0';
					flag_looop_e_skipped <= '0';
					inner_loop_counter <= (others => '0');
					
					-- If MONPRO is running and we have put data on the bus, we can stop telling
					-- MONPRO that the data is ready since it has started working with the data.
					if (running_MP1 = '1' and flag_final_xr_set = '1') then
						extDataReady_MP1 <= '0';
				
					-- If we have not given MONPRO the data, put the data on the bus, and
					-- set a flag indicating that data has been put on the bus.
					elsif (flag_final_xr_set = '0') then
						A_MP1 <= (0 => '1', others => '0');
						B_MP1 <= x_r;
						flag_final_xr_set <= '1';
					
					-- If the data has been put on the bus, we have not told MONPRO that the data is ready,
					-- and MONPRO does not have data ready to put out on the output, tell MONPRO
					-- that the data on the bus is ready.
					elsif (flag_final_xr_set = '1' and extDataReady_MP1 = '0' and outputReady_MP1 = '0') then
						extDataReady_MP1 <= '1';
					end if;
					
					-- If MONPRO has data ready to be put out on the output bus, we are signaling that we are
					-- ready to read, and MONPRO is currently not conducting any calcualtions, indicate that
					-- calculation of the final result is complete, indicate that we are not ready to receive any new data,
					-- indicate for the external circuit that the calcualtions are done, and store the output in the result_nxt register.
					if (outputReady_MP1 = '1' and extRecvReady_MP1 = '1' and running_MP1 = '0') then
						flag_final_done <= '1';
						extRecvReady_MP1 <= '0';
						valid_out <= '1';
						result_nxt <= u_MP1;
					end if;
				
				when ENDED =>
					-- Make sure MONPRO is active
					reset_MP1 <= '1';
					
					-- Clear flags and signals from previous state
					flag_final_done <= '0';
					flag_final_xr_set <= '0';
					
				when CLEAR =>
					-- Clear/Reset the MONPRO-module
					reset_MP1 <= '0';
	
				when others =>
					-- Clear/Reset the MONPRO-module
					reset_MP1 <= '0';
					
					-- Do we want more here?
					-- For instance, the same as we have done when reset_n = '0'?
					
			end case;
			
			-- If the external circuit is ready for new data to be put on the output bus, and
			-- the current result_nxt has a valid value, put the final result on the output bus.
			-- result_nxt has a size that is 2 bits larger than result
			if (ready_out = '1' and valid_out = '1') then
				result <= std_logic_vector(result_nxt(C_block_size-3 downto 0));
			end if;
        end if;
    end process state_machine;
end expBehave;
