library ieee;
use ieee.std_logic_1164.all;

entity ostdc_top is
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(0 downto 0); -- Reset (Active Low)
        SW       : in  std_logic_vector(9 downto 0)  -- Monitored probes
    );
end entity ostdc_top;

architecture rtl of ostdc_top is

    component ostdc_sys is
        port (
            clk_clk                         : in std_logic                    := '0';
            reset_reset_n                   : in std_logic                    := '0';
            probe_inputs_export             : in std_logic_vector(9 downto 0) := (others => '0')
        );
    end component ostdc_sys;

    signal reset_n : std_logic;

begin

    reset_n <= KEY(0);

    u0 : component ostdc_sys
        port map (
            clk_clk                          => CLOCK_50,
            reset_reset_n                    => reset_n,
            probe_inputs_export 					=> SW
        );

end architecture rtl;