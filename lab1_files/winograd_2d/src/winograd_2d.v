`timescale 1ns/1ps
// Each weight transform doubles G. After two dimensions, the inverse
// transform yields exactly four times the convolution. Arithmetic modulo
// 2^34 therefore suffices to recover all 32 requested bits at the end.
module winograd_2d (
    input wire clk, rstn, en,
    input wire [511:0] x_flat,
    input wire [287:0] w_flat,
    output reg [127:0] res_flat,
    output reg vld
);
    wire [33:0] x_row [0:3][0:3], w_row [0:2][0:3];
    reg [33:0] products [0:3][0:3];
    wire [33:0] inverse_rows [0:3][0:1];
    reg valid_transform, valid_product;
    genvar r, c;
    generate
        for (r=0; r<4; r=r+1) begin : row
            wire signed [33:0] x [0:3];
            for (c=0; c<4; c=c+1) begin : unpack_x
                assign x[c] = $signed(x_flat[32*(4*r+c) +: 32]);
            end
            w2_data_transform dx(x[0], x[1], x[2], x[3],
                x_row[r][0], x_row[r][1], x_row[r][2], x_row[r][3]);
            if (r<3) begin : weights
                wire signed [33:0] w [0:2];
                for (c=0; c<3; c=c+1) begin : unpack_w
                    assign w[c] = $signed(w_flat[32*(3*r+c) +: 32]);
                end
                w2_weight_transform gw(w[0], w[1], w[2],
                    w_row[r][0], w_row[r][1], w_row[r][2], w_row[r][3]);
            end
            assign inverse_rows[r][0] = products[r][0]+products[r][1]+products[r][2];
            assign inverse_rows[r][1] = products[r][1]-products[r][2]-products[r][3];
        end
        for (c=0; c<4; c=c+1) begin : column
            wire [33:0] d [0:3], g [0:3];
            w2_data_transform dx(x_row[0][c], x_row[1][c], x_row[2][c],
                x_row[3][c], d[0], d[1], d[2], d[3]);
            w2_weight_transform gw(w_row[0][c], w_row[1][c], w_row[2][c],
                g[0], g[1], g[2], g[3]);
            for (r=0; r<4; r=r+1) begin : lane
                reg [33:0] d_q, g_q;
                always @(posedge clk) begin
                    if (en) begin
                        d_q <= d[r];
                        g_q <= g[r];
                    end
                    if (valid_transform)
                        products[r][c] <= d_q * g_q;
                end
            end
        end
        for (c=0; c<2; c=c+1) begin : output_column
            wire [33:0] top_sum = inverse_rows[0][c]+inverse_rows[1][c]+inverse_rows[2][c];
            wire [33:0] bottom_sum = inverse_rows[1][c]-inverse_rows[2][c]-inverse_rows[3][c];
            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    res_flat[32*c +: 32] <= 0;
                    res_flat[32*(2+c) +: 32] <= 0;
                end else if (valid_product) begin
                    res_flat[32*c +: 32] <= top_sum[33:2];
                    res_flat[32*(2+c) +: 32] <= bottom_sum[33:2];
                end
            end
        end
    endgenerate
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            valid_transform <= 0;
            valid_product <= 0;
            vld <= 0;
        end else begin
            valid_transform <= en;
            valid_product <= valid_transform;
            vld <= valid_product;
        end
    end
endmodule

module w2_data_transform (
    input wire signed [33:0] a,b,c,d,
    output wire [33:0] t0,t1,t2,t3
);
    assign t0 = a-c;
    assign t1 = b+c;
    assign t2 = c-b;
    assign t3 = b-d;
endmodule

module w2_weight_transform (
    input wire signed [33:0] a,b,c,
    output wire [33:0] t0,t1,t2,t3
);
    assign t0 = a << 1;
    assign t1 = a+b+c;
    assign t2 = a-b+c;
    assign t3 = c << 1;
endmodule
