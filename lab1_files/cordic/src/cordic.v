`timescale 1ns/1ps
module cordic (
    input  logic               clk,
    input  logic signed [15:0] Xin,
    input  logic signed [15:0] Yin,
    input  logic        [31:0] angle,
    output logic signed [15:0] COSout,
    output logic signed [15:0] SINout,
    output logic               done
);
    // One coarse-rotation boundary plus sixteen micro-rotation boundaries.
    // x/y are signed 32-bit fixed point with twelve fractional bits.
    logic signed [31:0] x_q [0:15];
    logic signed [31:0] y_q [0:15];
    logic signed [32:0] z_q [0:15];
    logic signed [31:0] x_extended, y_extended, x_fixed, y_fixed;
    logic signed [32:0] angle_extended;
    logic [16:0] warm_q;

    localparam logic signed [32:0] HALF_TURN = 33'sh080000000;

    // round(atan(2^-i) * 2^32 / (2*pi)); constant elaboration-time lookup.
    function automatic logic signed [32:0] atan_bam(input integer index);
        case (index)
             0: atan_bam = 33'sh020000000;
             1: atan_bam = 33'sh012e4051e;
             2: atan_bam = 33'sh009fb385b;
             3: atan_bam = 33'sh0051111d4;
             4: atan_bam = 33'sh0028b0d43;
             5: atan_bam = 33'sh00145d7e1;
             6: atan_bam = 33'sh000a2f61e;
             7: atan_bam = 33'sh000517c55;
             8: atan_bam = 33'sh00028be53;
             9: atan_bam = 33'sh000145f2f;
            10: atan_bam = 33'sh0000a2f98;
            11: atan_bam = 33'sh0000517cc;
            12: atan_bam = 33'sh000028be6;
            13: atan_bam = 33'sh0000145f3;
            14: atan_bam = 33'sh00000a2fa;
            15: atan_bam = 33'sh00000517d;
            default: atan_bam = '0;
        endcase
    endfunction

    // Widen before shifting or negating: -16'sh8000 cannot fit in 16 bits.
    assign x_extended = $signed({{16{Xin[15]}}, Xin});
    assign y_extended = $signed({{16{Yin[15]}}, Yin});
    assign x_fixed = x_extended <<< 5'd12;
    assign y_fixed = y_extended <<< 5'd12;
    assign angle_extended = $signed({1'b0, angle});

    // E0: reduce to [-90,90) degrees with an optional half-turn vector flip.
    always_ff @(posedge clk) begin
        if ((angle >= 32'h40000000) && (angle < 32'hc0000000)) begin
            x_q[0] <= -x_fixed;
            y_q[0] <= -y_fixed;
            z_q[0] <= angle_extended - HALF_TURN;
        end else begin
            x_q[0] <= x_fixed;
            y_q[0] <= y_fixed;
            if (angle >= 32'hc0000000)
                // Here angle-2^32 is negative: explicitly encode its sign.
                // Positive 2^32 itself does NOT fit in signed 33 bits.
                z_q[0] <= $signed({1'b1, angle});
            else
                z_q[0] <= angle_extended;
        end
        // No reset/initialization: startup data and done are unspecified.
        // After seventeen clock edges all bits have become known ones.
        warm_q <= {warm_q[15:0], 1'b1};
    end
    assign done = warm_q[16];

    // E1..E15: iterations i=0..14, statically unrolled. Each shift is wiring.
    generate
        for (genvar i = 0; i < 15; i = i + 1) begin : g_rotate
            localparam logic signed [32:0] A = atan_bam(i);
            logic signed [31:0] x_shift, y_shift;
            assign x_shift = $signed(x_q[i]) >>> i;
            assign y_shift = $signed(y_q[i]) >>> i;
            always_ff @(posedge clk) begin
                if (!z_q[i][32]) begin
                    x_q[i+1] <= x_q[i] - y_shift;
                    y_q[i+1] <= y_q[i] + x_shift;
                    z_q[i+1] <= z_q[i] - A;
                end else begin
                    x_q[i+1] <= x_q[i] + y_shift;
                    y_q[i+1] <= y_q[i] - x_shift;
                    z_q[i+1] <= z_q[i] + A;
                end
            end
        end
    endgenerate

    logic signed [31:0] x_last, y_last, x_integer, y_integer;
    logic signed [31:0] x_last_shift, y_last_shift;
    assign x_last_shift = $signed(x_q[15]) >>> 5'd15;
    assign y_last_shift = $signed(y_q[15]) >>> 5'd15;
    assign x_last = z_q[15][32] ? (x_q[15] + y_last_shift)
                                          : (x_q[15] - y_last_shift);
    assign y_last = z_q[15][32] ? (y_q[15] - x_last_shift)
                                          : (y_q[15] + x_last_shift);

    // Intentional fractional-bit removal: arithmetic floor, including negatives.
    assign x_integer = x_last >>> 5'd12;
    assign y_integer = y_last >>> 5'd12;

    // E16: final i=15 rotation and output quantization share one boundary.
    // No extra x16/y16 register stage, and no duplicate gain compensation.
    always_ff @(posedge clk) begin
        // Intentional truncation: wrap modulo 2^16, no saturation.
        COSout <= $signed(x_integer[15:0]);
        SINout <= $signed(y_integer[15:0]);
    end
endmodule
