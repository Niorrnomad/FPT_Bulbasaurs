module gaussian_filter #(
    parameter IMG_WIDTH = 1280 
)(
    input clk,rst_n,i_href,i_vsync,
    input [15:0] i_data,
    
    output o_href,o_vsync,
    output [15:0] o_data
);


    wire [5:0] gray_in=i_data[10:5];

    reg [5:0] line_buff_0 [0:IMG_WIDTH-1] /* synthesis syn_ramstyle = "block_ram" */;
    reg [5:0] line_buff_1 [0:IMG_WIDTH-1] /* synthesis syn_ramstyle = "block_ram" */;
    reg [10:0] wr_ptr;
    
    reg [5:0] d1, d2, d0_reg;
    wire [5:0] d0 = gray_in;

    always @(posedge clk) begin
        if (i_href) begin
        d1<=line_buff_0[wr_ptr];
            d2<=line_buff_1[wr_ptr];
            d0_reg<=d0;

            line_buff_0[wr_ptr]<=d0;
            line_buff_1[wr_ptr]<=d1;
            
            if (wr_ptr==IMG_WIDTH-1)wr_ptr <=0;
        else wr_ptr<= wr_ptr+1;
        end else begin
        wr_ptr <= 0;
        end
    end

    wire [5:0] p0=d0_reg, p1=d1, p2=d2;

    reg [7:0] v_sum;
    reg v_href,i_href_d1;
    always @(posedge clk) i_href_d1<=i_href;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_sum<=0;v_href<=0;
        end else if (i_href_d1)begin
            v_sum<=p0+(p1<<1)+p2;
            v_href<=1;
    end else begin
            v_href <= 0;
        end
    end

reg [7:0] h0, h1, h2;
reg h_href;

always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0<=0; h1<=0; h2<=0; h_href <= 0;
        end else if (v_href) begin
            h2 <= h1; h1 <= h0; h0 <= v_sum;
            h_href<= 1;
    end else begin
            h_href<=0;
    end
    end

    reg [9:0] final_sum;
    reg valid_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_sum <= 0; valid_out <= 0;
        end else if (h_href) begin

        final_sum <= h0 + (h1 << 1) + h2;
        valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end


    wire [5:0] res_gray = final_sum[9:4];
    

    assign o_data = {res_gray[5:1], res_gray, res_gray[5:1]};
    assign o_href = valid_out;
    assign o_vsync = i_vsync;

endmodule