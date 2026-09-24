`timescale 1ns/1ps
module tb_nbody_long;
    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic        mmio_we, mmio_re;
    logic [7:0]  mmio_addr;
    logic [31:0] mmio_wdata;
    logic [31:0] mmio_rdata;
    logic        irq;

    nbody_accelerator dut (
        .clk(clk), .rst_n(rst_n),
        .mmio_we(mmio_we), .mmio_re(mmio_re),
        .mmio_addr(mmio_addr), .mmio_wdata(mmio_wdata), .mmio_rdata(mmio_rdata),
        .irq(irq)
    );

    logic [31:0] body_words [0:34];
    initial $readmemh("/tmp/nbody_words32.hex", body_words);

    task automatic mmio_write(input [7:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            mmio_we = 1'b1; mmio_addr = addr; mmio_wdata = data;
            @(negedge clk);
            mmio_we = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task automatic mmio_read(input [7:0] addr, output [31:0] data);
        begin
            @(negedge clk);
            mmio_re = 1'b1; mmio_addr = addr;
            @(negedge clk);
            data = mmio_rdata;
            mmio_re = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    integer i;
    longint unsigned cycle_count;
    logic irq_seen;
    logic [31:0] rdata;

    initial begin
        rst_n = 1'b0; mmio_we = 0; mmio_re = 0; mmio_addr = 0; mmio_wdata = 0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        for (i = 0; i < 35; i = i + 1)
            mmio_write(8'h40 + i*8'd4, body_words[i]);

        mmio_write(8'h08, 32'h3C23D70A);
        mmio_write(8'h0C, `N_ITER_VAL);

        mmio_write(8'h00, 32'h1);

        cycle_count = 0;
        irq_seen = 1'b0;
        while (!irq_seen) begin
            @(negedge clk);
            cycle_count = cycle_count + 1;
            if (irq) irq_seen = 1'b1;
        end

        $display("=== N_ITER=%0d : DONE after %0d cycles ===", `N_ITER_VAL, cycle_count);

        for (i = 0; i < 35; i = i + 1) begin
            mmio_read(8'h40 + i*8'd4, rdata);
            $display("word[%0d] = %h", i, rdata);
        end
        $finish;
    end
endmodule
