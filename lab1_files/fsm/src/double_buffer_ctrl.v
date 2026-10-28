`timescale 1ns/1ps
module double_buffer_ctrl (
    input  logic       clk,
    input  logic       rstn,
    input  logic       start,
    input  logic       load_done,
    input  logic       compute_done,
    output logic       load_req,
    output logic [1:0] load_tile,
    output logic       load_buf,
    output logic       compute_req,
    output logic [1:0] compute_tile,
    output logic       compute_buf,
    output logic       busy,
    output logic       done
);
    typedef enum logic {IDLE, RUN} state_t;
    state_t state_q, state_d;
    logic load_active_q, load_active_d, compute_active_q, compute_active_d;
    logic [1:0] full_q, full_d;
    logic [1:0] next_load_q, next_load_d, next_compute_q, next_compute_d;
    logic load_req_d, load_buf_d, compute_req_d, compute_buf_d, done_d;
    logic [1:0] load_tile_d, compute_tile_d;
    logic load_target_buf, compute_target_buf;

    assign busy = (state_q == RUN);
    // Scalar aliases avoid Icarus's always_comb constant-select warning.
    assign load_target_buf = next_load_q[0];
    assign compute_target_buf = next_compute_q[0];

    always_comb begin
        state_d = state_q;
        load_active_d = load_active_q;
        compute_active_d = compute_active_q;
        full_d = full_q;
        next_load_d = next_load_q;
        next_compute_d = next_compute_q;
        load_req_d = 1'b0;
        compute_req_d = 1'b0;
        done_d = 1'b0;
        load_tile_d = load_tile;
        load_buf_d = load_buf;
        compute_tile_d = compute_tile;
        compute_buf_d = compute_buf;

        case (state_q)
            IDLE: begin
                full_d = 2'b00;
                load_active_d = 1'b0;
                compute_active_d = 1'b0;
                next_load_d = 2'd0;
                next_compute_d = 2'd0;
                if (start) begin
                    state_d = RUN;
                    load_req_d = 1'b1;
                    load_tile_d = 2'd0;
                    load_buf_d = 1'b0;
                    load_active_d = 1'b1;
                    next_load_d = 2'd1;
                end
            end
            RUN: begin
                // Consume only responses for operations already in flight.
                // Full remains set through computation, until compute_done.
                if (load_done && load_active_q) begin
                    load_active_d = 1'b0;
                    full_d[load_buf] = 1'b1;
                end
                if (compute_done && compute_active_q) begin
                    compute_active_d = 1'b0;
                    full_d[compute_buf] = 1'b0;
                    if (compute_tile == 2'd2) begin
                        state_d = IDLE;
                        done_d = 1'b1;
                    end
                end

                // Apply completions before scheduling. Both schedulers see
                // updated ownership, including a newly reserved load buffer.
                if (state_d == RUN) begin
                    if (!load_active_d && !load_req && (next_load_q < 2'd3) &&
                        !full_d[load_target_buf] &&
                        !(compute_active_d && (compute_buf == load_target_buf))) begin
                        load_req_d = 1'b1;
                        load_tile_d = next_load_q;
                        load_buf_d = load_target_buf;
                        load_active_d = 1'b1;
                        next_load_d = next_load_q + 2'd1;
                    end
                    if (!compute_active_d && !compute_req && (next_compute_q < 2'd3) &&
                        full_d[compute_target_buf] &&
                        !(load_active_d && (load_buf_d == compute_target_buf))) begin
                        compute_req_d = 1'b1;
                        compute_tile_d = next_compute_q;
                        compute_buf_d = compute_target_buf;
                        compute_active_d = 1'b1;
                        next_compute_d = next_compute_q + 2'd1;
                    end
                end
            end
            default: begin
                state_d = IDLE;
                full_d = 2'b00;
                load_active_d = 1'b0;
                compute_active_d = 1'b0;
                next_load_d = 2'd0;
                next_compute_d = 2'd0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state_q <= IDLE;
            full_q <= 2'b00;
            load_active_q <= 1'b0;
            compute_active_q <= 1'b0;
            next_load_q <= 2'd0;
            next_compute_q <= 2'd0;
            load_req <= 1'b0;
            load_tile <= 2'd0;
            load_buf <= 1'b0;
            compute_req <= 1'b0;
            compute_tile <= 2'd0;
            compute_buf <= 1'b0;
            done <= 1'b0;
        end else begin
            state_q <= state_d;
            full_q <= full_d;
            load_active_q <= load_active_d;
            compute_active_q <= compute_active_d;
            next_load_q <= next_load_d;
            next_compute_q <= next_compute_d;
            load_req <= load_req_d;
            load_tile <= load_tile_d;
            load_buf <= load_buf_d;
            compute_req <= compute_req_d;
            compute_tile <= compute_tile_d;
            compute_buf <= compute_buf_d;
            done <= done_d;
        end
    end
endmodule
