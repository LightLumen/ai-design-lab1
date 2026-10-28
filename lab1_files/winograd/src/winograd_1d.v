`timescale 1ns/1ps
module winograd_1d (
    input  logic               clk,
    input  logic               rstn,
    input  logic               en,
    input  logic signed [31:0] r1_x, r2_x, r3_x, r4_x,
    input  logic signed [31:0] r1_w, r2_w, r3_w,
    output logic signed [31:0] r1_res, r2_res,
    output logic               vld
);
    logic signed [32:0] t0_d, t1_d, t2_d, t3_d;
    logic signed [33:0] u0_d, u1_d, u2_d, u3_d;
    logic signed [32:0] t0_q, t1_q, t2_q, t3_q;
    logic signed [33:0] u0_q, u1_q, u2_q, u3_q;
    logic signed [66:0] p0_d, p1_d, p2_d, p3_d;
    logic signed [66:0] p0_q, p1_q, p2_q, p3_q;
    logic signed [31:0] y0_d, y1_d;
    logic valid_s1, valid_s2;

    input_transform u_input_transform (
        .d0(r1_x), .d1(r2_x), .d2(r3_x), .d3(r4_x),
        .t0(t0_d), .t1(t1_d), .t2(t2_d), .t3(t3_d)
    );

    weight_transform u_weight_transform (
        .g0(r1_w), .g1(r2_w), .g2(r3_w),
        .u0(u0_d), .u1(u1_d), .u2(u2_d), .u3(u3_d)
    );

    // Explicitly size BOTH signed operands to 67 bits before multiplication.
    // A true 33x34 signed product fits exactly in the retained 67 bits.
    assign p0_d = $signed({{34{t0_q[32]}}, t0_q})
                * $signed({{33{u0_q[33]}}, u0_q});
    assign p1_d = $signed({{34{t1_q[32]}}, t1_q})
                * $signed({{33{u1_q[33]}}, u1_q});
    assign p2_d = $signed({{34{t2_q[32]}}, t2_q})
                * $signed({{33{u2_q[33]}}, u2_q});
    assign p3_d = $signed({{34{t3_q[32]}}, t3_q})
                * $signed({{33{u3_q[33]}}, u3_q});

    output_transform u_output_transform (
        .p0(p0_q), .p1(p1_q), .p2(p2_q), .p3(p3_q),
        .y0(y0_d), .y1(y1_d)
    );

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            t0_q <= '0; t1_q <= '0; t2_q <= '0; t3_q <= '0;
            u0_q <= '0; u1_q <= '0; u2_q <= '0; u3_q <= '0;
            p0_q <= '0; p1_q <= '0; p2_q <= '0; p3_q <= '0;
            r1_res <= '0;
            r2_res <= '0;
            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            vld <= 1'b0;
        end else begin
            // Move bubbles every cycle, even when current en is zero.
            valid_s1 <= en;
            valid_s2 <= valid_s1;
            vld <= valid_s2;

            // E0: capture the transforms of the currently accepted group.
            if (en) begin
                t0_q <= t0_d; t1_q <= t1_d;
                t2_q <= t2_d; t3_q <= t3_d;
                u0_q <= u0_d; u1_q <= u1_d;
                u2_q <= u2_d; u3_q <= u3_d;
            end

            // E1: use the previous stage's valid, independently of en.
            if (valid_s1) begin
                p0_q <= p0_d; p1_q <= p1_d;
                p2_q <= p2_d; p3_q <= p3_d;
            end

            // E2: old valid_s2 and old products describe the same group.
            // If invalid, hold output data while vld still shifts normally.
            if (valid_s2) begin
                r1_res <= y0_d;
                r2_res <= y1_d;
            end
        end
    end
endmodule
