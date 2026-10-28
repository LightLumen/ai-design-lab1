`timescale 1ns/1ps
module cordic_selfcheck_tb;
    logic clk = 1'b0;
    logic signed [15:0] Xin, Yin;
    logic [31:0] angle;
    wire signed [15:0] COSout, SINout;
    wire done;
    cordic dut (
        .clk(clk), .Xin(Xin), .Yin(Yin), .angle(angle),
        .COSout(COSout), .SINout(SINout), .done(done)
    );
    always #2 clk = ~clk;

    localparam real PI = 3.14159265358979323846;
    integer atan_reference [0:15];
    real gain;

    // Sequential, 64-bit software model. The angle is first mapped to
    // [-180,180), then reduced, independently of the DUT's unsigned cases.
    function automatic logic [31:0] fixed_reference (
        input logic signed [15:0] xi, yi,
        input logic [31:0] a
    );
        longint signed x, y, z, old_x, old_y;
        integer n;
        begin
            x = $signed(xi); x = x <<< 12;
            y = $signed(yi); y = y <<< 12;
            z = {1'b0, a};
            if (z >= 64'sd2147483648) z = z - 64'sd4294967296;
            if (z >= 64'sd1073741824) begin
                x = -x; y = -y; z = z - 64'sd2147483648;
            end else if (z < -64'sd1073741824) begin
                x = -x; y = -y; z = z + 64'sd2147483648;
            end
            for (n = 0; n < 16; n = n + 1) begin
                old_x = x; old_y = y;
                if (z >= 0) begin
                    x = old_x - (old_y >>> n);
                    y = old_y + (old_x >>> n);
                    z = z - atan_reference[n];
                end else begin
                    x = old_x + (old_y >>> n);
                    y = old_y - (old_x >>> n);
                    z = z + atan_reference[n];
                end
            end
            x = x >>> 12; y = y >>> 12;
            fixed_reference = {x[15:0], y[15:0]};
        end
    endfunction

    function automatic real abs_real(input real value);
        abs_real = value < 0.0 ? -value : value;
    endfunction

    // Sixteen queued edges plus the output edge implement E0 -> E16.
    logic [31:0] model_q [0:15];
    logic [31:0] angle_q [0:15];
    logic signed [15:0] xin_q [0:15], yin_q [0:15];
    real rx_q [0:15], ry_q [0:15];
    integer tag_q [0:15];
    integer cycles = 0, checked = 0, numeric_checked = 0, wrapped_checked = 0;
    integer stage;
    logic [31:0] expected_bits, expected_angle;
    logic signed [15:0] expected_xin, expected_yin;
    integer expected_tag;
    real expected_rx, expected_ry, theta, xr, yr, ex, ey;
    real max_error_x = 0.0, max_error_y = 0.0;

    always @(posedge clk) begin
        cycles = cycles + 1;
        // Capture the old queue tail before shifting this edge's input in.
        expected_bits = model_q[15];
        expected_angle = angle_q[15];
        expected_xin = xin_q[15]; expected_yin = yin_q[15];
        expected_rx = rx_q[15]; expected_ry = ry_q[15];
        expected_tag = tag_q[15];
        for (stage = 15; stage > 0; stage = stage - 1) begin
            model_q[stage] = model_q[stage-1];
            angle_q[stage] = angle_q[stage-1];
            xin_q[stage] = xin_q[stage-1]; yin_q[stage] = yin_q[stage-1];
            rx_q[stage] = rx_q[stage-1]; ry_q[stage] = ry_q[stage-1];
            tag_q[stage] = tag_q[stage-1];
        end
        model_q[0] = fixed_reference(Xin, Yin, angle);
        angle_q[0] = angle; xin_q[0] = Xin; yin_q[0] = Yin;
        tag_q[0] = cycles;
        theta = $itor($unsigned(angle[30:0]));
        if (angle[31]) theta = theta + 2147483648.0;
        theta = theta * (2.0 * PI) / 4294967296.0;
        xr = $itor($signed(Xin)); yr = $itor($signed(Yin));
        rx_q[0] = gain * (xr * $cos(theta) - yr * $sin(theta));
        ry_q[0] = gain * (xr * $sin(theta) + yr * $cos(theta));

        // The no-reset interface gives no guarantee during the first 16 edges.
        #1;
        if (cycles >= 17) begin
            if (done !== 1'b1 || {COSout, SINout} !== expected_bits)
                $fatal(1, "cycle=%0d time=%0t input_edge=%0d Xin=%0d Yin=%0d angle=%08h expected=(%0d,%0d,done=1) actual=(%0d,%0d,done=%b)",
                       cycles, $time, expected_tag, expected_xin, expected_yin,
                       expected_angle, $signed(expected_bits[31:16]),
                       $signed(expected_bits[15:0]), COSout, SINout, done);
            checked = checked + 1;

            // Independent trig reference, excluding wrap boundaries by margin.
            if (abs_real(expected_rx) <= 32760.0 && abs_real(expected_ry) <= 32760.0) begin
                ex = abs_real($itor($signed(COSout)) - expected_rx);
                ey = abs_real($itor($signed(SINout)) - expected_ry);
                if (ex > 8.0 || ey > 8.0)
                    $fatal(1, "numeric error cycle=%0d Xin=%0d Yin=%0d angle=%08h ideal=(%0.6f,%0.6f) got=(%0d,%0d) error=(%0.6f,%0.6f)",
                           cycles, expected_xin, expected_yin, expected_angle,
                           expected_rx, expected_ry, COSout, SINout, ex, ey);
                if (ex > max_error_x) max_error_x = ex;
                if (ey > max_error_y) max_error_y = ey;
                numeric_checked = numeric_checked + 1;
            end
            if (abs_real(expected_rx) >= 32776.0 || abs_real(expected_ry) >= 32776.0)
                wrapped_checked = wrapped_checked + 1;
            if (expected_xin == 16'sd19432 && expected_yin == 16'sd0 &&
                expected_angle[29:0] == 30'd0)
                $display("[AXIS] angle=%08h COSout=%0d SINout=%0d", expected_angle, COSout, SINout);
        end
    end

    task automatic drive (
        input logic signed [15:0] xi, yi,
        input logic [31:0] a
    );
        begin
            @(negedge clk);
            Xin = xi; Yin = yi; angle = a;
        end
    endtask

    function automatic logic [31:0] next_random(input logic [31:0] value);
        logic [31:0] a;
        begin
            a = value ^ (value << 13);
            a = a ^ (a >> 17);
            next_random = a ^ (a << 5);
        end
    endfunction

    logic signed [15:0] basis [0:4];
    logic [31:0] edges [0:14];
    logic [31:0] rng = 32'hbb67ae85, random_angle;
    logic signed [15:0] random_x, random_y;
    logic [63:0] angle_wide;
    integer i, j, k;
    initial begin
        gain = 1.0;
        for (i = 0; i < 16; i = i + 1) begin
            atan_reference[i] = $rtoi($atan(2.0 ** (-i)) * 4294967296.0 / (2.0 * PI) + 0.5);
            gain = gain * $sqrt(1.0 + 2.0 ** (-2*i));
        end
        Xin = 16'sd19432; Yin = 16'sd0; angle = 32'h00000000;
        basis[0] = 16'sh8000; basis[1] = -16'sd19432;
        basis[2] = 16'sd0; basis[3] = 16'sd19432; basis[4] = 16'sh7fff;
        edges[0] = 32'h00000000; edges[1] = 32'h00000001;
        edges[2] = 32'h3fffffff; edges[3] = 32'h40000000;
        edges[4] = 32'h40000001; edges[5] = 32'h7fffffff;
        edges[6] = 32'h80000000; edges[7] = 32'h80000001;
        edges[8] = 32'hbfffffff; edges[9] = 32'hc0000000;
        edges[10] = 32'hc0000001; edges[11] = 32'hfffffffe;
        edges[12] = 32'hffffffff; edges[13] = 32'h20000000;
        edges[14] = 32'he0000000;

        // Full-range vectors (including -32768) and one-BAM-unit boundaries.
        for (i = 0; i < 5; i = i + 1)
            for (j = 0; j < 5; j = j + 1)
                for (k = 0; k < 15; k = k + 1)
                    drive(basis[i], basis[j], edges[k]);

        // One sample per degree, delivered every clock rather than 1000ns apart.
        for (i = 0; i < 360; i = i + 1) begin
            angle_wide = (64'd4294967296 * i) / 64'd360;
            drive(16'sd19432, 16'sd0, angle_wide[31:0]);
        end
        // Angle stays fixed while both vector components change each cycle.
        for (i = 0; i < 32; i = i + 1)
            drive(16'(i * 137 - 2000), 16'(1500 - i * 83), 32'h20000000);
        repeat (4) drive(16'sd1234, -16'sd2345, 32'h20000000);

        for (i = 0; i < 1000; i = i + 1) begin
            rng = next_random(rng); random_x = $signed(rng[15:0]);
            rng = next_random(rng); random_y = $signed(rng[15:0]);
            rng = next_random(rng); random_angle = rng;
            drive(random_x, random_y, random_angle);
        end
        repeat (18) drive(16'sd0, 16'sd0, 32'h00000000);
        @(negedge clk);
        if (checked != 1774 || cycles != 1790 || numeric_checked < 500 || wrapped_checked < 100)
            $fatal(1, "coverage failure cycles=%0d checked=%0d numeric=%0d wrapped=%0d",
                   cycles, checked, numeric_checked, wrapped_checked);
        $display("ALL PASS: CORDIC selfcheck checked=%0d numeric=%0d wrapped=%0d cycles=%0d max_error_x=%0.6f max_error_y=%0.6f",
                 checked, numeric_checked, wrapped_checked, cycles, max_error_x, max_error_y);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "selfcheck timed out");
    end
endmodule
