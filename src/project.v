`default_nettype none

module tt_um_bulls_and_cows_vga (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire rst = ~rst_n;

    assign uio_oe  = 8'b11111111;
    assign uio_out = 8'b00000000;

    reg [15:0] user_in_reg;
    wire submit_guess = ui_in[4];
    wire load_nibble  = ui_in[5];
    wire [1:0] nibble_sel = ui_in[7:6];
    
    always @(posedge clk) begin
        if (rst) begin
            user_in_reg <= 16'h0000;
        end else if (load_nibble) begin
            case (nibble_sel)
                2'b00: user_in_reg[3:0]   <= ui_in[3:0];
                2'b01: user_in_reg[7:4]   <= ui_in[3:0];
                2'b10: user_in_reg[11:8]  <= ui_in[3:0];
                2'b11: user_in_reg[15:12] <= ui_in[3:0];
            endcase
        end
    end

    reg vga_clk = 0;
    always @(posedge clk) vga_clk <= ~vga_clk;

    reg [3:0] secret [3:0];
    reg [15:0] lfsr = 16'hACE1;
    
    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 16'hACE1;
        end else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            secret[0] <= (lfsr[3:0]   >= 10) ? lfsr[3:0]   - 10 : lfsr[3:0];
            secret[1] <= (lfsr[7:4]   >= 10) ? lfsr[7:4]   - 10 : lfsr[7:4];
            secret[2] <= (lfsr[11:8]  >= 10) ? lfsr[11:8]  - 10 : lfsr[11:8];
            secret[3] <= (lfsr[15:12] >= 10) ? lfsr[15:12] - 10 : lfsr[15:12];
        end
    end

    wire [3:0] guess [3:0];
    assign guess[0] = user_in_reg[3:0];
    assign guess[1] = user_in_reg[7:4];
    assign guess[2] = user_in_reg[11:8];
    assign guess[3] = user_in_reg[15:12];

    reg [1:0] box_status [3:0]; 
    reg game_over;
    
    integer i, j;
    reg found_elsewhere;

    always @(posedge clk) begin
        if (rst) begin
            game_over <= 0;
            box_status[0] <= 2'b00;
            box_status[1] <= 2'b00;
            box_status[2] <= 2'b00;
            box_status[3] <= 2'b00;
        end else if (submit_guess && !game_over) begin
            /* verilator lint_off BLKSEQ */
            for (i = 0; i < 4; i = i + 1) begin
                if (guess[i] == secret[i]) begin
                    box_status[i] <= 2'b01;
                end else begin
                    found_elsewhere = 0;
                    for (j = 0; j < 4; j = j + 1) begin
                        if (guess[i] == secret[j]) found_elsewhere = 1;
                    end
                    
                    if (found_elsewhere)
                        box_status[i] <= 2'b11;
                    else
                        box_status[i] <= 2'b10;
                end
            end
            /* verilator lint_on BLKSEQ */
            
            if ((guess[0] == secret[0]) && (guess[1] == secret[1]) && 
                (guess[2] == secret[2]) && (guess[3] == secret[3])) begin
                game_over <= 1;
            end
        end
    end

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_on;
    wire hsync;
    wire vsync;
    reg [2:0] rgb;

    vga_sync sync_unit (
        .clk(vga_clk),
        .rst(rst),
        .hsync(hsync),
        .vsync(vsync),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on)
    );

    wire in_box0 = (pixel_x >= 160 && pixel_x < 240) && (pixel_y >= 200 && pixel_y < 280);
    wire in_box1 = (pixel_x >= 260 && pixel_x < 340) && (pixel_y >= 200 && pixel_y < 280);
    wire in_box2 = (pixel_x >= 360 && pixel_x < 440) && (pixel_y >= 200 && pixel_y < 280);
    wire in_box3 = (pixel_x >= 460 && pixel_x < 540) && (pixel_y >= 200 && pixel_y < 280);

    localparam COLOR_GRAY   = 3'b101;
    localparam COLOR_GREEN  = 3'b010;
    localparam COLOR_RED    = 3'b100;
    localparam COLOR_YELLOW = 3'b110;
    localparam COLOR_BLACK  = 3'b000;

    always @(*) begin
        if (!video_on) begin
            rgb = COLOR_BLACK;
        end else begin
            rgb = COLOR_BLACK;
            
            if (in_box0) begin
                case(box_status[0])
                    2'b00: rgb = 3'b111;
                    2'b01: rgb = COLOR_GREEN;
                    2'b10: rgb = COLOR_RED;
                    2'b11: rgb = COLOR_YELLOW;
                endcase
            end else if (in_box1) begin
                case(box_status[1])
                    2'b00: rgb = 3'b111;
                    2'b01: rgb = COLOR_GREEN;
                    2'b10: rgb = COLOR_RED;
                    2'b11: rgb = COLOR_YELLOW;
                endcase
            end else if (in_box2) begin
                case(box_status[2])
                    2'b00: rgb = 3'b111;
                    2'b01: rgb = COLOR_GREEN;
                    2'b10: rgb = COLOR_RED;
                    2'b11: rgb = COLOR_YELLOW;
                endcase
            end else if (in_box3) begin
                case(box_status[3])
                    2'b00: rgb = 3'b111;
                    2'b01: rgb = COLOR_GREEN;
                    2'b10: rgb = COLOR_RED;
                    2'b11: rgb = COLOR_YELLOW;
                endcase
            end
        end
    end

    assign uo_out[0] = rgb[2];
    assign uo_out[1] = rgb[1];
    assign uo_out[2] = rgb[0];
    assign uo_out[3] = hsync;
    assign uo_out[4] = vsync;
    assign uo_out[5] = game_over;
    assign uo_out[7:6] = 2'b00;

endmodule

module vga_sync (
    input wire clk,
    input wire rst,
    output wire hsync,
    output wire vsync,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y,
    output wire video_on
);

    localparam HD = 640;
    localparam HF = 16;
    localparam HB = 48;
    localparam HR = 96;
    
    localparam VD = 480;
    localparam VF = 10;
    localparam VB = 33;
    localparam VR = 2;

    reg [9:0] h_count_reg, v_count_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            h_count_reg <= 0;
            v_count_reg <= 0;
        end else begin
            if (h_count_reg == (HD+HF+HB+HR-1)) begin
                h_count_reg <= 0;
                if (v_count_reg == (VD+VF+VB+VR-1))
                    v_count_reg <= 0;
                else
                    v_count_reg <= v_count_reg + 1;
            end else begin
                h_count_reg <= h_count_reg + 1;
            end
        end
    end

    assign hsync = (h_count_reg >= (HD+HF) && h_count_reg < (HD+HF+HR)) ? 0 : 1;
    assign vsync = (v_count_reg >= (VD+VF) && v_count_reg < (VD+VF+VR)) ? 0 : 1;
    
    assign video_on = (h_count_reg < HD) && (v_count_reg < VD);
    
    assign pixel_x = h_count_reg;
    assign pixel_y = v_count_reg;

endmodule
