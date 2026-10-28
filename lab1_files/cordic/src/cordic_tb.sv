`timescale 1 ns/10 ps

module cordic_tb;

  localparam width = 16; //width of x and y

  // Inputs
  reg [width-1:0] Xin, Yin;
  reg [31:0] angle;
  reg clk;

  wire signed [width-1:0] COSout, SINout;
  wire done;

  localparam An = 32000/1.64676;

  // Clock Generator
    always
    begin
        #2 clk = ~clk;
    end  

  // Golden Model
  function integer calculate_cos(input real angle_deg);
    calculate_cos = 32000 * $cos(angle_deg * 3.14159265359 / 180);
  endfunction

  function integer calculate_sin(input real angle_deg);
    calculate_sin = 32000 * $sin(angle_deg * 3.14159265359 / 180);
  endfunction

  parameter TOLERANCE = 8;
  integer passed=0, failed=0;
  function automatic longint abs_diff(input longint a, input longint b);
    abs_diff = a>=b ? a-b : b-a;
  endfunction 

  task automatic verify_output;
    input signed [31:0] expected_cos;
    input signed [31:0] expected_sin;
    // @(posedge done); // Wait for the CORDIC to finish processing
    begin
      if ((^COSout === 1'bx) || (^SINout === 1'bx) || abs_diff(COSout,expected_cos) > TOLERANCE || abs_diff(SINout,expected_sin) > TOLERANCE) begin
        failed=failed+1;
        $display("[RES, ERROR] At time %0t: Expected COS=%0d, SIN=%0d but got COS=%0d, SIN=%0d", $time, expected_cos, expected_sin, COSout, SINout);
      end else begin
        passed=passed+1;
        $display("[RES, PASS] At time %0t: Expected COS=%0d, SIN=%0d, get COS=%0d, SIN=%0d", $time, expected_cos, expected_sin, COSout, SINout);
      end
    end
  endtask


  // Test
  initial begin
    //set initial values
    angle = 32'b0;
    Xin = An;     // COSout = 32000*cos(angle)
    Yin = 0;      // SINout = 32000*sin(angle)

    //set clock
    clk = 'b0;

    // Test 1
    #1000 
    angle = 'b00100000000000000000000000000000;  // 45 deg = 45/360 * 2^32 = 32'b00100000000000000000000000000000
    #70 verify_output(calculate_cos(45), calculate_sin(45));

    // Test 2
    #930
    angle = 178956970; // 15 deg
    #70 verify_output(calculate_cos(15), calculate_sin(15));

    // Test 3
    #930
    angle = 357913941; // 30 deg
    #70 verify_output(calculate_cos(30), calculate_sin(30));

    // Test 4
    #930
    angle = 715827882; // 60 deg
    #70 verify_output(calculate_cos(60), calculate_sin(60));
  
    // Test 5
    #930
    angle = 894784853; // 75 deg
    #70 verify_output(calculate_cos(75), calculate_sin(75));

    // Test 6
    #930
    angle = 1073741824; // 90 deg
    #70 verify_output(calculate_cos(90), calculate_sin(90));

    // Test 7
    #930
    angle = 2147483648; // 180 deg
    #70 verify_output(calculate_cos(180), calculate_sin(180));

    // Test 8
    #930
    angle = 3221225472; // 270 deg
    #70 verify_output(calculate_cos(270), calculate_sin(270));

    // Test 9
    #930
    angle = 4283036831; // 359 deg
    #70 verify_output(calculate_cos(359), calculate_sin(359));

    // Test 10
    #930
    angle = 680036488; // 57 deg
    #70 verify_output(calculate_cos(57), calculate_sin(57));

    #930
    if (failed != 0 || passed != 10) $fatal(1,"FAIL: passed=%0d failed=%0d",passed,failed);
    $display("ALL PASS: CORDIC, 10 cases");
    $finish;
  end

  cordic TEST_RUN(clk, Xin, Yin, angle, COSout, SINout, done);

  // Monitor the output
  initial
    $monitor($time, , COSout, , SINout, , angle);
  
  // Dump waveform for Verdi
`ifndef NO_FSDB
  initial begin
    $fsdbDumpfile("cordic_tb.fsdb");
    $fsdbDumpvars("+all");
  end
`endif


endmodule