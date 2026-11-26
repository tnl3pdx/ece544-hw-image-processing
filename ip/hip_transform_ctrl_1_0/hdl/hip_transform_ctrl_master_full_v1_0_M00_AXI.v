
`timescale 1 ns / 1 ps

	module hip_transform_ctrl_master_full_v1_0_M00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Base address of targeted slave
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		// Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		parameter integer C_M_AXI_BURST_LEN	= 256,
		// Thread ID Width
		parameter integer C_M_AXI_ID_WIDTH	= 1,
		// Width of Address Bus
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		// Width of Data Bus
		parameter integer C_M_AXI_DATA_WIDTH	= 32,
		// Width of User Write Address Bus
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		// Width of User Read Address Bus
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		// Width of User Write Data Bus
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		// Width of User Read Data Bus
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		// Width of User Response Bus
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Initiate AXI transactions
		input wire  INIT_AXI_TXN,
		// Asserts when transaction is complete
		output wire  TXN_DONE,
		// Asserts when ERROR is detected
		output reg  ERROR,
		// Global Clock Signal.
		input wire  M_AXI_ACLK,
		// Global Reset Singal. This Signal is Active Low
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address ID
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		// Master Interface Write Address
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output wire [7 : 0] M_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_AWSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_AWBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each write transaction.
		output wire [3 : 0] M_AXI_AWQOS,
		// Optional User-defined signal in the write address channel.
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid write address and control information.
		output wire  M_AXI_AWVALID,
		// Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data.
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write last. This signal indicates the last transfer in a write burst.
		output wire  M_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		// Write valid. This signal indicates that valid write
    // data and strobes are available
		output wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    // can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		// Write response. This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Optional User-defined signal in the write response channel
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		// Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master
    // can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address.
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		// Read address. This signal indicates the initial
    // address of a read burst transaction.
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output wire [7 : 0] M_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_ARSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_ARBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each read transaction
		output wire [3 : 0] M_AXI_ARQOS,
		// Optional User-defined signal in the read address channel.
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid read address and control information
		output wire  M_AXI_ARVALID,
		// Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		// Master Read Data
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer
		input wire [1 : 0] M_AXI_RRESP,
		// Read last. This signal indicates the last transfer in a read burst
		input wire  M_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		// Read valid. This signal indicates that the channel
    // is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    // accept the read data and response information.
		output wire  M_AXI_RREADY
	);


	// function called clogb2 that returns an integer which has the
	//value of the ceiling of the log base 2

	  // function called clogb2 that returns an integer which has the 
	  // value of the ceiling of the log base 2.                      
	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     

	// C_TRANSACTIONS_NUM is the width of the index counter for 
	// number of write or read transaction.
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);

	// Example State machine to initialize counter, initialize write transactions, 
	// initialize read transactions and comparison of read data with the 
	// written data words.
	localparam [1:0] 
    IDLE = 2'b00, // This state initiates AXI4Lite transaction 
		INIT_WRITE   = 2'b01, // This state initializes write transaction,
		INIT_READ = 2'b10, // This state initializes read transaction

	        WADDR = 2'b10, // This state initializes write address transaction 
	                       // once write address is done, the state machine  
	                       // changes state to WDATA 
	        WDATA = 2'b11, // This state initializes write data transactions 
	                       // once the written data are done, the state machine 
	                       // changes state to WADDR 
	        RADDR = 2'b10, // This state initializes read address transaction 
	                       // once read address is done, the state machine  
	                       // changes state to RDATA 
	        RDATA = 2'b11; // This state initializes read data transactions 
	                       // once the data are read, the state machine 
	                       // changes state to RADDR 

	//reg [1:0] w_flow_state;
	//reg [1:0] r_flow_state;
	reg [1:0] state_write; 
	reg [1:0] state_read; 

	// AXI4 signals
	//AXI4 internal temp signals
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid;
	reg  	axi_wlast;
	reg  	axi_wvalid;
	reg  	axi_bready;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid;
	reg  	axi_rready;
	//write beat count in a burst
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	//read beat count in a burst
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	reg  	writes_done;
	reg  	reads_done;
	//Interface response error flags
	wire  	write_resp_error;
	wire  	read_resp_error;

	// User Signals
	wire [C_M_AXI_DATA_WIDTH-1:0] w_data_bus;
  wire [C_TRANSACTIONS_NUM:0] w_count_bus;
	wire [C_M_AXI_DATA_WIDTH-1:0] w_offset;
	wire w_slv_ready; // Asserted when slave is ready to receive write
	wire w_done;  // Asserted when write burst has completed

	wire [C_M_AXI_DATA_WIDTH-1:0] r_data_bus;
  wire [C_TRANSACTIONS_NUM:0] r_count_bus;
	wire [C_M_AXI_DATA_WIDTH-1:0] r_offset;
	wire r_slv_valid; // Asserted when slave's RDATA is ready to be read
	wire r_done;  // Asserted when read burst has completed

	wire start_w;
	wire start_r; 

  reg [C_TRANSACTIONS_NUM:0] w_counter_target;
  reg [C_TRANSACTIONS_NUM:0] r_counter_target;

  reg w_pending, r_pending;

	// End of User Signals

	// User Connections

	// Assert done signals for transform controller
	assign w_done = writes_done || (M_AXI_BVALID && axi_bready);
	assign r_done = reads_done || (M_AXI_RVALID && axi_rready && M_AXI_RLAST);

  assign w_slv_ready = M_AXI_WREADY && axi_wvalid;
  assign r_slv_valid = M_AXI_RVALID && axi_rready;

  assign r_data_bus = M_AXI_RDATA;

	// End of User Connections

	// I/O Connections assignments

	//I/O Connections. Write Address (AW)
	assign M_AXI_AWID	= 'b0;
	//The AXI address is a concatenation of the target base address + active offset range
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	//Burst LENgth is number of transaction beats
	assign M_AXI_AWLEN	= w_counter_target;
	//Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	//INCR burst type is usually used, except for keyhole bursts
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	//Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	//Write Data(W)
	assign M_AXI_WDATA	= w_data_bus;
	//All bursts are complete and aligned in this example
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	//Write Response (B)
	assign M_AXI_BREADY	= axi_bready;
	//Read Address (AR)
	assign M_AXI_ARID	= 'b0;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	//Burst LENgth is number of transaction beats, minus 1
	assign M_AXI_ARLEN	= r_counter_target;
	//Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	//INCR burst type is usually used, except for keyhole bursts
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	//Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID	= axi_arvalid;
	//Read and Read Response (R)
	assign M_AXI_RREADY	= axi_rready;

  // -----------------------------------
	// AXI Write Controller State Machine
  // -----------------------------------
	 always @(posedge M_AXI_ACLK)                        
	   begin                                             
	     if (M_AXI_ARESETN == 0)                                  
	       begin                                                                                    
	        axi_awvalid <= 1'b0;                               
	        axi_awaddr <= 1'b0;                        
	        axi_wvalid <= 1'b0;                        
	        axi_wlast <= 1'b0;                        
	        write_index <= 0;                                               
	        axi_bready <= 1'b0;                         
	        state_write <= IDLE;
          w_pending <= 1'b0;
          w_counter_target <= 0;
	       end                                                                                      
	    else if (start_w) begin
        axi_awvalid <= 1'b0;
        axi_wvalid  <= 1'b0;
        axi_wlast   <= 1'b0;
        axi_bready  <= 1'b0;
        write_index <= 0;
        state_write <= IDLE;
        w_pending <= 1'b1;
        w_counter_target <= w_count_bus;
      end else begin                        
	        case(state_write)                        
	          IDLE:                        
	            begin  
                // When w_pending is asserted, initiate
                // a write transaction                      
	              if (w_pending) begin    
                  axi_awvalid <= 1;                                             
                  axi_bready <= 0;                        
                  axi_wlast <= 0;                        
                  axi_awaddr <= w_offset;
                  write_index <= 0;
                  state_write <= WADDR;
                  w_pending <= 1'b0;                     
                end else begin                        
	                  if (M_AXI_BVALID && axi_bready) axi_bready <= 0;                        
	                  state_write <= state_write;                        
	                end                        
	            end                        
	          WADDR:                        
	//--------------------
	//Write Address Channel
	//--------------------
	            begin
                // If slave is ready (via AWREADY) and master has asserted awvalid,
                // start transaction                          
	              if (M_AXI_AWREADY && axi_awvalid)                          
	                begin
                    axi_awvalid <= 1'b0;
	                  axi_wvalid <= 1'b1;                                                                                                  
                    axi_wlast <= (w_counter_target == 0);
                    state_write <= WDATA;                                                       
	               end                         
	             else                          
	               begin                         
	                 if (axi_bready && M_AXI_BVALID) axi_bready <= 1'b0;                         
	                 state_write <= state_write;                         
	               end                         
	            end                         
	          WDATA:     
	//--------------------
	//Write Data Channel
	//--------------------
	            begin                      
	              if (M_AXI_WREADY && axi_wlast && axi_wvalid)                        
	                begin                                              
	                  axi_awvalid <= 1'b0;                               
	                  axi_wvalid <= 1'b0;                        
	                  axi_wlast <= 1'b0;                                                                    
	                  axi_bready <= 1'b1;
                    state_write <= IDLE;                     
	                end                        
	              else if (M_AXI_WREADY && axi_wvalid)                         
	                begin                                              
	                  if (write_index != w_counter_target)  write_index <= write_index + 1;                        
	                  if (write_index == w_counter_target-1) axi_wlast <= 1;                        
	                end                           
	            end                        
	       endcase                        
	     end                                             
	     end	                        

	//Flag any write response errors
	  assign write_resp_error = axi_bready & M_AXI_BVALID & M_AXI_BRESP[1];                    
	
  // -----------------------------------
	// AXI Read Controller State Machine
  // ----------------------------------- 
  always @(posedge M_AXI_ACLK)                         
	   begin                                              
	     if (M_AXI_ARESETN == 0)                           
	       begin                                                                                   
	         axi_arvalid <= 1'b0;                         
	         axi_rready <= 1'b0;                            
	         axi_araddr <= 0;                         
	         read_index <= 0;                         
	         state_read <= IDLE;
           r_pending <= 1'b0;
           r_counter_target <= 0;                             
	       end                                                                                              
	     else if (start_r) begin
        axi_arvalid <= 1'b0;                         
        axi_rready <= 1'b0;                                                    
        read_index <= 0;
        state_read <= IDLE;
        r_pending <= 1'b1;
        r_counter_target <= r_count_bus;
       end else begin                         
	        case(state_read)                         
	          IDLE:                         
	            begin                         
	             if (r_pending)                         
	               begin                         
	                 axi_arvalid <= 1;                         
	                 state_read <= RADDR; 
                   axi_araddr <= r_offset;
                   r_pending <= 1'b0;                            
	               end                         
	             else                          
	               begin                         
	                 state_read <= state_read;                         
	               end                         
	            end                         
	          RADDR:                         


	//----------------------------
	//Read Address Channel
	//----------------------------

	//The Read Address Channel (AW) provides a similar function to the
	//Write Address channel- to provide the tranfer qualifiers for the burst.

	//In this example, the read address increments in the same
	//manner as the write address channel.

	            begin                             
	              if(axi_arvalid && M_AXI_ARREADY)                             
	                begin                             
	                  axi_arvalid <= 0;                             
	                  axi_rready <= 1;                                                       
	                  state_read <= RDATA;                             
	                end                             
	              else state_read <= state_read;                             
	            end                             
	          RDATA:                         


	//--------------------------------
	//Read Data (and Response) Channel
	//--------------------------------

	            begin                                                  
	              if (M_AXI_RVALID && axi_rready && M_AXI_RLAST)                                                  
	                begin                                                  
	                  state_read <= IDLE;                                                  
	                  axi_arvalid <= 0;                                                  
	                  axi_rready <= 0;
                    read_index <= 0;                                                   
	                end                                                                                                   
	               else if (M_AXI_RVALID && axi_rready && (read_index != r_counter_target)) 
                  begin
                    read_index <= read_index + 1;
                  end                                                  
	            end                                                  
	        endcase                     
	     end                                                                                  
	   end                                                                                                               
  
  //Flag any read response errors                                                  
	 assign read_resp_error = axi_rready & M_AXI_RVALID & M_AXI_RRESP[1];
	
  /*
	// Write/Read State Machines and Control Signaling
	always @(posedge M_AXI_ACLK)  begin
		if (M_AXI_ARESETN == 1'b0)  begin
			w_flow_state <= IDLE;
      w_counter_target <= 'b0;
		end else begin 
			case (w_flow_state)
				IDLE:
					// Go into INIT_WRITE when start_w asserted
          // Latch counter target for number of bursts
					if (start_w == 1'b1) begin
						w_flow_state <= INIT_WRITE;
            w_counter_target <= w_count_bus;
					end
				INIT_WRITE:
					// Go back into IDLE when writes are done
					if (writes_done == 1'b1) begin
						w_flow_state <= IDLE;
					end
				default: begin
					w_flow_state <= IDLE;
          w_counter_target <= 'b0;
        end
			endcase
		end
	end

	always @(posedge M_AXI_ACLK)  begin
		if (M_AXI_ARESETN == 1'b0)  begin
			r_flow_state <= IDLE;
      r_counter_target <= 'b0;
		end else begin 
			case (r_flow_state)
				IDLE:
					// Go into INIT_READ when start_r asserted
					if (start_r == 1'b1) begin
						r_flow_state <= INIT_READ;
            r_counter_target <= r_count_bus;
					end
				INIT_READ:
					// Go back into IDLE when reads are done
					if (reads_done == 1'b1) begin
						r_flow_state <= IDLE;
					end
				default: begin
					r_flow_state <= IDLE;
          r_counter_target <= 'b0;
        end
			endcase
		end
	end
*/
	//--------------------------------
	//Example design throttling
	//--------------------------------

	// For maximum port throughput, this user example code will try to allow
	// each channel to run as independently and as quickly as possible.

	// However, there are times when the flow of data needs to be throtted by
	// the user application. This example application requires that data is
	// not read before it is written and that the write channels do not
	// advance beyond an arbitrary threshold (say to prevent an 
	// overrun of the current read address by the write address).

	// From AXI4 Specification, 13.13.1: "If a master requires ordering between 
	// read and write transactions, it must ensure that a response is received 
	// for the previous transaction before issuing the next transaction."

	// This example accomplishes this user application throttling through:
	// -Reads wait for writes to fully complete
	// -Address writes wait when not read + issued transaction counts pass 
	// a parameterized threshold
	// -Writes wait when a not read + active data burst count pass 
	// a parameterized threshold
                                                                                                                                                                                                         
	 // Check for last write completion.                                                                        
	                                                                                                            
	 // This logic is to qualify the last write count with the final write                                      
	 // response. This demonstrates how to confirm that a write has been                                        
	 // committed.                                                                                              
                                                                                                       
  always @(posedge M_AXI_ACLK) begin
      if (M_AXI_ARESETN == 1'b0)
          writes_done <= 1'b0;
      else if (start_w)
          writes_done <= 1'b0;
      else if (M_AXI_BVALID && axi_bready)
          writes_done <= 1'b1;
  end                                                                                                  
	                                                                                                            
	                                                                                                            
	 // Check for last read completion.                                                                         
	                                                                                                            
	 // This logic is to qualify the last read count with the final read                                        
	 // response. This demonstrates how to confirm that a read has been                                         
	 // committed.                                                                                              
	                                                                                                            
	  always @(posedge M_AXI_ACLK)                                                                              
	  begin                                                                                                     
	    if (M_AXI_ARESETN == 0)                                                                                 
	      reads_done <= 1'b0;                                                                                   
	    else if (start_r)
        reads_done <= 1'b0;                                                                                                        
	    //The reads_done should be associated with a rready response                                            
	    //else if (M_AXI_BVALID && axi_bready && (write_burst_counter == {(C_NO_BURSTS_REQ-1){1}}) && axi_wlast)
	    else if (M_AXI_RVALID && axi_rready && M_AXI_RLAST)
	      reads_done <= 1'b1;  
    end                                                                                                                                                                                   
	// Add user logic here

	




	// User logic ends

	endmodule
