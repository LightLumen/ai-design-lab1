`timescale 1ns/1ps
module cordic_wave_dump;
    initial begin
        $dumpfile("build/cordic/cordic_public.vcd");
        $dumpvars(0, cordic_tb);
    end
endmodule
