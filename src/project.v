/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vidishac2004_calc (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidirectional inputs
    output wire [7:0] uio_out,  // bidirectional outputs
    output wire [7:0] uio_oe,   // 1=output, 0=input
    input  wire       ena,      // always 1
    input  wire       clk,      // clock
    input  wire       rst_n     // active-low reset
);

    wire [3:0] row;
    wire [3:0] col;
    wire [7:0] result;

    assign row = ui_in[3:0];

    calculator_to_led u_calc (
        .clk(clk),
        .reset(rst_n),   
        .row(row),
        .col(col),
        .result(result)
    );

    assign uo_out = result;

    assign uio_out[3:0] = col;
    assign uio_oe[3:0]  = 4'b1111;   // these are outputs

    assign uio_out[7:4] = 4'b0000;
    assign uio_oe[7:4]  = 4'b0000;   // inputs / unused

    wire _unused = &{ena, ui_in[7:4], uio_in, 1'b0};

endmodule

module calculator_to_led(
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] row,
    output logic [3:0] col,
    output logic [7:0] result
);

    logic rst;
    logic [3:0] decoded_key;
    logic [2:0] key_type;
    logic       key_valid;
    logic       clear;

    assign rst   = ~reset;
    assign clear = key_valid && (key_type == 3'd3);

    keypad_FSM u_keypad (
        .clk(clk),
        .reset(rst),
        .row(row),
        .col(col),
        .decoded_key(decoded_key),
        .key_type(key_type),
        .key_valid(key_valid)
    );

    calculator_control dut1(
        .clk(clk),
        .reset(rst),
        .key_valid(key_valid),
        .decoded_key(decoded_key),
        .key_type(key_type),
        .clear(clear),
        .result(result)
    );

endmodule

module keypad_FSM(
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] row,

    output logic [3:0] col,
    output logic [3:0] decoded_key,
    output logic [2:0] key_type,
    output logic       key_valid
);

    typedef enum logic [2:0] {
        IDLE,
        SCAN_COL0,
        SCAN_COL1,
        SCAN_COL2,
        SCAN_COL3,
        DEBOUNCE,
        DECODE,
        WAIT_RELEASE
    } state_t;

    state_t state, next_state;

    logic [1:0]  col_index, col_index_next;
    logic [3:0]  row_sample, row_sample_next;
    logic [19:0] debounce_counter, debounce_counter_next;

    localparam logic [2:0] TYPE_DIGIT  = 3'd0;
    localparam logic [2:0] TYPE_OP     = 3'd1;
    localparam logic [2:0] TYPE_EQUALS = 3'd2;
    localparam logic [2:0] TYPE_CLEAR  = 3'd3;

    localparam int DEBOUNCE_MAX =  250000;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            col_index        <= 2'd0;
            row_sample       <= 4'b1111;
            debounce_counter <= 20'd0;
        end else begin
            state            <= next_state;
            col_index        <= col_index_next;
            row_sample       <= row_sample_next;
            debounce_counter <= debounce_counter_next;
        end
    end

    always_comb begin
        next_state            = state;
        col_index_next        = col_index;
        row_sample_next       = row_sample;
        debounce_counter_next = debounce_counter;

        col         = 4'b1111;
        key_valid   = 1'b0;
        decoded_key = 4'd0;
        key_type    = TYPE_DIGIT;

        case (state)
            IDLE: begin
                next_state = SCAN_COL0;
            end

            SCAN_COL0: begin
                col = 4'b1110;
                if (row != 4'b1111) begin
                    col_index_next        = 2'd0;
                    row_sample_next       = row;
                    debounce_counter_next = 20'd0;
                    next_state            = DEBOUNCE;
                end else begin
                    next_state = SCAN_COL1;
                end
            end

            SCAN_COL1: begin
                col = 4'b1101;
                if (row != 4'b1111) begin
                    col_index_next        = 2'd1;
                    row_sample_next       = row;
                    debounce_counter_next = 20'd0;
                    next_state            = DEBOUNCE;
                end else begin
                    next_state = SCAN_COL2;
                end
            end

            SCAN_COL2: begin
                col = 4'b1011;
                if (row != 4'b1111) begin
                    col_index_next        = 2'd2;
                    row_sample_next       = row;
                    debounce_counter_next = 20'd0;
                    next_state            = DEBOUNCE;
                end else begin
                    next_state = SCAN_COL3;
                end
            end

            SCAN_COL3: begin
                col = 4'b0111;
                if (row != 4'b1111) begin
                    col_index_next        = 2'd3;
                    row_sample_next       = row;
                    debounce_counter_next = 20'd0;
                    next_state            = DEBOUNCE;
                end else begin
                    next_state = SCAN_COL0;
                end
            end

            DEBOUNCE: begin
                case (col_index)
                    2'd0: col = 4'b1110;
                    2'd1: col = 4'b1101;
                    2'd2: col = 4'b1011;
                    2'd3: col = 4'b0111;
                    default: col = 4'b1111;
                endcase

                if (row == row_sample) begin
                    if (debounce_counter >= DEBOUNCE_MAX) begin
                        next_state = DECODE;
                    end else begin
                        debounce_counter_next = debounce_counter + 20'd1;
                    end
                end else begin
                    next_state = SCAN_COL0;
                end
            end

            DECODE: begin
                key_valid = 1'b1;

                case ({col_index, row_sample})
                    {2'd0,4'b1110}: begin decoded_key = 4'd1; key_type = TYPE_DIGIT;  end
                    {2'd0,4'b1101}: begin decoded_key = 4'd4; key_type = TYPE_DIGIT;  end
                    {2'd0,4'b1011}: begin decoded_key = 4'd7; key_type = TYPE_DIGIT;  end
                    {2'd0,4'b0111}: begin decoded_key = 4'd0; key_type = TYPE_CLEAR;  end

                    {2'd1,4'b1110}: begin decoded_key = 4'd2; key_type = TYPE_DIGIT;  end
                    {2'd1,4'b1101}: begin decoded_key = 4'd5; key_type = TYPE_DIGIT;  end
                    {2'd1,4'b1011}: begin decoded_key = 4'd8; key_type = TYPE_DIGIT;  end
                    {2'd1,4'b0111}: begin decoded_key = 4'd0; key_type = TYPE_DIGIT;  end

                    {2'd2,4'b1110}: begin decoded_key = 4'd3; key_type = TYPE_DIGIT;  end
                    {2'd2,4'b1101}: begin decoded_key = 4'd6; key_type = TYPE_DIGIT;  end
                    {2'd2,4'b1011}: begin decoded_key = 4'd9; key_type = TYPE_DIGIT;  end
                    {2'd2,4'b0111}: begin decoded_key = 4'd0; key_type = TYPE_EQUALS; end

                    {2'd3,4'b1110}: begin decoded_key = 4'd0; key_type = TYPE_OP;     end
                    {2'd3,4'b1101}: begin decoded_key = 4'd1; key_type = TYPE_OP;     end
                    {2'd3,4'b1011}: begin decoded_key = 4'd2; key_type = TYPE_OP;     end
                    {2'd3,4'b0111}: begin decoded_key = 4'd3; key_type = TYPE_OP;     end

                    default: begin
                        decoded_key = 4'd0;
                        key_type    = TYPE_CLEAR;
                    end
                endcase

                next_state = WAIT_RELEASE;
            end

            WAIT_RELEASE: begin
                col = 4'b1111;
                if (row == 4'b1111)
                    next_state = SCAN_COL0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule

module calculator_control(
    input  logic       clk,
    input  logic       reset,
    input  logic       key_valid,
    input  logic [3:0] decoded_key,
    input  logic [2:0] key_type,
    input  logic       clear,
    output logic [7:0] result
);

    logic load_A, load_B, load_result, en_buffer, clr_input_buffer, start_alu;
    logic load_op;
    logic [2:0] op_sel_fsm;
    logic [2:0] op_sel_reg;

    logic [7:0] buffer_value;
    logic [7:0] A, B;
    logic [7:0] alu_result;
    logic       alu_done, alu_error;

    calculator_FSM calc_fsm (
        .clk(clk),
        .reset(reset),
        .key_valid(key_valid),
        .alu_done(alu_done),
        .alu_error(alu_error),
        .clear(clear),
        .decoded_key(decoded_key),
        .key_type(key_type),
        .load_A(load_A),
        .load_B(load_B),
        .load_result(load_result),
        .load_op(load_op),
        .en_buffer(en_buffer),
        .clr_input_buffer(clr_input_buffer),
        .start_alu(start_alu),
        .op_sel(op_sel_fsm)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            op_sel_reg <= 3'd0;
        else if (clear)
            op_sel_reg <= 3'd0;
        else if (load_op)
            op_sel_reg <= op_sel_fsm;
    end

    input_buffer inst_input_buffer (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .en_buffer(en_buffer),
        .key_valid(key_valid),
        .decoded_key(decoded_key),
        .key_type(key_type),
        .clr_input_buffer(clr_input_buffer),
        .buffer_value(buffer_value)
    );

    operand_regs inst_operand_regs (
        .clk(clk),
        .reset(reset),
        .clr_regs(clear),
        .load_A(load_A),
        .load_B(load_B),
        .load_result(load_result),
        .buffer_value(buffer_value),
        .alu_result(alu_result),
        .A(A),
        .B(B),
        .result(result)
    );

    alu inst_alu (
        .clk(clk),
        .reset(reset),
        .start_alu(start_alu),
        .A(A),
        .B(B),
        .op_sel(op_sel_reg),
        .alu_result(alu_result),
        .alu_done(alu_done),
        .alu_error(alu_error)
    );

endmodule

module input_buffer(
    input  logic       clk,
    input  logic       reset,
    input  logic       clear,
    input  logic       en_buffer,
    input  logic       key_valid,
    input  logic [3:0] decoded_key,
    input  logic [2:0] key_type,
    input  logic       clr_input_buffer,
    output logic [7:0] buffer_value
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer_value <= 8'd0;
        end
        else if (clear) begin
            buffer_value <= 8'd0;
        end
        else if (clr_input_buffer && en_buffer && key_valid && key_type == 3'd0) begin
            buffer_value <= {4'd0, decoded_key};
        end
        else if (clr_input_buffer) begin
            buffer_value <= 8'd0;
        end
        else if (en_buffer && key_valid && key_type == 3'd0) begin
            buffer_value <= {buffer_value[3:0], decoded_key};
        end
    end

endmodule

module operand_regs(
    input  logic       clk,
    input  logic       reset,
    input  logic       clr_regs,
    input  logic       load_A,
    input  logic       load_B,
    input  logic       load_result,
    input  logic [7:0] buffer_value,
    input  logic [7:0] alu_result,
    output logic [7:0] A,
    output logic [7:0] B,
    output logic [7:0] result
);

    logic [7:0] operand_value;

    always_comb begin
        operand_value = ({4'b0, buffer_value[7:4]} << 3) +
                        ({4'b0, buffer_value[7:4]} << 1) +
                        {4'b0, buffer_value[3:0]};
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            A      <= 8'd0;
            B      <= 8'd0;
            result <= 8'd0;
        end
        else if (clr_regs) begin
            A      <= 8'd0;
            B      <= 8'd0;
            result <= 8'd0;
        end
        else begin
            if (load_A)
                A <= operand_value;
            if (load_B)
                B <= operand_value;
            if (load_result)
                result <= alu_result;
        end
    end

endmodule

module calculator_FSM(
    input  logic       clk,
    input  logic       reset,
    input  logic       key_valid,
    input  logic       alu_done,
    input  logic       alu_error,
    input  logic       clear,
    input  logic [3:0] decoded_key,
    input  logic [2:0] key_type,

    output logic       load_A,
    output logic       load_B,
    output logic       load_result,
    output logic       load_op,
    output logic       en_buffer,
    output logic       clr_input_buffer,
    output logic       start_alu,
    output logic [2:0] op_sel
);

    typedef enum logic [3:0] {
        IDLE        = 4'd0,
        INPUT_A     = 4'd1,
        OP_SEL      = 4'd2,
        INPUT_B     = 4'd3,
        LOAD_B      = 4'd4,
        START_ALU   = 4'd5,
        EXECUTE     = 4'd6,
        LOAD_RESULT = 4'd7,
        DISPLAY     = 4'd8,
        ERROR_STATE = 4'd9
    } state_t;

    state_t state, next_state;

    logic [2:0] op_captured;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            op_captured <= 3'd0;
        end else begin
            state <= next_state;
            if (key_valid && key_type == 3'd1)
                op_captured <= decoded_key[2:0];
        end
    end

    always_comb begin
        next_state = state;

        if (clear) begin
            next_state = IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    if (key_valid && key_type == 3'd0)
                        next_state = INPUT_A;
                end

                INPUT_A: begin
                    if (key_valid && key_type == 3'd0)
                        next_state = INPUT_A;
                    else if (key_valid && key_type == 3'd1)
                        next_state = OP_SEL;
                end

                OP_SEL: begin
                    next_state = INPUT_B;
                end

                INPUT_B: begin
                    if (key_valid && key_type == 3'd0)
                        next_state = INPUT_B;
                    else if (key_valid && key_type == 3'd2)
                        next_state = LOAD_B;
                end

                LOAD_B: begin
                    next_state = START_ALU;
                end

                START_ALU: begin
                    next_state = EXECUTE;
                end

                EXECUTE: begin
                    if (alu_done) begin
                        if (alu_error)
                            next_state = ERROR_STATE;
                        else
                            next_state = LOAD_RESULT;
                    end
                end

                LOAD_RESULT: begin
                    next_state = DISPLAY;
                end

                DISPLAY: begin
                    if (key_valid && key_type == 3'd0)
                        next_state = INPUT_A;
                end

                ERROR_STATE: begin
                end

                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end

    always_comb begin
        load_A           = 1'b0;
        load_B           = 1'b0;
        load_result      = 1'b0;
        load_op          = 1'b0;
        start_alu        = 1'b0;
        clr_input_buffer = 1'b0;
        en_buffer        = 1'b0;
        op_sel           = 3'b000;

        if (clear) begin
            clr_input_buffer = 1'b1;
        end
        else begin
            case (state)
                IDLE: begin
                    if (key_valid && key_type == 3'd0)
                        en_buffer = 1'b1;
                end

                INPUT_A: begin
                    if (key_valid && key_type == 3'd0)
                        en_buffer = 1'b1;
                end

                OP_SEL: begin
                    load_A           = 1'b1;
                    load_op          = 1'b1;
                    clr_input_buffer = 1'b1;
                    op_sel           = op_captured;
                end

                INPUT_B: begin
                    if (key_valid && key_type == 3'd0)
                        en_buffer = 1'b1;
                end

                LOAD_B: begin
                    load_B = 1'b1;
                end

                START_ALU: begin
                    start_alu = 1'b1;
                end

                LOAD_RESULT: begin
                    load_result = 1'b1;
                end

                DISPLAY: begin
                    if (key_valid && key_type == 3'd0) begin
                        clr_input_buffer = 1'b1;
                        en_buffer        = 1'b1;
                    end
                end

                ERROR_STATE: begin
                end

                default: begin
                end
            endcase
        end
    end

endmodule

module alu(
    input  logic       clk,
    input  logic       reset,
    input  logic       start_alu,
    input  logic [7:0] A,
    input  logic [7:0] B,
    input  logic [2:0] op_sel,

    output logic [7:0] alu_result,
    output logic       alu_done,
    output logic       alu_error
);

    typedef enum logic [2:0] {
        ALU_IDLE,
        ADD,
        SUB,
        MUL,
        DIV,
        ALU_DONE,
        ALU_ERROR
    } alu_state_t;

    alu_state_t state, next_state;

    logic [7:0] A_reg, B_reg, result_reg;
    logic [7:0] A_next, B_next, result_next;
    logic [3:0] count, count_next;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= ALU_IDLE;
            A_reg      <= 8'd0;
            B_reg      <= 8'd0;
            result_reg <= 8'd0;
            count      <= 4'd0;
        end else begin
            state      <= next_state;
            A_reg      <= A_next;
            B_reg      <= B_next;
            result_reg <= result_next;
            count      <= count_next;
        end
    end

    always_comb begin
        next_state  = state;
        alu_done    = 1'b0;
        alu_error   = 1'b0;

        A_next      = A_reg;
        B_next      = B_reg;
        result_next = result_reg;
        count_next  = count;

        case (state)
            ALU_IDLE: begin
                if (start_alu) begin
                    A_next      = A;
                    B_next      = B;
                    result_next = 8'd0;
                    count_next  = 4'd0;

                    case (op_sel)
                        3'd0: next_state = ADD;
                        3'd1: next_state = SUB;
                        3'd2: next_state = MUL;
                        3'd3: next_state = DIV;
                        default: next_state = ALU_ERROR;
                    endcase
                end
            end

            ADD: begin
                result_next = A_reg + B_reg;
                next_state  = ALU_DONE;
            end

            SUB: begin
                result_next = A_reg - B_reg;
                next_state  = ALU_DONE;
            end

            MUL: begin
                if (count < 8) begin
                    if (B_reg[0])
                        result_next = result_reg + A_reg;
                    A_next     = A_reg << 1;
                    B_next     = B_reg >> 1;
                    count_next = count + 1;
                    next_state = MUL;
                end else begin
                    next_state = ALU_DONE;
                end
            end

            DIV: begin
                if (B_reg == 8'd0) begin
                    next_state = ALU_ERROR;
                end
                else if (A_reg >= B_reg) begin
                    A_next      = A_reg - B_reg;
                    result_next = result_reg + 8'd1;
                    next_state  = DIV;
                end
                else begin
                    next_state = ALU_DONE;
                end
            end

            ALU_DONE: begin
                alu_done   = 1'b1;
                next_state = ALU_IDLE;
            end

            ALU_ERROR: begin
                alu_done   = 1'b1;
                alu_error  = 1'b1;
                next_state = ALU_IDLE;
            end

            default: begin
                next_state = ALU_IDLE;
            end
        endcase
    end

    assign alu_result = result_reg;

endmodule
