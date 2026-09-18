library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debug_core_avalon is
    generic (
        BUFFER_DEPTH : integer := 256; -- Power of 2 (inferred M10K BRAM)
        DATA_WIDTH   : integer := 10   -- SW[9:0] width
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        -- Avalon-MM Slave Interface
        avs_address   : in  std_logic_vector(1 downto 0);
        avs_chipselect: in  std_logic;
        avs_read      : in  std_logic;
        avs_write     : in  std_logic;
        avs_writedata : in  std_logic_vector(31 downto 0);
        avs_readdata  : out std_logic_vector(31 downto 0);

        -- Probed Hardware Signals
        probe_inputs : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity debug_core_avalon;

architecture rtl of debug_core_avalon is

    -- Register Storage
    signal reg_control  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_trigger  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    
    -- Status Bits
    signal flag_armed    : std_logic := '0';
    signal flag_triggered: std_logic := '0';
    signal flag_full     : std_logic := '0';

    -- Internal BRAM Array (Inferred M10K Block RAM)
    type ram_type is array (0 to BUFFER_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal trace_ram    : ram_type := (others => (others => '0'));

    -- Pointers
    signal write_ptr    : integer range 0 to BUFFER_DEPTH-1 := 0;
    signal read_ptr     : integer range 0 to BUFFER_DEPTH-1 := 0;

begin

    -- Status Register Mapping
    flag_armed <= reg_control(0);

    -- 1. Avalon-MM Register Writes & Soft Reset
    process(clk, reset)
    begin
        if reset = '1' then
            reg_control <= (others => '0');
            reg_trigger <= (others => '0');
        elsif rising_edge(clk) then
            -- Self-clearing reset bit handling
            if reg_control(1) = '1' then
                reg_control(1) <= '0';
            end if;

            if (avs_chipselect = '1' and avs_write = '1') then
                case avs_address is
                    when "00" => reg_control <= avs_writedata;
                    when "01" => reg_trigger <= avs_writedata(DATA_WIDTH-1 downto 0);
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    -- 2. Capture Engine & State Machine Logic
    process(clk, reset)
    begin
        if reset = '1' or reg_control(1) = '1' then
            write_ptr      <= 0;
            flag_triggered <= '0';
            flag_full      <= '0';
        elsif rising_edge(clk) then
            if flag_armed = '1' and flag_triggered = '0' then
                -- Write probe inputs into circular buffer
                trace_ram(write_ptr) <= probe_inputs;

                -- Check Trigger Pattern
                if probe_inputs = reg_trigger then
                    flag_triggered <= '1';
                end if;

                -- Increment Pointer
                if write_ptr = BUFFER_DEPTH - 1 then
                    write_ptr <= 0;
                    flag_full <= '1';
                else
                    write_ptr <= write_ptr + 1;
                end if;
            end if;
        end if;
    end process;

    -- 3. Avalon-MM Synchronous Bus Read Decoding
    process(clk)
    begin
        if rising_edge(clk) then
            if (avs_chipselect = '1' and avs_read = '1') then
                case avs_address is
                    when "00" => 
                        avs_readdata <= (31 downto 3 => '0', 
                                         2 => flag_full, 
                                         1 => flag_triggered, 
                                         0 => flag_armed);
                    when "01" => 
                        avs_readdata <= std_logic_vector(resize(unsigned(reg_trigger), 32));
                    when "10" => 
                        avs_readdata <= std_logic_vector(resize(unsigned(trace_ram(read_ptr)), 32));
                        -- Auto-increment read pointer on buffer read
                        if read_ptr = BUFFER_DEPTH - 1 then
                            read_ptr <= 0;
                        else
                            read_ptr <= read_ptr + 1;
                        end if;
                    when "11" => 
                        avs_readdata <= std_logic_vector(to_unsigned(BUFFER_DEPTH, 32));
                    when others => 
                        avs_readdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end architecture rtl;