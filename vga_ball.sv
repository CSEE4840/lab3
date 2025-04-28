Error: Verilog HDL syntax error at vga_ball.sv(85) near text: "wire";  expecting "end". Check for and fix any syntax errors that appear immediately before or at the specified keyword. The Intel FPGA Knowledge Database contains many articles with specific details on how to resolve this error. Visit the Knowledge Database at https://www.altera.com/support/support-resources/knowledge-base/search.html and search for this specific error message number. File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 85
Error: Verilog HDL syntax error at vga_ball.sv(86) near text: "wire";  expecting "end". Check for and fix any syntax errors that appear immediately before or at the specified keyword. The Intel FPGA Knowledge Database contains many articles with specific details on how to resolve this error. Visit the Knowledge Database at https://www.altera.com/support/support-resources/knowledge-base/search.html and search for this specific error message number. File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 86
Error: Verilog HDL syntax error at vga_ball.sv(87) near text: "wire";  expecting "end". Check for and fix any syntax errors that appear immediately before or at the specified keyword. The Intel FPGA Knowledge Database contains many articles with specific details on how to resolve this error. Visit the Knowledge Database at https://www.altera.com/support/support-resources/knowledge-base/search.html and search for this specific error message number. File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 87
Error: Verilog HDL syntax error at vga_ball.sv(88) near text: "wire";  expecting "end". Check for and fix any syntax errors that appear immediately before or at the specified keyword. The Intel FPGA Knowledge Database contains many articles with specific details on how to resolve this error. Visit the Knowledge Database at https://www.altera.com/support/support-resources/knowledge-base/search.html and search for this specific error message number. File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 88
Error: Verilog HDL syntax error at vga_ball.sv(90) near text: "integer";  expecting "end". Check for and fix any syntax errors that appear immediately before or at the specified keyword. The Intel FPGA Knowledge Database contains many articles with specific details on how to resolve this error. Visit the Knowledge Database at https://www.altera.com/support/support-resources/knowledge-base/search.html and search for this specific error message number. File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 90
Error: Verilog HDL syntax error at vga_ball.sv(91) near text: "wire";  expecting "end". Check for and fix any syntax errors that appear immediately before or at the specified keyword. The Intel FPGA Knowledge Database contains many articles with specific details on how to resolve this error. Visit the Knowledge Database at https://www.altera.com/support/support-resources/knowledge-base/search.html and search for this specific error message number. File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 91
Error: Ignored design unit "vga_ball" at vga_ball.sv(7) due to previous errors File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 7
Error: Ignored design unit "vga_counters" at vga_ball.sv(120) due to previous errors File: /homes/user/stud/fall24/ty2534/Downloads/MazeGame/pacman-main/hardware/vga_ball.sv Line: 120
Warning: Quartus Prime Generate HDL Interface was unsuccessful. 8 errors, 0 warnings
Error:     Peak virtual memory: 889 megabytes
Error:     Processing ended: Mon Apr 28 17:17:07 2025
Error:     Elapsed time: 00:00:01
Error:     Total CPU time (on all processors): 00:00:00
Error: No modules found when analyzing null.



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

    // Tile memory (4800 tiles, each stores 6 bits for tile ID)
    reg [5:0] tiles [0:4799];

    // Tile bitmaps (41 tile types, each 8 rows of 8 bits)
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
        '{8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100,8'b00111100},
        '{8'b00000000,8'b00111100,8'b01111110,8'b01111110,8'b01111110,8'b01111110,8'b00111100,8'b00000000},
        '{8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000,8'b00000000}
    };

    // VGA Output
    always @(*) begin
        VGA_R = 0;
        VGA_G = 0;
        VGA_B = 0;

        wire [6:0] tile_x = hcount[10:3];
        wire [5:0] tile_y = vcount[9:3];
        wire [2:0] tx = hcount[2:0];
        wire [2:0] ty = vcount[2:0];

        integer tile_index = tile_y * 80 + tile_x;
        wire [5:0] tile_id = tiles[tile_index];

        if (tile_bitmaps[tile_id][ty][7 - tx]) begin
            VGA_B = 8'hFF;
        end
    end

    // Tile initialization
    initial begin
        integer i;
        for (i = 0; i < 4800; i = i + 1) begin
            tiles[i] = 0; // Default to background
        end

        // ====== Your tile assignment here ======
        tiles[2356] = 23;
        tiles[3765] = 12;
        tiles[4500] = 8;
        tiles[1800] = 15;
        tiles[2500] = 5;
        // You can continue your 2000 lines here
        // ========================================
    end

endmodule
