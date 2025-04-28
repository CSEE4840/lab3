module vga_ball (
    input logic clk,
    input logic reset,
    input logic [15:0] writedata,
    input logic write,
    input logic chipselect,
    input logic [2:0] address,

    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_CLK, VGA_HS, VGA_VS,
    output logic VGA_BLANK_n, VGA_SYNC_n
);

    // VGA counters
    logic [10:0] hcount;
    logic [9:0]  vcount;

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

    // ================================================
    // 1. Tile map (layout from MIF)
    // ================================================
    logic [5:0] tile_map [0:4799]; // 0-40, needs 6 bits now

    initial begin
        $readmemb("map.mif", tile_map);
    end

    // ================================================
    // 2. 41 Tile bitmaps
    // ================================================
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

    // ================================================
    // 3. VGA Pixel Output Logic
    // ================================================

    always_ff @(posedge clk) begin
        if (VGA_BLANK_n) begin
            logic [6:0] tile_x = hcount[10:3];
            logic [5:0] tile_y = vcount[9:3];
            logic [2:0] pixel_x = hcount[2:0];
            logic [2:0] pixel_y = vcount[2:0];

            logic [5:0] tile_type;
            if (tile_x < 80 && tile_y < 60)
                tile_type = tile_map[tile_y * 80 + tile_x];
            else
                tile_type = 0;

            logic pixel_bit;
            pixel_bit = tile_bitmaps[tile_type][pixel_y][7 - pixel_x];

            if (pixel_bit) begin
                VGA_R <= 8'hFF;
                VGA_G <= 8'hFF;
                VGA_B <= 8'h00;
            end else begin
                VGA_R <= 8'h00;
                VGA_G <= 8'h00;
                VGA_B <= 8'h00;
            end
        end else begin
            VGA_R <= 8'h00;
            VGA_G <= 8'h00;
            VGA_B <= 8'h00;
        end
    end

endmodule



/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * Register map:
 * 
 * Byte Offset  7 ... 0   Meaning
 *        0    |  Red  |  Red component of background color (0-255)
 *        1    | Green |  Green component of background color (0-255)
 *        2    | Blue  |  Blue component of background color (0-255)
 *        3    | x 15..0 |      center x
 *        4    | y  15 ...0| center y
 */

module vga_ball(
    input logic        clk,
    input logic        reset,
    input logic [15:0]  writedata,
    input logic        write,
    input             chipselect,
    input logic [2:0]  address,

    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic       VGA_CLK, VGA_HS, VGA_VS,
                       VGA_BLANK_n,
    output logic       VGA_SYNC_n
);

    logic [10:0]       hcount;
    logic [9:0]        vcount;
    logic [7:0]        bg_r,bg_g,bg_b;
    logic [15:0]       center_x, center_y, radius;

    vga_counters counters(.clk50(clk), .*);

    always_ff @(posedge clk)
        if (reset) begin
            bg_r <= 8'h0;
	    bg_g <= 8'h0;
	    bg_b <= 8'h80;
            center_x <= 11'd320; 
            center_y <= 10'd240; 
            radius <= 25'd15; 
        end else if (chipselect && write) 
            case (address)
		3'h0 : bg_r <= writedata[7:0];
		3'h1 : bg_r <= writedata[7:0];
		3'h2 : bg_r <= writedata[7:0];
                3'h3 : center_x <= writedata; 
                3'h4 : center_y <= writedata; 
            endcase

    always_comb begin
        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'hff};
        if (VGA_BLANK_n) begin
            if (((hcount[10:1] - center_x) * (hcount[10:1] - center_x) + (vcount - center_y) * (vcount - center_y)) <= (25'd255))
                {VGA_R, VGA_G, VGA_B} = {8'hff, 8'h0, 8'hff}; 
        end
    end

endmodule

module vga_counters(
 input logic 	     clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic 	     VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600
   
   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

   logic endOfLine;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else  	         hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;
       
   logic endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) &
		      !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   // 101 0000 0000  1280	       01 1110 0000  480
   // 110 0011 1111  1599	       10 0000 1100  524
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
			!( vcount[9] | (vcount[8:5] == 4'b1111) );

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
   assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
endmodule
