#################################################################################
# Get license DFT compiler
#################################################################################
#get_license Galaxy-DFT
get_license Test-DFTC-TMAX
#get_license Test-Compression-Synthesis
#################################################################################
source -echo -verbose ./setups/setup.tcl
source $RTL_DIR 
file mkdir ${REPORTS_DIR}/timing_report
#################################################################################
# Search Path Setup
#
# Set up the search path to find the libraries and design files.
#################################################################################
set_app_var search_path ". ${ADDITIONAL_SEARCH_PATH} $search_path"
set_app_var target_library ${TARGET_LIBRARY_FILES}
set_app_var synthetic_library {dw_foundation.sldb dft_jtag.sldb}
set_app_var link_library "* $target_library $ADDITIONAL_LINK_LIB_FILES $synthetic_library"
# Define the verification setup file for Formality
set_svf ${OUTPUTS_DIR}/${DCRM_SVF_OUTPUT_FILE_TOP}
set_vsdc ${OUTPUTS_DIR}/${DCRM_VSDC_OUTPUT_FILE_TOP}

#set_svf ${OUTPUTS_DIR}/${DCRM_SVF_OUTPUT_FILE_DIG_TOP}
set_app_var sh_new_variable_message false
if {$synopsys_program_name == "dc_shell"}  {
#################################################################################
# Design Compiler Setup Variables
#################################################################################
set_host_options -max_cores 4 
}

#################################################################################
# Setup SAIF Name Mapping Database
#
# Include an RTL SAIF for better power optimization and analysis.
#
# saif_map should be issued prior to RTL elaboration to create a name mapping
# database for better annotation.
################################################################################

# saif_map -start
#################################################################################
# Read in the RTL Design
#
# Read in the RTL source files or read in the elaborated design (.ddc).
#################################################################################
#### Replace 'tri' variable by 'wire'
set_app_var verilogout_no_tri true
#### Insert Mux to select between test clock and system clock
#################################################################################
#### Set option for boundary optimization
####
set compile_preserve_subdesign_interfaces true
#### Disable Constant Propagation When Boundary Optimization is Disabled
set compile_enable_constant_propagation_with_no_boundary_opt false
#set compile_enable_constant_propagation_with_no_boundary_opt true
#### Controlling Phase Inversion of boundary optimization
set compile_disable_hierarchical_inverter_opt true
#### Propagating Unconnected Registers and Unconnected Bits of Multibit Registers Across Hierarchies With Boundary Optimization Disabled
set compile_optimize_unloaded_seq_logic_with_no_bound_opt false 
#set compile_optimize_unloaded_seq_logic_with_no_bound_opt true 
#################################################################################
set auto_ungroup_preserve_constraints false

set hdlin_reporting_level verbose 
set hdlin_enable_rtldrc_info true
set test_bsd_synthesis_gated_tck true
#set compile_seqmap_propagate_constants false to prevent constant registers from being removed during compile
#set compile_seqmap_propagate_constants false
set compile_seqmap_propagate_constants true
#change for reduce area
#set compile_delete_unloaded_sequential_cells true
set compile_delete_unloaded_sequential_cells false
set hdlin_keep_signal_name user 
set enable_keep_signal true
set compile_enable_register_merging false
set compile_enable_register_merging_with_exceptions false
#### Selects the scan-out pin on a scan cell based on availability instead of timing slack.
set test_disable_find_best_scan_out true
set set_power_prediction true
set compile_clock_gating_through_hierarchy true
#################################################################################
#### Configure for bus style
#set bus_inference_style {%s<%d>}
#set bus_inference_descending_sort false
#################################################################################
####Design Compiler Ultra automatically identifies  shift registers in the design during test-ready compile.
set compile_seqmap_identify_shift_registers false
set_clock_gating_style -sequential_cell latch -control_point before -control_signal scan_enable

define_design_lib WORK -path ./WORK

analyze -format sverilog ${RTL_SOURCE_FILES}

elaborate ${DESIGN_NAME}

if {[file exists [which ${CELL_DONT_TOUCH_FILE}]]} {
  puts "RM-Info: Sourcing script file [which ${CELL_DONT_TOUCH_FILE}]\n"
  source -echo -verbose ${CELL_DONT_TOUCH_FILE}
}


write -format verilog -hierarchy -output ${OUTPUTS_DIR}/${DESIGN_NAME}_generic.v
write -hierarchy -format ddc -output ${OUTPUTS_DIR}/${DCRM_ELABORATED_DESIGN_DDC_OUTPUT_FILE}

#################################################################################
# Apply Logical Design Constraints
#################################################################################

# You can use either SDC file ${DCRM_SDC_INPUT_FILE} or Tcl file 
# ${DCRM_CONSTRAINTS_INPUT_FILE} to constrain your design.

#if {[file exists [which ${DCRM_SDC_INPUT_FILE}]]} {
#  puts "RM-Info: Reading SDC file [which ${DCRM_SDC_INPUT_FILE}]\n"
#  read_sdc ${DCRM_SDC_INPUT_FILE}
#}

if {[file exists [which ${DCRM_CONSTRAINTS_INPUT_FILE}]]} {
  puts "RM-Info: Sourcing script file [which ${DCRM_CONSTRAINTS_INPUT_FILE}]\n"
  source -echo -verbose ${DCRM_CONSTRAINTS_INPUT_FILE}
}


if {[llength all_clocks] > 0} {
    group_path -name in2reg -from [all_inputs] -to [all_clocks]
    group_path -name reg2out -to [all_outputs] -from [all_clocks]
    group_path -name reg2reg -from [all_clocks] -to [all_clocks]
}
group_path -name in2out -from [all_inputs] -to [all_outputs]

 

# Check the current design for consistency
check_design -summary
check_design > ${REPORTS_DIR}/${DCRM_CHECK_DESIGN_REPORT}
#################################################################################
source $DONT_USE 
set_dont_touch [get_cells -hierarchical *FIXED_SYNC*]
remove_attribute [get_cells dig_top/output_control_inst/i_cal_top/*/*/*FIXED_SYNC*] dont_touch
remove_attribute [get_cells dig_top/serial_comm_inst/*/*FIXED_SYNC*] dont_touch
remove_attribute [get_cells dig_top/serial_comm_inst/*/*/*FIXED_SYNC*] dont_touch
remove_attribute [get_cells dig_top/reset_ctrl_inst/*/*FIXED_SYNC*] dont_touch

set_dont_touch [get_cells -hierarchical *CUSTOM*]
set_dont_touch [get_cells -hierarchical *instjtag_csr_rd_wrt_b*]
set_dont_touch [get_cells -hierarchical *inst_scan_enable*]
set_dont_touch [get_cells -hierarchical *inst_clock_dr*]
set_dont_touch [get_cells -hierarchical *mux_*_mode*]
set_dont_touch [get_cells  dig_top/clk_mgmt_inst/clk_gate_*_inst/clk_gate_latch_inst/inst*]
set_dont_touch [get_cells  dig_top/PLL_FREF_BUF]
# The analyze_datapath_extraction command can help you to analyze why certain data 
# paths are no extracted, uncomment the following line to report analyisis.

# analyze_datapath_extraction > ${REPORTS_DIR}/${DCRM_ANALYZE_DATAPATH_EXTRACTION_REPORT}
#################################################################################
set_fix_multiple_port_nets  -all -outputs -feedthroughs -constants -buffer_constants [get_designs *]
#remove_unconnected_ports -blast_buses [get_cells -hierarchical *]


#################################################################################
# Save Design after First Compile
#################################################################################
write -format verilog -hierarchy -output ${OUTPUTS_DIR}/${DESIGN_NAME}_compile_first.v
write -format ddc -hierarchy -output ${OUTPUTS_DIR}/${DCRM_COMPILE_ULTRA_DDC_OUTPUT_FILE}
write_test_model -format ddc -output ${OUTPUTS_DIR}/compile_first.ddc

proc CreateIgnoreBSR {filename package} {
  set f [open $filename "w"]
  foreach_in_collection p [get_port *] {
     puts $f "set_bsd_linkage_port -port_list {[get_object_name $p]}"
  }
  close $f
}

CreateIgnoreBSR "inceptive_ignore_bsr.tcl" my_package

if {${DFT_FLOW} == "TRUE"} {
#
if {${SCAN_CHAIN} == "TRUE"} {
#set_svf ${OUTPUTS_DIR}/${DCRM_SVF_OUTPUT_FILE_DIG_TOP}
current_design dig_top
#### read sdc for block
if {[file exists [which ${BLOCK_DCRM_CONSTRAINTS_INPUT_FILE}]]} {
  puts "RM-Info: Sourcing script file [which ${BLOCK_DCRM_CONSTRAINTS_INPUT_FILE}]\n"
  source -echo -verbose ${BLOCK_DCRM_CONSTRAINTS_INPUT_FILE}
}


if {[llength all_clocks] > 0} {
    group_path -name in2reg -from [all_inputs] -to [all_clocks]
    group_path -name reg2out -to [all_outputs] -from [all_clocks]
    group_path -name reg2reg -from [all_clocks] -to [all_clocks]
}
group_path -name in2out -from [all_inputs] -to [all_outputs]
####

remove_unconnected_ports -blast_buses [get_cells -hierarchical *]
set_scan_element false [get_cells -hierarchical *nscn*] 
set_scan_element false [get_cells clk_mgmt_inst/*/*FIXED_SYNC*]
set_scan_element false [get_cells regs_inst/*/*FIXED_SYNC*]
set_scan_element false [get_cells timer_range_extension_inst/*/*FIXED_SYNC*]
set_scan_element false [get_cells lcpll_dig_top_inst/*/*/*FIXED_SYNC*]
set_scan_element false [get_cells core_fsm_top_inst/*/*FIXED_SYNC*]
set_scan_element false [get_cells input_capture_inst/*/*FIXED_SYNC*]
#set_scan_element false [get_cells output_control_inst/*/*FIXED_SYNC*]
#set_scan_element false [get_cells output_control_inst/icfd_noise_cal/*/*/*FIXED_SYNC*]
set_scan_element false [get_cells -hierarchical *in_q*] 
set_scan_element false [get_cells -hierarchical *out_dat*] 
set_scan_element false [get_cells -hierarchical *ASIC1_IO_LP_RESETN*] 
set_scan_element false [get_cells -hierarchical *TDO_TRI_STATE_B*]

set_register_type  -flip_flop DFFR_E  [get_cells -hierarchical *nscn*] 
set_register_type  -flip_flop DFFR_E  [get_cells -hierarchical *FIXED_SYNC*] 
set_register_type  -flip_flop DFFR_E  [get_cells -hierarchical *in_q*] 
set_register_type  -flip_flop DFFR_E  [get_cells -hierarchical *out_dat*] 
set_register_type  -flip_flop DFFR_E  [get_cells -hierarchical *ASIC1_IO_LP_RESETN*] 

#####set_dont_touch
set_dont_touch [get_cells -hierarchical *FIXED_SYNC*]
remove_attribute [get_cells output_control_inst/i_cal_top/*/*/*FIXED_SYNC*] dont_touch
remove_attribute [get_cells serial_comm_inst/*/*FIXED_SYNC*] dont_touch
remove_attribute [get_cells serial_comm_inst/*/*/*FIXED_SYNC*] dont_touch
remove_attribute [get_cells reset_ctrl_inst/*/*FIXED_SYNC*] dont_touch

set_dont_touch [get_cells -hierarchical *CUSTOM*]
set_dont_touch [get_cells -hierarchical *instjtag_csr_rd_wrt_b*]
set_dont_touch [get_cells -hierarchical *inst_scan_enable*]
set_dont_touch [get_cells -hierarchical *inst_clock_dr*]
set_dont_touch [get_cells -hierarchical *mux_*_mode*]
set_dont_touch [get_cells  clk_mgmt_inst/clk_gate_*_inst/clk_gate_latch_inst/inst*]
set_dont_touch [get_cells  PLL_FREF_BUF]
#compile 
# Insert mutiplexer at output port that is shared function with scan output port 
set_app_var test_mux_constant_so true
# Enable  DFT Compiler
set_dft_configuration -scan enable \
-fix_clock enable \
-fix_reset enable \
-fix_set enable 


# Define scan chain
set_scan_configuration -style multiplexed_flip_flop
set_scan_configuration -exclude_elements [get_cells -hierarchical *nscn*] 
set_scan_configuration -exclude_elements [get_cells clk_mgmt_inst/*/*FIXED_SYNC*]
set_scan_configuration -exclude_elements [get_cells regs_inst/*/*FIXED_SYNC*]
set_scan_configuration -exclude_elements [get_cells timer_range_extension_inst/*/*FIXED_SYNC*]
set_scan_configuration -exclude_elements [get_cells lcpll_dig_top_inst/*/*/*FIXED_SYNC*]
set_scan_configuration -exclude_elements [get_cells core_fsm_top_inst/*/*FIXED_SYNC*]
set_scan_configuration -exclude_elements [get_cells input_capture_inst/*/*FIXED_SYNC*]
#set_scan_configuration -exclude_elements [get_cells output_control_inst/*/*FIXED_SYNC*]
#set_scan_configuration -exclude_elements [get_cells output_control_inst/icfd_noise_cal/*/*/*FIXED_SYNC*]
set_scan_configuration -exclude_elements [get_cells -hierarchical *in_q*] 
set_scan_configuration -exclude_elements [get_cells -hierarchical *out_dat*] 
set_scan_configuration -exclude_elements [get_cells -hierarchical *ASIC1_IO_LP_RESETN*] 
set_scan_configuration -exclude_elements [get_cells -hierarchical *TDO_TRI_STATE_B*] 

set_scan_configuration -preserve_multibit_segment true
#set_scan_configuration -add_lockup true
#compile_ultra -scan -no_seq_output_inversion -no_autoungroup -no_boundary_optimization 
compile_ultra -scan -no_seq_output_inversion -no_autoungroup -no_boundary_optimization -gate_clock 
write -format verilog -hierarchy -output ${OUTPUTS_DIR}/TOP_test.v
# Define scan compression  chain
set_scan_configuration -chain_count 1 -clock_mixing mix_clocks
# Requires dedicated top-level scan output ports
set_scan_configuration -create_dedicated_scan_out_ports false


#######Lock-Up Latch Insertion Between Clock Domains######
# Disbale  lock-up latch insertion
# set_scan_configuration -add_lockup false
# Add lock-up latches at the end of each scan chain
#set_scan_configuration -insert_terminal_lockup true -add_test_retiming_flops end_only
set_scan_configuration -insert_terminal_lockup true 
# Use a lock-up flip-flop instead  level-sensitive lock-up latch
# set_scan_configuration -lockup_type flip_flop

#############################################################################
# Define new Test port
#############################################################################
if {${SHARE_TEST_FUNC} == "FALSE"} {
create_port -direction in SI 
create_port -direction out SO
create_port -direction in SCAN_ENABLE
create_port -direction in TEST_MODE
} else {
create_port -direction in TEST_MODE
create_port -direction in SET
}

#############################################################################
# Define dft signal 
#############################################################################
#############################################################################
set_app_var test_default_period 20 
set_app_var test_default_strobe 18 
#############################################################################
set_dft_signal  -view existing_dft -type ScanClock -port CLK_CORE -timing [list 5 15]
set_dft_signal  -view existing_dft -type ScanClock -port TCK_SCLOCK_IN -timing [list 5 15] -associated_internal_clocks clk_mgmt_inst/SCLOCK_IN 
set_dft_signal  -view existing_dft -type ScanClock -port LVDS_SCLOCK_OUT -timing [list 5 15]
set_dft_signal  -view existing_dft -type ScanClock -port CLK_FB_CLK -timing [list 5 15]
set_dft_signal  -view existing_dft -type Reset -port PORB -active 0
set_dft_signal  -view existing_dft -type Reset -port SET -active 0

set_dft_signal -view spec -type TestData -port CLK_CORE
set_dft_signal -view spec -type TestData -port LVDS_SCLOCK_OUT
set_dft_signal -view spec -type TestData -port CLK_FB_CLK
set_dft_signal -view spec -type TestData -port PORB -active_state 0
set_dft_signal -view spec -type TestData -port SET -active_state 0

#############################################################################
#############################################################################

if {${SHARE_TEST_FUNC} == "FALSE"} {
set_dft_signal -view spec -type ScanDataOut -port SO 
set_dft_signal -view spec -type ScanDataIn -port SI
set_dft_signal -view spec -type ScanEnable -port SCAN_ENABLE
set_dft_signal -view spec -type TestMode -port TEST_MODE -active 1
} else {
set_dft_signal -view spec -type ScanDataOut -port TDO_TO_IO -hookup_pin clk_mgmt_inst/CUSTOM_TDO_OUT/D0 
set_dft_signal -view spec -type ScanDataIn -port TDI_SCLOCK_DATA
set_dft_signal -view spec -type ScanEnable -port scan_enable -hookup_pin clk_mgmt_inst/CUSTOM_SCAN_ENABLE/Z
set_dft_signal -view spec -type TestMode -port TEST_MODE -active 1
}


set_autofix_configuration -type clock -test_data CLK_CORE  
set_autofix_configuration -type clock -test_data LVDS_SCLOCK_OUT
set_autofix_configuration -type clock -test_data CLK_FB_CLK
set_autofix_configuration -type reset -test_data PORB
set_autofix_configuration -type set -test_data SET
 
if {${BOUNDARY_SCAN} == "TRUE"} {
create_test_protocol
report_scan_configuration                  > ${REPORTS_DIR}/dig_top_${DCRM_DFT_SCAN_CONFIGURATION_REPORT}
dft_drc -verbose > ${REPORTS_DIR}/BLOCK_pre_drc.rpt
preview_dft -show all                      > ${REPORTS_DIR}/BLOCK_preview.dft
insert_dft
# Use the -show all version to preview_dft for more detailed report
dft_drc -verbose > ${REPORTS_DIR}/BLOCK_post_drc.rpt
write_scan_def -output ${OUTPUTS_DIR}/dig_top.scandef 
check_scan_def > ${REPORTS_DIR}/check_scan_def.rpt
write_test_protocol -test_mode ScanCompression_mode -output ${OUTPUTS_DIR}/dig_top_test_protocol_compression.spf
write_test_protocol -test_mode Internal_scan -output ${OUTPUTS_DIR}/dig_top_test_protocol_internal.spf

write -format verilog -hierarchy -output ${OUTPUTS_DIR}/${DESIGN_NAME}_internal_scan.v
write -hierarchy -format ddc -output ${OUTPUTS_DIR}/dig_top.ddc
write_test_model -format ddc -output ${OUTPUTS_DIR}/dig_top_test_model.ddc
write_test_model -format ctl -output ${OUTPUTS_DIR}/dig_top_test_model.ctl
}
report_scan_path -chain all > ${REPORTS_DIR}/BLOCK_SCAN_PATH_RPT.rpt

#compile_ultra -scan -incremental  -no_autoungroup -no_boundary_optimization -no_seq_output_inversion
compile_ultra -scan -incremental  -no_autoungroup -no_boundary_optimization -no_seq_output_inversion -gate_clock

write_scan_def -output ${OUTPUTS_DIR}/dig_top_after_opt.scandef 
check_scan_def > ${REPORTS_DIR}/check_scan_def_after_opt.rpt

report_timing -transition_time -nets -attributes -nosplit -group in2reg -max_path 3000  > ${REPORTS_DIR}/timing_report/dig_top_in2reg_${DCRM_FINAL_TIMING_REPORT}
report_timing -transition_time -nets -attributes -nosplit -group reg2out -max_path 3000 > ${REPORTS_DIR}/timing_report/dig_top_reg2out_${DCRM_FINAL_TIMING_REPORT}
report_timing -transition_time -nets -attributes -nosplit -group reg2reg -max_path 3000 > ${REPORTS_DIR}/timing_report/dig_top_reg2reg_${DCRM_FINAL_TIMING_REPORT}
report_timing -transition_time -nets -attributes -nosplit -group in2out -max_path 3000  > ${REPORTS_DIR}/timing_report/dig_top_in2out_${DCRM_FINAL_TIMING_REPORT}
}

#set_svf -off
#set_svf -append ${OUTPUTS_DIR}/${DCRM_SVF_OUTPUT_FILE_TOP}
if {${BOUNDARY_SCAN} == "TRUE"} {
current_design TOP

# place set_dont_touch on core and pads
set_dont_touch dig_top 
set_dont_touch [get_cells -of [get_pins -leaf -of [get_nets -of [get_ports *]]]]
set_dont_use [get_lib_cells PwcV1p40T125_STD_CELL_8HP_12T/SDFF*]  
# Read TOP SDC

# TCL script to create pin_map
proc CreatePinMap {filename package} {
  set f [open $filename "w"]
  puts $f "PACKAGE = $package;"
  set n 0
  foreach_in_collection p [get_port *] {
     incr n
     puts $f "PORT = [get_object_name $p], PIN = P$n;"
  }
  close $f
}
CreatePinMap "pin_map.txt" my_package
# Define new JTAG port
# Enable BSD Compiler
set_dft_configuration -scan disable
set_dft_configuration -bsd enable

set_dft_signal -view spec -type tdi -port TDI_SCLOCK_DATA
set_dft_signal -view spec -type tdo -port TDO_TO_IO
set_dft_signal -view spec -type tck -port TCK_SCLOCK_IN
set_dft_signal -view spec -type tms -port TMS_FROM_IO
set_dft_signal -view spec -type trst -port PORB -active_state 0

#Selecting the TAP Controller Reset Configuration
#>>Initializing the TAP with asynchronous reset using TRST
	#set_dft_signal -view spec -type trst -port my_trst
	#set_bsd_configuration -asynchronous_reset true
#>>Initializing the TAP With Asynchronous Reset Using a PUR Cell
	#set_bsd_power_up_reset -cell_name cell_name \
	-reset_pin_name pin_name -active [high | low] \
	-delay power_up_reset_delay

# Define Boundary scan
# To force BSRs on specific I/O pins using a softmacro cell modeling
# the pin function of the I/O lib cell with structural Verilog using
# standard lib cell.

#define_dft_design -type PAD -design_name PDUW16SDGZ_H_G \
 -interface {data_out C H data_in I H enable OEN L port PAD H} -params {$pad_type$ string bidirectional $lib_cell$ string false}

define_dft_design -type PAD -design_name SBUFTD16 -interface {data_in I H enable OE H port Z H} -params {$pad_type$ string tristate_output $lib_cell$ string false}
 

define_dft_design -design_name BUFFER_E -type PAD -interface {port A h data_out Z h} -params {$pad_type$ string input}

# To modify default TCK timing
set_app_var test_default_period 20 
set_app_var test_bsd_default_strobe 18

####set_app_var test_default_period 100
####set_app_var test_bsd_default_strobe 95
####set_app_var test_bsd_default_strobe_width 0
####set_app_var test_bsd_default_delay 0
####set_app_var test_bsd_default_bidir_delay 0

#set_boundary_cell -class bsd -type BC_2 -ports [remove_from_collection [all_inputs] [get_ports SCLK]]
#set_boundary_cell -class bsd -type BC_4 -ports SCLK
#set_boundary_cell -class bsd -type BC_1 -ports  [remove_from_collection [all_outputs] [get_ports TDO]]
#set_boundary_cell -class bsd -type BC_2 -ports [get_ports DIN*]
#set_boundary_cell -class bsd -type BC_1 -ports  [get_ports DOUT*]
#set_boundary_cell -class bsd -type BC_4 -ports TCK

# Avoid putting boundary-scan cells on some ports in design
source scripts/ignore_bsr.tcl

#set in_ports  [get_object_name [remove_from_collection [all_inputs] [get_ports {TCK TRST_N TDI TMS}]]]
#foreach port $in_ports {
#echo $port
#set_bsd_linkage_port -port_list {$port}
#}

#Insert the BSR chain into the existing I/O block
#set_dft_location -include {BSR} dig_top
# Insert the TAP controller into the existing core logic block
#set_dft_location -include {TAP} dig_top

read_pin_map pin_map.txt

set_bsd_configuration -ir_width 4 \
                       -check_pad_designs -all \
                       -style asynchronous \
                       -instruction_encoding binary \
                       -default_package my_package
# define JTAG instructions

###set_bsd_instruction [list EXTEST]  -code [list 0001] -reg BOUNDARY
###set_bsd_instruction [list SAMPLE]  -code [list 0100] -reg BOUNDARY
###set_bsd_instruction [list PRELOAD] -code [list 0100] -reg BOUNDARY
###set_bsd_instruction [list BYPASS]  -code [list 1111] -reg BYPASS
###set_bsd_instruction [list CLAMP] -cod [list 0010] -reg BYPASS
###set_bsd_instruction -view spec [list IDCODE] -capture_value 32'h10002045
##### Connect PORB port to dig_top/SET
connect_net PORB [get_pins {dig_top/SET}]

set_dft_signal -view spec -type capture_clk  -hookup_pin dig_top/clock_dr
set_dft_signal -view spec -type capture_clk  -hookup_pin dig_top/CLK_CORE 
set_dft_signal -view spec -type capture_clk  -hookup_pin dig_top/LVDS_SCLOCK_OUT
set_dft_signal -view spec -type capture_clk  -hookup_pin dig_top/CLK_FB_CLK
set_dft_signal -view spec -type tdi          -hookup_pin dig_top/TDI_SCLOCK_DATA
set_dft_signal -view spec -type tdo          -hookup_pin dig_top/TDO_TO_IO
set_dft_signal -view spec -type bsd_shift_en -hookup_pin dig_top/scan_enable
set_dft_signal -view spec -type bsd_run_test_idle -hookup_pin dig_top/tms_detected_jtag_mode -active_state 0
set_dft_signal -view spec -type bsd_test_logic_reset -hookup_pin dig_top/logic_reset -active_state 0

set_bsd_instruction -view spec SCAN_ATPG  -code 1101 -register dig_top_reg  -high {dig_top/TEST_MODE dig_top/scan_atpg} 
set_bsd_instruction -view spec RD_WR  -code 1001 -register dig_top_reg -high {dig_top/TEST_MODE dig_top/jtag_csr_rd_wrt}


set_scan_path dig_top_reg -class bsd -view spec \
   -hookup {dig_top/TDO_TO_IO dig_top/scan_enable dig_top/CLK_CORE  dig_top/LVDS_SCLOCK_OUT dig_top/CLK_FB_CLK } -exact_length 15000

#set_bsd_instruction -view spec SCAN_ATPG  -code 1101 -register dig_top_reg  -high {dig_top/TEST_MODE dig_top/scan_atpg} 
#set_bsd_instruction -view spec SCAN_ATPG  -code 1101 -register dig_top_reg  -high {dig_top/TEST_MODE} 
#set_bsd_instruction -view spec RD_WR  -code 1001 -register dig_top_reg -high {dig_top/TEST_MODE dig_top/jtag_csr_rd_wrt}

}
#############################################################################
# DFT Test Protocol Creation
#############################################################################
create_test_protocol
#write_test_protocol -output ${OUTPUTS_DIR}/${DESIGN_NAME}_test_protocol.spf

#############################################################################
# DFT Insertion
#############################################################################

# Use the -verbose version of dft_drc to assist in debugging if necessary

dft_drc                                
dft_drc -verbose                           > ${REPORTS_DIR}/${DCRM_DFT_DRC_CONFIGURED_VERBOSE_REPORT}
report_scan_configuration                  > ${REPORTS_DIR}/${DCRM_DFT_SCAN_CONFIGURATION_REPORT}
report_scan_compression_configuration      > ${REPORTS_DIR}/${DCRM_DFT_COMPRESSION_CONFIGURATION_REPORT}
report_dft_insertion_configuration         > ${REPORTS_DIR}/${DCRM_DFT_PREVIEW_CONFIGURATION_REPORT}

# Use the -show all version to preview_dft for more detailed report
preview_dft                                > ${REPORTS_DIR}/${DCRM_DFT_PREVIEW_DFT_SUMMARY_REPORT}
preview_dft -show all -test_points all     > ${REPORTS_DIR}/${DCRM_DFT_PREVIEW_DFT_ALL_REPORT}
####BSD check

if {${BOUNDARY_SCAN} == "TRUE"} {
preview_dft -bsd tap
preview_dft -bsd cells
preview_dft -bsd data_registers
preview_dft -bsd instructions
preview_dft -script
preview_dft -bsd all > test.rpt
}

report_scan_path -chain all > ${REPORTS_DIR}/SCAN_PATH_RPT.rpt

insert_dft

#current_test_mode Internal_scan
#current_test_mode ScanCompression_mode
if {${BOUNDARY_SCAN} == "TRUE"} {
write_test_protocol -instruction SCAN_ATPG  -output ${OUTPUTS_DIR}/${DESIGN_NAME}_dig_top_test_protocol_ATPG.spf
write_test_protocol -instruction RD_WR  -output ${OUTPUTS_DIR}/${DESIGN_NAME}_dig_top_test_protocol_RD_WR.spf
dft_drc -verbose                           > ${REPORTS_DIR}/${DESIGN_NAME}_dft_drc_autofixed_configured.rpt
## write the BSD-inserted netlist
change_names -rules verilog -hierarchy
write -format ddc -output ${OUTPUTS_DIR}/${DESIGN_NAME}_bsd.ddc -hier
write_bsdl -naming_check BSDL -output ${OUTPUTS_DIR}/${DESIGN_NAME}.bsdl
#### can write patterns after BSD insertion
create_bsd_patterns
write_test -format stil -output ${OUTPUTS_DIR}/${DESIGN_NAME}_stil
write_test -format wgl_serial -output ${OUTPUTS_DIR}/${DESIGN_NAME}_wgl_tb.wgl
write_test -format verilog -output ${OUTPUTS_DIR}/${DESIGN_NAME}_verilog_tb.v

check_bsd -verbose >  ${REPORTS_DIR}/check_bsd.log

# generate SDC for boundary-scan logic 
#source /tools/synopsys/syn_vP_2019.03_SP4/syn/P-2019.03-SP4/auxx/syn/dftc/sdcgen_bsd.tcl
source /tools/synopsys/syn_vN-2017.09-SP4/auxx/syn/dftc/sdcgen_bsd.tcl
sdcgen_bsd -check_bsd_log ${REPORTS_DIR}/check_bsd.log -chk_port_name -tck_port_name  TCK_SCLOCK_IN  -tdi_port_name  TDI_SCLOCK_DATA  -tms_port_name  TMS_FROM_IO -trst_port_name PORB  -tdo_port_name  TDO_TO_IO   -output ${OUTPUTS_DIR}/TOP_bsd.sdc 

#set_dft_signal -view spec -type tdi -port TDI_SCLOCK_DATA
#set_dft_signal -view spec -type tdo -port TDO_TO_IO
#set_dft_signal -view spec -type tck -port TCK_SCLOCK_IN
#set_dft_signal -view spec -type tms -port TMS_FROM_IO
#set_dft_signal -view spec -type trst -port PORB -active_state 0

 
}
##check_bsd -verbose -infer_instructions true
# using the same commands.

write -format verilog -hierarchy -output ${OUTPUTS_DIR}/${DESIGN_NAME}_DFT.v
#################################################################################
# Re-create Default Path Groups
#
# In case of ports being created during insert_dft they need to be added
# to those path groups.
# Separating these paths can help improve optimization.
#################################################################################
#if {[file exists [which ${DCRM_CONSTRAINTS_INPUT_FILE}]]} {
#  puts "RM-Info: Sourcing script file [which ${DCRM_CONSTRAINTS_INPUT_FILE}]\n"
#  source -echo -verbose ${DCRM_CONSTRAINTS_INPUT_FILE}
#}
#
#set ports_clock_root [filter_collection [get_attribute [get_clocks] sources] object_class==port]
#group_path -name REGOUT -to [all_outputs]
#group_path -name REGIN -from [remove_from_collection [all_inputs] ${ports_clock_root}]
#group_path -name FEEDTHROUGH -from [remove_from_collection [all_inputs] ${ports_clock_root}] -to [all_outputs]

#set_svf -append ${OUTPUTS_DIR}/${DCRM_SVF_OUTPUT_FILE_DIG_TOP}
#################################################################################
# DFT Incremental Compile
# Only required if scan chain insertion has been performed.
#compile_ultra -scan -incremental  -no_autoungroup -no_boundary_optimization -no_seq_output_inversion 
compile_ultra -scan -incremental  -no_autoungroup -no_boundary_optimization -no_seq_output_inversion -gate_clock
} else {
#compile_ultra   -no_autoungroup -no_boundary_optimization -no_seq_output_inversion
compile_ultra   -no_autoungroup -no_boundary_optimization -no_seq_output_inversion -gate_clock
}
# High-effort area optimization
#
# optimize_netlist -area command, was introduced in I-2013.12 release to improve
# area of gate-level netlists. The command performs monotonic gate-to-gate 
# optimization on mapped designs, thus improving area without degrading timing or
# leakage. 
#################################################################################
set_max_area 0
#not licensed for 'DC-Ultra-Opt'
#optimize_netlist -area

#################################################################################
# Write Out Final Design and Reports
#
#        .ddc:   Recommended binary format used for subsequent Design Compiler sessions
#    Milkyway:   Recommended binary format for IC Compiler
#        .v  :   Verilog netlist for ASCII flow (Formality, PrimeTime, VCS)
#       .spef:   Topographical mode parasitics for PrimeTime
#        .sdf:   SDF backannotated topographical mode timing for PrimeTime
#        .sdc:   SDC constraints for ASCII flow
#
#################################################################################
#licensed for 'DC-Extension'
#write_icc2_files -force  -output ${OUTPUTS_DIR}/${DCRM_FINAL_DESIGN_ICC2}

#set bus_inference_style {%s[%d]}
#set bus_naming_style {%s[%d]}
#set hdlout_internal_busses true
change_names -hierarchy -rule verilog -verbose                                                                                                                                                                                                                                                                                       
#define_name_rules name_rule -allowed "A-Z a-z 0-9 _" -max_length 255 -type cell
#define_name_rules name_rule -allowed "A-Z a-z 0-9 _[]" -max_length 255 -type net
#define_name_rules name_rule -case_insensitive
#change_names -hierarchy -rules name_rule -verbose

#################################################################################
# Write out Design
#################################################################################

write -format verilog -hierarchy -output ${OUTPUTS_DIR}/${DCRM_FINAL_VERILOG_OUTPUT_FILE}

write -format ddc     -hierarchy -output ${OUTPUTS_DIR}/${DCRM_FINAL_DDC_OUTPUT_FILE}


# Write and close SVF file and make it available for immediate use
set_svf -off
set_vsdc -off

#################################################################################
# Write out Design Data
#################################################################################

if {[shell_is_in_topographical_mode]} {

  # Note: A secondary floorplan file ${DCRM_DCT_FINAL_FLOORPLAN_OUTPUT_FILE}.objects
  #       might also be written to capture physical-only objects in the design.
  #       This file should be read in before reading the main floorplan file.

  write_floorplan -all ${OUTPUTS_DIR}/${DCRM_DCT_FINAL_FLOORPLAN_OUTPUT_FILE}

  # If the DCRM_DCT_SPG_PLACEMENT_OUTPUT_FILE variable has been set in dc_setup_filenames.tcl
  # file then the standard cell physical guidance is being created to support SPG ASCII hand-off
  # to IC Compiler by the write_def command.
  # Invoking write_def commands requires a Design Compiler Graphical license or an IC Compiler
  # Design Planning license.

  if {[info exists DCRM_DCT_SPG_PLACEMENT_OUTPUT_FILE]} {
    write_def -components -output ${OUTPUTS_DIR}/${DCRM_DCT_SPG_PLACEMENT_OUTPUT_FILE}
  }

  # Write parasitics data from Design Compiler Topographical placement for static timing analysis
  write_parasitics -output ${OUTPUTS_DIR}/${DCRM_DCT_FINAL_SPEF_OUTPUT_FILE}

  # Write SDF backannotation data from Design Compiler Topographical placement for static timing analysis
  write_sdf ${OUTPUTS_DIR}/${DCRM_DCT_FINAL_SDF_OUTPUT_FILE}

  # Do not write out net RC info into SDC
  set_app_var write_sdc_output_lumped_net_capacitance false
  set_app_var write_sdc_output_net_resistance false
}

write_sdc -nosplit ${OUTPUTS_DIR}/${DCRM_FINAL_SDC_OUTPUT_FILE}

# If SAIF is used, write out SAIF name mapping file for PrimeTime-PX
# saif_map -type ptpx -write_map ${OUTPUTS_DIR}/${DESIGN_NAME}.mapped.SAIF.namemap

#################################################################################
# Generate Final Reports
#################################################################################

report_qor > ${REPORTS_DIR}/${DCRM_FINAL_QOR_REPORT}

# Create a QoR snapshot of timing, physical, constraints, clock, power data, and routing on 
# active scenarios and stores it in the location  specified  by  the icc_snapshot_storage_location 
# variable. 

if {[shell_is_in_topographical_mode]} {
  set icc_snapshot_storage_location ${REPORTS_DIR}/${DCRM_DCT_FINAL_QOR_SNAPSHOT_FOLDER}
  create_qor_snapshot -name ${DCRM_DCT_FINAL_QOR_SNAPSHOT_REPORT} > ${REPORTS_DIR}/${DCRM_DCT_FINAL_QOR_SNAPSHOT_REPORT}
}

report_timing -transition_time -nets -attributes -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_TIMING_REPORT}

#foreach_in_collection grp [reg2reg in2reg reg2out in2out]  {
#      report_timing -group $grp -max_path 3000 > ${REPORTS_DIR}/${grp}.rpt
#} 

report_timing -transition_time -nets -attributes -nosplit -group in2reg -max_path 3000  > ${REPORTS_DIR}/timing_report/in2reg_${DCRM_FINAL_TIMING_REPORT}
report_timing -transition_time -nets -attributes -nosplit -group reg2out -max_path 3000 > ${REPORTS_DIR}/timing_report/reg2out_${DCRM_FINAL_TIMING_REPORT}
report_timing -transition_time -nets -attributes -nosplit -group reg2reg -max_path 3000 > ${REPORTS_DIR}/timing_report/reg2reg_${DCRM_FINAL_TIMING_REPORT}
report_timing -transition_time -nets -attributes -nosplit -group in2out -max_path 3000  > ${REPORTS_DIR}/timing_report/in2out_${DCRM_FINAL_TIMING_REPORT}

if {[shell_is_in_topographical_mode]} {
  report_area -physical -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_AREA_REPORT}
} else {
  report_area -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_AREA_REPORT}
}

if {[shell_is_in_topographical_mode]} {
  # report_congestion (topographical mode only) uses zroute for estimating and reporting 
  # routing related congestion which improves the congestion correlation with IC Compiler.
  # Design Compiler Topographical supports create_route_guide command to be consistent with IC
  # Compiler after topographical mode synthesis.
  # Those commands require a license for Design Compiler Graphical.

  report_congestion > ${REPORTS_DIR}/${DCRM_DCT_FINAL_CONGESTION_REPORT}

  # Use the following to generate and write out a congestion map from batch mode
  # This requires a GUI session to be temporarily opened and closed so a valid DISPLAY
  # must be set in your UNIX environment.

  if {[info exists env(DISPLAY)]} {
    gui_start

    # Create a layout window
    set MyLayout [gui_create_window -type LayoutWindow]

    # Build congestion map in case report_congestion was not previously run
    report_congestion -build_map

    # Display congestion map in layout window
    gui_show_map -map "Global Route Congestion" -show true

    # Zoom full to display complete floorplan
    gui_zoom -window [gui_get_current_window -view] -full

    # Write the congestion map out to an image file
    # You can specify the output image type with -format png | xpm | jpg | bmp

    # The following saves only the congestion map without the legends
    gui_write_window_image -format png -file ${REPORTS_DIR}/${DCRM_DCT_FINAL_CONGESTION_MAP_OUTPUT_FILE}

    # The following saves the entire congestion map layout window with the legends
    gui_write_window_image -window ${MyLayout} -format png -file ${REPORTS_DIR}/${DCRM_DCT_FINAL_CONGESTION_MAP_WINDOW_OUTPUT_FILE}

    gui_stop
  } else {
    puts "Information: The DISPLAY environment variable is not set. Congestion map generation has been skipped."
  }
}

# Use SAIF file for power analysis
# read_saif -auto_map_names -input ${DESIGN_NAME}.saif -instance < DESIGN_INSTANCE > -verbose
report_power -cell  -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_POWER_REPORT_GATE}
report_power -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_POWER_REPORT}
report_clock_gating -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_CLOCK_GATING_REPORT}

# Uncomment the next line if you include the -self_gating to the compile_ultra command
# to report the XOR Self Gating information.
# report_self_gating  -nosplit > ${REPORTS_DIR}/${DCRM_FINAL_SELF_GATING_REPORT}

# Uncomment the next line to reports the number, area, and  percentage  of cells 
# for each threshold voltage group in the design.
# report_threshold_voltage_group -nosplit > ${REPORTS_DIR}/${DCRM_THRESHOLD_VOLTAGE_GROUP_REPORT}

#################################################################################
# Write out Milkyway Design for Top-Down Flow
#
# This should be the last step in the script
#################################################################################

if {[shell_is_in_topographical_mode]} {
  # write_milkyway uses mw_design_library variable from dc_setup.tcl
  write_milkyway -overwrite -output ${DCRM_FINAL_MW_CEL_NAME}
}

#exit
