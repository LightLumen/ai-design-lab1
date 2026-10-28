`timescale 1ns/1ps
module input_transform (
    input  logic signed [31:0] d0, d1, d2, d3,
    output logic signed [32:0] t0, t1, t2, t3
);
    logic signed [32:0] d0_ext, d1_ext, d2_ext, d3_ext;

    assign d0_ext = $signed({d0[31], d0});
    assign d1_ext = $signed({d1[31], d1});
    assign d2_ext = $signed({d2[31], d2});
    assign d3_ext = $signed({d3[31], d3});

    assign t0 = d0_ext - d2_ext;
    assign t1 = d1_ext + d2_ext;
    assign t2 = d2_ext - d1_ext;
    assign t3 = d1_ext - d3_ext;
endmodule
