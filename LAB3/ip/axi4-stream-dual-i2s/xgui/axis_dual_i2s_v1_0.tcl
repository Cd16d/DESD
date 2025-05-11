# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_static_text $IPINST -name "Warnings" -parent ${Page_0} -text {The jumper on the board MUST BE in position SLV.
The input clock axis_clk MUST BE 22.591 MHz.}


}


