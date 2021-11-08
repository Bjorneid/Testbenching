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
	generic (
		C_block_size : positive := 256 + 2
	);
    Port ( clk : in std_logic;
           reset_n : in std_logic;
           outputReady : out std_logic := '0';			-- this module/entity has the new value for u ready to be put out on the bus
           running : out std_logic := '0';					-- this module/entity has started the calculations
           extRecvReady : in std_logic;				-- The external circuit/logic is ready to receive the new value for u.
           extDataReady : in std_logic;				-- Data recieved from an external circuit is ready to be read on the inputs.
           
           A : in unsigned (C_block_size - 1 downto 0);
           B : in unsigned (C_block_size - 1 downto 0);
           n : in std_logic_vector (C_block_size - 1 downto 0);
           
           u : out unsigned (C_block_size - 1 downto 0) := (others => '0'));	-- The end result after the algorithm completes.
end MonProBit;

architecture Behavioral of MonProBit is
	-- MONPRO - REGISTERS
    signal temp_u1 : unsigned(C_block_size - 1 downto 0) := (others => '0');
    signal inner_loop_counter : unsigned(10 - 1 downto 0) := (others => '0');
    signal temp_A_shift : unsigned(C_block_size - 1 downto 0) := (others => '0');
    
    -- 
    -- MODEXP - STATE MACHINE
    type states is (IDLE, CALC_LOOOP, FINAL, ENDED);
	signal state : states := IDLE;
    signal next_state : states := IDLE;

    signal shift_A_done : std_ulogic := '0';
	signal sum_n_done : std_ulogic := '0';
	signal sum_n_skipped : std_ulogic := '0';
	signal sum_B_done : std_ulogic := '0';
	signal sum_B_skipped : std_ulogic := '0';
	signal shift_done : std_ulogic := '0';
	signal loop_done : std_ulogic := '0';
    
    signal outputReady_internal : std_ulogic := '0';
    
begin

	-- In this process we determine if the state should be changed, 
	-- and which state it should be changed to.
    state_change: process (clk, reset_n)
    begin
        if (reset_n = '0') then
            next_state <= IDLE;
            state <= IDLE;
        elsif rising_edge(clk) then
			if (state = IDLE and extDataReady = '1') then
				next_state <= CALC_LOOOP;
				state <= CALC_LOOOP;
	
			elsif (state = CALC_LOOOP and loop_done = '1') then
				next_state <= FINAL;
				state <= FINAL;
				
			elsif (state = FINAL and outputReady_internal = '1') then
				next_state <= ENDED;
				state <= ENDED;
			
			elsif (state = ENDED and running = '0') then			
				next_state <= IDLE;
				state <= IDLE;
				
			end if;
        end if;
    end process state_change;

	-- Here we simply set the different main flags that are associated with the current state.
    state_machine: process (clk, reset_n)
    	
    begin
        if reset_n = '0' then
        	running <= '0';
        	temp_u1 <= (others => '0');
        	temp_A_shift <= (others => '0');
			inner_loop_counter <= (others => '0');
			
   			outputReady_internal <= '0';
   			
			outputReady <= '0';
			u <= (others => '0');
    
        elsif rising_edge(clk) then
			case state is
				when IDLE =>
					
				temp_u1 <= (others => '0');
				
				-- This is the for-loop from the high level code of the MonProEff algorithm
				when CALC_LOOOP =>
					running <= '1';
					outputReady_internal <= '0';
					outputReady <= '0';
					
					if (inner_loop_counter < to_unsigned(C_block_size, 10)) then
					
						if (shift_A_done = '0') then
							shift_A_done <= '1';
							-- Prepare a right shifted A
							temp_A_shift <= shift_right(A, to_integer(inner_loop_counter));
						
						elsif (sum_n_done = '0' and sum_n_skipped = '0') then
							-- Check if the next value of temp_u1 will become odd, if so
							-- add n to temp_u1. This will make sure that the next value is even.
							if (temp_u1(0) = '1' xor (temp_A_shift(0) = '1' and B(0) = '1')) then
								sum_n_done <= '1';
								temp_u1 <= temp_u1 + unsigned(n);
							else
								sum_n_skipped <= '1';
							end if;
							
						elsif (sum_B_done = '0' and sum_B_skipped = '0') then
							-- Add B to temp_u1 if bit 0 of temp_A_shift equals 1
							if (temp_A_shift(0) = '1') then
							     sum_B_done <= '1';
								 temp_u1 <= temp_u1 + B;
							else
							     sum_B_skipped <= '1';
							end if;
						
						-- Divide by 2
						elsif shift_done = '0' then
							shift_done <= '1';
							temp_u1 <= shift_right(temp_u1, 1);
						end if;
						
						-- This is the counter in our for-loop
						if shift_done = '1' then
                            shift_A_done <= '0';
                            sum_n_done <= '0';
                            sum_n_skipped <= '0';
                            sum_B_done <= '0';
                            sum_B_skipped <= '0';
                            shift_done <= '0';
                        
                            inner_loop_counter <= inner_loop_counter + 1;
                        end if;
						
					else
                        loop_done <= '1';
                        shift_A_done <= '0';
                        sum_n_done <= '0';
                        sum_n_skipped <= '0';
                        sum_B_done <= '0';
                        sum_B_skipped <= '0';
                        shift_done <= '0';
                        
                        temp_A_shift <= (others => '0');
					end if;

				-- This is the final part of the MonProEff algorithm where we simply check if u is equal or larger than n,
    			-- and where we either subtract n from u, set u equal 0, or use the current u as the final value for u.
				when FINAL =>
					outputReady_internal <= '1';
					
					loop_done <= '0';
					inner_loop_counter <= (others => '0');
	
				when ENDED =>
					running <= '0';

	
				when others =>
					 
			end case;
			
			-- We do not want the output to change out of nothing
			-- the external logic has got to tell this module/enitity
			-- when it is ready for a new value on the bus.
			if (extRecvReady = '1' and outputReady_internal = '1') then
				u <= temp_u1;
				outputReady <= '1';
							
			end if;
        end if;

    end process state_machine;
    
end Behavioral;
