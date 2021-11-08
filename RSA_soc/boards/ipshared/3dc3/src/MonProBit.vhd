----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/25/2021 07:32:42 PM
-- Design Name: 
-- Module Name: MonProBit - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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
use IEEE.numeric_std.all;

entity MonProBit is
	generic(width : positive := 256 + 2);
    Port ( clk : in std_logic;
           reset_n : in std_logic;
           outputReady : out std_logic := '0';			-- this module/entity has the new value for u ready to be put out on the bus
           running : out std_logic := '0';					-- this module/entity has started the calculations
           extRecvReady : in std_logic;				-- The external circuit/logic is ready to receive the new value for u.
           extDataReady : in std_logic;				-- Data recieved from an external circuit is ready to be read on the inputs.
           
           A : in unsigned (width - 1 downto 0);
           B : in unsigned (width - 1 downto 0);
           n : in std_logic_vector (width - 1 downto 0);
           
           u : out unsigned (width - 1 downto 0) := (others => '0'));	-- The end result after the algorithm completes.
end MonProBit;

architecture Behavioral of MonProBit is
    signal temp_u1 : unsigned(width - 1 downto 0) := (others => '0');
    signal temp_u2 : unsigned(width - 1 downto 0) := (others => '0');
    signal final_u : unsigned(width - 1 downto 0) := (others => '0');
    signal inner_loop_counter : unsigned(10 - 1 downto 0) := (others => '0');
    
    type states is (IDLE, CALC_LOOOP, FINAL, ENDED);
	signal state : states := IDLE;
    signal next_state : states := IDLE;

    signal flag_idle : std_ulogic := '0';
    signal flag_loop : std_ulogic := '0';
    signal flag_final : std_ulogic := '0';
    signal flag_end : std_ulogic := '0';
    
    signal outputReady_internal : std_ulogic := '0';
    
begin

	-- In this process we determine if the state should be changed, 
	-- and which state it should be changed to.
    state_change: process (clk, reset_n)
    begin
        if rising_edge(clk) then
			if (state = IDLE and extDataReady = '1') then
				running <= '1';
				
				next_state <= CALC_LOOOP;
				state <= CALC_LOOOP;
	
			elsif (state = CALC_LOOOP and flag_loop = '1' and inner_loop_counter >= to_unsigned(width, 10) - 1) then
				next_state <= FINAL;
				state <= FINAL;
				
			elsif (state = FINAL and flag_final = '1') then
				next_state <= ENDED;
				state <= ENDED;
			
			elsif (state = ENDED and flag_end = '1') then
				running <= '0';
			
				next_state <= IDLE;
				state <= IDLE;
			end if;
        end if;
        
        if (reset_n = '0') then
        	running <= '0';
        
            next_state <= IDLE;
            state <= IDLE;
        end if;
    end process state_change;

	-- Here we simply set the different main flags that are associated with the current state.
    state_machine: process (clk)
    begin
        if rising_edge(clk) then
			case state is
				when IDLE =>
					flag_idle <= '1';
					flag_loop <= '0';
					flag_final <= '0';
					flag_end <= '0';
			
				when CALC_LOOOP =>
					flag_idle <= '0';
					flag_loop <= '1';
					flag_final <= '0';
					flag_end <= '0';
					
				when FINAL =>
					flag_idle <= '0';
					flag_loop <= '0';
					flag_final <= '1';
					flag_end <= '0';
	
				when ENDED =>
					flag_idle <= '0';
					flag_loop <= '0';
					flag_final <= '0';
					flag_end <= '1';
	
				when others =>
					flag_idle <= '0';
					flag_loop <= '0';
					flag_final <= '0';
					flag_end <= '0';
			end case;
        end if;
    end process state_machine;
    
    -- This is the for-loop from the high level code of the MonProEff algorithm
    inner_loop: process (clk, reset_n)
        variable temp_A_shift : unsigned(width - 1 downto 0);
        variable temp : unsigned(width - 1 downto 0);
    begin
    	if rising_edge(clk) then
			if (flag_loop = '1' and inner_loop_counter < to_unsigned(width, 10)) then
				-- Prepare a right shifted A
				temp_A_shift := shift_right(A, to_integer(inner_loop_counter));
							
				-- Check if the next value of temp will become odd, if so
				-- add n to temp. This will make sure that the next value is even.
				if (temp(0) = '1' xor (temp_A_shift(0) = '1' and B(0) = '1')) then
					temp := temp + unsigned(n);
				end if;
				
				-- Add B to temp if bit 0 of temp_A_shift equals 1
				if (temp_A_shift(0) = '1') then
					temp := temp + B;
				end if;
				
				-- Divide by 2
				temp := shift_right(temp, 1);
				
				temp_u1 <= temp;
			end if;
			
			-- This is the counter in our for-loop
			if (flag_loop = '1') then
				inner_loop_counter <= inner_loop_counter + 1;
			elsif flag_loop = '0' then
				inner_loop_counter <= (others => '0');
				temp := (others => '0');
			end if;
        end if;
        
        if reset_n = '0' then
        	temp := (others => '0');
        	temp_A_shift := (others => '0');
        	temp_u1 <= (others => '0');
			inner_loop_counter <= (others => '0');
		end if;
    end process inner_loop;
    
    -- This is the final part of the MonProEff algorithm where we simply check if u is equal or larger than n,
    -- and where we either subtract n from u, set u equal 0, or use the current u as the final value for u.
    final_processing: process (clk, reset_n) -- add reset_n here such that the output can be "reset_n"
    begin
    
    if rising_edge(clk) then
		if (flag_final = '1') then
			
			if (temp_u1 > unsigned(n)) then
				temp_u2 <= temp_u1 - unsigned(n);

			-- By checking this we can simply set temp_u2 equal to 0
			-- instead of subtracting n from temp_u1.
			elsif (temp_u1 = unsigned(n)) then
				temp_u2 <= (others => '0');
				
			-- temp_u1 is less than n, and therefore the result is
			-- equal to temp_u1.
			else
				temp_u2 <= temp_u1;
			end if;
			
			outputReady_internal <= '1';
		
		-- If we have started performing calculations then ...
		elsif flag_loop = '1' then
			outputReady_internal <= '0';
		end if;
    end if;
    
   	if reset_n = '0' then
   		temp_u2 <= (others => '0');
   		outputReady_internal <= '0';
    end if;
    end process final_processing;
    
    -- We do not want the output to change out of nothing
    -- the external logic has got to tell this module/enitity
    -- when it is ready for a new value on the bus.
    change_output: process (clk, reset_n) -- add reset_n here such that the output can be "reset_n"
	begin
		if rising_edge(clk) then
			if (extRecvReady = '1' and outputReady_internal = '1') then
				final_u <= temp_u2;
				outputReady <= '1';
			
			elsif outputReady_internal = '0' then
				outputReady <= '0';
			end if;
		end if;
		
		if reset_n = '0' then
			final_u <= (others => '0');
			outputReady <= '0';
		end if;
	end process change_output;

    u <= final_u;
    
end Behavioral;
