module video_top(
    input             I_clk           , //27Mhz
    input             I_rst_n         ,
    output     [1:0]  O_led           ,
    inout             SDA             ,
    inout             SCL             ,
    input             VSYNC           ,
    input             HREF            ,
    input      [9:0]  PIXDATA         ,
    input             PIXCLK          ,
    output            XCLK            ,
    output     [0:0]  O_hpram_ck      ,
    output     [0:0]  O_hpram_ck_n    ,
    output     [0:0]  O_hpram_cs_n    ,
    output     [0:0]  O_hpram_reset_n ,
    inout      [7:0]  IO_hpram_dq     ,
    inout      [0:0]  IO_hpram_rwds   ,
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n   ,

    input key
);

reg  [31:0] run_cnt;
wire        running;

wire        tp0_vs_in  ;
wire        tp0_hs_in  ;
wire        tp0_de_in ;
wire [ 7:0] tp0_data_r;
wire [ 7:0] tp0_data_g;
wire [ 7:0] tp0_data_b;

reg         vs_r;
reg  [9:0]  cnt_vs;

reg  [9:0]  pixdata_d1;
reg         hcnt;
wire [15:0] cam_data;

// --- GAUSSIAN WIRES ---
wire [15:0] gaussian_out_data;
wire        gaussian_out_href;
wire        gaussian_out_vsync;

//frame buffer in
wire        ch0_vfb_clk_in ;
wire        ch0_vfb_vs_in  ;
wire        ch0_vfb_de_in  ;
wire [15:0] ch0_vfb_data_in;

//syn_code
wire        syn_off0_re; 
wire        syn_off0_vs;
wire        syn_off0_hs;
            
wire        off0_syn_de  ;
wire [15:0] off0_syn_data;

//Hyperram
wire        dma_clk  ; 
wire        memory_clk;
wire        mem_pll_lock  ;

//memory interface
wire          cmd           ;
wire          cmd_en        ;
wire [21:0]   addr          ;
wire [31:0]   wr_data       ;
wire [3:0]    data_mask     ;
wire          rd_data_valid ;
wire [31:0]   rd_data       ;
wire          init_calib    ;

//rgb data
wire        rgb_vs      ;
wire        rgb_hs      ;
wire        rgb_de      ;
wire [23:0] rgb_data    ;  

//HDMI TX
wire serial_clk;
wire pll_lock;
wire hdmi_rst_n;
wire pix_clk;
wire clk_12M;
wire key_flag; 

//LED test
always @(posedge I_clk or negedge sys_resetn) 
begin
    if(!sys_resetn)
        run_cnt <= 32'd0;
    else if(run_cnt >= 32'd27_000_000)
        run_cnt <= 32'd0;
    else
        run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd13_500_000) ? 1'b1 : 1'b0;
assign  O_led[0] = key_flag; // LED on -> Gaussian
assign  O_led[1] = ~O_led[0];
assign  XCLK = clk_12M;

// Camera reset
Reset_Sync u_Reset_Sync (
  .resetn(sys_resetn),
  .ext_reset(I_rst_n & pll_lock),
  .clk(I_clk)
);

OV2640_Controller u_OV2640_Controller
(
    .clk             (clk_12M),         
    .resend          (1'b0),            
    .config_finished (), 
    .sioc            (SCL),             
    .siod            (SDA),             
    .reset           (),        
    .pwdn            ()             
);

// Data RAW  
assign cam_data = {PIXDATA[9:5],PIXDATA[9:4],PIXDATA[9:5]}; 

// GAUSSIAN FILTER INSTANTIATION 
gaussian_filter #(
    .IMG_WIDTH(1280) 
) u_gaussian_filter (
    .clk     (PIXCLK),        
    .rst_n   (sys_resetn),
    .i_href  (HREF),          
    .i_vsync (VSYNC),         
    .i_data  (cam_data),      
    
    .o_href  (gaussian_out_href),  
    .o_vsync (gaussian_out_vsync), 
    .o_data  (gaussian_out_data)   
);
wire [15:0] gaussian_out_data2;
gaussian_filter #(
    .IMG_WIDTH(1280) 
) u_gaussian_filter2 (
    .clk     (PIXCLK),        
    .rst_n   (sys_resetn),
    .i_href  (HREF),          
    .i_vsync (VSYNC),         
    .i_data  (gaussian_out_data),      
    
    .o_data  (gaussian_out_data2)   
);

// Frame Buffer Input Mux 
// key_flag = 0 -> Basic Camera 
// key_flag = 1 -> Gaussian Camera 
    
    assign ch0_vfb_clk_in  = PIXCLK;        
    assign ch0_vfb_vs_in   = key_flag ? gaussian_out_vsync : VSYNC; 
    assign ch0_vfb_de_in   = key_flag ? gaussian_out_href  : HREF;   
    assign ch0_vfb_data_in = key_flag ? gaussian_out_data2  : cam_data; 
  
key_flag key_flag_inst(
    .clk(I_clk),
    .rst_n(I_rst_n),
    .key(key),
    .key_flag(key_flag)
);

//SRAM Controller
Video_Frame_Buffer_Top Video_Frame_Buffer_Top_inst
( 
    .I_rst_n        (init_calib       ),
    .I_dma_clk      (dma_clk          ),
    .I_wr_halt      (1'd0             ), 
    .I_rd_halt      (1'd0             ), 
    // video data input            
    .I_vin0_clk     (ch0_vfb_clk_in   ),
    .I_vin0_vs_n    (ch0_vfb_vs_in    ),
    .I_vin0_de      (ch0_vfb_de_in    ),
    .I_vin0_data    (ch0_vfb_data_in  ),
    .O_vin0_fifo_full   (                 ),
    // video data output           
    .I_vout0_clk        (pix_clk          ),
    .I_vout0_vs_n       (~syn_off0_vs     ),
    .I_vout0_de         (syn_off0_re      ),
    .O_vout0_den        (off0_syn_de      ),
    .O_vout0_data       (off0_syn_data    ),
    .O_vout0_fifo_empty (                 ),
    // ddr write request
    .O_cmd              (cmd              ),
    .O_cmd_en           (cmd_en           ),
    .O_addr             (addr             ),
    .O_wr_data          (wr_data          ),
    .O_data_mask        (data_mask        ),
    .I_rd_data_valid    (rd_data_valid    ),
    .I_rd_data          (rd_data          ),
    .I_init_calib       (init_calib       )
); 

//HyperRAM ip
GW_PLLVR GW_PLLVR_inst
(
    .clkout(memory_clk    ), 
    .lock  (mem_pll_lock  ), 
    .clkin (I_clk         )  
);

HyperRAM_Memory_Interface_Top HyperRAM_Memory_Interface_Top_inst
(
    .clk                (I_clk          ),
    .memory_clk         (memory_clk     ),
    .pll_lock           (mem_pll_lock   ),
    .rst_n              (sys_resetn     ),  
    .O_hpram_ck         (O_hpram_ck     ),
    .O_hpram_ck_n       (O_hpram_ck_n   ),
    .IO_hpram_rwds      (IO_hpram_rwds  ),
    .IO_hpram_dq        (IO_hpram_dq    ),
    .O_hpram_reset_n(O_hpram_reset_n),
    .O_hpram_cs_n       (O_hpram_cs_n   ),
    .wr_data            (wr_data        ),
    .rd_data            (rd_data        ),
    .rd_data_valid      (rd_data_valid  ),
    .addr               (addr           ),
    .cmd                (cmd            ),
    .cmd_en             (cmd_en         ),
    .clk_out            (dma_clk        ),
    .data_mask          (data_mask      ),
    .init_calib         (init_calib     )
); 

wire out_de;
syn_gen syn_gen_inst
(                                   
    .I_pxl_clk   (pix_clk         ),
    .I_rst_n     (hdmi_rst_n      ),
    .I_h_total   (16'd1650        ),
    .I_h_sync    (16'd40          ),
    .I_h_bporch  (16'd220         ),
    .I_h_res     (16'd1280        ),
    .I_v_total   (16'd750         ),
    .I_v_sync    (16'd5           ),
    .I_v_bporch  (16'd20          ),
    .I_v_res     (16'd720         ),
    .I_rd_hres   (16'd640         ),
    .I_rd_vres   (16'd480         ),
    .I_hs_pol    (1'b1            ),
    .I_vs_pol    (1'b1            ),
    .O_rden      (syn_off0_re     ),
    .O_de        (out_de          ),   
    .O_hs        (syn_off0_hs     ),
    .O_vs        (syn_off0_vs     )
);

localparam N = 2; 
                          
reg  [N-1:0]  Pout_hs_dn   ;
reg  [N-1:0]  Pout_vs_dn   ;
reg  [N-1:0]  Pout_de_dn   ;

always@(posedge pix_clk or negedge hdmi_rst_n)
begin
    if(!hdmi_rst_n)
        begin                          
            Pout_hs_dn  <= {N{1'b1}};
            Pout_vs_dn  <= {N{1'b1}}; 
            Pout_de_dn  <= {N{1'b0}}; 
        end
    else 
        begin                          
            Pout_hs_dn  <= {Pout_hs_dn[N-2:0],syn_off0_hs};
            Pout_vs_dn  <= {Pout_vs_dn[N-2:0],syn_off0_vs}; 
            Pout_de_dn  <= {Pout_de_dn[N-2:0],out_de}; 
        end
end

//TMDS TX
assign rgb_data    = off0_syn_de ? {off0_syn_data[15:11],3'd0,off0_syn_data[10:5],2'd0,off0_syn_data[4:0],3'd0} : 24'h0000ff;
assign rgb_vs      = Pout_vs_dn[N-1];
assign rgb_hs      = Pout_hs_dn[N-1];
assign rgb_de      = Pout_de_dn[N-1];

TMDS_PLLVR TMDS_PLLVR_inst
(.clkin     (I_clk      )      
,.clkout    (serial_clk)      
,.clkoutd   (clk_12M   ) 
,.lock      (pll_lock  )      
);

assign hdmi_rst_n = sys_resetn & pll_lock;

CLKDIV u_clkdiv
(.RESETN(hdmi_rst_n)
,.HCLKIN(serial_clk) 
,.CLKOUT(pix_clk)    
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";

DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi_rst_n   ), 
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ), 
    .I_rgb_vs      (rgb_vs        ), 
    .I_rgb_hs      (rgb_hs        ),    
    .I_rgb_de      (rgb_de        ), 
    .I_rgb_r       (rgb_data[23:16]    ),  
    .I_rgb_g       (rgb_data[15: 8]    ),  
    .I_rgb_b       (rgb_data[ 7: 0]    ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),  
    .O_tmds_data_n (O_tmds_data_n )
);

endmodule

// --- SUB MODULES ---

module Reset_Sync (
 input clk,
 input ext_reset,
 output resetn
);
 reg [3:0] reset_cnt = 0;
 always @(posedge clk or negedge ext_reset) begin
     if (~ext_reset)
         reset_cnt <= 4'b0;
     else
         reset_cnt <= reset_cnt + !resetn;
 end
 assign resetn = &reset_cnt;
endmodule

module key_flag#(
    parameter clk_frequency = 27_000_000 ,
    parameter io_num        = 1
)(
    input                   clk , 
    input                   rst_n,
    input                   key,
    output                  key_flag
);
parameter count_ms = clk_frequency / 1000 ;
parameter count_20ms = count_ms * 20 -1 ;
parameter count_500ms = count_ms * 500 -1 ;

reg [($clog2(count_20ms)-1)+10:0] count_20ms_reg;
reg key_input = 1'd1;
always @(posedge clk) begin
    key_input <= ~key  ;
end
reg key_flag_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count_20ms_reg <= 'd0;
    else if(key_input)
        count_20ms_reg <= count_20ms_reg + 'd1 ;
    else if(count_20ms_reg >= count_20ms) begin
            key_flag_r = ~key_flag_r;
            count_20ms_reg <= 'd0;;
    end
    else
        count_20ms_reg <= 'd0;;
end
assign key_flag = key_flag_r;
endmodule