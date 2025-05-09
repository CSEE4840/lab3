module vga_ball (
    input clk,
    input reset,
    input [15:0] writedata,
    input write,
    input chipselect,
    input [4:0] address,

    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_CLK, VGA_HS, VGA_VS,
    output VGA_BLANK_n, VGA_SYNC_n,
    output pwm_out
);

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
    audio_player background_music (
	.clk(clk),
	.reset(reset),
	.play(1'b1),
	.pwm_out(pwm_out)
    );

    localparam DIR_UP = 3'd0, DIR_RIGHT = 3'd1, DIR_DOWN = 3'd2, DIR_LEFT = 3'd3, DIR_EAT = 3'd4;

    reg [9:0] pacman_x;
    reg [9:0] pacman_y;
    reg [2:0] pacman_dir;
    reg [12:0] trigger_tile_index;

    reg [9:0] ghost_x[0:3];
    reg [9:0] ghost_y[0:3];
    reg [1:0] ghost_dir[0:3];

    reg [25:0] second_counter;
    reg [6:0] game_timer;
    reg gameover_latched;
    reg [25:0] gameover_wait;

    wire [6:0] pac_tile_x = pacman_x[9:3];
    wire [6:0] pac_tile_y = pacman_y[9:3];
    wire [12:0] pacman_tile_index = pac_tile_y * 80 + pac_tile_x;

    reg [11:0] tile[0:4799];
    reg [7:0] tile_bitmaps[0:879];

    reg [7:0] score;
    reg [31:0] pacman_up[0:15], pacman_right[0:15], pacman_down[0:15], pacman_left[0:15], pacman_eat[0:15];

    wire [6:0] tile_x = hcount[10:4];
    wire [6:0] tile_y = vcount[9:3];
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [11:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id * 8 + ty];
    wire pixel_on = bitmap_row[7 - tx];

    wire [3:0] pacman_x16 = hcount[10:1] - pacman_x;
    wire [3:0] pacman_y16 = vcount - pacman_y;
    wire on_pacman = (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
                      vcount >= pacman_y && vcount < pacman_y + 16);

    reg [31:0] pacman_row;
    integer i, gi, gx, gy;
    integer d0, d1, d2, d3;
    integer base_tile;
    integer base_score_tile;
    reg [1:0] ghost_pixel;

    initial begin
        $readmemh("map.vh", tile);
        $readmemh("tiles.vh", tile_bitmaps);

        base_tile = 800;

        tile[base_tile + 0]  = 38 + (18 * 2);
        tile[base_tile + 1]  = 38 + (2 * 2);
        tile[base_tile + 2]  = 38 + (14 * 2);
        tile[base_tile + 3]  = 38 + (17 * 2);
        tile[base_tile + 4]  = 38 + (4 * 2);
        tile[base_tile + 80] = 38 + (18 * 2) + 1;
        tile[base_tile + 81] = 38 + (2 * 2) + 1;
        tile[base_tile + 82] = 38 + (14 * 2) + 1;
        tile[base_tile + 83] = 38 + (17 * 2) + 1;
        tile[base_tile + 84] = 38 + (4 * 2) + 1;
    end

    reg [12:0] demo_index;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            second_counter <= 0;
            game_timer <= 0;
            gameover_latched <= 0;
            gameover_wait <= 0;
            pacman_x <= 340;
            pacman_y <= 240;
            pacman_dir <= DIR_RIGHT;
            score <= 0;
            demo_index <= 13'd4088;

            ghost_x[0] <= 100; ghost_y[0] <= 100; ghost_dir[0] <= DIR_LEFT;
            ghost_x[1] <= 200; ghost_y[1] <= 100; ghost_dir[1] <= DIR_RIGHT;
            ghost_x[2] <= 300; ghost_y[2] <= 100; ghost_dir[2] <= DIR_UP;
            ghost_x[3] <= 400; ghost_y[3] <= 100; ghost_dir[3] <= DIR_DOWN;
        end else begin
            if (!gameover_latched)
                second_counter <= second_counter + 1;

            if (chipselect && write) begin
                case (address)
                    5'd0: begin
                        pacman_x <= writedata[7:0];
                        pacman_y <= writedata[15:8];
                    end
                    5'd3: pacman_dir <= writedata[2:0];
                    5'd4: trigger_tile_index <= writedata[12:0];
                endcase
            end

            if (!gameover_latched && second_counter == 50_000_000) begin
                second_counter <= 0;
                game_timer <= game_timer + 1;

                if (game_timer == 50) begin
                    gameover_latched <= 1;
                    tile[3800 + 0]  <= 38 + (6 * 2);  // G
                    tile[3800 + 1]  <= 38 + (0 * 2);  // A
                    tile[3800 + 2]  <= 38 + (12 * 2); // M
                    tile[3800 + 3]  <= 38 + (4 * 2);  // E
                    tile[3800 + 4]  <= 12'h25;        // space or blank tile
                    tile[3800 + 5]  <= 38 + (14 * 2); // O
                    tile[3800 + 6]  <= 38 + (21 * 2); // V
                    tile[3800 + 7]  <= 38 + (4 * 2);  // E
                    tile[3800 + 8]  <= 38 + (17 * 2); // R

                    tile[3880 + 0]  <= 38 + (6 * 2) + 1;
                    tile[3880 + 1]  <= 38 + (0 * 2) + 1;
                    tile[3880 + 2]  <= 38 + (12 * 2) + 1;
                    tile[3880 + 3]  <= 38 + (4 * 2) + 1;
                    tile[3880 + 4]  <= 12'h25;
                    tile[3880 + 5]  <= 38 + (14 * 2) + 1;
                    tile[3880 + 6]  <= 38 + (21 * 2) + 1;
                    tile[3880 + 7]  <= 38 + (4 * 2) + 1;
                    tile[3880 + 8]  <= 38 + (17 * 2) + 1;
                end else begin
                    if (demo_index <= 13'd4130) begin
                        tile[demo_index] <= 12'd37;
                        demo_index <= demo_index + 1;
                    end

                    if (score < 9999)
                        score <= score + 1;

                    pacman_dir <= (pacman_dir == DIR_EAT) ? DIR_UP : pacman_dir + 1;
                    ghost_dir[0] <= ghost_dir[0] + 1;
                    ghost_dir[1] <= ghost_dir[1] + 1;
                    ghost_dir[2] <= ghost_dir[2] + 1;
                    ghost_dir[3] <= ghost_dir[3] + 1;

                    d3 = score / 1000;
                    d2 = (score % 1000) / 100;
                    d1 = (score % 100) / 10;
                    d0 = score % 10;

                    base_score_tile = 1078;
                    tile[base_score_tile + 0]  = 38 + (26 * 2) + d3 * 2;
                    tile[base_score_tile + 1]  = 38 + (26 * 2) + d2 * 2;
                    tile[base_score_tile + 2]  = 38 + (26 * 2) + d1 * 2;
                    tile[base_score_tile + 3]  = 38 + (26 * 2) + d0 * 2;
                    tile[base_score_tile + 80] = 38 + (26 * 2) + d3 * 2 + 1;
                    tile[base_score_tile + 81] = 38 + (26 * 2) + d2 * 2 + 1;
                    tile[base_score_tile + 82] = 38 + (26 * 2) + d1 * 2 + 1;
                    tile[base_score_tile + 83] = 38 + (26 * 2) + d0 * 2 + 1;
                end
            end else if (gameover_latched) begin
                gameover_wait <= gameover_wait + 1;
                if (gameover_wait == 50_000_000) begin
                    $readmemh("map.vh", tile);
                    score <= 0;
                    game_timer <= 0;
                    demo_index <= 13'd4088;
                    pacman_x <= 340;
                    pacman_y <= 240;
                    pacman_dir <= DIR_RIGHT;
                    ghost_dir[0] <= DIR_LEFT;
                    ghost_dir[1] <= DIR_RIGHT;
                    ghost_dir[2] <= DIR_UP;
                    ghost_dir[3] <= DIR_DOWN;
                    ghost_x[0] <= 100; ghost_y[0] <= 100;
                    ghost_x[1] <= 200; ghost_y[1] <= 100;
                    ghost_x[2] <= 300; ghost_y[2] <= 100;
                    ghost_x[3] <= 400; ghost_y[3] <= 100;
                    gameover_latched <= 0;
                    gameover_wait <= 0;
                end
            end

            pac_tile_x = pacman_x[9:3];
            pac_tile_y = pacman_y[9:3];
            pacman_tile_index = pac_tile_y * 80 + pac_tile_x;

            if (pacman_tile_index == trigger_tile_index) begin
                tile[trigger_tile_index] <= 12'h03;
            end
        end
    end
    initial begin
        $readmemh("pacman_up.vh",    pacman_up);
        $readmemh("pacman_right.vh", pacman_right);
        $readmemh("pacman_down.vh",  pacman_down);
        $readmemh("pacman_left.vh",  pacman_left);
	$readmemh("pacman_eat.vh",  pacman_eat);
    end

    // Ghost shared sprite
	localparam logic [1:0] GHOST_LEFT [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};

	localparam logic [1:0] GHOST_RIGHT [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};
	localparam logic [1:0] GHOST_UP [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};

	localparam logic [1:0] GHOST_DOWN [0:15][0:15] = '{
     '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};


    always @(*) begin
        VGA_R = 0; VGA_G = 0; VGA_B = 0;

        if (pixel_on) begin
            if (tile_id == 12'h0A || tile_id >= 12'h26)
                {VGA_R, VGA_G, VGA_B} = 24'hFFFFFF;
            else
                VGA_B = 8'hFF;
        end

        pacman_row = 32'b0;
        if (vcount >= pacman_y && vcount < pacman_y + 16) begin
            case (pacman_dir)
                DIR_UP:    pacman_row = pacman_up[vcount - pacman_y];
                DIR_RIGHT: pacman_row = pacman_right[vcount - pacman_y];
                DIR_DOWN:  pacman_row = pacman_down[vcount - pacman_y];
                DIR_LEFT:  pacman_row = pacman_left[vcount - pacman_y];
                DIR_EAT:   pacman_row = pacman_eat[vcount - pacman_y];
            endcase
        end

        if (on_pacman && pacman_row[15 - (hcount[10:1] - pacman_x)]) begin
            VGA_R = 8'hFF;
            VGA_G = 8'hFF;
            VGA_B = 8'h00;
        end

        for (gi = 0; gi < 4; gi = gi + 1) begin
            if (hcount[10:1] >= ghost_x[gi] && hcount[10:1] < ghost_x[gi] + 16 &&
                vcount >= ghost_y[gi] && vcount < ghost_y[gi] + 16) begin

                gx = hcount[10:1] - ghost_x[gi];
                gy = vcount - ghost_y[gi];

                case (ghost_dir[gi])
                    DIR_UP:    ghost_pixel = GHOST_UP[gy][gx];
                    DIR_DOWN:  ghost_pixel = GHOST_DOWN[gy][gx];
                    DIR_LEFT:  ghost_pixel = GHOST_LEFT[gy][gx];
                    DIR_RIGHT: ghost_pixel = GHOST_RIGHT[gy][gx];
                    default:   ghost_pixel = 2'b00;
                endcase

                case (ghost_pixel)
                    2'b01: case (gi)
                        0: begin VGA_R = 8'hFF; VGA_G = 0;     VGA_B = 0;     end
                        1: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 8'hFF; end
                        2: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 0;     end
                        3: begin VGA_R = 0;     VGA_G = 8'hFF; VGA_B = 8'hFF; end
                    endcase
                    2'b10: begin VGA_R = 8'hFF; VGA_G = 8'hFF; VGA_B = 8'hFF; end
                    2'b11: begin VGA_R = 0;     VGA_G = 0;     VGA_B = 8'h88; end
                endcase
            end
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
   // 101 0010 0000 to 101 1101 1111 (active LOW during 1312-1503) (192 cycles)
   assign VGA_HS = !( (hcount[10:8] == 3'b101) & !(hcount[7:5] == 3'b111));
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
