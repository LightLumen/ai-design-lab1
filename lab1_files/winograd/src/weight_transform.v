`timescale 1ns/1ps
module weight_transform (
    input  logic signed [31:0] g0, g1, g2,
    output logic signed [33:0] u0, u1, u2, u3
);
    logic signed [33:0] g0_ext, g1_ext, g2_ext;

    assign g0_ext = $signed({{2{g0[31]}}, g0});
    assign g1_ext = $signed({{2{g1[31]}}, g1});
    assign g2_ext = $signed({{2{g2[31]}}, g2});

    // Scale the entire weight transform by two; divide only at output.
    assign u0 = g0_ext <<< 1'b1;
    assign u1 = (g0_ext + g1_ext) + g2_ext;
    assign u2 = (g0_ext - g1_ext) + g2_ext;
    assign u3 = g2_ext <<< 1'b1;
endmodule
