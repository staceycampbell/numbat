set ws_name "vchess_workspace"
file delete -force $ws_name

setws ./$ws_name
cd $ws_name
set hw ../vchess/vchess_top.xsa
set proc "psu_cortexa53_0"

platform create -name "vchess_standalone" -hw $hw -os standalone
domain create -name standalone_domain -os standalone -proc $proc
bsp setlib -name lwip211
platform write
platform generate

set app_name vchess_application
app create -name $app_name -platform vchess_standalone -domain standalone_domain -template {Empty Application(C)} -sysproj vchess_app_system
set abs_path [file normalize ../src]
importsources -name $app_name -path $abs_path -soft-link
app config -name $app_name include-path $abs_path

set swapp_name swvchess

# Create app inside vitis workspace
app create -name $swapp_name -platform vchess_standalone -domain standalone_domain -lang C++ -template {Empty Application (C++)} -sysproj vchess_app_system

# Link files from source-control to vitis workspace
set src_path [file normalize ../src]
set include_path [file normalize ../src]
importsources -name $swapp_name -path $src_path -soft-link
app config -name $swapp_name include-path $include_path

