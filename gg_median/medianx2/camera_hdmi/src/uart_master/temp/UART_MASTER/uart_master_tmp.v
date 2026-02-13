//Copyright (C)2014-2023 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.9 (64-bit)
//Part Number: GW1NSR-LV4CQN48PC6/I5
//Device: GW1NSR-4C
//Created Time: Thu Nov 13 14:31:58 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	UART_MASTER_Top your_instance_name(
		.I_CLK(I_CLK_i), //input I_CLK
		.I_RESETN(I_RESETN_i), //input I_RESETN
		.I_TX_EN(I_TX_EN_i), //input I_TX_EN
		.I_WADDR(I_WADDR_i), //input [2:0] I_WADDR
		.I_WDATA(I_WDATA_i), //input [7:0] I_WDATA
		.I_RX_EN(I_RX_EN_i), //input I_RX_EN
		.I_RADDR(I_RADDR_i), //input [2:0] I_RADDR
		.O_RDATA(O_RDATA_o), //output [7:0] O_RDATA
		.SIN(SIN_i), //input SIN
		.RxRDYn(RxRDYn_o), //output RxRDYn
		.SOUT(SOUT_o), //output SOUT
		.TxRDYn(TxRDYn_o), //output TxRDYn
		.DDIS(DDIS_o), //output DDIS
		.INTR(INTR_o), //output INTR
		.DCDn(DCDn_i), //input DCDn
		.CTSn(CTSn_i), //input CTSn
		.DSRn(DSRn_i), //input DSRn
		.RIn(RIn_i), //input RIn
		.DTRn(DTRn_o), //output DTRn
		.RTSn(RTSn_o) //output RTSn
	);

//--------Copy end-------------------
