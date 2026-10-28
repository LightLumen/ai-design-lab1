`timescale 1ns/1ps
module output_transform (
    input  logic signed [66:0] p0, p1, p2, p3,
    output logic signed [31:0] y0, y1
);
    logic signed [68:0] p0_ext, p1_ext, p2_ext, p3_ext;
    logic signed [68:0] s0, s1, y0_full, y1_full;

    assign p0_ext = $signed({{2{p0[66]}}, p0});
    assign p1_ext = $signed({{2{p1[66]}}, p1});
    assign p2_ext = $signed({{2{p2[66]}}, p2});
    assign p3_ext = $signed({{2{p3[66]}}, p3});

    assign s0 = (p0_ext + p1_ext) + p2_ext;
    assign s1 = (p1_ext - p2_ext) - p3_ext;
    assign y0_full = s0 >>> 1'b1;
    assign y1_full = s1 >>> 1'b1;

    // Intentional truncation: return the result modulo 2^32.
    assign y0 = $signed(y0_full[31:0]);
    assign y1 = $signed(y1_full[31:0]);
endmodule
