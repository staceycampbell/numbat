set ws_name vchess_workspace
file delete -force $ws_name

setws ./$ws_name
cd $ws_name

set hw "../vchess/vchess_top.xsa"
set proc "psu_cortexa53_0"
platform create -name "vchess_standalone" -hw $hw -os standalone
domain create -name standalone_domain -os standalone -proc $proc
bsp setlib -name lwip211
platform write
platform generate

# Create Vchess app
set sw_app_name "swvchess_app"
set sw_src_path [file normalize ../src]
set sw_include_path [file normalize ../src]
app create -name $sw_app_name -platform vchess_standalone -domain standalone_domain -template {Empty Application(C)}
importsources -name $sw_app_name -path $sw_src_path -soft-link
file link -symbolic $sw_app_name/src/lscript.ld $sw_src_path/lscript.ld
app config -name $sw_app_name include-path $sw_include_path
app config -name $sw_app_name -add libraries m
app build -name $sw_app_name
