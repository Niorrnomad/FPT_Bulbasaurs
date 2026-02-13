//Copyright (C)2014-2023 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.9 (64-bit)
//Part Number: GW1NSR-LV4CQN48PC6/I5
//Device: GW1NSR-4C
//Created Time: Sun Nov 23 00:00:47 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	RAM_based_shift_reg_top your_instance_name(
		.clk(clk_i), //input clk
		.Reset(Reset_i), //input Reset
		.Din(Din_i), //input [7:0] Din
		.Q(Q_o) //output [7:0] Q
	);

//--------Copy end-------------------
