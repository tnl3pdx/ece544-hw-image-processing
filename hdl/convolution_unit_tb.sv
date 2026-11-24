module convolution_unit_tb;

parameter COLOR_BITS = 8;
parameter KERNEL_SIZE=3;
parameter NCYCLES=3;
parameter TESTCASES=1000;
parameter SCALING_BITS=16;
localparam ARR_LEN=KERNEL_SIZE*KERNEL_SIZE;
localparam REMAINDER=ARR_LEN % NCYCLES;
// boolean value that is true if there is a remainder
localparam HAS_REMAINDER= REMAINDER != 0 ? 1 : 0;

logic clk, reset;
logic start;
logic signed [COLOR_BITS-1:0] kernel [ARR_LEN-1:0];
logic [COLOR_BITS-1:0] colors [ARR_LEN-1:0];
logic [COLOR_BITS-1:0] output_color;
logic signed [SCALING_BITS-1:0] scaling_factor;
logic valid;

convolution_unit #(.COLOR_BITS(COLOR_BITS),.KERNEL_SIZE(KERNEL_SIZE),.NCYCLES(NCYCLES)) dut (.*);

initial clk=0;
always #10 clk = ~clk;

initial begin
    reset = 1;

    repeat (3) @(posedge clk);

    reset = 0;

    // scaling factor of 1
    scaling_factor = 0;

    // identity kernel
    for (int i=0; i<TESTCASES; i++) begin
        foreach (colors[j]) colors[j] = 8'($urandom);
        kernel = '{
            8'h00,
            8'h00,
            8'h00,
            8'h00,
            8'h01,
            8'h00,
            8'h00,
            8'h00,
            8'h00
        };
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        @(posedge clk);
        wait (valid);
        @(posedge clk);
    end

    // edge detection kernel
    for (int i=0; i<TESTCASES; i++) begin
        foreach (colors[j]) colors[j] = 8'($urandom);
        kernel = '{
            8'h00,
            8'h01,
            8'h00,
            8'h01,
            -4,
            8'h01,
            8'h00,
            8'h01,
            8'h00
        };
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        @(posedge clk);
        wait (valid);
        @(posedge clk);
    end
    
    // blur kernel
    scaling_factor = 8;
    for (int i=0; i<TESTCASES; i++) begin
        foreach (colors[j]) colors[j] = 8'($urandom);
        kernel = '{
            8'h01,
            8'h01,
            8'h01,
            8'h01,
            8'h01,
            8'h01,
            8'h01,
            8'h01,
            8'h01
        };
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        @(posedge clk);
        wait (valid);
        @(posedge clk);
    end

    $finish();
end

// Defaults for properties
// This one doesnt work in vivado
// default disable iff (reset);
default clocking cb_main @(posedge clk);
endclocking

property valid_after_start;
    start ##1 !start[*NCYCLES-1 + HAS_REMAINDER] |=> valid;
endproperty
p_valid_after_start: assert property (disable iff (reset) valid_after_start);

property correct_output_color;
    int total;
    (start,total=calculate_total(scaling_factor,kernel,colors)) ##[1:NCYCLES] valid |-> (total == int'(output_color));
endproperty
p_correct_output_color: assert property (disable iff (reset) correct_output_color);

// behaviourally determines what the resulting color should be
function automatic int calculate_total(
    input logic signed [SCALING_BITS-1:0] scale,
    input logic signed [COLOR_BITS-1:0] k [ARR_LEN-1:0],
    input logic [COLOR_BITS-1:0] c [ARR_LEN-1:0]
);
    int sum = 0;
    for(int i=0; i < ARR_LEN; i++) begin
        sum += k[i] * int'(c[ARR_LEN-1-i]);
    end
    if (scale >= 0)
        sum = sum/(scale+1);
    else 
        sum = sum/(scale);
    if (sum >= (1<<COLOR_BITS))
        return (1<<COLOR_BITS)-1;
    else if (sum <= 0)
        return 0;
    else
        return sum;
endfunction

endmodule
