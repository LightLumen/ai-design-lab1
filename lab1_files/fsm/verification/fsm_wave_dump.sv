`timescale 1ns/1ps
module fsm_wave_dump;
    initial begin
        $dumpfile("build/fsm/fsm_public.vcd");
        $dumpvars(0, double_buffer_ctrl_tb);
    end
endmodule
