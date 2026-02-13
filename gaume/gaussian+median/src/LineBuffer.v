module LineBuffer (
    input wire clk,
    input wire rst_n,
    input wire de_in,
    input wire [15:0] data_in,
    output reg [15:0] data_out
);
    parameter H_RES = 640; 
    
    reg [15:0] mem [0:1023] /* synthesis syn_ramstyle = "block_ram" */;
    reg [9:0] ptr; 

    always @(posedge clk) begin
        if (de_in) begin
            data_out <= mem[ptr]; 
            mem[ptr] <= data_in;  
        end else begin
            data_out <= 16'd0;    
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr <= 0;
        end else begin
            if (de_in) begin
                if (ptr < H_RES - 1) 
                    ptr <= ptr + 1'b1;
                else 
                    ptr <= 0; 
            end else begin
                ptr <= 0; 
            end
        end
    end

endmodule