module vga_ball (
    input clk,
    input reset,

    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_CLK, VGA_HS, VGA_VS,
    output VGA_BLANK_n, VGA_SYNC_n
);

    // VGA sync counters
    wire [10:0] hcount;
    wire [9:0]  vcount;

    vga_counters counters_inst (
        .clk50(clk),
        .hcount(hcount),
        .vcount(vcount),
        .VGA_CLK(VGA_CLK),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_n(VGA_BLANK_n),
        .VGA_SYNC_n(VGA_SYNC_n)
    );

    // Tile memory
    reg [5:0] tiles [0:4799];  // 4800 tiles (0~40 IDs)

    // Tile bitmaps
    reg [7:0] tile_bitmaps [0:40][0:7]; // 41 tile types, 8x8 each

    integer i;
    initial begin
        // Initialize all tiles to empty (tile ID 0)
        for (i = 0; i < 4800; i = i + 1)
            tiles[i] = 0;

        // ==== YOUR TILE ASSIGNMENTS BELOW ====
        // Example:
        // tiles[2356] = 12;
        // tiles[xxxx] = yy;
        // (you will write 2000 lines here manually or by script)
        // ======================================
    end

    // VGA Output
    always @(*) begin
        VGA_R = 8'd0;
        VGA_G = 8'd0;
        VGA_B = 8'd0;

        // Tile calculation
        wire [6:0] tile_x = hcount[10:3];
        wire [5:0] tile_y = vcount[9:3];
        wire [2:0] tx = hcount[2:0];
        wire [2:0] ty = vcount[2:0];

        integer tile_index = tile_y * 80 + tile_x;
        reg [5:0] tile_id;
        tile_id = tiles[tile_index];

        // Draw tile
        if (tile_bitmaps[tile_id][ty][7 - tx]) begin
            VGA_B = 8'hFF;  // Set blue pixel
        end
    end

endmodule
