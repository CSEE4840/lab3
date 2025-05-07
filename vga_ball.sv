Error (10028): Can't resolve multiple constant drivers for net "pacman_dir[2]" at vga_ball.sv(73) File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/soc_system/synthesis/submodules/vga_ball.sv Line: 73
Error (10029): Constant driver at vga_ball.sv(55) File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/soc_system/synthesis/submodules/vga_ball.sv Line: 55
Error (10028): Can't resolve multiple constant drivers for net "pacman_dir[1]" at vga_ball.sv(73) File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/soc_system/synthesis/submodules/vga_ball.sv Line: 73
Error (10028): Can't resolve multiple constant drivers for net "pacman_dir[0]" at vga_ball.sv(73) File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/soc_system/synthesis/submodules/vga_ball.sv Line: 73
Error (12152): Can't elaborate user hierarchy "soc_system:soc_system0|vga_ball:vga_ball_0" File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/soc_system/synthesis/soc_system.v Line: 333



module vga_ball (
    input clk,
    input reset,
    input [15:0] writedata,
    input write,
    input chipselect,
    input [4:0] address,

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

    // Direction encoding
    localparam DIR_UP = 2'd0, DIR_RIGHT = 2'd1, DIR_DOWN = 2'd2, DIR_LEFT = 2'd3;

    // Pac-Man position and direction
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;
    reg [1:0] pacman_dir;

    // Ghosts: 4 ghosts
    reg [9:0] ghost_x[0:3];
    reg [9:0] ghost_y[0:3];
    reg [1:0] ghost_dir[0:3];

    // 1Hz auto-rotate
    reg [25:0] second_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            second_counter <= 0;
            pacman_dir <= DIR_RIGHT;

            ghost_x[0] <= 100; ghost_y[0] <= 100; ghost_dir[0] <= DIR_LEFT;
            ghost_x[1] <= 200; ghost_y[1] <= 100; ghost_dir[1] <= DIR_RIGHT;
            ghost_x[2] <= 300; ghost_y[2] <= 100; ghost_dir[2] <= DIR_UP;
            ghost_x[3] <= 400; ghost_y[3] <= 100; ghost_dir[3] <= DIR_DOWN;

        end else begin
            second_counter <= second_counter + 1;
            if (second_counter == 50_000_000) begin
                second_counter <= 0;
                pacman_dir <= pacman_dir + 1;

                ghost_dir[0] <= ghost_dir[0] + 1;
                ghost_dir[1] <= ghost_dir[1] + 1;
                ghost_dir[2] <= ghost_dir[2] + 1;
                ghost_dir[3] <= ghost_dir[3] + 1;
            end
        end
    end

    // Software write
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pacman_x <= 340;
            pacman_y <= 240;
        end else if (chipselect && write) begin
            case (address)
                5'd0: begin
                    pacman_x <= writedata[7:0];
                    pacman_y <= writedata[15:8];
                end
                5'd3: pacman_dir <= writedata[1:0];
            endcase
        end
    end

    // Tile and character memory
    reg [11:0] tile[0:4799];
    reg [7:0] tile_bitmaps[0:8191];
    reg [7:0] char_bitmaps[0:575];
    integer i;
integer base_tile;
    initial begin
        $readmemh("map.vh", tile);
        $readmemh("tiles.vh", tile_bitmaps);
        $readmemh("characters.vh", char_bitmaps);

        // SCORE at tile[980]
        base_tile = 980;
        tile[base_tile + 0]  = 12'd1000;
        tile[base_tile + 1]  = 12'd1002;
        tile[base_tile + 2]  = 12'd1004;
        tile[base_tile + 3]  = 12'd1006;
        tile[base_tile + 4]  = 12'd1008;

        tile[base_tile + 80] = 12'd1001;
        tile[base_tile + 81] = 12'd1003;
        tile[base_tile + 82] = 12'd1005;
        tile[base_tile + 83] = 12'd1007;
        tile[base_tile + 84] = 12'd1009;

        for (i = 0; i < 8; i++) begin
            tile_bitmaps[1000 * 8 + i] = char_bitmaps[18 * 16 + i];
            tile_bitmaps[1001 * 8 + i] = char_bitmaps[18 * 16 + i + 8];
            tile_bitmaps[1002 * 8 + i] = char_bitmaps[2  * 16 + i];
            tile_bitmaps[1003 * 8 + i] = char_bitmaps[2  * 16 + i + 8];
            tile_bitmaps[1004 * 8 + i] = char_bitmaps[14 * 16 + i];
            tile_bitmaps[1005 * 8 + i] = char_bitmaps[14 * 16 + i + 8];
            tile_bitmaps[1006 * 8 + i] = char_bitmaps[17 * 16 + i];
            tile_bitmaps[1007 * 8 + i] = char_bitmaps[17 * 16 + i + 8];
            tile_bitmaps[1008 * 8 + i] = char_bitmaps[4  * 16 + i];
            tile_bitmaps[1009 * 8 + i] = char_bitmaps[4  * 16 + i + 8];
        end
    end

    // Pac-Man sprites
    reg [31:0] pacman_up[0:15], pacman_right[0:15], pacman_down[0:15], pacman_left[0:15];
    initial begin
        $readmemh("pacman_up.vh",    pacman_up);
        $readmemh("pacman_right.vh", pacman_right);
        $readmemh("pacman_down.vh",  pacman_down);
        $readmemh("pacman_left.vh",  pacman_left);
    end

    // Ghost shared sprite
	localparam logic [1:0] GHOST_LEFT [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd3,2'd3,2'd2,2'd1,2'd3,2'd3,2'd2,2'd1,2'd3,2'd3,2'd1,2'd1,2'd0,2'd0},
    '{2'd1,2'd1,2'd3,2'd3,2'd2,2'd1,2'd3,2'd3,2'd2,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd0},
    '{2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};

	localparam logic [1:0] GHOST_UP [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};
	localparam logic [1:0] GHOST_RIGHT [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd2,2'd3,2'd3,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};

	localparam logic [1:0] GHOST_DOWN [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd3,2'd3,2'd2,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};



    // VGA tile render
    wire [6:0] tile_x = hcount[10:4];
    wire [6:0] tile_y = vcount[9:3];
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [11:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id * 8 + ty];
    wire pixel_on = bitmap_row[7 - tx];

    // Pac-Man render
    wire [3:0] pacman_x16 = hcount[10:1] - pacman_x;
    wire [3:0] pacman_y16 = vcount - pacman_y;
    wire on_pacman = (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
                      vcount >= pacman_y && vcount < pacman_y + 16);

    reg [31:0] pacman_row;
        integer gi;
    integer gx;
    integer gy;
    reg [1:0] ghost_pixel;
reg [1:0] pacman_pixel;
    // VGA pixel output with ghost overlay
    always @(*) begin
        VGA_R = 0;
        VGA_G = 0;
        VGA_B = 0;

        // Tile background
        if (pixel_on)
            VGA_B = 8'hFF;

        // Ghosts
        for (gi = 0; gi < 4; gi = gi + 1) begin
            if (hcount[10:1] >= ghost_x[gi] && hcount[10:1] < ghost_x[gi] + 16 &&
                vcount           >= ghost_y[gi] && vcount           < ghost_y[gi] + 16) begin

                // compute local coordinates
                gx = hcount[10:1] - ghost_x[gi];
                gy = vcount           - ghost_y[gi];

                // pick the right row/column from the ghost sprite
                case (ghost_dir[gi])
                    DIR_UP:    ghost_pixel = GHOST_UP[gy][gx];
                    DIR_DOWN:  ghost_pixel = GHOST_DOWN[gy][gx];
                    DIR_LEFT:  ghost_pixel = GHOST_LEFT[gy][gx];
                    DIR_RIGHT: ghost_pixel = GHOST_RIGHT[gy][gx];
                    default:   ghost_pixel = 2'b00;
                endcase

                // overlay the ghost pixel
                case (ghost_pixel)
                    2'b01: begin
                        case (gi)
                            0: begin VGA_R = 8'hFF; VGA_G = 0;     VGA_B = 0;     end // Red
                            1: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 8'hFF; end // Pink
                            2: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 0;     end // Orange
                            3: begin VGA_R = 0;     VGA_G = 8'hFF; VGA_B = 8'hFF; end // Light Blue
                        endcase
                    end
                    2'b10: begin VGA_R = 8'hFF; VGA_G = 8'hFF; VGA_B = 8'hFF; end // White
                    2'b11: begin VGA_R = 0;     VGA_G = 0;     VGA_B = 8'h88; end // Dark Blue
                endcase
            end
        end

        // Pac-Man (always yellow)
        if (on_pacman) begin
            case (pacman_pixel)
                2'b01, 2'b10, 2'b11: begin
                    VGA_R = 8'hFF;
                    VGA_G = 8'hFF;
                    VGA_B = 0;
                end
                default: ;
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
