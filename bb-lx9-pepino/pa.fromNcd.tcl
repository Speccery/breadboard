
# PlanAhead Launch Script for Post PAR Floorplanning, created by Project Navigator

create_project -name bb-lx9-pepino -dir "W:/Omat/trunk/breadboard/bb-lx9-pepino/planAhead_run_1" -part xc6slx9ftg256-2
set srcset [get_property srcset [current_run -impl]]
set_property design_mode GateLvl $srcset
set_property edif_top_file "W:/Omat/trunk/breadboard/bb-lx9-pepino/system.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {W:/Omat/trunk/breadboard/bb-lx9-pepino} {../bb-lx9/ipcore_dir} }
set_property target_constrs_file "pepino.ucf" [current_fileset -constrset]
add_files [list {pepino.ucf}] -fileset [get_property constrset [current_run]]
link_design
read_xdl -file "W:/Omat/trunk/breadboard/bb-lx9-pepino/system.ncd"
if {[catch {read_twx -name results_1 -file "W:/Omat/trunk/breadboard/bb-lx9-pepino/system.twx"} eInfo]} {
   puts "WARNING: there was a problem importing \"W:/Omat/trunk/breadboard/bb-lx9-pepino/system.twx\": $eInfo"
}
