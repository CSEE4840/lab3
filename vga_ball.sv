module vga_ball (
    input logic clk,
    input logic reset,
    input logic [15:0] writedata,
    input logic write,
    input logic chipselect,
    input logic [2:0] address,

    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_CLK, VGA_HS, VGA_VS,
                  VGA_BLANK_n, VGA_SYNC_n
);

    // VGA timing counters
    logic [10:0] hcount;
    logic [9:0] vcount;
    logic video_on;

    // Fixed positions for now
    logic [9:0] ghost_x = 100;
    logic [9:0] ghost_y = 100;
    logic [9:0] pacman_x = 200;
    logic [9:0] pacman_y = 100;

    // Bitmap for 16x16 ghost
    logic [15:0] ghost_bitmap[0:15] = '{
        16'b0000011111100000,
        16'b0001111111111000,
        16'b0011111111111100,
        16'b0111111111111110,
        16'b0111111111111110,
        16'b1111111111111111,
        16'b1111111111111111,
        16'b1111011111101111,
        16'b1111011111101111,
        16'b1111111111111111,
        16'b1111111111111111,
        16'b1110011001100111,
        16'b0000000000000000,
        16'b0011000000110000,
        16'b0011000000110000,
        16'b0000000000000000
    };

    // Bitmap for 16x16 Pac-Man (open mouth)
    logic [15:0] pacman_bitmap[0:15] = '{
        16'b0000011111100000,
        16'b0001111111110000,
        16'b0011111111111000,
        16'b0111111111100000,
        16'b0111111111000000,
        16'b1111111110000000,
        16'b1111111110000000,
        16'b1111111111000000,
        16'b1111111111100000,
        16'b1111111111110000,
        16'b0111111111111000,
        16'b0011111111110000,
        16'b0001111111100000,
        16'b0000111111000000,
        16'b0000011110000000,
        16'b0000000000000000
    };

    // Include VGA sync generator (from lab or IP)
    vga_counters counters(
        .clk50(clk),
        .hcount(hcount),
        .vcount(vcount),
        .video_on(video_on),
        .VGA_CLK(VGA_CLK),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_n(VGA_BLANK_n),
        .VGA_SYNC_n(VGA_SYNC_n)
    );

    // Output color logic
    always_comb begin
        VGA_R = 0;
        VGA_G = 0;
        VGA_B = 0;

        if (video_on) begin
            // Ghost drawing
            if ((hcount >= ghost_x) && (hcount < ghost_x + 16) &&
                (vcount >= ghost_y) && (vcount < ghost_y + 16)) begin
                int gx = hcount - ghost_x;
                int gy = vcount - ghost_y;
                if (ghost_bitmap[gy][15 - gx])
                    {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'hFF};  // Purple
            end
            // Pac-Man drawing
            else if ((hcount >= pacman_x) && (hcount < pacman_x + 16) &&
                     (vcount >= pacman_y) && (vcount < pacman_y + 16)) begin
                int px = hcount - pacman_x;
                int py = vcount - pacman_y;
                if (pacman_bitmap[py][15 - px])
                    {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'h00};  // Yellow
            end
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
