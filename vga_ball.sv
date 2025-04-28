module vga_ball (
    input clk,
    input reset,
    input [15:0] writedata,
    input write,
    input chipselect,
    input [2:0] address,

    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_CLK, VGA_HS, VGA_VS,
    output VGA_BLANK_n, VGA_SYNC_n
);

    // VGA sync counters
    wire [10:0] hcount;
    wire [9:0]  vcount;

    // VGA sync generator instance
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

    // Tile memory (4800 tiles, 6 bits per tile)
    reg [5:0] tiles [0:4799];  // 4800 tiles (0~40 IDs)

    // Tile bitmaps (6 types, example for illustration)
    logic [7:0] tile_bitmaps [0:40][0:7] = '{

 

        '{8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000},
 

        '{8'b00000000,8'b00000000,8'b00011000,8'b00011000,8'b00011000,8'b00011000,8'b00000000,8'b00000000},
 

        '{8'b11111100,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000},
 

        '{8'b00111111,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11111100},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00111111},
 

        '{8'b11111111,8'b00000000,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100},
 

        '{8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00000000,8'b11111111},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b11111111,8'b11111111,8'b11000000,8'b11000000,8'b11000000},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b11111111,8'b11111111,8'b00000011,8'b00000011,8'b00000011},
 

        '{8'b00111100,8'b00111100,8'b00111100,8'b11111111,8'b11111111,8'b00111100,8'b00111100,8'b00111100},
 

        '{8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111},
 

        '{8'b11111111,8'b11111111,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000},
 

        '{8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b11111111,8'b11111111},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011},
 

        '{8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b11111111},
 

        '{8'b00000000,8'b00000000,8'b11111111,8'b11111111,8'b00000000,8'b00000000,8'b00000000,8'b00000000},
 

        '{8'b00110000,8'b00110000,8'b00110000,8'b00110000,8'b00110000,8'b00110000,8'b00110000,8'b00110000},
 

        '{8'b11111111,8'b11111111,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000},
 

        '{8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b11111111,8'b11111111},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011},
 

        '{8'b00000000,8'b00000000,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00000000,8'b00000000},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b00000000,8'b00000000,8'b11000000,8'b11000000},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000000,8'b00000000,8'b00000011,8'b00000011},
 

        '{8'b11111100,8'b11000000,8'b11111100,8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11000000},
 

        '{8'b00111111,8'b00000011,8'b00111111,8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00000011},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b11000000,8'b11111100,8'b11000000,8'b11111100,8'b11000000},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b00000011,8'b00111111,8'b00000011,8'b00111111,8'b00000011},
 

        '{8'b11000000,8'b11000000,8'b11000000,8'b00000000,8'b11000000,8'b11000000,8'b11000000,8'b00000000},
 

        '{8'b00000011,8'b00000011,8'b00000011,8'b00000000,8'b00000011,8'b00000011,8'b00000011,8'b00000000},
 

        '{8'b00111100,8'b00111100,8'b11111111,8'b11111111,8'b11111111,8'b11111111,8'b00111100,8'b00111100},
 

        '{8'b00000000,8'b00000000,8'b00111100,8'b00111100,8'b11111111,8'b11111111,8'b00000000,8'b00000000},
 

        '{8'b00000000,8'b11111111,8'b11111111,8'b00000000,8'b00000000,8'b11111111,8'b11111111,8'b00000000},
 

        '{8'b00011000,8'b00011000,8'b00011000,8'b00011000,8'b00011000,8'b00011000,8'b00011000,8'b00011000},
 

        '{8'b00011000,8'b00011000,8'b00011000,8'b11111111,8'b00011000,8'b00011000,8'b00011000,8'b00011000},
 

        '{8'b00011000,8'b00011000,8'b00011000,8'b11111111,8'b00011000,8'b00011000,8'b00011000,8'b00011000},
 

        '{8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100},
 

        '{8'b00000000,8'b00111100,8'b01111110,8'b01111110,8'b01111110,8'b01111110,8'b00111100,8'b00000000},
 

        '{8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000}
 

    };

    // VGA Output Calculation
    wire [6:0] tile_x = hcount[10:3];  // Tile index in the x-direction
    wire [5:0] tile_y = vcount[9:3];   // Tile index in the y-direction
    wire [2:0] tx = hcount[2:0];       // x-offset inside the tile (for 8x8 pixels)
    wire [2:0] ty = vcount[2:0];       // y-offset inside the tile (for 8x8 pixels)

    integer tile_index;
    wire [5:0] tile_id;

    always @(*) begin
        // Default VGA output to black
        VGA_R = 8'd0;
        VGA_G = 8'd0;
        VGA_B = 8'd0;

        // Tile calculation
        tile_index = tile_y * 80 + tile_x;  // 80 tiles per row (assuming 640 pixels wide)
        tile_id = tiles[tile_index];  // Fetch tile ID from memory

        // Draw tile based on the tile bitmap and offset inside the tile
        if (tile_bitmaps[tile_id][ty][7 - tx]) begin
            VGA_B = 8'hFF;  // Set blue pixel for visible part of the tile
        end
    end

    // Initializing the tiles array
    initial begin
        // Initialize all tiles to empty (tile ID 0)
        integer i;
        for (i = 0; i < 4800; i = i + 1) begin
            tiles[i] = 0;  // Default tile ID 0 (empty or background)
        end

        // ==== Tile Assignments (example) ====
        // Set specific tiles to different tile IDs
        tiles[2356] = 23;  // Set tile at index 2356 to tile ID 23
        tiles[3765] = 12;  // Set tile at index 3765 to tile ID 12
        tiles[4500] = 8;   // Set tile at index 4500 to tile ID 8
        tiles[1800] = 15;  // Set tile at index 1800 to tile ID 15
        tiles[2500] = 5;   // Set tile at index 2500 to tile ID 5
        // You can add as many tile assignments as needed here
        // ======================================
    end

    // Control logic for writing tile data (optional, based on chipselect and write signals)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset tiles to empty on reset
            integer i;
            for (i = 0; i < 4800; i = i + 1) begin
                tiles[i] = 0;
            end
        end else if (chipselect && write) begin
            // Update tile data based on address and writedata
            if (address < 4800) begin
                tiles[address] <= writedata[5:0];  // Write the 6-bit tile ID to the specified address
            end
        end
    end

endmodule
