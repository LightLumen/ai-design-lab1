`timescale 1ns/1ps
// Separate simulation-only top: leave the DUT and original testbench intact.
module winograd_wave_dump;
    initial begin
        $dumpfile("build/winograd/winograd_public.vcd");
        $dumpvars(0, winograd_1d_tb);
    end
endmodule
