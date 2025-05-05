`include "characters.vh"

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

    // Pac-Man position
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;

    wire [9:0] ghost_x = 300;
    wire [9:0] ghost_y = 240;

    // Tile coordinates
    wire [6:0] tile_x = hcount[10:4];  // 640 / 16 = 40
    wire [6:0] tile_y = vcount[9:3];   // 480 / 8 = 60
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    // Write position logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pacman_x <= 340;
            pacman_y <= 240;
        end else if (chipselect && write) begin
            case (address)
                3'd0: pacman_x <= writedata[9:0];
                3'd1: pacman_y <= writedata[9:0];
            endcase
        end
    end

    // Tile map: 80x60 = 4800 tiles
    reg [11:0] tile[0:4799];
    initial begin
        $readmemh("map.vh", tile);
    end

    // Tile bitmaps: each tile has 8 lines, support for >980 tiles
    reg [7:0] tile_bitmaps[0:8191];  // Enough for up to tile 1023
    initial begin
        $readmemh("tiles.vh", tile_bitmaps);
    end

    // Load character bitmaps
    reg [7:0] char_bitmaps[0:575];  // 36 chars × 16 rows
    initial begin
        $readmemh("characters.vh", char_bitmaps);

        integer i;
        for (i = 0; i < 8; i++) begin
            tile_bitmaps[980*8 + i] = char_bitmaps[18*16 + i]; // S
            tile_bitmaps[981*8 + i] = char_bitmaps[2*16  + i]; // C
            tile_bitmaps[982*8 + i] = char_bitmaps[14*16 + i]; // O
            tile_bitmaps[983*8 + i] = char_bitmaps[17*16 + i]; // R
            tile_bitmaps[984*8 + i] = char_bitmaps[4*16  + i]; // E
        end
    end

    // Ghost sprite (16x16)
    reg [15:0] ghost_bitmap[0:15];
    initial begin
        ghost_bitmap[ 0] = 16'b0000000000000000;
        ghost_bitmap[ 1] = 16'b0000001111000000;
        ghost_bitmap[ 2] = 16'b0001111111110000;
        ghost_bitmap[ 3] = 16'b0111111111111100;
        ghost_bitmap[ 4] = 16'b0111111111111100;
        ghost_bitmap[ 5] = 16'b0111001111001110;
        ghost_bitmap[ 6] = 16'b0110000110000110;
        ghost_bitmap[ 7] = 16'b0110000110000110;
        ghost_bitmap[ 8] = 16'b0110000110000110;
        ghost_bitmap[ 9] = 16'b0111001111001110;
        ghost_bitmap[10] = 16'b0111111111111110;
        ghost_bitmap[11] = 16'b0111111111111110;
        ghost_bitmap[12] = 16'b0111111111111110;
        ghost_bitmap[13] = 16'b0110011100110010;
        ghost_bitmap[14] = 16'b1000001100110001;
        ghost_bitmap[15] = 16'b0000000000000000;
    end

    // Pac-Man sprites
    reg [15:0] pacman_up[0:15], pacman_right[0:15], pacman_down[0:15], pacman_left[0:15];
    initial begin
        $readmemh("pacman_up.vh",    pacman_up);
        $readmemh("pacman_right.vh", pacman_right);
        $readmemh("pacman_down.vh",  pacman_down);
        $readmemh("pacman_left.vh",  pacman_left);
    end

    // Direction logic
    localparam DIR_UP = 2'd0, DIR_RIGHT = 2'd1, DIR_DOWN = 2'd2, DIR_LEFT = 2'd3;
    reg [1:0] pacman_dir;

    // Timer
    reg [25:0] timer_count;
    wire one_sec_tick = (timer_count == 26'd49_999_999);
    always @(posedge clk or posedge reset) begin
        if (reset)
            timer_count <= 0;
        else if (one_sec_tick)
            timer_count <= 0;
        else
            timer_count <= timer_count + 1;
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            pacman_dir <= DIR_RIGHT;
        else if (one_sec_tick)
            pacman_dir <= pacman_dir + 1;
    end

    // VGA tile rendering
    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [11:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id * 8 + ty];
    wire pixel_on = bitmap_row[7 - tx];

    always @(*) begin
        VGA_R = 0; VGA_G = 0; VGA_B = 0;

        if (pixel_on)
            VGA_B = 8'hFF;

        // Ghost rendering
        if (hcount[10:1] >= ghost_x && hcount[10:1] < ghost_x + 16 &&
            vcount >= ghost_y && vcount < ghost_y + 16) begin
            if (ghost_bitmap[vcount - ghost_y][15 - (hcount[10:1] - ghost_x)]) begin
                VGA_R = 8'hFF; VGA_B = 8'hFF;
            end
        end

        // Pac-Man rendering
        if (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
            vcount >= pacman_y && vcount < pacman_y + 16) begin
            case (pacman_dir)
                DIR_UP:    if (pacman_up[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
                DIR_RIGHT: if (pacman_right[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
                DIR_DOWN:  if (pacman_down[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
                DIR_LEFT:  if (pacman_left[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
            endcase
        end
    end

endmodule




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

    // Pac-Man position
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;

    wire [9:0] ghost_x = 300;
    wire [9:0] ghost_y = 240;

    // Tile coordinates
    wire [6:0] tile_x = hcount[10:4];  // 640 / 16 = 40 max
    wire [6:0] tile_y = vcount[9:3];   // 480 / 8 = 60 max
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    // Write position logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pacman_x <= 340;
            pacman_y <= 240;
        end else if (chipselect && write) begin
            case (address)
                3'd0: pacman_x <= writedata[9:0];
                3'd1: pacman_y <= writedata[9:0];
            endcase
        end
    end

    // Tile map: 80x60 = 4800 tiles
    reg [5:0] tile[0:4799];
    initial begin
        $readmemh("map.vh", tile);
    end

    // Tile bitmaps: 37 tiles, each with 8 rows
    reg [7:0] tile_bitmaps[0:36*8-1];
    initial begin
        $readmemh("tiles.vh", tile_bitmaps);
    end

    // Ghost sprite (16x16)
    reg [15:0] ghost_bitmap[0:15];
    initial begin
        ghost_bitmap[ 0] = 16'b0000000000000000;
        ghost_bitmap[ 1] = 16'b0000001111000000;
        ghost_bitmap[ 2] = 16'b0001111111110000;
        ghost_bitmap[ 3] = 16'b0111111111111100;
        ghost_bitmap[ 4] = 16'b0111111111111100;
        ghost_bitmap[ 5] = 16'b0111001111001110;
        ghost_bitmap[ 6] = 16'b0110000110000110;
        ghost_bitmap[ 7] = 16'b0110000110000110;
        ghost_bitmap[ 8] = 16'b0110000110000110;
        ghost_bitmap[ 9] = 16'b0111001111001110;
        ghost_bitmap[10] = 16'b0111111111111110;
        ghost_bitmap[11] = 16'b0111111111111110;
        ghost_bitmap[12] = 16'b0111111111111110;
        ghost_bitmap[13] = 16'b0110011100110010;
        ghost_bitmap[14] = 16'b1000001100110001;
        ghost_bitmap[15] = 16'b0000000000000000;
    end

    // Pac-Man directional sprites (16x16)
    reg [15:0] pacman_up    [0:15];
    reg [15:0] pacman_right [0:15];
    reg [15:0] pacman_down  [0:15];
    reg [15:0] pacman_left  [0:15];

    initial begin
        $readmemh("pacman_up.vh",    pacman_up);
        $readmemh("pacman_right.vh", pacman_right);
        $readmemh("pacman_down.vh",  pacman_down);
        $readmemh("pacman_left.vh",  pacman_left);
    end

    // Direction encoding
    localparam DIR_UP    = 2'd0;
    localparam DIR_RIGHT = 2'd1;
    localparam DIR_DOWN  = 2'd2;
    localparam DIR_LEFT  = 2'd3;

    reg [1:0] pacman_dir;

    // 1-second timer (assuming 50 MHz clock)
    reg [25:0] timer_count;
    wire one_sec_tick = (timer_count == 26'd49_999_999);

    always @(posedge clk or posedge reset) begin
        if (reset)
            timer_count <= 26'd0;
        else if (one_sec_tick)
            timer_count <= 26'd0;
        else
            timer_count <= timer_count + 1;
    end

    // Update direction every second
    always @(posedge clk or posedge reset) begin
        if (reset)
            pacman_dir <= DIR_RIGHT; // Starting direction
        else if (one_sec_tick)
            pacman_dir <= pacman_dir + 1;
    end

    // VGA Output logic // --- TILE RENDERING ---
        wire [12:0] tile_index = tile_y * 80 + tile_x;
        wire [5:0] tile_id = tile[tile_index];
        wire [7:0] bitmap_row = tile_bitmaps[tile_id*8+ty];
        wire pixel_on = bitmap_row[7 - tx];
    always @(*) begin
        VGA_R = 8'd0;
        VGA_G = 8'd0;
        VGA_B = 8'd0;

       

        if (pixel_on) begin
            VGA_B = 8'hFF;
        end

        // --- GHOST RENDERING ---
        if (hcount[10:1] >= ghost_x && hcount[10:1] < ghost_x + 16 &&
            vcount >= ghost_y && vcount < ghost_y + 16) begin
            if (ghost_bitmap[vcount - ghost_y][15 - (hcount[10:1] - ghost_x)]) begin
                VGA_R = 8'hFF;
                VGA_B = 8'hFF;
            end
        end

        // --- PACMAN RENDERING ---
        if (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
            vcount >= pacman_y && vcount < pacman_y + 16) begin
            case (pacman_dir)
                DIR_UP:
                    if (pacman_up[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin
                        VGA_R = 8'hFF;
                        VGA_G = 8'hFF;
                    end
                DIR_RIGHT:
                    if (pacman_right[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin
                        VGA_R = 8'hFF;
                        VGA_G = 8'hFF;
                    end
                DIR_DOWN:
                    if (pacman_down[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin
                        VGA_R = 8'hFF;
                        VGA_G = 8'hFF;
                    end
                DIR_LEFT:
                    if (pacman_left[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin
                        VGA_R = 8'hFF;
                        VGA_G = 8'hFF;
                    end
            endcase
        end
    end

endmodule




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

    // Pac-Man position
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;

    wire [9:0] ghost_x = 300;
    wire [9:0] ghost_y = 240;

    // Tile coordinates
    wire [6:0] tile_x = hcount[10:4];  // 640 / 16 = 40 max
    wire [6:0] tile_y = vcount[9:3];   // 480 / 8 = 60 max
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    // Write position logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pacman_x <= 340;
            pacman_y <= 240;
        end else if (chipselect && write) begin
            case (address)
                3'd0: pacman_x <= writedata[9:0];
                3'd1: pacman_y <= writedata[9:0];
            endcase
        end
    end

    // Tile map: 80x60 = 4800 tiles
    reg [5:0] tile[0:4799];
    initial begin
        $readmemh("map.vh", tile);
    end

    // Tile bitmaps: 37 tiles, each with 8 rows
    reg [7:0] tile_bitmaps[0:36][0:7];
    initial begin
        $readmemh("tiles.vh", tile_bitmaps);
    end

    // Ghost and Pac-Man sprites (16x16)
    reg [15:0] ghost_bitmap[0:15];
    reg [15:0] pacman_bitmap[0:15];
    initial begin
        ghost_bitmap[ 0] = 16'b0000000000000000;
        ghost_bitmap[ 1] = 16'b0000001111000000;
        ghost_bitmap[ 2] = 16'b0001111111110000;
        ghost_bitmap[ 3] = 16'b0111111111111100;
        ghost_bitmap[ 4] = 16'b0111111111111100;
        ghost_bitmap[ 5] = 16'b0111001111001110;
        ghost_bitmap[ 6] = 16'b0110000110000110;
        ghost_bitmap[ 7] = 16'b0110000110000110;
        ghost_bitmap[ 8] = 16'b0110000110000110;
        ghost_bitmap[ 9] = 16'b0111001111001110;
        ghost_bitmap[10] = 16'b0111111111111110;
        ghost_bitmap[11] = 16'b0111111111111110;
        ghost_bitmap[12] = 16'b0111111111111110;
        ghost_bitmap[13] = 16'b0110011100110010;
        ghost_bitmap[14] = 16'b1000001100110001;
        ghost_bitmap[15] = 16'b0000000000000000;

        pacman_bitmap[ 0] = 16'b0000000000000000;
        pacman_bitmap[ 1] = 16'b0000011111000000;
        pacman_bitmap[ 2] = 16'b0001111111110000;
        pacman_bitmap[ 3] = 16'b0011111111111000;
        pacman_bitmap[ 4] = 16'b0011111111111000;
        pacman_bitmap[ 5] = 16'b0000111111111100;
        pacman_bitmap[ 6] = 16'b0000000111111100;
        pacman_bitmap[ 7] = 16'b0000000000111100;
        pacman_bitmap[ 8] = 16'b0000000111111100;
        pacman_bitmap[ 9] = 16'b0001111111111100;
        pacman_bitmap[10] = 16'b0011111111111000;
        pacman_bitmap[11] = 16'b0011111111111000;
        pacman_bitmap[12] = 16'b0001111111110000;
        pacman_bitmap[13] = 16'b0000011111000000;
        pacman_bitmap[14] = 16'b0000000000000000;
        pacman_bitmap[15] = 16'b0000000000000000;
    end

    // VGA Output logic
    always @(*) begin
        VGA_R = 8'd0;
        VGA_G = 8'd0;
        VGA_B = 8'd0;

        // --- TILE RENDERING ---
        wire [12:0] tile_index = tile_y * 80 + tile_x;
        wire [5:0] tile_id = tile[tile_index];
        wire [7:0] bitmap_row = tile_bitmaps[tile_id][ty];
        wire pixel_on = bitmap_row[7 - tx];

        if (pixel_on) begin
            VGA_B = 8'hFF;
        end

        // --- GHOST RENDERING ---
        if (hcount[10:1] >= ghost_x && hcount[10:1] < ghost_x + 16 &&
            vcount >= ghost_y && vcount < ghost_y + 16) begin
            if (ghost_bitmap[vcount - ghost_y][15 - (hcount[10:1] - ghost_x)]) begin
                VGA_R = 8'hFF;
                VGA_B = 8'hFF;
            end
        end

        // --- PACMAN RENDERING ---
        if (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
            vcount >= pacman_y && vcount < pacman_y + 16) begin
            if (pacman_bitmap[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin
                VGA_R = 8'hFF;
                VGA_G = 8'hFF;
            end
        end
    end

endmodule





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

    // Tile addressing	
    integer i;
    wire [6:0] tile_x = hcount[10:4];
    wire [6:0] tile_y = vcount[9:3];
    wire [2:0] tx = hcount[2:0];
    wire [2:0] ty = vcount[2:0];

    // Tile bitmaps (initialized directly in declaration)
    logic [7:0] tile_bitmaps [37:0][7:0] = '{
    '{8'b00001111, 8'b00110000, 8'b01000000, 8'b01000111, 8'b10001000, 8'b10010000, 8'b10010000, 8'b10010000},
    '{8'b11111111, 8'b00000000, 8'b00000000, 8'b11111111, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b11111111, 8'b00000000, 8'b00000000, 8'b11100000, 8'b00010000, 8'b00001000, 8'b00001000, 8'b00001000},
    '{8'b11111111, 8'b00000000, 8'b00000000, 8'b00000111, 8'b00001000, 8'b00010000, 8'b00010000, 8'b00010000},
    '{8'b11110000, 8'b00001100, 8'b00000010, 8'b11100010, 8'b00010001, 8'b00001001, 8'b00001001, 8'b00001001},
    '{8'b00001001, 8'b00001001, 8'b00001001, 8'b00010001, 8'b11100010, 8'b00000010, 8'b00001100, 8'b11110000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111111, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000111, 8'b00001000, 8'b00010000, 8'b00010000, 8'b00010000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b11100000, 8'b00010000, 8'b00001000, 8'b00001000, 8'b00001000},
    '{8'b10010000, 8'b10010000, 8'b10010000, 8'b10010000, 8'b10010000, 8'b10010000, 8'b10010000, 8'b10010000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00011000, 8'b00011000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00001000, 8'b00001000, 8'b00001000, 8'b00001000, 8'b00001000, 8'b00001000, 8'b00001000, 8'b00001000},
    '{8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000},
    '{8'b00001001, 8'b00001001, 8'b00001001, 8'b00001001, 8'b00001001, 8'b00001001, 8'b00001001, 8'b00001001},
    '{8'b00001001, 8'b00001001, 8'b00001001, 8'b00010001, 8'b11100001, 8'b00000001, 8'b00000001, 8'b00000001},
    '{8'b10010000, 8'b10010000, 8'b10010000, 8'b10001000, 8'b10000111, 8'b10000000, 8'b10000000, 8'b10000000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b11111111, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00010000, 8'b00010000, 8'b00010000, 8'b00001000, 8'b00000111, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00001000, 8'b00001000, 8'b00001000, 8'b00010000, 8'b11100000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b10010000, 8'b10010000, 8'b10010000, 8'b10001000, 8'b01000111, 8'b01000000, 8'b00110000, 8'b00001111},
    '{8'b00111100, 8'b01111110, 8'b11111111, 8'b11111111, 8'b11111111, 8'b11111111, 8'b01111110, 8'b00111100},
    '{8'b00001000, 8'b00001000, 8'b00001000, 8'b00000100, 8'b00000011, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00010000, 8'b00010000, 8'b00010000, 8'b00100000, 8'b11000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00001111, 8'b00001000, 8'b00001000, 8'b00001001},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111111, 8'b00000001, 8'b00000001, 8'b11111111},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111111, 8'b10000000, 8'b10000000, 8'b11111111},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11110000, 8'b00010000, 8'b00010000, 8'b10010000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000011, 8'b00000100, 8'b00001000, 8'b00001000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111111, 8'b00000000, 8'b00000000, 8'b11111111},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11000000, 8'b00100000, 8'b00010000, 8'b00010000},
    '{8'b00001001, 8'b00001000, 8'b00001000, 8'b00001111, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111111, 8'b11111111, 8'b00000000},
    '{8'b10010000, 8'b00010000, 8'b00010000, 8'b11110000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00001000, 8'b00001000, 8'b00000100, 8'b00000011, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b00010000, 8'b00010000, 8'b00100000, 8'b11000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},
    '{8'b10000000, 8'b10000000, 8'b10000000, 8'b10000111, 8'b10001000, 8'b10010000, 8'b10010000, 8'b10010000},
    '{8'b00000001, 8'b00000001, 8'b00000001, 8'b11100001, 8'b00010001, 8'b00001001, 8'b00001001, 8'b00001001},
    '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000}
    };


    // Tile map (80x60 = 4800 entries)
    reg [5:0] tile [0:4799];

    // Example tile placements
    initial begin
	for (i=0; i<4800; i=i+1)
	   tile[i] = 6'd37;
        tile[1226] = 6'd0;
        for (i=1227; i<1238; i=i+1)
	   tile[i] = 6'd1;
	tile[1239] = 6'd2;
	tile[1240] = 6'd3;
	for (i=1241; i<1252; i=i+1)
	   tile[i] = 6'd1;
	tile[1253] = 6'd4;
        
    end

    // Tile selection
    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [5:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id][ty];

    // VGA Output
    always @(*) begin
        VGA_R = 8'd0;
        VGA_G = 8'd0;
        VGA_B = 8'd0;

        if (bitmap_row[7 - tx]) begin
            VGA_R = 8'h00;
            VGA_G = 8'h00;
            VGA_B = 8'hFF;
        end
    end

endmodule
