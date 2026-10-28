`timescale 1ns/1ps
module winograd_1d_selfcheck_tb;
    logic clk = 1'b0;
    logic rstn, en;
    logic signed [31:0] r1_x, r2_x, r3_x, r4_x;
    logic signed [31:0] r1_w, r2_w, r3_w;
    wire signed [31:0] r1_res, r2_res;
    wire vld;

    winograd_1d dut (
        .clk(clk), .rstn(rstn), .en(en),
        .r1_x(r1_x), .r2_x(r2_x), .r3_x(r3_x), .r4_x(r4_x),
        .r1_w(r1_w), .r2_w(r2_w), .r3_w(r3_w),
        .r1_res(r1_res), .r2_res(r2_res), .vld(vld)
    );
    always #5 clk = ~clk;

    // Independent direct-convolution model: 64-bit individual products,
    // each explicitly extended BEFORE a 69-bit three-term accumulation.
    function automatic logic signed [31:0] golden (
        input logic signed [31:0] x0, x1, x2, w0, w1, w2
    );
        logic signed [63:0] a, b, c;
        logic signed [68:0] ae, be, ce, total;
        begin
            a = $signed({{32{x0[31]}}, x0}) * $signed({{32{w0[31]}}, w0});
            b = $signed({{32{x1[31]}}, x1}) * $signed({{32{w1[31]}}, w1});
            c = $signed({{32{x2[31]}}, x2}) * $signed({{32{w2[31]}}, w2});
            ae = $signed({{5{a[63]}}, a});
            be = $signed({{5{b[63]}}, b});
            ce = $signed({{5{c[63]}}, c});
            total = (ae + be) + ce;
            golden = $signed(total[31:0]);
        end
    endfunction

    logic qv0, qv1, expected_vld;
    logic signed [31:0] q00, q01, q10, q11;
    logic signed [31:0] expected0, expected1;
    logic signed [31:0] basis [0:2];
    integer tag0, tag1, expected_tag;
    integer cycles = 0, accepted = 0, checked = 0, bubbles = 0;
    integer flushed = 0, reset_events = 0;
    integer i, k, code;
    logic signed [31:0] vector [0:6];
    logic [31:0] rng = 32'h6a09e667;

    // Model entries are shifted with blocking assignments in oldest-first
    // order. Their input-to-output distance is two edges, independent of RTL.
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            if (qv0 === 1'b1) flushed = flushed + 1;
            if (qv1 === 1'b1) flushed = flushed + 1;
            if (clk === 1'b0) reset_events = reset_events + 1;
            qv0 = 1'b0; qv1 = 1'b0; expected_vld = 1'b0;
            q00 = '0; q01 = '0; q10 = '0; q11 = '0;
            expected0 = '0; expected1 = '0;
            tag0 = 0; tag1 = 0; expected_tag = 0;
        end else begin
            cycles = cycles + 1;
            expected_vld = qv1;
            if (qv1) begin
                expected0 = q10;
                expected1 = q11;
                expected_tag = tag1;
                checked = checked + 1;
            end else bubbles = bubbles + 1;
            qv1 = qv0; q10 = q00; q11 = q01; tag1 = tag0;
            qv0 = en;
            if (en) begin
                accepted = accepted + 1;
                tag0 = accepted;
                q00 = golden(r1_x, r2_x, r3_x, r1_w, r2_w, r3_w);
                q01 = golden(r2_x, r3_x, r4_x, r1_w, r2_w, r3_w);
            end
        end

        // Wait until NBA and the following combinational propagation finish.
        #1;
        if (vld !== expected_vld || r1_res !== expected0 || r2_res !== expected1)
            $fatal(1, "cycle=%0d time=%0t group=%0d expected=(%0d,%0d,v%0b) actual=(%0d,%0d,v%0b)",
                   cycles, $time, expected_tag, expected0, expected1, expected_vld,
                   r1_res, r2_res, vld);
        if (!rstn) begin
            if ({dut.t0_q, dut.t1_q, dut.t2_q, dut.t3_q,
                 dut.u0_q, dut.u1_q, dut.u2_q, dut.u3_q,
                 dut.p0_q, dut.p1_q, dut.p2_q, dut.p3_q,
                 dut.valid_s1, dut.valid_s2} !== '0)
                $fatal(1, "pipeline register not zero during reset at %0t", $time);
        end else if (dut.valid_s2) begin
            if (dut.u_output_transform.s0[0] !== 1'b0 ||
                dut.u_output_transform.s1[0] !== 1'b0)
                $fatal(1, "scaled output not even at cycle %0d", cycles);
        end
    end

    task automatic drive (
        input logic valid,
        input logic signed [31:0] x0, x1, x2, x3, w0, w1, w2
    );
        begin
            @(negedge clk);
            en = valid;
            r1_x = x0; r2_x = x1; r3_x = x2; r4_x = x3;
            r1_w = w0; r2_w = w1; r3_w = w2;
        end
    endtask

    task automatic idle_cycle;
        // Deliberately unknown invalid data: it must never create an output.
        drive(1'b0, 'x, 'x, 'x, 'x, 'x, 'x, 'x);
    endtask

    function automatic logic [31:0] next_random(input logic [31:0] x);
        logic [31:0] a;
        begin
            a = x ^ (x << 13);
            a = a ^ (a >> 17);
            next_random = a ^ (a << 5);
        end
    endfunction

    initial begin
        rstn = 1'b1; en = 1'b0;
        r1_x = '0; r2_x = '0; r3_x = '0; r4_x = '0;
        r1_w = '0; r2_w = '0; r3_w = '0;
        basis[0] = 32'sh80000000;
        basis[1] = 32'sd0;
        basis[2] = 32'sh7fffffff;
        #2 rstn = 1'b0;  // Assert between clock edges.
        @(negedge clk); rstn = 1'b1;

        // Explicit valid pattern 1,1,0,1,0,0, including odd weight sums.
        drive(1'b1, -32'sd10, 32'sd20, -32'sd30, 32'sd40,
              32'sd2, 32'sd3, -32'sd4);
        drive(1'b1, '0, '0, '0, '0, '0, '0, '0);
        idle_cycle();
        drive(1'b1, 32'sd1, -32'sd1, 32'sd1, -32'sd1,
              32'sd1, 32'sd1, 32'sd1);
        idle_cycle(); idle_cycle();

        // All 3^7 combinations of MIN, ZERO, MAX across data and weights.
        // MAX and MIN products/sums exercise wraparound and >64-bit sums.
        for (i = 0; i < 2187; i = i + 1) begin
            code = i;
            for (k = 0; k < 7; k = k + 1) begin
                vector[k] = basis[code % 3];
                code = code / 3;
            end
            drive(1'b1, vector[0], vector[1], vector[2], vector[3],
                  vector[4], vector[5], vector[6]);
        end

        // Deterministic full-width random values, both isolated and long gaps.
        for (i = 0; i < 1000; i = i + 1) begin
            for (k = 0; k < 7; k = k + 1) begin
                rng = next_random(rng);
                vector[k] = $signed(rng);
            end
            drive(1'b1, vector[0], vector[1], vector[2], vector[3],
                  vector[4], vector[5], vector[6]);
            if ((i % 4) == 0) idle_cycle();
            if ((i % 31) == 0) repeat (3) idle_cycle();
        end
        repeat (4) idle_cycle();

        // Both pending stages must be discarded by asynchronous reset.
        drive(1'b1, 32'sd11, 32'sd12, 32'sd13, 32'sd14,
              32'sd2, 32'sd3, 32'sd4);
        drive(1'b1, -32'sd21, 32'sd22, -32'sd23, 32'sd24,
              -32'sd5, 32'sd6, -32'sd7);
        @(negedge clk);
        en = 1'b0;
        #2 rstn = 1'b0;
        repeat (2) @(negedge clk);
        rstn = 1'b1;
        // Drive first post-reset group at this falling edge (no extra wait).
        en = 1'b1;
        r1_x = 32'sh80000000; r2_x = 32'sh7fffffff;
        r3_x = -32'sd1; r4_x = 32'sd1;
        r1_w = -32'sd1; r2_w = 32'sd1; r3_w = 32'sd3;
        repeat (5) idle_cycle();
        #2;
        if (accepted != 3193 || checked != 3191 || flushed != 2 ||
            qv0 !== 1'b0 || qv1 !== 1'b0 || bubbles == 0 || reset_events != 2)
            $fatal(1, "coverage/accounting failure: accepted=%0d checked=%0d flushed=%0d bubbles=%0d resets=%0d",
                   accepted, checked, flushed, bubbles, reset_events);
        $display("ALL PASS: Winograd selfcheck accepted=%0d checked=%0d reset_flushed=%0d bubbles=%0d cycles=%0d",
                 accepted, checked, flushed, bubbles, cycles);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "selfcheck timed out");
    end
endmodule
