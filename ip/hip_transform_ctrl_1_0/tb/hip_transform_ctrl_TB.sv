`timescale 1 ns / 1 ps
`define HIP_AXI_M dut.hip_transform_ctrl_0.inst.hip_transform_ctrl_master_full_v1_0_M00_AXI_inst

import hip_axi_bd_axi_vip_0_0_pkg::*;

module tb_top();

  // Clock and reset
  logic clk = 0;
  logic rst = 0;
  
  always #5 clk = ~clk;

  // DUT
  hip_axi_bd dut
       (.clk_100MHz(clk),
        .reset_rtl_0(rst));

  // Signals
  logic [8:0] static_beats;
  logic [31:0] static_offset;
  int counter;
  logic [31:0] wdata_array[];
  logic [31:0] rdata_array[];
  logic [31:0] w_value;
  logic [31:0] r_value;

  // VIP Slave Instantiation
  hip_axi_bd_axi_vip_0_0_slv_mem_t slv_agent;

  task automatic tc_write_trans(
    input logic [8:0] beats,
    input logic [31:0] offset
  );
    
    counter = 0;

    static_beats = beats;
    static_offset = offset;
    w_value = wdata_array[counter];

    @(posedge clk)
    force `HIP_AXI_M.w_count_bus = static_beats;
    force `HIP_AXI_M.w_offset = static_offset;
    force `HIP_AXI_M.w_data_bus = w_value;
    force `HIP_AXI_M.start_w = 1'b0;

    @(posedge clk);
    force `HIP_AXI_M.start_w = 1'b1;

    @(posedge clk);
    force `HIP_AXI_M.start_w = 1'b0;

    while (`HIP_AXI_M.w_done !== 1'b1) begin
        @(posedge clk);
        if (`HIP_AXI_M.w_slv_ready == 1'b1) begin
          counter++;
          w_value = wdata_array[counter];
        end
    end
  endtask

  task automatic tc_read_trans(
    input logic [8:0] beats,
    input logic [31:0] offset
  );
    
    counter = 0;
    
    static_beats = beats;
    static_offset = offset;

    @(posedge clk);
    force `HIP_AXI_M.r_count_bus = static_beats;
    force `HIP_AXI_M.r_offset = static_offset;
    force `HIP_AXI_M.start_r = 1'b0;

    @(posedge clk);
    force `HIP_AXI_M.start_r = 1'b1;

    @(posedge clk);
    force `HIP_AXI_M.start_r = 1'b0;

    while (`HIP_AXI_M.r_done !== 1'b1) begin
        @(posedge clk);
        if (`HIP_AXI_M.r_slv_valid == 1'b1) begin
          rdata_array[counter++] = `HIP_AXI_M.r_data_bus;
        end
    end
  endtask

  task automatic tc_wr_seq(
    input logic [8:0] beats,
    input logic [31:0] offset
  );

    int correct = 0;
    int incorrect = 0;

    $display("Testing %d-beat writes and reads at 0x%0H", beats+1, offset);

    // Allocate randomized values in static arrays
    wdata_array = new[beats+1];
    rdata_array = new[beats+1];

    // Generate random values in write data array
    foreach (wdata_array[i]) begin
      wdata_array[i] = $urandom();
    end

    // Write array to AXI VIP
    tc_write_trans(beats, offset);

    // Read same location
    tc_read_trans(beats, offset);

    foreach (wdata_array[i]) begin
      if (wdata_array[i] != rdata_array[i]) begin
        incorrect++;
        $display("Mismatch for index %d!", i);
      end else begin
        correct++;
      end
    end

    if (incorrect > 0) begin
      $display("WR Sequence Failed! Correct: %d, Incorrect %d\n", correct, incorrect);
    end else begin
      $display("WR Sequence Passed! Correct: %d, Incorrect %d\n", correct, incorrect);
    end

    wdata_array.delete();
    rdata_array.delete();
  endtask

  task automatic tc_write_seq(
    input logic [8:0] beats,
    input logic [31:0] offset
  );

    $display("Testing %d-beat write at 0x%0H\n", beats+1, offset);

    // Allocate randomized values in static arrays
    wdata_array = new[beats+1];

    // Generate random values in write data array
    $display("Write Array Contents:");
    foreach (wdata_array[i]) begin
      wdata_array[i] = $urandom(); 
      $display("Item[%d]: 0x%0H", i, wdata_array[i]);
    end

    // Write array to AXI VIP
    tc_write_trans(beats, offset);

    wdata_array.delete();
  endtask

  task automatic tc_read_seq(
    input logic [8:0] beats,
    input logic [31:0] offset
  );

    $display("Testing %d-beat read at 0x%0H", beats+1, offset);

    // Allocate randomized values in static arrays
    rdata_array = new[beats+1];

    // Read from AXI VIP
    tc_read_trans(beats, offset);

    $display("Read Array Contents:");
    foreach(rdata_array[i]) begin
      $display("Item[%d]: 0x%0H", i, rdata_array[i]);
    end

    rdata_array.delete();
  endtask


  initial begin
    // Start AXI Slave VIP
    slv_agent = new("AXI Slave Agent", dut.axi_vip_0.inst.IF);
    slv_agent.start_slave();

    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;
    wait (`HIP_AXI_M.M_AXI_ARESETN == 1'b1);
    @(posedge clk);

    tc_write_seq(0, 32'h0000_0000);
    tc_write_seq(3, 32'h0000_1000);
    tc_read_seq(0, 32'h0000_0000);
    tc_read_seq(3, 32'h0000_1000);

    tc_wr_seq(63, 32'h0000_0000);
    tc_wr_seq(255, 32'h0000_0000);


    wait(`HIP_AXI_M.M_AXI_WREADY == 1'b1);

    $display("Finished Tests\n");
    
    repeat(5) @(posedge clk)

    $finish; 
  end


endmodule