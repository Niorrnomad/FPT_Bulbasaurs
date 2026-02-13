module median_filter #(
    parameter IMG_WIDTH = 3480 
)(
    input clk,rst_n,i_href,i_vsync,
    input [15:0] i_data,
    
    output o_href,o_vsync,
    output [15:0] o_data
);

    wire [5:0] gray_in = i_data[10:5]; 

    reg [5:0] line_buff_0 [0:IMG_WIDTH-1] /* synthesis syn_ramstyle = "block_ram" */;
    reg [5:0] line_buff_1 [0:IMG_WIDTH-1] /* synthesis syn_ramstyle = "block_ram" */;
    reg [10:0] wr_ptr;
    
    reg [5:0] d1, d2, d0_reg;
    wire [5:0] d0=gray_in;              


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

    function [5:0] median3;
        input [5:0] a, b, c;
        begin
            if ((a>=b&&a<=c)||(a>=c&&a<=b)) median3=a;
            else if ((b>=a&&b<=c)||(b>=c&&b<=a))median3=b;
            else median3=c;
            end
        endfunction
    reg [5:0] v_med;
    reg href_d1,i_href_d1;
    always @(posedge clk)i_href_d1<=i_href;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_med <= 0; href_d1<=0;
        end else if (i_href_d1) begin
        v_med <= median3(p0, p1, p2);href_d1<=1;
        end else begin
            href_d1<=0;
        end
    end

    reg [5:0] h0, h1, h2;
    reg href_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0<=0; h1<=0; h2<=0; href_d2 <= 0;
        end else if (href_d1) begin
            h2 <= h1; h1 <= h0; h0 <= v_med;
            href_d2 <= 1;
        end else begin
            href_d2 <= 0;
        end
    end

    reg [5:0] final_med;
    reg valid_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_med <= 0; valid_out <= 0;
        end else if (href_d2) begin
            final_med <= median3(h0, h1, h2);
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

    assign o_data = {final_med[5:1], final_med, final_med[5:1]};
    assign o_href = valid_out;
    assign o_vsync = i_vsync;

endmodule