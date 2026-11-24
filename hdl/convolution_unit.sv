module convolution_unit #(
    parameter int ARR_SIZE=3,
    parameter int COLOR_BITS=8,
    //NOTE: This is not pipelined and just operates in place. It shoud be
    //similarly resource efficient to pipelining because each stage reuses
    //the same resources.
    //
    //Also of note. If your NCYCLES does not divide ARR_SIZE^2, then you will
    //end up with a bonus cycle that calculates the remainder of entries.
    //Picking 1, ARR_SIZE, ARR_SIZE^2/2, or ARR_SIZE^2 are all sensible
    //options.
    parameter int NCYCLES=3,
    localparam ARR_LEN = ARR_SIZE*ARR_SIZE
) (
    input logic clk, reset, 
    // signal to read a new value into the pipeline
    input logic start,
    // input kernel
    input logic signed [COLOR_BITS-1:0] kernel [ARR_LEN-1:0],
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

// +1 for 
// +1 for the bonus remainder cycle
localparam CYCLE_BITS = $clog2(NCYCLES+2);

// how many multiplications we do per cycle
localparam MULT_CHUNK = ARR_LEN/NCYCLES;
localparam MULT_REMAINDER = ARR_LEN % NCYCLES;

logic signed [ACC_BITS-1:0] accumulators [MULT_CHUNK];
logic [COLOR_BITS-1:0] total;

logic started;
logic [CYCLE_BITS-1:0] stage;

always_comb begin
    // clamp total if it is out of the range of 0 .. 2^COLOR_BITS
    if (accumulators.sum() >= (1 << COLOR_BITS))
        total = '1;
    else if (accumulators.sum() < 0)
        total = '0;
    // Take last 8 bits of total if it is in range
    else 
        total = COLOR_BITS'(accumulators.sum());
end

always_ff @(posedge clk) begin
    if (reset) begin
        started <= 0;
        valid <= 0;
    end else begin
        // setup stage register and do the first round of multiplies
        if (!started && start) begin
            for (int i=0; i<MULT_CHUNK; i++) begin
                accumulators[i] <= colors[i] * kernel[i-1];
            end
            stage <= 1;
            valid <= 0;
        // do the next batch of multiplies
        end else if (stage < CYCLE_BITS'(NCYCLES)) begin
            for (int i=0; i<MULT_CHUNK; i++) begin
                accumulators[i] <= colors[i + MULT_CHUNK*stage] * kernel[i-1-MULT_CHUNK*stage];
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
                    accumulators[i] <= colors[i + MULT_CHUNK*stage] * kernel[i-1-MULT_CHUNK*stage];
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
