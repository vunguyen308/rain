
##################################################################
# TetraMAX Reference Methodology Main Script                     #
# Script: tmax.tcl                                               #
# Version: M-2016.12 (January 9, 2017)                           #
# Copyright (C) 2008-2017 Synopsys, Inc. All rights reserved.    #
##################################################################

# Option Name:  Setting
# =====================
# ATPG Engine:  TETRAMAX
# Transition Delay:  TRUE
# Stuck-at Testing:  TRUE
# Dynamic Bridging:  FALSE
# Static Bridging:  FALSE
# Path Delay:  FALSE
# Power-Aware ATPG:  FALSE
# On-Chip Clocking:  FALSE
# DFTMAX Ultra Compression:  FALSE
# Protocol Creation:  FALSE
# Lynx-Compatible:  FALSE

##################################################################
#    SETUP: Settings for overall execution                       #
##################################################################

# Log file name is hard-coded to capture setup values. Change the name if desired.
set_messages -log tmax.log -replace
report_version -full
set TMAX_SCRIPTS_ROOT "./rm_tmax_scripts"
set TMAX_SETUP_ROOT "./rm_setup"
source -echo ${TMAX_SETUP_ROOT}/tmax_setup.tcl
if { $TMAX_DEBUG_MODE } {
   set_messages -level expert
}
if { $TMAX_COMPRESSION_MODE } {
   set tmax_file_ext comp
} else {
   set tmax_file_ext scan
}
if { $TMAX_NUM_PROCS > 1 } {
   set_atpg -num_processes $TMAX_NUM_PROCS
   set_simulation -num_processes $TMAX_NUM_PROCS
}
# Source tmax2pt.tcl which will be used later.
#source $env(SYNOPSYS)/auxx/syn/tmax/tmax2pt.tcl
#alias stil2Verilog 'setenv SYNOPSYS /tools/synopsys/tetramax_vN-2017.09-SP5-2; $SYNOPSYS/bin/stil2verilog' 
#alias stil2Verilog 'setenv SYNOPSYS /tools/synopsys/tetramax_vN-2017.09-SP5-2/bin/stil2verilog' 

#source /tools/synopsys/TetraMAX-M-2016.12-SP2/auxx/syn/tmax/tmax2pt.tcl
source /tools/synopsys/tetramax_vN-2017.09-SP5-2/auxx/syn/tmax/tmax2pt.tcl

# Uncomment if you want the run to continue if errors are encountered.
#set_commands noabort

# If you have rules to downgrade (with or without masking),
# add them to the variable definitions in tmax_setup.tcl.
if { $RULES_TO_DOWNGRADE != "" } {
   foreach tmax_rule $RULES_TO_DOWNGRADE {
      set_rules $tmax_rule warning
      report_rules $tmax_rule
   }
}
if { $RULES_TO_MASK != "" } {
   foreach tmax_rule $RULES_TO_MASK {
      set_rules $tmax_rule warning -mask
      report_rules $tmax_rule
   }
}

##################################################################
#    Define global variables for both DRC runs                   #
##################################################################

# This setting is needed for Dual STIL Flow parallel simulation.
# It is not needed for parallel simulation using default STIL patterns,
# and using it reduces test coverage.
#set_drc -noshadows
#set_drc -serial_shadows_only

# These settings allow ATPG to use nonscan cell values loaded by the last shift.
# Fault simulation can use more shifts, but ATPG can only use 1 shift,
# and write_timing_constraints can only write checks for 1 shift.
# These settings are not compatible with Dual STIL Flow parallel simulation.
set_drc -load_nonscan_cells
set_simulation -shift_cycles 1
set_drc -trace
# If there are Z1 violations when loadable nonscan cells are used,
# this may be needed to resolve them:
#set_drc -deterministic_z1check

# Use this setting if there are internally-generated asynchronous resets.
#set_drc -allow_unstable_set_resets

# This additional setting is needed if M404 warnings are printed when
# using write_patterns -format stil99 (not with -format stil).
#set_drc -nodslave_remodel -noreclassify_invalid_dslaves

# If run_simulation finds mismatches, use this setting to prevent them.
# Don't set this normally because runtime is much longer.
set_atpg -resim_atpg_patterns fault_sim

# Use this setting to prevent multiload patterns, which increase coverage
# but are expensive in terms of test time and test data volume.
#set_atpg -single_load_per_pattern

# Merge effort
set_atpg -merge high
set_atpg -coverage 100
#set_atpg -patterns 1000
#set_atpg -chain_test off

# This setting prevents pipeline scan data registers from capturing known
# values during capture cycles, which can cause parallel-load simulation
# mismatches.
set_simulation -nopipeline_cells

if { $TMAX_DEBUG_MODE } {
   set_drc -store_setup
   set_simulation -progress_message 10
   if { $TMAX_COMPRESSION_MODE } {
      set_drc -compressor_debug_data
   }
}

# These settings allow more flexible use of fault lists.
set_faults -summary verbose -noequiv_code
# These settings give pessimistic reports, but the information can be useful.
#set_faults -fault_coverage -pt_credit 0

##################################################################
#    BUILD: Read in and build the design                         #
##################################################################

# If two definitions of a module are read, last one read is used.
set_netlist -redefined_module last

# If you have modules with no TMAX models, add them to the variable definition in tmax_setup.tcl.
# The -empty_box switch may be better if tristate buses are involved.
if { $MODULES_TO_BLACK_BOX != "" } {
   foreach module $MODULES_TO_BLACK_BOX {
      set_build -black_box $module
   }
}
if { $MODULES_TO_EMPTY_BOX != "" } {
   foreach module $MODULES_TO_BLACK_BOX {
      set_build -empty_box $module
   }
}
# If you have PLL sources coming from modeled instances, add them to the variable definition in tmax_setup.tcl.
if { $INSTANCES_TO_BLACK_BOX != "" } {
   foreach inst $INSTANCES_TO_BLACK_BOX {
      set_build -instance_modify [list $inst TIEX ]
   }
}

# This variable must be defined in tmax_setup.tcl, as there is no default.
foreach tmax_library $TMAX_LIBRARY_FILES {
   read_netlist $tmax_library -library
}
# The default design netlist is the DC-RM output.
# If you are not using the DC-RM, change the variable in tmax_setup.tcl.
foreach tmax_netlist $NETLIST_FILES {
   read_netlist $tmax_netlist
}

run_build_model $DESIGN_NAME

#########################################################################
##    TD_DRC: Run DRC for Transition-Delay and/or Dynamic Bridging Test #
#########################################################################
#
## These are the most common transition delay settings.
#set_delay -launch_cycle system_clock -nopi_changes -common_launch_capture_clock
#add_po_masks -all
#add_slow_bidis -all
#
## Set constraints on the Primary Inputs (top-level inputs) here.
## Normally scan enables and resets must be inactive when testing transition delay faults.
## All scan enables and resets must be inactive for Power-Aware ATPG.
## Uncomment with proper port names and off states.
#add_pi_constraints 1 RSTN
##add_pi_constraints 1 reset_n
##add_pi_constraints 0 <input_port>
#
#add_pi_constraint 1 burnin
#add_pi_constraint 1 vdda
#add_pi_constraint 1 vddp
#add_pi_constraint 0 vssa
#add_pi_constraint 0 vssp
#for {set i 0} {$i < 10} {incr i} {
#    add_pi_constraint 0 str[$i]
#}
## The timing exceptions flow works best when the set_case_analysis matches the
## TMAX DRC clocking. If this is not the case, change the environment to
## "sdc_case_analysis".
#set_sdc -environment tmax_drc
#if { $TMAX_DEBUG_MODE } {
#   set_sdc -mark_gui_gates -verbose
#   foreach sdc_file $EXCEPTION_FILES {
#      if { [file exists ${sdc_file}] } {
#         read_sdc -echo $sdc_file
#      } else {
#         puts "RM-Info: SDC file ${sdc_file} was not found. Timing exceptions from other defined SDC files will still be used.\n"
#      }
#   }
#} else {
#   foreach sdc_file $EXCEPTION_FILES {
#      if { [file exists ${sdc_file}] } {
#         read_sdc $sdc_file
#      } else {
#         puts "RM-Info: SDC file ${sdc_file} was not found. Timing exceptions from other defined SDC files will still be used.\n"
#      }
#   }
#}
#
## To update waveform timing, uncomment and edit the script as needed:
##source -echo -verbose ${TMAX_SCRIPTS_ROOT}/tmax_update_spf.tcl
#
#report_settings drc
#if { $TMAX_DEBUG_MODE } {
#   report_settings -all > ${REPORTS_DIR}/${DESIGN_NAME}_trans_drc_settings.${tmax_file_ext}.rpt
#}
#
## The default STIL protocol file is the DC-RM output.
## If you are not using the DC-RM, change the variable in tmax_setup.tcl.
#run_drc $PROTOCOL_FILE
#
## Writing the image file speeds up subsequent ATPG or diagnosis runs.
#write_image ${RESULTS_DIR}/${DESIGN_NAME}_trans.${tmax_file_ext}.img -replace -violations -netlist_data -design_view
#
#report_clocks -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_trans_clocks.${tmax_file_ext}.rpt
#report_clocks -matrix >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_clocks.${tmax_file_ext}.rpt
#report_sdc -all_paths > ${REPORTS_DIR}/${DESIGN_NAME}_trans_exceptions.${tmax_file_ext}.rpt
#
## These reports are for loadable nonscan cells:
#echo "Loadable nonscan cells:" > ${REPORTS_DIR}/${DESIGN_NAME}_trans_nonscan_loading.${tmax_file_ext}.rpt
#report_nonscan_cells load >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_nonscan_loading.${tmax_file_ext}.rpt
#echo "Non-X loadable nonscan cells:" >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_nonscan_loading.${tmax_file_ext}.rpt
#report_nonscan_cells nonx_load >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_nonscan_loading.${tmax_file_ext}.rpt
## This returns an error unless set_simulation -shift_cycles > 0
##analyze_nonscan_loading >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_nonscan_loading.${tmax_file_ext}.rpt
#
## This report is useful for setting a power budget.
##report_clocks -gating > ${REPORTS_DIR}/${DESIGN_NAME}_trans_clockgating.${tmax_file_ext}.rpt
#if { $TMAX_DEBUG_MODE } {
#   report_scan_cells -all -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_trans_scan_cells.${tmax_file_ext}.rpt
#   report_nonscan_cells -unique > ${REPORTS_DIR}/${DESIGN_NAME}_trans_nonscan_cells.${tmax_file_ext}.rpt
#   # These are the most common report_lockup_latches switches:
#   report_lockup_latches -gated_clocking -latch_based_balanced -pipeline > ${REPORTS_DIR}/${DESIGN_NAME}_trans_lockup_latches.${tmax_file_ext}.rpt
#   if { $TMAX_COMPRESSION_MODE } {
#      report_compressors -all -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_trans_compressors.${tmax_file_ext}.rpt
#   }
#}
#
## Capture cycles for dynamic testing must be at least 2,
## and should be enough to test through memories.
#set_atpg -capture_cycles 4
#set_patterns -histogram_summary
#
## Settings for Power-Aware ATPG
##
## The power budget should be set based on ATE requirements. Do not set the
## power budget to a number less than the minimum recommened on the last line
## of the report_clocks -gating report.
##set_atpg -power_budget 40 -calculate_power
## Uncomment to reduce shift power at the expense of pattern count.
##set_atpg -fill adjacent -shift_power_effort medium
## This chain test pattern allows full diagnostics with minimum power.
##set_atpg -chain_test 001100110011C
## High power effort can reduce test coverage (see the online help).
##set_atpg -power_effort high
#if { $TMAX_DEBUG_MODE } {
#   set_atpg -verbose
#}
## After all ATPG settings are made, write constraints for PrimeTime.
## Use -unit ps if you have used update_scale on the waveform tables.
##write_timing_constraints ${RESULTS_DIR}/${DESIGN_NAME}_trans_capture.${tmax_file_ext}.tcl -mode capture -replace -wft _allclock_launch_WFT_ -wft _allclock_capture_WFT_
##write_timing_constraints ${RESULTS_DIR}/${DESIGN_NAME}_trans_shift.${tmax_file_ext}.tcl -mode shift -replace -only_constrain_scanouts
#
## If you are only running TetraMAX to get PrimeTime constraints, quit here.
##quit
#
## Add faults for all fault models to be used for ATPG.
#set_faults -persistent_fault_models
#set_faults -model transition
#add_faults -all
#report_summaries faults
#set_faults -model stuck
#add_faults -all
#report_summaries faults
#
## Use Slack-Based Transition Fault Testing if a global slack file exists.
## The max_tmgn and max_delta_per_fault numbers here are good starting values.
## Change them to design-specific values for later runs.
#if { [file exists ${GLOBAL_SLACK_FILE}] } {
#   puts "RM-Info: Global Slack File will be used for Transition Delay Fault testing.\n"
#   set_faults -model transition
#   if { $TMAX_DEBUG_MODE } {
#      # This method is needed to capture all missing slack messages.
#      read_timing ${GLOBAL_SLACK_FILE} -delete -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_trans_m663.${tmax_file_ext}.rpt
#   } else {
#      read_timing ${GLOBAL_SLACK_FILE} -delete
#   }
## The starting point for max_tmgn is 30% of the fault list,
## and for max_delta_per_fault is zero.
#   set_delay -max_tmgn 30%
#   set_delay -max_delta_per_fault 0
#} else {
#   puts "RM-Info: Global Slack File not found. Transition Delay Fault testing will not use slacks.\n"
#}
#
###################################################################
##    TD_ATPG: Create Patterns for Transition-Delay Test          #
###################################################################
#
#set_faults -model transition
#
#set_atpg -abort_limit 10
#report_settings atpg
#report_settings simulation
#report_settings delay
#if { $TMAX_DEBUG_MODE } {
#   report_settings -all > ${REPORTS_DIR}/${DESIGN_NAME}_trans_atpg_settings.${tmax_file_ext}.rpt
#}
#
#if { $TMAX_OPTIMIZE_PATTERNS } {
#   run_atpg -optimize_patterns
#
#   # Optimize patterns runs two-clock ATPG only. Use fast sequential ATPG
#   # to generate patterns for logic around memories or other nonscan cells.
#   run_atpg fast_sequential_only -auto_compression
#
#   # Additional runs with increased abort limits may improve coverage
#   #set_atpg -abort_limit 100
#   #run_atpg fast_sequential_only -auto_compression
#   #set_atpg -abort_limit 1000
#   #run_atpg fast_sequential_only -auto_compression
#
#} else {
#   # Standard ATPG run for debug or finding coverage limits.
#   run_atpg -auto_compression
#
#   # Additional runs with increased abort limits may improve coverage
#   #set_atpg -abort_limit 100
#   #run_atpg -auto_compression
#   #set_atpg -abort_limit 1000
#   #run_atpg -auto_compression
#}
#
## Check simulation results of patterns in debug mode only.
#if { $TMAX_DEBUG_MODE } {
#   run_simulation
#}
#write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_trans.${tmax_file_ext}.bin.gz -format binary -replace -compress gzip
## If you need patterns in the 1999 version of STIL, instead of the default
## 2005 version, change to -format stil99 and remove -cellnames type.
## You may also need to change DRC settings.
#write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_trans.${tmax_file_ext}.stil.gz -format stil -replace -compress gzip -cellnames type
##
## This setting is required to run write_testbench in batch mode:
#setenv LTRAN_SHELL 1
#write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_trans.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_trans.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_trans.${tmax_file_ext}.maxtb.log "
##
## This testbench may be used for both parallel and serial simulation.
## The default is parallel - modify the VCS script to run serial.
## Simulating all serial patterns may take excessive runtime.
## To serially simulate only patterns 0 to 10, modify the DEFINES line
## of the VCS script to read:
## DEFINES="+define+tmax_serial+tmax_n_pattern_sim=10" 
##
## Uncomment the following commands to use the Dual STIL Flow,
## which also requires changes to the DRC settings earlier in the script.
##
## Multicore simulation is not reliable for write_patterns
##set_simulation -num_processes 0
##write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_trans_ser.${tmax_file_ext}.stil.gz -format stil -serial -replace -compress gzip
##write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_trans_par.${tmax_file_ext}.stil.gz -format stil -nounified_stil_flow -parallel -replace -compress gzip -cellnames type
##setenv LTRAN_SHELL 1
##write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_trans_ser.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_trans_ser.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_trans_ser.${tmax_file_ext}.maxtb.log "
##write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_trans_par.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_trans_par.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_trans_par.${tmax_file_ext}.maxtb.log "
##if { $TMAX_NUM_PROCS > 1 } {
##   set_simulation -num_processes $TMAX_NUM_PROCS
##}
##
#write_faults ${RESULTS_DIR}/${DESIGN_NAME}_trans_post.${tmax_file_ext}.faults.gz -all -replace -compress gzip
#
#report_patterns -all -types > ${REPORTS_DIR}/${DESIGN_NAME}_trans_pat_types.${tmax_file_ext}.rpt
#report_summaries faults patterns cpu_usage memory_usage > ${REPORTS_DIR}/${DESIGN_NAME}_trans_summaries.${tmax_file_ext}.rpt
#if { [file exists ${GLOBAL_SLACK_FILE}] } {
#   report_faults -slack effectiveness > ${REPORTS_DIR}/${DESIGN_NAME}_trans_slack_based.${tmax_file_ext}.rpt
#   report_faults -slack tmgn 50 >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_slack_based.${tmax_file_ext}.rpt
#   report_faults -slack tdet 50 >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_slack_based.${tmax_file_ext}.rpt
#   report_faults -slack delta 50 >> ${REPORTS_DIR}/${DESIGN_NAME}_trans_slack_based.${tmax_file_ext}.rpt
#}
#
## Report for Power-Aware ATPG results
##report_power -per_pattern -percentage > ${REPORTS_DIR}/${DESIGN_NAME}_trans_power.${tmax_file_ext}.rpt
#
#if { !($TMAX_DIRECT_CREDIT) } {
#   set_faults -model stuck
#   run_fault_sim
#   report_summaries faults
#}

##################################################################
#    SA_DRC: Run DRC for Stuck-At and/or Static Bridging Test    #
##################################################################

drc -force
remove_atpg_constraints -all
remove_capture_masks -all
remove_cell_constraints -all
remove_clocks -all
remove_compressors -all
remove_pi_constraints -all
remove_po_masks -all
remove_scan_chains -all
remove_scan_enables -all
remove_slow_bidis -all
remove_slow_cells -all

add_slow_bidis -all
#just for fun, MUST REMOVE
#add_pi_constraint 1 TRST_N
#set_rules C39 warning

#add_clock 0 TCK_SCLOCK_IN
#set_drc -controller_clock TCK_SCLOCK_IN
add_clock 0 TCK
set_drc -controller_clock TCK
set_drc -initialize_dff_dlat 0
#set_drc -clock -seq_capture
# Set constraints on the Primary Inputs (top-level inputs) here.
# Normally scan enables and resets need no constraints when testing stuck-at faults.
# All scan enables and resets must be inactive for Power-Aware ATPG.
# Uncomment with proper port names and off states.

# To use SDC timing exceptions for static (stuck-at and/or static bridging)
# fault ATPG, uncomment this line:
#set_simulation -timing_exceptions_for_stuck_at

# If SDC timing exceptions were used earlier, they do not need to be read again.
# If different exceptions, or a different -hold setting, are used,
# then the old exceptions must be removed before reading new ones.
#remove_sdc -all
#set_sdc -environment tmax_drc
#if { $TMAX_DEBUG_MODE } {
#   set_sdc -mark_gui_gates -verbose
#   foreach sdc_file $EXCEPTION_FILES {
#      read_sdc -echo $sdc_file
#   }
#} else {
#   foreach sdc_file $EXCEPTION_FILES {
#      read_sdc $sdc_file
#   }
#}

report_settings drc
if { $TMAX_DEBUG_MODE } {
   report_settings -all > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_drc_settings.${tmax_file_ext}.rpt
}

# The default STIL protocol file is the DC-RM output.
# If you are not using the DC-RM, change the variable in tmax_setup.tcl.
#run_drc $PROTOCOL_FILE > reports/TOP_stuck_drc.scan.rpt
run_drc $PROTOCOL_FILE
# HERE
# Writing the image file speeds up subsequent ATPG or diagnosis runs.
write_image ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.img -replace -violations -netlist_data -design_view

report_scan_cells -all
report_clocks -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_clocks.${tmax_file_ext}.rpt
report_clocks -matrix >> ${REPORTS_DIR}/${DESIGN_NAME}_stuck_clocks.${tmax_file_ext}.rpt
report_sdc -all_paths > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_exceptions.${tmax_file_ext}.rpt

# These reports are for loadable nonscan cells:
echo "Loadable nonscan cells:" > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_nonscan_loading.${tmax_file_ext}.rpt
report_nonscan_cells load >> ${REPORTS_DIR}/${DESIGN_NAME}_stuck_nonscan_loading.${tmax_file_ext}.rpt
echo "Non-X loadable nonscan cells:" >> ${REPORTS_DIR}/${DESIGN_NAME}_stuck_nonscan_loading.${tmax_file_ext}.rpt
report_nonscan_cells nonx_load >> ${REPORTS_DIR}/${DESIGN_NAME}_stuck_nonscan_loading.${tmax_file_ext}.rpt
# This returns an error unless set_simulation -shift_cycles > 0
#analyze_nonscan_loading >> ${REPORTS_DIR}/${DESIGN_NAME}_stuck_nonscan_loading.${tmax_file_ext}.rpt

# This report is useful for setting a power budget.
#report_clocks -gating > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_clockgating.${tmax_file_ext}.rpt
if { $TMAX_DEBUG_MODE } {
   report_scan_cells -all -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_scan_cells.${tmax_file_ext}.rpt
   report_nonscan_cells -unique > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_nonscan_cells.${tmax_file_ext}.rpt
   # These are the most common report_lockup_latches switches:
   report_lockup_latches -gated_clocking -latch_based_balanced -pipeline > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_lockup_latches.${tmax_file_ext}.rpt
   if { $TMAX_COMPRESSION_MODE } {
      report_compressors -all -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_compressors.${tmax_file_ext}.rpt
   }
}

# Capture cycles for static testing should be enough to test through memories.
set_atpg -capture_cycles 2 
#set_atpg -full_seq_atpg
set_patterns -histogram_summary

# Settings for Power-Aware ATPG
#
# The power budget should be set based on ATE requirements. Do not set the
# power budget to a number less than the minimum recommened on the last line
# of the report_clocks -gating report.
#set_atpg -power_budget 40 -calculate_power
# Uncomment to reduce shift power at the expense of pattern count.
#set_atpg -fill adjacent -shift_power_effort medium
# This chain test pattern allows full diagnostics with minimum power.
#set_atpg -chain_test 001100110011C
# High power effort can reduce test coverage (see the online help).
#set_atpg -power_effort high
if { $TMAX_DEBUG_MODE } {
   set_atpg -verbose
}
# After all ATPG settings are made, write constraints for PrimeTime.
# Use -unit ps if you have used update_scale on the waveform tables.
write_timing_constraints ${RESULTS_DIR}/${DESIGN_NAME}_stuck_capture.${tmax_file_ext}.tcl -mode capture -replace
write_timing_constraints ${RESULTS_DIR}/${DESIGN_NAME}_stuck_shift.${tmax_file_ext}.tcl -mode shift -replace -only_constrain_scanouts

##################################################################
#    SA_ATPG: Create Patterns for Stuck-At Fault Test            #
##################################################################

set_faults -model stuck
add_fault -all
#add_fault dig_top
#add_fault TOP_inst
#remove_faults -module level_sync.*
#remove_faults -module pulse_sync.*
#source -echo ${TMAX_SCRIPTS_ROOT}/remove_faults.tcl

if { $TMAX_DIRECT_CREDIT } {
   update_faults -direct_credit
   report_summaries faults
}

set_atpg -abort_limit 1000
report_settings atpg
report_settings simulation
if { $TMAX_DEBUG_MODE } {
   report_settings -all > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_atpg_settings.${tmax_file_ext}.rpt
}

#if { $TMAX_OPTIMIZE_PATTERNS } {
#   run_atpg -optimize_patterns
#
#   # Optimize patterns runs two-clock ATPG only. Use fast sequential ATPG
#   # to generate patterns for logic around memories or other nonscan cells.
#    run_atpg fast_sequential_only -auto_compression
##   run_atpg full_sequential_only -auto_compression
#
#   # Additional runs with increased abort limits may improve coverage
#   #set_atpg -abort_limit 100
#   #run_atpg fast_sequential_only -auto_compression
#   #set_atpg -abort_limit 1000
#   #run_atpg fast_sequential_only -auto_compression
#
#} else {
   # Standard ATPG run for debug or finding coverage limits.
#   run_atpg -auto_compression

   # Additional runs with increased abort limits may improve coverage
#  set_atpg -abort_limit 100
#run_atpg -auto_compression
run_atpg -auto_compression basic_scan_only
#analyze_test_points -target fault_class -test_points_file tp_file_a -replace
#run_atpg -auto_compression -observe_file tp_file_a
#run_atpg -auto_compression basic_scan_only -observe_file tp_file_a
#}

# Check simulation results of patterns in debug mode only.
if { $TMAX_DEBUG_MODE } {
   run_simulation
}
#write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.bin.gz -format binary -replace -compress gzip
## If you need patterns in the 1999 version of STIL, instead of the default
## 2005 version, change to -format stil99 and remove -cellnames type.
## You may also need to change DRC settings.
write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.stil.gz -format stil -replace -compress gzip -cellnames type
##
## This setting is required to run write_testbench in batch mode:
setenv LTRAN_SHELL 1
write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.maxtb.log "

#stil2Verilog  ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.stil.gz maxtb -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -replace
#stil2Verilog -input ${RESULTS_DIR}/${DESIGN_NAME}_stuck.${tmax_file_ext}.stil.gz -failing_cell_report simv.log -log new_simv.log
#

# This testbench may be used for both parallel and serial simulation.
# The default is parallel - modify the VCS script to run serial.
# Simulating all serial patterns may take excessive runtime.
# To serially simulate only patterns 0 to 10, modify the DEFINES line
# of the VCS script to read:
# DEFINES="+define+tmax_serial+tmax_n_pattern_sim=10" 
#
# Uncomment the following commands to use the Dual STIL Flow,
# which also requires changes to the DRC settings earlier in the script.
#
# Multicore simulation is not reliable for write_patterns
#set_simulation -num_processes 0
#write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_stuck_ser.${tmax_file_ext}.stil.gz -format stil -nounified_stil_flow -serial -replace -compress gzip
#write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_stuck_ser.${tmax_file_ext}.bin -format binary -nounified_stil_flow -serial -replace
#write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_stuck_par.${tmax_file_ext}.stil.gz -format stil -nounified_stil_flow -parallel -replace -compress gzip -cellnames type
setenv LTRAN_SHELL 1
#write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_stuck_ser.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_stuck_ser.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_stuck_ser.${tmax_file_ext}.maxtb.log "
#write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_stuck_par.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_stuck_par.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_stuck_par.${tmax_file_ext}.maxtb.log "
if { $TMAX_NUM_PROCS > 1 } {
   set_simulation -num_processes $TMAX_NUM_PROCS
}
#
write_faults ${RESULTS_DIR}/${DESIGN_NAME}_stuck_post.${tmax_file_ext}.faults.gz -all -replace -compress gzip

report_patterns -all -types > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_pat_types.${tmax_file_ext}.rpt
report_summaries faults patterns cpu_usage memory_usage > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_summaries.${tmax_file_ext}.rpt

report_faults -level 100 1 > ${REPORTS_DIR}/${DESIGN_NAME}_coverage.${tmax_file_ext}.rpt
report_faults -level 100 1 -verbose > ${REPORTS_DIR}/${DESIGN_NAME}_coverage_verbose.${tmax_file_ext}.rpt
# Report for Power-Aware ATPG results
#report_power -per_pattern -percentage > ${REPORTS_DIR}/${DESIGN_NAME}_stuck_power.${tmax_file_ext}.rpt
#analyze_faults -class an -verbose > an_fault_detail_post.txt
#analyze_faults -class nd -verbose > no_fault_detail_post.txt
#analyze_faults -class an -verbose > an_fault_detail.txt
#analyze_faults -class nd -verbose > no_fault_detail.txt

##################################################################
#    High X-Tolerance Scan Chain Diagnosis:                      #
#    Create a separate pattern set to diagnose scan chain        #
#    failures in high X-tolerant compression mode. If you are    #
#    using compression with default X-tolerance, comment out     #
#    this section because the patterns will be useless.          #
##################################################################

#if { $TMAX_COMPRESSION_MODE } {
#   remove_faults -all
#   set_faults -model stuck -nopersistent_fault_models
#   # Restore default settings for chain test
#   set_atpg -fill random -chain_test 0011R
#   # If power settings were set, uncomment to restore default for shift power
#   #set_atpg -shift_power_effort off
#   set_atpg -xtol_chain_diagnosis high
#   run_atpg -only_chain_diagnosis -auto
#   set_atpg -xtol_chain_diagnosis off
#   set_atpg -patterns [expr [sizeof_collection [get_patterns -all]] + 100]
#   run_atpg -auto
#
#   write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_scdiag.${tmax_file_ext}.bin.gz -format binary -replace -compress gzip
#   # If you need patterns in the 1999 version of STIL, instead of the default
#   # 2005 version, change to -format stil99 and remove -cellnames type.
#   # You may also need to change DRC settings.
#   write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_scdiag.${tmax_file_ext}.stil.gz -format stil -replace -compress gzip -cellnames type
#   #
#   # This setting is required to run write_testbench in batch mode:
#   setenv LTRAN_SHELL 1
#   write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_scdiag.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_scdiag.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_scdiag.${tmax_file_ext}.maxtb.log "
#   #
#   # This testbench may be used for both parallel and serial simulation.
#   # The default is parallel - modify the VCS script to run serial.
#   # Simulating all serial patterns may take excessive runtime.
#   # To serially simulate only patterns 0 to 10, modify the DEFINES line
#   # of the VCS script to read:
#   # DEFINES="+define+tmax_serial+tmax_n_pattern_sim=10" 
#   #
#   # Uncomment the following commands to use the Dual STIL Flow,
#   # which also requires changes to the DRC settings earlier in the script.
#   #
#   # Multicore simulation is not reliable for write_patterns
#   #set_simulation -num_processes 0
#   #write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_ser.${tmax_file_ext}.stil.gz -format stil -serial -replace -compress gzip
#   #write_patterns ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_par.${tmax_file_ext}.stil.gz -format stil -nounified_stil_flow -parallel -replace -compress gzip -cellnames type
#   #setenv LTRAN_SHELL 1
#   #write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_ser.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_ser.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_ser.${tmax_file_ext}.maxtb.log "
#   #write_testbench -input ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_par.${tmax_file_ext}.stil.gz -output ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_par.${tmax_file_ext}.maxtb -replace -config_file ${TMAX_SCRIPTS_ROOT}/tmax_maxtb_config.tcl -parameters " -v_file ${NETLIST_FILES} -v_lib ${TMAX_LIBRARY_FILES} -sim_script vcs -log ${RESULTS_DIR}/${DESIGN_NAME}_scdiag_par.${tmax_file_ext}.maxtb.log "
#   #
#
#   report_summaries faults patterns cpu_usage memory_usage > ${REPORTS_DIR}/${DESIGN_NAME}_scdiag_summaries.${tmax_file_ext}.rpt
#}

##################################################################
#    End of TetraMAX RM main script                              #
##################################################################

report_summaries cpu_usage memory_usage
#quit
