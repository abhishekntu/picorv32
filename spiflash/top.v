module top (
	input clk,
	output trap,

	input [31:0] gpio_i,
	output reg [31:0] gpio_o,

	output spi_cs,
	output spi_sclk,
	output spi_mosi,
	input spi_miso
);
	parameter integer MEM_WORDS = 256;
	parameter [31:0] STACKADDR = (4*MEM_WORDS);       // end of memory
	parameter [31:0] PROGADDR_RESET = 32'h 8010_0000; // 1 MB into flash

	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	wire mem_valid;
	wire mem_instr;
	reg mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg  [31:0] mem_rdata;

	wire spimem_ready;
	wire [31:0] spimem_rdata;

	picorv32 #(
		.STACKADDR(STACKADDR),
		.PROGADDR_RESET(PROGADDR_RESET)
	) cpu (
		.clk         (clk        ),
		.resetn      (resetn     ),
		.trap        (trap       ),
		.mem_valid   (mem_valid  ),
		.mem_instr   (mem_instr  ),
		.mem_ready   (mem_ready  || spimem_ready),
		.mem_addr    (mem_addr   ),
		.mem_wdata   (mem_wdata  ),
		.mem_wstrb   (mem_wstrb  ),
		.mem_rdata   (spimem_ready ? spimem_rdata : mem_rdata  )
	);

	spimemio spimemio (
		.clk(clk),
		.resetn(resetn),

		.valid (mem_valid && mem_addr[31:30] == 2'b10),
		.ready (spimem_ready),
		.addr  (mem_addr[23:0]),
		.rdata (spimem_rdata),

		.spi_cs   (spi_cs  ),
		.spi_sclk (spi_sclk),
		.spi_mosi (spi_mosi),
		.spi_miso (spi_miso)
	);

	reg [31:0] memory [0:MEM_WORDS-1];

	always @(posedge clk) begin
		mem_ready <= 0;
		if (mem_valid && !mem_ready) begin
			if (mem_addr < 4*MEM_WORDS) begin
				mem_ready <= 1;
				mem_rdata <= memory[mem_addr >> 2];
				if (mem_wstrb[0]) memory[mem_addr >> 2][ 7: 0] <= mem_wdata[ 7: 0];
				if (mem_wstrb[1]) memory[mem_addr >> 2][15: 8] <= mem_wdata[15: 8];
				if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
				if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
			end
			if (mem_addr == 32'h c000_0000) begin
				mem_ready <= 1;
				mem_rdata <= gpio_i;
				if (mem_wstrb[0]) gpio_o[ 7: 0] <= mem_wdata[ 7: 0];
				if (mem_wstrb[1]) gpio_o[15: 8] <= mem_wdata[15: 8];
				if (mem_wstrb[2]) gpio_o[23:16] <= mem_wdata[23:16];
				if (mem_wstrb[3]) gpio_o[31:24] <= mem_wdata[31:24];
			end
		end
	end
endmodule
