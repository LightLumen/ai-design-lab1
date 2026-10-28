`timescale 1ns/1ps
module env_check;
    logic signed [31:0] negative_value;
    integer cosine;
    function automatic longint abs_diff(input longint a, input longint b);
        abs_diff = a >= b ? a - b : b - a;
    endfunction
    initial begin
        negative_value = -32'sd7;
        cosine = 32000 * $cos(0.0);
        #1;
        if ((negative_value >>> 1) !== -32'sd4 || cosine != 32000 ||
            abs_diff(-64'sd1099511627776, 64'sd1) != 64'sd1099511627777)
            $fatal(1, "Environment feature check failed");
        $display("ENV_CHECK_PASS: SystemVerilog, signed arithmetic, longint, real math");
        $finish;
    end
endmodule
