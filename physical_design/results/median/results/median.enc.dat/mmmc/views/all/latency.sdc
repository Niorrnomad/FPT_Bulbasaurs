set_clock_latency -source -early -min -rise  -0.344473 [get_ports {clk}] -clock clk 
set_clock_latency -source -early -min -fall  -0.356464 [get_ports {clk}] -clock clk 
set_clock_latency -source -early -max -rise  -0.125936 [get_ports {clk}] -clock clk 
set_clock_latency -source -early -max -fall  -0.124144 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -min -rise  -0.344473 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -min -fall  -0.356464 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max -rise  -0.125936 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max -fall  -0.124144 [get_ports {clk}] -clock clk 
