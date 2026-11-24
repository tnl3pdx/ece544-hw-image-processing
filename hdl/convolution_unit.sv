module convolution_unit #(
    parameter int KERNEL_SIZE=3,
    parameter int COLOR_BITS=8,
    parameter int SCALING_BITS=16,
    //NOTE: This is not pipelined and just operates in place. It shoud be
    //similarly resource efficient to pipelining because each stage reuses
    //the same resources.
    //
    //Also of note. If your NCYCLES does not divide ARR_SIZE^2, then you will
    //end up with a bonus cycle that calculates the remainder of entries.
    //Picking 1, ARR_SIZE, ARR_SIZE^2/2, or ARR_SIZE^2 are all sensible
    //options.
    parameter int NCYCLES=3,
    localparam ARR_LEN = KERNEL_SIZE*KERNEL_SIZE
) (
    input logic clk, reset, 
    // signal to read a new value into the pipeline
    input logic start,
    // input kernel
    input logic signed [COLOR_BITS-1:0] kernel [ARR_LEN-1:0],
    // input scaling factor. factor is 1/(n+1) for positive n and 1/n for
    // negative n
    input logic signed [SCALING_BITS-1:0] scaling_factor,

    // input color array
    input logic [COLOR_BITS-1:0] colors [ARR_LEN-1:0],
    // output value of convolution
    output logic [COLOR_BITS-1:0] output_color,
    // high if the output is stable and ready
    output logic valid
);
// multiplication doubles the bit length
// ARR_LEN copies of addition
// add 1 because clog2 undercounts for powers of 2
localparam ACC_BITS = 2*COLOR_BITS + $clog2(ARR_LEN+1);

// +1 to hold exact powers of 2
// +1 for the bonus remainder cycle
localparam CYCLE_BITS = $clog2(NCYCLES+2);

// how many multiplications we do per cycle
localparam MULT_CHUNK = ARR_LEN/NCYCLES;
localparam MULT_REMAINDER = ARR_LEN % NCYCLES;

// registered inputs
logic signed [COLOR_BITS-1:0] kernel_reg [ARR_LEN-1:0];
logic [COLOR_BITS-1:0] colors_reg [ARR_LEN-1:0];

logic signed [ACC_BITS-1:0] accumulators [MULT_CHUNK];
// accumulators summed + scaled by the scaling factor
logic signed [ACC_BITS-1:0] scaled_result;
// clamped version of the above value
logic [COLOR_BITS-1:0] total;

logic started;
logic [CYCLE_BITS-1:0] stage;

always_comb begin
    if (scaling_factor >= 0)
        scaled_result = accumulators.sum()/(1+scaling_factor);
    else
        scaled_result = accumulators.sum()/scaling_factor;

    // clamp total if it is out of the range of 0 .. 2^COLOR_BITS
    if (scaled_result >= (1 << COLOR_BITS))
        total = '1;
    else if (scaled_result < 0)
        total = '0;
    // Take last 8 bits of total if it is in range
    else 
        total = COLOR_BITS'(scaled_result);
end

always_ff @(posedge clk) begin
    if (reset) begin
        started <= 0;
        valid <= 0;
    end else begin
        // setup stage register and do the first round of multiplies
        if (!started && start) begin
            for (int i=0; i<MULT_CHUNK; i++) begin
                accumulators[i] <= signed'({1'b0,colors[i]}) * kernel[ARR_LEN-i-1];
            end
            colors_reg <= colors;
            kernel_reg <= kernel;
            stage <= 1;
            valid <= 0;
        // do the next batch of multiplies
        end else if (stage < CYCLE_BITS'(NCYCLES)) begin
            for (int i=0; i<MULT_CHUNK; i++) begin
                accumulators[i] <= accumulators[i] + signed'({1'b0,colors_reg[i + MULT_CHUNK*stage]}) * kernel_reg[ARR_LEN-i-1-MULT_CHUNK*stage];
            end
            stage <= stage + 1;
        // potentially we are done, unless there is a remainder
        end else if (stage == CYCLE_BITS'(NCYCLES)) begin
            if (MULT_REMAINDER == 0) begin
                output_color <= total;
                valid <= 1'b1;
                started <= 1'b0;
            end else begin
                for (int i=0; i<MULT_REMAINDER; i++) begin
                    accumulators[i] <= accumulators[i] + signed'({1'b0,colors_reg[i + MULT_CHUNK*stage]}) * kernel_reg[ARR_LEN-i-1-MULT_CHUNK*stage];
                end
            end
        // guranteed to have completed the remainder cycle so we are done
        end else if (stage > CYCLE_BITS'(NCYCLES)) begin
            output_color <= total;
            valid <= 1'b1;
            started <= 1'b0;
        end
    end
end

endmodule
