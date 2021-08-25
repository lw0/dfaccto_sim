{{>lib:vhdl/dependencies.part.tpl}}
use work.{{x_interfacepkg}}.all;

entity {{identifier}} is
  generic (
    CFGSCRIPT : String := "");
end {{identifier}};


architecture Structure of {{identifier}} is

  constant c_ClockPeriod : Time := {{?x_clocknanos}}{{x_clocknanos}}{{|x_clocknanos}}4{{/x_clocknanos}} ns;
  constant c_ClockDelay : Time := c_ClockPeriod / 2;
  constant c_ChangeDelay : Time := c_ClockPeriod / 16;

  signal s_clk : std_logic := '0';
  signal s_rst_n : std_logic := '0';
  signal s_stop : std_logic := '0';

{{#ports}}
  {{>lib:vhdl/defsignal.part.tpl}}
{{/ports}}

begin

  -- Instances:

  {{#instances}}
  {{>lib:vhdl/instance.part.tpl}}

  {{/instances}}


  -- Testbench Logic:

  process
  begin
    x_setup(CFGSCRIPT);
    while s_stop = '0' loop
      wait for c_ClockDelay;
      s_clk <= '0';
      wait for c_ClockDelay;
      s_clk <= '1';
    end loop;
    wait for c_ClockDelay;
    x_shutdown;
    report "End Simulation" severity failure;
  end process;

  process (s_clk)
    variable v_rst_n : std_logic;
    variable v_stop : std_logic;
{{#ports}}
{{? x_interface}}
    -- {{name}}
    constant c_{{name}}_ref : natural := x_register("{{x_interface}}", "{{name}}");
    {{*x_vars}}
{{/ x_interface}}
{{/ports}}
  begin
    if s_clk'event and s_clk = '1' then
      ------- Update -------
{{#ports}}
{{? x_interface}}
      {{*x_update}}
{{/ x_interface}}
{{/ports}}
      -------- Tick --------
      x_tick(v_rst_n, v_stop);
      s_rst_n <= v_rst_n;
      s_stop <= v_stop;
      ------- State --------
{{#ports}}
{{? x_interface}}
      {{*x_state}}
{{/ x_interface}}
{{/ports}}
      ----------------------
    end if;
  end process;

{{#ports}}
{{? .type.x_is_sys}}
  {{.qualified}}.clk <= s_clk;
  {{.qualified}}.rst_n <= s_rst_n;
{{/ .type.x_is_sys}}
{{/ports}}

end Structure;
