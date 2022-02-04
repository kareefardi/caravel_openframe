## MASTER CLOCKS
create_clock [get_ports {"ext_clk"} ] -name "ext_clk"  -period 25
create_clock [get_ports {"pll_clk"} ] -name "pll_clk"  -period 6.6666666666667 
create_clock [get_ports {"pll_clk90"} ] -name "pll_clk90"  -period 6.6666666666667 

## GENERATED CLOCKS
# divided PLL clocks
# $::env(STD_CELL_LIBRARY)__o22ai_2 _248_ (
#    .Y(\divider.out )
#  );
# $::env(STD_CELL_LIBRARY)__o22ai_2 _257_ (
#   .Y(\divider2.out )
# );
set divider1_out_pin [get_pins -of_objects divider.out -filter lib_pin_name==Y]
set divider2_out_pin [get_pins -of_objects divider2.out -filter lib_pin_name==Y]
create_generated_clock -name pll_clk_divided -source [get_ports pll_clk] -divide_by 2 $divider1_out_pin
create_generated_clock -name pll_clk90_divided -source [get_ports pll_clk90] -divide_by 2 $divider2_out_pin
#  $::env(STD_CELL_LIBRARY)__mux2_2 _322_ (
#    .A0(ext_clk_syncd_pre),
#    .A1(ext_clk),
#    .S(resetb),
#    .X(_146_)
#  );
#  $::env(STD_CELL_LIBRARY)__dfxtp_2 _410_ (
#    .CLK(pll_clk),
#    .D(_025_),
#    .Q(ext_clk_syncd_pre)
#  );
#  assign core_ext_clk = (use_pll_first) ? ext_clk_syncd : ext_clk;
set muxes_2 [list $::env(STD_CELL_LIBRARY)__mux2_1 $::env(STD_CELL_LIBRARY)__mux2_2 $::env(STD_CELL_LIBRARY)__mux2_4 $::env(STD_CELL_LIBRARY)__mux2_8]
foreach mux_2 $muxes_2 {
    set mux2_instance [get_cells -of_objects ext_clk_syncd_pre -filter ref_name==$mux_2]
    if { $mux2_instance ne "" } {
        puts "\[caravel_clocking_sdc\] found mux2: $mux2_instance"
        break
    }
}
set core_ext_clk_pre_pin [get_pins -filter lib_pin_name==X -of_objects $mux2_instance]
set core_ext_clk_synced_source [get_pins -of_objects ext_clk_syncd_pre -filter lib_pin_name==Q]
create_generated_clock -name core_ext_clk -source [get_ports ext_clk] -divide_by 1 $core_ext_clk_pre_pin
create_generated_clock -name core_ext_clk_syncd -source $core_ext_clk_synced_source -divide_by 1 $core_ext_clk_pre_pin

# assign core_clk = (use_pll_second) ? pll_clk_divided : core_ext_clk;
create_generated_clock -name core_clk -source $core_ext_clk_pre_pin  -divide_by 1 [get_ports core_clk] 
create_generated_clock -name core_clk_pll -source $divider1_out_pin   -divide_by 1 [get_ports core_clk] 

# assign user_clk = (use_pll_second) ? pll_clk90_divided : core_ext_clk;
create_generated_clock -name user_clk -source $core_ext_clk_pre_pin  -divide_by 1 [get_ports user_clk] 
create_generated_clock -name user_clk_pll -source $divider2_out_pin  -divide_by 1 [get_ports user_clk]  

# logically exclusive clocks, the generated pll clocks and the ext core clk
set_clock_groups -logically_exclusive -group core_ext_clk -group core_ext_clk_syncd
set_clock_groups -logically_exclusive -group core_clk -group core_clk_pll
set_clock_groups -logically_exclusive -group user_clk -group user_clk_pll

set_clock_groups -logically_exclusive -group ext_clk -group {pll_clk pll_clk90 pll_clk_divided pll_clk90_divided}

## INPUT/OUTPUT DELAYS
set ext_clk_input_delay_value 1
set ext_clk_output_delay_value [expr 25 * $::env(IO_PCT)]
set pll_clk_input_delay_value [expr 6.6666666666667  * $::env(IO_PCT)]
set pll_clk_output_delay_value [expr 6.6666666666667  * $::env(IO_PCT)]
puts "\[INFO\]: Setting output delay to: $ext_clk_output_delay_value"
puts "\[INFO\]: Setting input delay to: $ext_clk_input_delay_value"

set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {ext_clk_sel}]

#set_input_delay $input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {resetb}]
set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {sel2[0]}]
set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {sel2[1]}]
set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {sel2[2]}]
set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {sel[0]}]
set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {sel[1]}]
set_input_delay $ext_clk_input_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {sel[2]}]

set_output_delay $ext_clk_output_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {resetb_sync}]
#set_output_delay $output_delay_value  -clock [get_clocks {ext_clk}] -add_delay [get_ports {core_clk}]
#set_output_delay $output_delay_value -clock [get_clocks {ext_clk}] -add_delay [get_ports {user_clk}]

set_max_fanout $::env(SYNTH_MAX_FANOUT) [current_design]

# TODO set this as parameter
set_driving_cell -lib_cell $::env(SYNTH_DRIVING_CELL) -pin $::env(SYNTH_DRIVING_CELL_PIN) [all_inputs]
set cap_load [expr $::env(SYNTH_CAP_LOAD) / 1000.0]
puts "\[INFO\]: Setting load to: $cap_load"
set_load  $cap_load [all_outputs]

puts "\[INFO\]: Setting timing derate to: [expr {$::env(SYNTH_TIMING_DERATE) * 10}] %"
set_timing_derate -early [expr {1-$::env(SYNTH_TIMING_DERATE)}]
set_timing_derate -late [expr {1+$::env(SYNTH_TIMING_DERATE)}]

puts "\[INFO\]: Setting clock uncertainity to: $::env(SYNTH_CLOCK_UNCERTAINITY)"
set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINITY) [get_clocks {ext_clk}]
set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINITY) [get_clocks {pll_clk}]
set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINITY) [get_clocks {pll_clk90}]

puts "\[INFO\]: Setting clock transition to: $::env(SYNTH_CLOCK_TRANSITION)"
set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks {ext_clk}]
set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks {pll_clk}]
set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks {pll_clk90}]
