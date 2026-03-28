if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name max_lib\
   -timing\
    [list ${::IMEX::libVar}/mmmc/fast_vdd1v0_basicCells.lib]
create_op_cond -name max -library_file ${::IMEX::libVar}/mmmc/fast_vdd1v0_basicCells.lib -P 10 -V 10 -T 10
create_rc_corner -name max_rc\
   -cap_table ${::IMEX::libVar}/mmmc/gpdk045.tch\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0
create_delay_corner -name max_delay\
   -library_set max_lib\
   -rc_corner max_rc
create_constraint_mode -name m\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/m/m.sdc]
create_analysis_view -name apb -constraint_mode m -delay_corner max_delay -latency_file ${::IMEX::dataVar}/mmmc/views/apb/latency.sdc
set_analysis_view -setup [list apb] -hold [list apb]
