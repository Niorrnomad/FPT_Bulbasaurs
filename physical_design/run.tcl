# ============================================================
#  run.tcl 
# ============================================================

set_db super_thread_servers {}
set_db auto_super_thread false
set_db max_cpus_per_server 0
set_db information_level 0
# === Design setup ===
set DESIGN  gaussian_filter
set RTL_DIR "/home/niorr/FPT_Bulbasaurs/physical_design/gaussian_camera.v"
set LIB_DIR "/home/niorr/adder_rtl/lib/gsclib045_all_v4.8"
set OUT_DIR "/home/niorr/FPT_Bulbasaurs/physical_design/results"
set SDC_FILE "/home/niorr/FPT_Bulbasaurs/physical_design/new.sdc"

# === Environment setup ===
file mkdir $OUT_DIR
set_db init_hdl_search_path [list $RTL_DIR]


read_libs $LIB_DIR/gsclib045/timing/slow_vdd1v0_basicCells.lib
set_db library [list $LIB_DIR/gsclib045/timing/slow_vdd1v0_basicCells.lib]

read_hdl  $RTL_DIR

elaborate $DESIGN

read_sdc $SDC_FILE


syn_generic
syn_map
syn_opt


write_hdl > $OUT_DIR/${DESIGN}_synth.v
write_sdc > $OUT_DIR/${DESIGN}_synth.sdc
report_area  > $OUT_DIR/${DESIGN}_area.rpt
report_power > $OUT_DIR/${DESIGN}_power.rpt
report_timing > $OUT_DIR/${DESIGN}_timing.rpt
report_qor >$OUT_DIR/${DESIGN}_qor.rpt

gui_show
