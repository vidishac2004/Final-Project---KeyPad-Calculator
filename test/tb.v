`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
`timescale 1ns / 1ps

module tb;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    integer pass_count;
    integer fail_count;

    tt_um_vidishac2004_calc dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Keypad press helper
    task press_key;
        input integer col_idx;
        input integer row_idx;
        integer cycles;
        reg [3:0] expected_col;
        reg [3:0] row_pattern;
        begin
            case (col_idx)
                0: expected_col = 4'b1110;
                1: expected_col = 4'b1101;
                2: expected_col = 4'b1011;
                3: expected_col = 4'b0111;
                default: expected_col = 4'b1111;
            endcase

            case (row_idx)
                0: row_pattern = 4'b1110;
                1: row_pattern = 4'b1101;
                2: row_pattern = 4'b1011;
                3: row_pattern = 4'b0111;
                default: row_pattern = 4'b1111;
            endcase

            cycles = 0;
            ui_in[3:0] = 4'b1111;
            while (uio_out[3:0] !== expected_col && cycles < 200) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 200) begin
                $display("ERROR: timeout waiting for column %0d", col_idx);
            end

            ui_in[3:0] = row_pattern;
            repeat (8) @(posedge clk);

            ui_in[3:0] = 4'b1111;
            repeat (8) @(posedge clk);
        end
    endtask

    // col0: 1,4,7,CLEAR
    // col1: 2,5,8,0
    // col2: 3,6,9,=
    // col3: +,-,*,/
    task press_digit;
        input integer digit;
        begin
            case (digit)
                0: press_key(1, 3);
                1: press_key(0, 0);
                2: press_key(1, 0);
                3: press_key(2, 0);
                4: press_key(0, 1);
                5: press_key(1, 1);
                6: press_key(2, 1);
                7: press_key(0, 2);
                8: press_key(1, 2);
                9: press_key(2, 2);
                default: $display("ERROR: invalid digit %0d", digit);
            endcase
        end
    endtask

    // + -> decoded_key 0 -> col3,row0
    // - -> decoded_key 1 -> col3,row1
    // * -> decoded_key 2 -> col3,row2
    // / -> decoded_key 3 -> col3,row3
    task press_add; begin press_key(3, 0); end endtask
    task press_sub; begin press_key(3, 1); end endtask
    task press_mul; begin press_key(3, 2); end endtask
    task press_div; begin press_key(3, 3); end endtask
    task press_eq;  begin press_key(2, 3); end endtask
    task press_clear; begin press_key(0, 3); end endtask

    task do_reset;
        begin
            rst_n = 0;
            ui_in[3:0] = 4'b1111;
            repeat (4) @(posedge clk);
            rst_n = 1;
            repeat (4) @(posedge clk);
        end
    endtask

    task check_result;
        input [7:0] expected;
        input [255:0] test_name;
        begin
            repeat (40) @(posedge clk);
            if (uo_out == expected) begin
                $display("GOOD     : %0s = %0d", test_name, uo_out);
                pass_count = pass_count + 1;
            end else begin
                $display("NOT GOOD : %0s expected %0d got %0d", test_name, expected, uo_out);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        ena   = 1'b1;
        rst_n = 1'b1;
        ui_in = 8'hFF;   // rows idle high, upper bits unused
        uio_in = 8'h00;  // not used by your wrapper

        do_reset();

        // 7 + 5 = 12
        press_digit(7);
        press_add();
        press_digit(5);
        press_eq();
        check_result(8'd12, "7+5");

        // 7 - 5 = 2
        do_reset();
        press_digit(7);
        press_sub();
        press_digit(5);
        press_eq();
        check_result(8'd2, "7-5");

        // 6 * 3 = 18
        do_reset();
        press_digit(6);
        press_mul();
        press_digit(3);
        press_eq();
        check_result(8'd18, "6*3");

        // 9 / 3 = 3
        do_reset();
        press_digit(9);
        press_div();
        press_digit(3);
        press_eq();
        check_result(8'd3, "9/3");

        // 45 - 8 = 37
        do_reset();
        press_digit(4);
        press_digit(5);
        press_sub();
        press_digit(8);
        press_eq();
        check_result(8'd37, "45-8");

        // 12 + 5 = 17
        do_reset();
        press_digit(1);
        press_digit(2);
        press_add();
        press_digit(5);
        press_eq();
        check_result(8'd17, "12+5");

        // 99 - 11 = 88
        do_reset();
        press_digit(9);
        press_digit(9);
        press_sub();
        press_digit(1);
        press_digit(1);
        press_eq();
        check_result(8'd88, "99-11");

        // 23 + 14 = 37
        do_reset();
        press_digit(2);
        press_digit(3);
        press_add();
        press_digit(1);
        press_digit(4);
        press_eq();
        check_result(8'd37, "23+14");

        // 15 * 6 = 90
        do_reset();
        press_digit(1);
        press_digit(5);
        press_mul();
        press_digit(6);
        press_eq();
        check_result(8'd90, "15*6");

        // 96 / 8 = 12
        do_reset();
        press_digit(9);
        press_digit(6);
        press_div();
        press_digit(8);
        press_eq();
        check_result(8'd12, "96/8");

        // 5 - 5 = 0
        do_reset();
        press_digit(5);
        press_sub();
        press_digit(5);
        press_eq();
        check_result(8'd0, "5-5");

        $display("");
        $display("passed: %0d  failed: %0d", pass_count, fail_count);

        if (fail_count == 0)
            $display("all tests passed");
        else
            $display("some tests failed");

        $finish;
    end

endmodule
