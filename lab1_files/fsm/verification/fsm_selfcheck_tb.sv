`timescale 1ns/1ps
module fsm_selfcheck_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rstn = 1'b1, start = 1'b0;
    logic load_done = 1'b0, compute_done = 1'b0;
    wire load_req, load_buf, compute_req, compute_buf, busy, done;
    wire [1:0] load_tile, compute_tile;
    double_buffer_ctrl dut (
        .clk(clk), .rstn(rstn), .start(start),
        .load_done(load_done), .compute_done(compute_done),
        .load_req(load_req), .load_tile(load_tile), .load_buf(load_buf),
        .compute_req(compute_req), .compute_tile(compute_tile),
        .compute_buf(compute_buf), .busy(busy), .done(done)
    );

    localparam integer EMPTY = 0, LOADING = 1, READY = 2, COMPUTING = 3;
    integer owner [0:1], tile_in_buffer [0:1];
    logic l_active = 1'b0, c_active = 1'b0, job_live = 1'b0;
    integer l_tile, l_buf, c_tile, c_buf, l_timer, c_timer;
    integer next_l, next_c, completed, done_in_job;
    logic overlap_in_job, prev_lreq, prev_creq, prev_done;
    logic [1:0] prev_ltile, prev_ctile;
    logic prev_lbuf, prev_cbuf;
    integer cycles = 0, jobs_accepted = 0, jobs_completed = 0, aborted = 0;
    integer overlap_cycles = 0, simultaneous_done = 0, spurious_seen = 0;
    integer load_requests = 0, compute_requests = 0;
    integer fixed_l = 3, fixed_c = 8;
    logic random_mode = 1'b0, inject_spurious = 1'b0;
    logic [31:0] rng = 32'h3c6ef372;
    logic accepted_now, finished_now;

    function automatic integer latency(input logic is_compute);
        begin
            if (random_mode) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                latency = 1 + (rng % 9);
            end else latency = is_compute ? fixed_c : fixed_l;
        end
    endfunction

    // Independent engines observe requests at posedge. A latency of one
    // means response at the following posedge, never the receiving edge.
    always @(negedge clk) begin
        load_done = 1'b0;
        compute_done = 1'b0;
        if (rstn) begin
            if (l_active && l_timer > 0) begin
                l_timer = l_timer - 1;
                if (l_timer == 0) load_done = 1'b1;
            end
            if (c_active && c_timer > 0) begin
                c_timer = c_timer - 1;
                if (c_timer == 0) compute_done = 1'b1;
            end
            if (inject_spurious && !l_active) load_done = 1'b1;
            if (inject_spurious && !c_active) compute_done = 1'b1;
        end
    end

    // Event-based reference: buffer ownership follows externally observed
    // requests/completions, with no hierarchical reads of DUT state.
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            if (job_live) aborted = aborted + 1;
            job_live = 1'b0;
            l_active = 1'b0; c_active = 1'b0;
            l_timer = 0; c_timer = 0;
            next_l = 0; next_c = 0; completed = 0; done_in_job = 0;
            owner[0] = EMPTY; owner[1] = EMPTY;
            tile_in_buffer[0] = -1; tile_in_buffer[1] = -1;
            overlap_in_job = 1'b0;
            prev_lreq = 1'b0; prev_creq = 1'b0; prev_done = 1'b0;
            prev_ltile = 2'd0; prev_ctile = 2'd0;
            prev_lbuf = 1'b0; prev_cbuf = 1'b0;
            accepted_now = 1'b0; finished_now = 1'b0;
        end else begin
            cycles = cycles + 1;
            if ((^{load_req, load_tile, load_buf, compute_req, compute_tile,
                    compute_buf, busy, done}) === 1'bx)
                $fatal(1, "X/Z cycle=%0d", cycles);
            if ((load_req && prev_lreq) || (compute_req && prev_creq) || (done && prev_done))
                $fatal(1, "pulse width cycle=%0d req=(%b,%b) done=%b", cycles, load_req, compute_req, done);
            if (!load_req && ({load_tile, load_buf} !== {prev_ltile, prev_lbuf}))
                $fatal(1, "inactive load metadata changed cycle=%0d", cycles);
            if (!compute_req && ({compute_tile, compute_buf} !== {prev_ctile, prev_cbuf}))
                $fatal(1, "inactive compute metadata changed cycle=%0d", cycles);

            accepted_now = start && !busy;
            finished_now = compute_done && c_active && (c_tile == 2);
            if (load_done && compute_done && l_active && c_active)
                simultaneous_done = simultaneous_done + 1;
            if (load_done) begin
                if (l_active) begin
                    if (owner[l_buf] != LOADING || tile_in_buffer[l_buf] != l_tile)
                        $fatal(1, "load completion ownership cycle=%0d tile=%0d buf=%0d", cycles, l_tile, l_buf);
                    owner[l_buf] = READY;
                    l_active = 1'b0;
                end else spurious_seen = spurious_seen + 1;
            end
            if (compute_done) begin
                if (c_active) begin
                    if (owner[c_buf] != COMPUTING || tile_in_buffer[c_buf] != c_tile)
                        $fatal(1, "compute completion ownership cycle=%0d tile=%0d buf=%0d", cycles, c_tile, c_buf);
                    owner[c_buf] = EMPTY;
                    c_active = 1'b0;
                    completed = completed + 1;
                end else spurious_seen = spurious_seen + 1;
            end
            if (job_live && completed < 3 && busy !== 1'b1)
                $fatal(1, "busy dropped cycle=%0d completed=%0d", cycles, completed);

            if (load_req) begin
                if (!job_live || !busy || l_active || next_l >= 3 ||
                    load_tile !== next_l[1:0] || load_buf !== next_l[0] ||
                    owner[load_buf] != EMPTY || (next_l == 2 && completed < 1))
                    $fatal(1, "load scheduling cycle=%0d tile=%0d buf=%0d next=%0d owner=%0d active=%b completed=%0d",
                           cycles, load_tile, load_buf, next_l, owner[load_buf], l_active, completed);
                l_active = 1'b1; l_tile = next_l; l_buf = load_buf;
                owner[l_buf] = LOADING; tile_in_buffer[l_buf] = l_tile;
                l_timer = latency(1'b0); next_l = next_l + 1;
                load_requests = load_requests + 1;
            end
            if (compute_req) begin
                if (!job_live || !busy || c_active || next_c >= 3 ||
                    compute_tile !== next_c[1:0] || compute_buf !== next_c[0] ||
                    owner[compute_buf] != READY || tile_in_buffer[compute_buf] != next_c)
                    $fatal(1, "compute scheduling cycle=%0d tile=%0d buf=%0d next=%0d owner=%0d active=%b",
                           cycles, compute_tile, compute_buf, next_c, owner[compute_buf], c_active);
                c_active = 1'b1; c_tile = next_c; c_buf = compute_buf;
                owner[c_buf] = COMPUTING;
                c_timer = latency(1'b1); next_c = next_c + 1;
                compute_requests = compute_requests + 1;
            end
            if (l_active && c_active) begin
                if (l_buf == c_buf) $fatal(1, "same-buffer overlap cycle=%0d", cycles);
                overlap_in_job = 1'b1;
                overlap_cycles = overlap_cycles + 1;
            end
            if (done) begin
                if (!job_live || completed != 3 || next_l != 3 || next_c != 3 ||
                    l_active || c_active || !overlap_in_job || done_in_job != 0 || busy)
                    $fatal(1, "job completion cycle=%0d loaded=%0d computed=%0d completed=%0d overlap=%b",
                           cycles, next_l, next_c, completed, overlap_in_job);
                done_in_job = 1;
                jobs_completed = jobs_completed + 1;
                job_live = 1'b0;
            end
            if (accepted_now) begin
                if (job_live || l_active || c_active)
                    $fatal(1, "new job accepted while occupied cycle=%0d", cycles);
                job_live = 1'b1;
                jobs_accepted = jobs_accepted + 1;
                next_l = 0; next_c = 0; completed = 0; done_in_job = 0;
                owner[0] = EMPTY; owner[1] = EMPTY;
                overlap_in_job = 1'b0;
            end
            prev_lreq = load_req; prev_creq = compute_req; prev_done = done;
            prev_ltile = load_tile; prev_lbuf = load_buf;
            prev_ctile = compute_tile; prev_cbuf = compute_buf;
        end
        #1; // Inspect newly registered outputs after NBA, separately.
        if (!rstn) begin
            if ({busy, done, load_req, compute_req, load_tile, load_buf,
                 compute_tile, compute_buf} !== '0)
                $fatal(1, "asynchronous reset did not clear outputs time=%0t", $time);
        end else begin
            if (accepted_now && {busy, load_req, load_tile, load_buf} !== 5'b11000)
                $fatal(1, "start did not issue tile0 after NBA cycle=%0d", cycles);
            if (finished_now && {done, busy, load_req, compute_req} !== 4'b1000)
                $fatal(1, "final completion/done timing cycle=%0d", cycles);
        end
    end

    task automatic wait_completed(input integer target);
        integer timeout;
        begin
            timeout = 0;
            while (jobs_completed < target && timeout < 300) begin
                @(negedge clk); timeout = timeout + 1;
            end
            if (jobs_completed != target)
                $fatal(1, "timeout target=%0d completed=%0d next=(%0d,%0d)", target, jobs_completed, next_l, next_c);
        end
    endtask

    task automatic run_job(input integer lc, cc, input logic randomized);
        integer target;
        begin
            target = jobs_completed + 1;
            @(negedge clk);
            fixed_l = lc; fixed_c = cc; random_mode = randomized;
            start = 1'b1;
            @(negedge clk); start = 1'b0;
            // One-cycle start while busy must not queue an extra job.
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            wait_completed(target);
            repeat (3) @(negedge clk);
            if (busy || job_live || load_req || compute_req || done)
                $fatal(1, "not quiet after job cycle=%0d", cycles);
        end
    endtask

    task automatic abort_job(input integer phase);
        begin
            @(negedge clk);
            fixed_l = 6; fixed_c = 6; random_mode = 1'b0;
            start = 1'b1;
            @(negedge clk); start = 1'b0;
            case (phase)
                0: wait (l_active && !c_active);
                1: wait (l_active && c_active);
                2: wait (c_active && c_tile == 2 && !l_active);
            endcase
            @(negedge clk);
            #2 rstn = 1'b0; // Assert away from either clock edge.
            repeat (2) @(negedge clk);
            rstn = 1'b1;
            repeat (3) @(negedge clk);
            if (busy || done || load_req || compute_req || job_live)
                $fatal(1, "reset left stale work phase=%0d", phase);
        end
    endtask

    integer l, c, i, accept_target, complete_target;
    initial begin
        #1 rstn = 1'b0;
        repeat (2) @(negedge clk);
        rstn = 1'b1;

        // No requests in idle, even in the presence of stray completions.
        @(negedge clk); inject_spurious = 1'b1;
        repeat (3) @(negedge clk);
        inject_spurious = 1'b0;
        repeat (2) @(negedge clk);

        for (l = 1; l <= 5; l = l + 1)
            for (c = 1; c <= 5; c = c + 1)
                run_job(l, c, 1'b0);
        for (i = 0; i < 20; i = i + 1) run_job(1, 1, 1'b1);

        // Holding start high requests a new job only after returning idle.
        accept_target = jobs_accepted + 2;
        complete_target = jobs_completed + 2;
        @(negedge clk);
        fixed_l = 3; fixed_c = 4; random_mode = 1'b0; start = 1'b1;
        wait (jobs_accepted == accept_target);
        @(negedge clk); start = 1'b0;
        wait_completed(complete_target);
        repeat (3) @(negedge clk);

        for (i = 0; i < 3; i = i + 1) begin
            abort_job(i);
            run_job(2, 3, 1'b0);
        end
        if (jobs_completed != 50 || jobs_accepted != 53 || aborted != 3 ||
            simultaneous_done == 0 || overlap_cycles == 0 || spurious_seen == 0)
            $fatal(1, "coverage failure accepted=%0d completed=%0d aborted=%0d simultaneous=%0d overlap=%0d stray=%0d",
                   jobs_accepted, jobs_completed, aborted, simultaneous_done, overlap_cycles, spurious_seen);
        $display("ALL PASS: FSM selfcheck accepted=%0d completed=%0d aborted=%0d loads=%0d computes=%0d overlap_cycles=%0d simultaneous_done=%0d ignored_stray=%0d cycles=%0d",
                 jobs_accepted, jobs_completed, aborted, load_requests, compute_requests,
                 overlap_cycles, simultaneous_done, spurious_seen, cycles);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "global timeout");
    end
endmodule
