library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity debouncer is
    generic(
        g_timeout          : integer   := 5;        -- Time in ms
        g_clock_freq_KHZ   : integer   := 100_000   -- Frequency in KHz of the system 
    );   
    port (  
        rst_n       : in    std_logic; -- asynchronous reset, low-active
        clk         : in    std_logic; -- system clk
        ena         : in    std_logic; -- enable must be on 1 to work (kind of synchronous reset)
        sig_in      : in    std_logic; -- signal to debounce
        debounced   : out   std_logic  -- 1 pulse flag output when the timeout has occurred
    ); 
end debouncer;

architecture Behavioural of debouncer is 
    
    -- Calculate the number of cycles of the counter (debounce_time * freq), result in cycles
    constant c_cycles           : integer := integer(g_timeout * g_clock_freq_KHZ) ;
    -- Calculate the length of the counter so the count fits
    constant c_counter_width    : integer := integer(ceil(log2(real(c_cycles))));
    
    -- Estados de la FSM
    type t_state is (IDLE, BTN_PRS, VALID, BTN_UNPRS);
    signal current_state, next_state : t_state;
    
    -- Contador para el tiempo de debounce
    signal count : unsigned(c_counter_width-1 downto 0);
    signal time_elapsed : std_logic;
    
begin
    -- Timer
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            count <= (others => '0');
            time_elapsed <= '0';
        elsif rising_edge(clk) then
            if current_state = BTN_PRS or current_state = BTN_UNPRS then
                if count = to_unsigned(c_cycles, c_counter_width) then
                    time_elapsed <= '1';
                    count <= (others => '0');
                else
                    count <= count + 1;
                    time_elapsed <= '0';
                end if;
            else
                count <= (others => '0');
                time_elapsed <= '0';
            end if;
        end if;
    end process;

    -- FSM Register of next state
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            if ena = '0' then
                current_state <= IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    process (current_state, sig_in, time_elapsed, ena) --sensitivity list
    begin
        case current_state is
            when IDLE =>
                if sig_in = '1' then
                    next_state <= BTN_PRS;
                else
                    next_state <= IDLE;
                end if;
                debounced <= '0';
            
            when BTN_PRS =>
                if time_elapsed = '1' and sig_in = '1' then
                    next_state <= VALID;
                elsif ena = '0' then
                    next_state <= IDLE;
                elsif time_elapsed = '1' and sig_in = '0' then
                    next_state <= IDLE;
                else
                    next_state <= BTN_PRS;
                end if;
                debounced <= '0';
                
            when VALID =>
                if sig_in = '0' then
                    next_state <= BTN_UNPRS;
                else
                    next_state <= VALID;
                end if;
                debounced <= '1';
                
            when BTN_UNPRS =>
                if time_elapsed = '1' then
                    next_state <= IDLE;
                elsif ena = '0' then
                    next_state <= IDLE;
                else
                    next_state <= BTN_UNPRS;
                end if;
                debounced <= '0';
        end case;
    end process;

end Behavioural;