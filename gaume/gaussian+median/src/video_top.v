module video_top(
    input             I_clk           , // 27Mhz
    input             I_rst_n         ,
    output     [1:0]  O_led           , // LED hiển thị
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

    input key // Nút nhấn chuyển chế độ
);

//==================================================
// 1. SYSTEM CONTROL
//==================================================
reg  [31:0] run_cnt;
wire        running;
wire        clk_12M; 
assign      XCLK = clk_12M; 

always @(posedge I_clk or negedge sys_resetn) begin
    if(!sys_resetn) run_cnt <= 32'd0;
    else if(run_cnt >= 32'd27_000_000) run_cnt <= 32'd0;
    else run_cnt <= run_cnt + 1'b1;
end
assign  running = (run_cnt < 32'd13_500_000) ? 1'b1 : 1'b0;

//==================================================
// 2. CAMERA INPUT
//==================================================
wire sys_resetn;
wire pll_lock;
wire hdmi_rst_n;

Reset_Sync u_Reset_Sync (.resetn(sys_resetn), .ext_reset(I_rst_n & pll_lock), .clk(I_clk));

OV2640_Controller u_OV2640_Controller (
    .clk(clk_12M), .resend(1'b0), .config_finished(),
    .sioc(SCL), .siod(SDA), .reset(), .pwdn()
);

// Fake RGB Grayscale (An toàn nhất cho Demo)
wire [15:0] cam_data;
assign cam_data = {PIXDATA[9:5], PIXDATA[9:4], PIXDATA[9:5]}; 

//==================================================
// 3. CHUỖI XỬ LÝ ẢNH (PIPELINE)
//==================================================

// --- BƯỚC 1: GAUSSIAN FILTER ---
// Đầu vào: Camera Data
// Đầu ra: gauss_data
wire [15:0] gauss_data;
wire        gauss_href;
wire        gauss_vsync;

gaussian_filter #( .IMG_WIDTH(1280) ) u_gaussian (
    .clk(PIXCLK), .rst_n(sys_resetn),
    .i_href(HREF), .i_vsync(VSYNC), .i_data(cam_data),
    .o_href(gauss_href), .o_vsync(gauss_vsync), .o_data(gauss_data)
);

// --- BƯỚC 2: MEDIAN FILTER (CASCADE) ---
// Đầu vào: LẤY TỪ GAUSSIAN (gauss_data)
// Đầu ra: median_data (Đây là kết quả đã qua cả 2 bộ lọc)
wire [15:0] median_data;
wire        median_href;
wire        median_vsync;

median_filter #( .IMG_WIDTH(1280) ) u_median (
    .clk(PIXCLK), .rst_n(sys_resetn),
    // QUAN TRỌNG: Nối đầu ra của Gaussian vào đầu vào của Median
    .i_href(gauss_href), .i_vsync(gauss_vsync), .i_data(gauss_data),
    
    .o_href(median_href), .o_vsync(median_vsync), .o_data(median_data)
);

//==================================================
// 4. LOGIC ĐIỀU KHIỂN & LED
//==================================================
wire key_pulse;
reg [1:0] mode_select; // 0: Normal, 1: Gaussian, 2: Gaussian+Median

button_pulse u_btn (
    .clk(I_clk), .rst_n(sys_resetn), .key(key), .pulse(key_pulse)
);

// Chuyển chế độ vòng tròn: 0 -> 1 -> 2 -> 0
always @(posedge I_clk or negedge sys_resetn) begin
    if (!sys_resetn)
        mode_select <= 2'd0;
    else if (key_pulse) begin
        if (mode_select == 2'd2)
            mode_select <= 2'd0;
        else
            mode_select <= mode_select + 1'b1;
    end
end

// ĐIỀU KHIỂN LED:
// Mode 0: Tắt hết
// Mode 1 (Gaussian): LED 0 Sáng (O_led[0])
// Mode 2 (Gauss+Median): LED 1 Sáng (O_led[1])
assign O_led[0] = (mode_select == 2'd1); 
assign O_led[1] = (mode_select == 2'd2);

//==================================================
// 5. BỘ CHUYỂN MẠCH (MULTIPLEXER)
//==================================================
reg        ch0_vfb_clk_in ;
reg        ch0_vfb_vs_in  ;
reg        ch0_vfb_de_in  ;
reg [15:0] ch0_vfb_data_in;

always @(*) begin
    ch0_vfb_clk_in = PIXCLK;
    
    case (mode_select)
        2'd0: begin // ẢNH GỐC
            ch0_vfb_vs_in   = VSYNC;
            ch0_vfb_de_in   = HREF;
            ch0_vfb_data_in = cam_data;
        end
        2'd1: begin // ẢNH GAUSSIAN (Sau bước 1)
            ch0_vfb_vs_in   = gauss_vsync;
            ch0_vfb_de_in   = gauss_href;
            ch0_vfb_data_in = gauss_data;
        end
        2'd2: begin // ẢNH GAUSSIAN + MEDIAN (Sau bước 2)
            // Lấy tín hiệu từ Median Filter (vì Median nối sau Gaussian)
            ch0_vfb_vs_in   = median_vsync;
            ch0_vfb_de_in   = median_href;
            ch0_vfb_data_in = median_data;
        end
        default: begin
            ch0_vfb_vs_in   = VSYNC;
            ch0_vfb_de_in   = HREF;
            ch0_vfb_data_in = cam_data;
        end
    endcase
end

//==================================================
// 6. FRAME BUFFER, RAM, HDMI (GIỮ NGUYÊN)
//==================================================
wire dma_clk, memory_clk, mem_pll_lock;
wire cmd, cmd_en, rd_data_valid, init_calib;
wire [21:0] addr;
wire [31:0] wr_data, rd_data;
wire [3:0] data_mask;
wire pix_clk;
wire syn_off0_re, syn_off0_vs, syn_off0_hs, off0_syn_de;
wire [15:0] off0_syn_data;

Video_Frame_Buffer_Top Video_Frame_Buffer_Top_inst ( 
    .I_rst_n(init_calib), .I_dma_clk(dma_clk), .I_wr_halt(1'd0), .I_rd_halt(1'd0), 
    .I_vin0_clk(ch0_vfb_clk_in), .I_vin0_vs_n(ch0_vfb_vs_in), .I_vin0_de(ch0_vfb_de_in), .I_vin0_data(ch0_vfb_data_in),
    .I_vout0_clk(pix_clk), .I_vout0_vs_n(~syn_off0_vs), .I_vout0_de(syn_off0_re), 
    .O_vout0_den(off0_syn_de), .O_vout0_data(off0_syn_data),
    .O_cmd(cmd), .O_cmd_en(cmd_en), .O_addr(addr), .O_wr_data(wr_data), .O_data_mask(data_mask), 
    .I_rd_data_valid(rd_data_valid), .I_rd_data(rd_data), .I_init_calib(init_calib)
); 

GW_PLLVR GW_PLLVR_inst (.clkout(memory_clk), .lock(mem_pll_lock), .clkin(I_clk));
HyperRAM_Memory_Interface_Top HyperRAM_Memory_Interface_Top_inst (
    .clk(I_clk), .memory_clk(memory_clk), .pll_lock(mem_pll_lock), .rst_n(sys_resetn),  
    .O_hpram_ck(O_hpram_ck), .O_hpram_ck_n(O_hpram_ck_n), .IO_hpram_rwds(IO_hpram_rwds), .IO_hpram_dq(IO_hpram_dq),
    .O_hpram_reset_n(O_hpram_reset_n), .O_hpram_cs_n(O_hpram_cs_n),
    .wr_data(wr_data), .rd_data(rd_data), .rd_data_valid(rd_data_valid), .addr(addr), .cmd(cmd), .cmd_en(cmd_en), 
    .clk_out(dma_clk), .data_mask(data_mask), .init_calib(init_calib)
); 

wire out_de;
syn_gen syn_gen_inst (                                   
    .I_pxl_clk(pix_clk), .I_rst_n(hdmi_rst_n),
    .I_h_total(16'd1650), .I_h_sync(16'd40), .I_h_bporch(16'd220), .I_h_res(16'd1280),
    .I_v_total(16'd750), .I_v_sync(16'd5), .I_v_bporch(16'd20), .I_v_res(16'd720),
    .I_rd_hres(16'd640), .I_rd_vres(16'd480), 
    .I_hs_pol(1'b1), .I_vs_pol(1'b1),
    .O_rden(syn_off0_re), .O_de(out_de), .O_hs(syn_off0_hs), .O_vs(syn_off0_vs)
);

localparam N = 2; 
reg [N-1:0] Pout_hs_dn, Pout_vs_dn, Pout_de_dn;
always@(posedge pix_clk or negedge hdmi_rst_n) begin
    if(!hdmi_rst_n) begin Pout_hs_dn<={N{1'b1}}; Pout_vs_dn<={N{1'b1}}; Pout_de_dn<={N{1'b0}}; end
    else begin Pout_hs_dn<={Pout_hs_dn[N-2:0],syn_off0_hs}; Pout_vs_dn<={Pout_vs_dn[N-2:0],syn_off0_vs}; Pout_de_dn<={Pout_de_dn[N-2:0],out_de}; end
end

wire rgb_vs, rgb_hs, rgb_de;
wire [23:0] rgb_data;
assign rgb_data = off0_syn_de ? {off0_syn_data[15:11],3'd0,off0_syn_data[10:5],2'd0,off0_syn_data[4:0],3'd0} : 24'h0000ff;
assign rgb_vs = Pout_vs_dn[N-1];
assign rgb_hs = Pout_hs_dn[N-1];
assign rgb_de = Pout_de_dn[N-1];

wire serial_clk;
TMDS_PLLVR TMDS_PLLVR_inst (.clkin(I_clk), .clkout(serial_clk), .clkoutd(clk_12M), .lock(pll_lock));
assign hdmi_rst_n = sys_resetn & pll_lock;
CLKDIV u_clkdiv (.RESETN(hdmi_rst_n), .HCLKIN(serial_clk), .CLKOUT(pix_clk), .CALIB(1'b1));
defparam u_clkdiv.DIV_MODE="5";

DVI_TX_Top DVI_TX_Top_inst (
    .I_rst_n(hdmi_rst_n), .I_serial_clk(serial_clk), .I_rgb_clk(pix_clk), 
    .I_rgb_vs(rgb_vs), .I_rgb_hs(rgb_hs), .I_rgb_de(rgb_de), 
    .I_rgb_r(rgb_data[23:16]), .I_rgb_g(rgb_data[15: 8]), .I_rgb_b(rgb_data[ 7: 0]),  
    .O_tmds_clk_p(O_tmds_clk_p), .O_tmds_clk_n(O_tmds_clk_n),
    .O_tmds_data_p(O_tmds_data_p), .O_tmds_data_n(O_tmds_data_n)
);

endmodule

// --- SUB MODULES ---

// Reset Sync
module Reset_Sync (input clk, input ext_reset, output resetn);
 reg [3:0] reset_cnt = 0;
 always @(posedge clk or negedge ext_reset) begin
     if (~ext_reset) reset_cnt <= 4'b0;
     else reset_cnt <= reset_cnt + !resetn;
 end
 assign resetn = &reset_cnt;
endmodule
 
// Button Module
module button_pulse (
    input clk,
    input rst_n,
    input key,
    output reg pulse
);
    reg [19:0] cnt;
    reg key_prev;
    wire btn_pressed = (key == 0); // Active Low
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            pulse <= 0;
            key_prev <= 0;
        end else begin
            if (btn_pressed) begin
                if (cnt < 20'd500_000) cnt <= cnt + 1;
            end else begin
                cnt <= 0;
            end
            
            pulse <= 0;
            if (cnt == 20'd499_999 && !key_prev) begin
                pulse <= 1; // Tạo 1 xung duy nhất khi nhấn đủ lâu
                key_prev <= 1;
            end
            if (!btn_pressed) key_prev <= 0;
        end
    end
endmodule