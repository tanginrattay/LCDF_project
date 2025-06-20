set_property PACKAGE_PIN W16 [get_ports BTNX4]
set_property IOSTANDARD LVCMOS18 [get_ports BTNX4]
set_property IOSTANDARD LVCMOS18 [get_ports {RST_n}]
set_property PACKAGE_PIN V18 [get_ports {RST_n}]
set_property PACKAGE_PIN AC18 [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports clk]

set_property -dict {PACKAGE_PIN N21 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {R[0]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {R[1]}]
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {R[2]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {R[3]}]
set_property -dict {PACKAGE_PIN R22 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {G[0]}]
set_property -dict {PACKAGE_PIN R23 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {G[1]}]
set_property -dict {PACKAGE_PIN T24 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {G[2]}]
set_property -dict {PACKAGE_PIN T25 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {G[3]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {B[0]}]
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {B[1]}]
set_property -dict {PACKAGE_PIN T22 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {B[2]}]
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports {B[3]}]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports VS]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33 SLEW FAST} [get_ports HS]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {btn[0]}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {btn[1]}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {btn[2]}]
set_property  IOSTANDARD LVCMOS33 [get_ports gamemode_led[0]]
set_property  PACKAGE_PIN AF24 [get_ports gamemode_led[0]]
set_property  IOSTANDARD LVCMOS33 [get_ports gamemode_led[1]]
set_property  PACKAGE_PIN AE21 [get_ports gamemode_led[1]]

set_property  IOSTANDARD LVCMOS15 [get_ports {sw[0]}]
set_property  PACKAGE_PIN AA10 [get_ports {sw[0]}] 
set_property  IOSTANDARD LVCMOS15 [get_ports {sw[1]}]
set_property  IOSTANDARD LVCMOS15 [get_ports {sw[2]}]
set_property  PACKAGE_PIN AB10 [get_ports {sw[1]}] 
set_property  PACKAGE_PIN AA13 [get_ports {sw[2]}] 

set_property PACKAGE_PIN AF25 [get_ports {beep}]
set_property IOSTANDARD LVCMOS33 [get_ports {beep}]

set_property PACKAGE_PIN AD21 [get_ports {AN[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {AN[0]}]

set_property PACKAGE_PIN AC21 [get_ports {AN[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {AN[1]}]

set_property PACKAGE_PIN AB21 [get_ports {AN[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {AN[2]}]

set_property PACKAGE_PIN AC22 [get_ports {AN[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {AN[3]}]

set_property PACKAGE_PIN AB22 [get_ports {Segment[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[0]}]

set_property PACKAGE_PIN AD24 [get_ports {Segment[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[1]}]

set_property PACKAGE_PIN AD23 [get_ports {Segment[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[2]}]

set_property PACKAGE_PIN Y21 [get_ports {Segment[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[3]}]

set_property PACKAGE_PIN W20 [get_ports {Segment[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[4]}]

set_property PACKAGE_PIN AC24 [get_ports {Segment[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[5]}]

set_property PACKAGE_PIN AC23 [get_ports {Segment[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[6]}]

set_property PACKAGE_PIN AA22 [get_ports {Segment[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {Segment[7]}]