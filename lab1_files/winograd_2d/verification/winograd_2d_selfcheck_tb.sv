`timescale 1ns/1ps
module winograd_2d_selfcheck_tb;
    bit clk;
    logic rstn, en;
    logic [511:0] x_flat;
    logic [287:0] w_flat;
    wire [127:0] res_flat;
    wire vld;
    winograd_2d dut(.*);
    always #5 clk = ~clk;

    function automatic logic [127:0] direct(input logic [511:0] x, input logic [287:0] w);
        logic signed [67:0] sum;
        for (int r=0; r<2; r++)
            for (int c=0; c<2; c++) begin
                sum = 0;
                for (int i=0; i<3; i++)
                    for (int j=0; j<3; j++)
                        sum += $signed(x[32*((r+i)*4+c+j) +: 32])
                             * $signed(w[32*(i*3+j) +: 32]);
                direct[32*(2*r+c) +: 32] = sum[31:0];
            end
    endfunction

    logic [127:0] gold [0:2];
    bit [2:0] valid;
    int checked, flushed, accepted;
    always @(posedge clk) begin
        if (!rstn) begin
            flushed += int'(valid[0]) + int'(valid[1]);
            valid = 0;
        end else begin
            valid = {valid[1:0], en};
            accepted += int'(en);
            gold[2] = gold[1];
            gold[1] = gold[0];
            gold[0] = direct(x_flat, w_flat);
        end
        #1;
        if (vld !== valid[2] || (!rstn && res_flat !== '0))
            $fatal(1, "reset/valid mismatch at %t", $time);
        if (valid[2]) begin
            if (res_flat !== gold[2])
                $fatal(1, "at %t expected %h got %h", $time, gold[2], res_flat);
            checked++;
        end
    end

    initial begin
        rstn=0; en=0; x_flat=0; w_flat=0;
        for (int k=0; k<1200; k++) begin
            @(negedge clk);
            rstn = k != 150;
            en = k<160 || $urandom_range(3)!=0;
            for (int i=0; i<16; i++) x_flat[32*i +: 32] = $urandom;
            for (int i=0; i<9; i++) w_flat[32*i +: 32] = $urandom;
            if (k<144) begin
                x_flat=0; w_flat=0;
                x_flat[32*(k/9) +: 32] = -1;
                w_flat[32*(k%9) +: 32] = 1;
            end else if (k<148) begin
                x_flat = {16{(k%2) ? 32'h80000000 : 32'h7fffffff}};
                w_flat = {9{(k<146) ? 32'h80000000 : 32'h7fffffff}};
            end
        end
        @(negedge clk); en=0;
        repeat(3) @(negedge clk);
        if (checked+flushed!=accepted || flushed!=2 || checked<800)
            $fatal(1, "coverage failure");
        $display("ALL PASS: 2D Winograd accepted=%0d checked=%0d reset_flushed=%0d",
                 accepted, checked, flushed);
        $finish;
    end
endmodule
