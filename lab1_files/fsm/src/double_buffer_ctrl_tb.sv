`timescale 1ns/1ps

module double_buffer_ctrl_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rstn = 1'b0;
    reg start = 1'b0;
    reg load_done = 1'b0;
    reg compute_done = 1'b0;
    wire load_req;
    wire [1:0] load_tile;
    wire load_buf;
    wire compute_req;
    wire [1:0] compute_tile;
    wire compute_buf;
    wire busy;
    wire done;

    double_buffer_ctrl dut (
        .clk(clk), .rstn(rstn), .start(start),
        .load_done(load_done), .compute_done(compute_done),
        .load_req(load_req), .load_tile(load_tile), .load_buf(load_buf),
        .compute_req(compute_req), .compute_tile(compute_tile),
        .compute_buf(compute_buf), .busy(busy), .done(done)
    );

    integer load_latency = 3;
    integer compute_latency = 8;
    integer load_timer;
    integer compute_timer;
    integer next_load;
    integer next_compute;
    integer completed;
    integer done_count;
    reg load_active;
    reg compute_active;
    reg [1:0] inflight_load_tile;
    reg [1:0] inflight_compute_tile;
    reg inflight_load_buf;
    reg inflight_compute_buf;
    reg [2:0] tile_loaded;
    reg overlap_seen;
    reg prev_load_req;
    reg prev_compute_req;
    reg job_accepted;

    // Model two independent engines. Responses are never in the request cycle.
    always @(negedge clk) begin
        load_done = 1'b0;
        compute_done = 1'b0;
        if (rstn) begin
            if (load_active && load_timer > 0) begin
                load_timer = load_timer - 1;
                if (load_timer == 0) load_done = 1'b1;
            end
            if (compute_active && compute_timer > 0) begin
                compute_timer = compute_timer - 1;
                if (compute_timer == 0) compute_done = 1'b1;
            end
        end
    end

    // Public scoreboard: check ordering, dependencies, resource conflicts,
    // one-cycle request pulses, completion, and actual load/compute overlap.
    always @(posedge clk) begin
        if (!rstn) begin
            load_timer = 0;
            compute_timer = 0;
            next_load = 0;
            next_compute = 0;
            completed = 0;
            done_count = 0;
            load_active = 1'b0;
            compute_active = 1'b0;
            tile_loaded = 3'b000;
            overlap_seen = 1'b0;
            prev_load_req = 1'b0;
            prev_compute_req = 1'b0;
            job_accepted = 1'b0;
        end else begin
            if (load_done) begin
                if (!load_active) $fatal(1, "load_done without a load request");
                load_active = 1'b0;
                tile_loaded[inflight_load_tile] = 1'b1;
            end
            if (compute_done) begin
                if (!compute_active) $fatal(1, "compute_done without a compute request");
                compute_active = 1'b0;
                completed = completed + 1;
            end
            if (job_accepted && completed < 3 && busy !== 1'b1)
                $fatal(1, "busy dropped before the job finished");

            if (load_req !== 1'b0 && load_req !== 1'b1)
                $fatal(1, "load_req is X/Z");
            if (compute_req !== 1'b0 && compute_req !== 1'b1)
                $fatal(1, "compute_req is X/Z");
            if (done !== 1'b0 && done !== 1'b1)
                $fatal(1, "done is X/Z");
            if (load_req && prev_load_req)
                $fatal(1, "load_req must be a one-cycle pulse");
            if (compute_req && prev_compute_req)
                $fatal(1, "compute_req must be a one-cycle pulse");

            if (load_req) begin
                if (busy !== 1'b1 || load_active || next_load >= 3)
                    $fatal(1, "invalid load request");
                if (load_tile !== next_load[1:0] || load_buf !== next_load[0])
                    $fatal(1, "load tile/buffer order is wrong");
                if (compute_active && inflight_compute_buf == load_buf)
                    $fatal(1, "loading a buffer being computed");
                if (next_load == 2 && completed < 1)
                    $fatal(1, "buffer 0 reused before tile 0 completed");
                load_active = 1'b1;
                inflight_load_tile = load_tile;
                inflight_load_buf = load_buf;
                load_timer = load_latency;
                next_load = next_load + 1;
            end

            if (compute_req) begin
                if (busy !== 1'b1 || compute_active || next_compute >= 3)
                    $fatal(1, "invalid compute request");
                if (compute_tile !== next_compute[1:0] || compute_buf !== next_compute[0])
                    $fatal(1, "compute tile/buffer order is wrong");
                if (tile_loaded[compute_tile] !== 1'b1)
                    $fatal(1, "computing a tile before its load completed");
                if (load_active && inflight_load_buf == compute_buf)
                    $fatal(1, "computing a buffer being loaded");
                compute_active = 1'b1;
                inflight_compute_tile = compute_tile;
                inflight_compute_buf = compute_buf;
                compute_timer = compute_latency;
                next_compute = next_compute + 1;
            end

            if (load_active && compute_active) overlap_seen = 1'b1;
            if (done) begin
                if (completed != 3 || load_active || compute_active)
                    $fatal(1, "done asserted before all three tiles completed");
                done_count = done_count + 1;
                if (done_count != 1) $fatal(1, "done must be a single pulse");
                job_accepted = 1'b0;
            end
            if (!job_accepted && start && busy === 1'b0)
                job_accepted = 1'b1;
            prev_load_req = load_req;
            prev_compute_req = compute_req;
        end
    end

    task automatic run_case(input integer load_cycles, input integer compute_cycles);
        integer cycles;
        begin
            @(negedge clk);
            rstn = 1'b0;
            start = 1'b0;
            load_latency = load_cycles;
            compute_latency = compute_cycles;
            repeat (3) @(negedge clk);
            rstn = 1'b1;
            @(negedge clk) start = 1'b1;
            @(negedge clk) start = 1'b0;
            // A request during an active job must not create another job.
            repeat (5) @(negedge clk);
            start = 1'b1;
            @(negedge clk) start = 1'b0;
            for (cycles = 0; cycles < 200 && done_count == 0; cycles = cycles + 1)
                @(negedge clk);
            if (done_count != 1 || next_load != 3 || next_compute != 3 || completed != 3)
                $fatal(1, "three-tile job did not finish correctly");
            if (!overlap_seen)
                $fatal(1, "load and compute never overlapped");
            repeat (5) @(negedge clk);
            if (busy !== 1'b0 || done_count != 1)
                $fatal(1, "controller did not return to idle");
            $display("PASS: load latency=%0d compute latency=%0d", load_cycles, compute_cycles);
        end
    endtask

    task automatic reset_mid_job;
        begin
            @(negedge clk) rstn = 1'b0;
            repeat (2) @(negedge clk);
            rstn = 1'b1;
            @(negedge clk) start = 1'b1;
            @(negedge clk) start = 1'b0;
            wait (load_active);
            @(negedge clk) rstn = 1'b0;
            repeat (3) @(negedge clk);
            if (busy !== 1'b0 || done !== 1'b0 || load_req !== 1'b0 || compute_req !== 1'b0)
                $fatal(1, "reset did not stop the active job");
            $display("PASS: reset during an active job");
        end
    endtask

    initial begin
        run_case(3, 8);
        reset_mid_job();
        run_case(8, 3);
        $display("ALL PASS");
        $finish;
    end
endmodule
