`timescale 1ns/1ps

module winograd_1d_tb;
    reg clk;
    reg rstn;
    reg en;
    reg signed [31:0] r1_x, r2_x, r3_x, r4_x;
    reg signed [31:0] r1_w, r2_w, r3_w;
    wire signed [31:0] r1_res, r2_res;
    wire vld;

    // Instantiate DUT
    winograd_1d dut (
        .clk(clk),
        .rstn(rstn),
        .en(en),
        .r1_x(r1_x), .r2_x(r2_x), .r3_x(r3_x), .r4_x(r4_x),
        .r1_w(r1_w), .r2_w(r2_w), .r3_w(r3_w),
        .r1_res(r1_res), .r2_res(r2_res),
        .vld(vld)
    );

    // Golden Model
    reg signed [31:0] expected_r1_res [9:0];
    reg signed [31:0] expected_r2_res [9:0];
    parameter TOLERANCE = 0;
    integer passed=0, failed=0; 

    task calc_expected_results;
            input signed [31:0] x1, x2, x3, x4;
            input signed [31:0] w1, w2, w3;
            output signed [31:0] exp_r1, exp_r2;
        begin
            exp_r1 = x1 * w1 + x2 * w2 + x3 * w3;
            exp_r2 = x2 * w1 + x3 * w2 + x4 * w3;
        end
    endtask

    task compare_results;
            input [15:0] case_no;
            input signed [31:0] exp_r1, exp_r2;
            input signed [31:0] res_r1, res_r2;
        begin
            if (res_r1 !== exp_r1 || res_r2 !== exp_r2 || vld !== 1'b1) begin
                failed=failed+1;
                $display("[Case %d] ERROR at %0t: Expected r1_res=%d, r2_res=%d; Got r1_res=%d, r2_res=%d",
                        case_no, $time, exp_r1, exp_r2, r1_res, r2_res);
            end else begin
                passed=passed+1;
                $display("[Case %d] PASS at %0t: Expected r1_res=%d, r2_res=%d; Got r1_res=%d, r2_res=%d",
                        case_no, $time, exp_r1, exp_r2, r1_res, r2_res);
            end
        end
    endtask


    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rstn = 0;
        en = 0;
        r1_x = 0; r2_x = 0; r3_x = 0; r4_x = 0;
        r1_w = 0; r2_w = 0; r3_w = 0;
        
        #10 rstn = 1;
        
        // Case 0
        #10 en = 1;
        r1_x = -32'sd10; r2_x = 32'sd20;
        r3_x = -32'sd30; r4_x = 32'sd40;
        r1_w = 32'sd2; r2_w = 32'sd3; r3_w = -32'sd4;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[0], expected_r2_res[0]);

        // Case 1
        #10 en = 1;
        r1_x = 32'sd0; r2_x = 32'sd0;
        r3_x = 32'sd0; r4_x = 32'sd0;
        r1_w = 32'sd0; r2_w = 32'sd0; r3_w = 32'sd0;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[1], expected_r2_res[1]);

        // Case 2
        #10 en = 1;
        r1_x = 32'sd5000; r2_x = -32'sd1532;
        r3_x = 32'sd2532; r4_x = -32'sd3533;
        r1_w = 32'sd104; r2_w = -32'sd232; r3_w = 32'sd353;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[2], expected_r2_res[2]);

        // Case 3
        # 10 en = 1;
        r1_x = 32'sd32767; r2_x = 32'sd32767; 
        r3_x = 32'sd32767; r4_x = 32'sd32767;
        r1_w = 32'sd32767; r2_w = -32'sd32767; r3_w = 32'sd32767;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[3], expected_r2_res[3]);

        // Case 4
        # 10 en = 1;
        r1_x = -32'sd32768; r2_x = -32'sd32768;
        r3_x = -32'sd32768; r4_x = -32'sd32768;
        r1_w = -32'sd32768; r2_w = 32'sd32768; r3_w = -32'sd32768;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[4], expected_r2_res[4]);

        // Case 5
        # 10 en = 1;
        r1_x = 32'sd1; r2_x = 32'sd1;
        r3_x = 32'sd1; r4_x = 32'sd1;
        r1_w = 32'sd1; r2_w = 32'sd1; r3_w = 32'sd1;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[5], expected_r2_res[5]);

        // Case 6
        # 10 en = 1;
        r1_x = 32'sd1; r2_x = -32'sd1;
        r3_x = 32'sd1; r4_x = -32'sd1;
        r1_w = 32'sd2; r2_w = 32'sd2; r3_w = 32'sd2;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[6], expected_r2_res[6]);

        // Case 7
        # 10 en = 1;
        r1_x = -32'sd1898; r2_x = -32'sd0504;
        r3_x = -32'sd2025; r4_x = -32'sd0310;
        r1_w = -32'sd32768; r2_w = -32'sd32768; r3_w = -32'sd32768;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[7], expected_r2_res[7]);

        // Case 8
        # 10 en = 1;
        r1_x = 32'sd1073741823; r2_x = 32'sd1073741823;
        r3_x = 32'sd1073741823; r4_x = 32'sd1073741823;
        r1_w = 32'sd1; r2_w = 32'sd0; r3_w = 32'sd1;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[8], expected_r2_res[8]);

        // Case 9
        # 10 en = 1;
        r1_x = -32'sd1073741824; r2_x = -32'sd1073741824;
        r3_x = -32'sd1073741824; r4_x = -32'sd1073741824;
        r1_w = -32'sd1; r2_w = 32'sd1; r3_w = -32'sd2;
        calc_expected_results(r1_x, r2_x, r3_x, r4_x, r1_w, r2_w, r3_w, expected_r1_res[9], expected_r2_res[9]);

        # 10 en = 0;
        
        // Stop simulation after some time
        #100;
        if (failed != 0 || passed != 10) $fatal(1,"FAIL: passed=%0d failed=%0d",passed,failed);
        $display("ALL PASS: Winograd, 10 cases");
        $finish;
    end

    initial begin
        # 45;
        # 1 compare_results(0,expected_r1_res[0], expected_r2_res[0], r1_res, r2_res);
        # 10 compare_results(1,expected_r1_res[1], expected_r2_res[1], r1_res, r2_res);
        # 10 compare_results(2,expected_r1_res[2], expected_r2_res[2], r1_res, r2_res);
        # 10 compare_results(3,expected_r1_res[3], expected_r2_res[3], r1_res, r2_res);
        # 10 compare_results(4,expected_r1_res[4], expected_r2_res[4], r1_res, r2_res);
        # 10 compare_results(5,expected_r1_res[5], expected_r2_res[5], r1_res, r2_res);
        # 10 compare_results(6,expected_r1_res[6], expected_r2_res[6], r1_res, r2_res);
        # 10 compare_results(7,expected_r1_res[7], expected_r2_res[7], r1_res, r2_res);
        # 10 compare_results(8,expected_r1_res[8], expected_r2_res[8], r1_res, r2_res);
        # 10 compare_results(9,expected_r1_res[9], expected_r2_res[9], r1_res, r2_res);
    end

    // Monitor output
    initial begin
        $monitor($time, " en=%b, r1_res=%d, r2_res=%d, vld=%b", en, r1_res, r2_res, vld);
    end

    // Dump waveform for Verdi
`ifndef NO_FSDB
    initial begin
        $fsdbDumpfile("winograd_1d_tb.fsdb");
	    $fsdbDumpvars("+all");
    end
`endif


endmodule
