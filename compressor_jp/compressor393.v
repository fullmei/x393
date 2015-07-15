/*******************************************************************************
 * Module: compressor393
 * Date:2015-07-14  
 * Author: Andrey Filippov     
 * Description: Top module containg all compressor channels
 *
 * Copyright (c) 2015 Elphel, Inc .
 * compressor393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  compressor393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  compressor393 # (
        parameter CMPRS_NUM_AFI_CHN =         2, // 1 - multiplex all 4 compressors to a single AXI_HP, 2 - split between to AXI_HP
        parameter CMPRS_GROUP_ADDR =          'h600, // total of 'h60
        parameter CMPRS_BASE_INC =            'h10,
        parameter CMPRS_AFIMUX_RADDR0=        'h40,  // relative to CMPRS_NUM_AFI_CHN ( 16 addr)
        parameter CMPRS_AFIMUX_RADDR1=        'h50,  // relative to CMPRS_NUM_AFI_CHN ( 16 addr)
        parameter CMPRS_AFIMUX_MASK=          'h7f0,
        
        parameter CMPRS_STATUS_REG_BASE=      'h10,
        parameter CMPRS_HIFREQ_REG_BASE=      'h14, 
        parameter CMPRS_AFIMUX_REG_ADDR0=     'h18,  // Uses 4 locations
        parameter CMPRS_AFIMUX_REG_ADDR1=     'h1c,  // Uses 4 locations
        
        parameter CMPRS_STATUS_REG_INC=        1,
        parameter CMPRS_HIFREQ_REG_INC=        1,
//        parameter CMPRS_ADDR=                'h120, //TODO: assign valid address
        parameter CMPRS_MASK=                 'h7f8,
        parameter CMPRS_CONTROL_REG=           0,
        parameter CMPRS_STATUS_CNTRL=          1,
        parameter CMPRS_FORMAT=                2,
        parameter CMPRS_COLOR_SATURATION=      3,
        parameter CMPRS_CORING_MODE=           4,
        parameter CMPRS_TABLES=                6, // 6..7

        parameter FRAME_HEIGHT_BITS=          16, // Maximal frame height 
        parameter LAST_FRAME_BITS=            16, // number of bits in frame counter (before rolls over)
        // Bit-fields in compressor control word
        parameter CMPRS_CBIT_RUN =             2, // bit # to control compressor run modes
        parameter CMPRS_CBIT_RUN_BITS =        2, // number of bits to control compressor run modes
        parameter CMPRS_CBIT_QBANK =           6, // bit # to control quantization table page
        parameter CMPRS_CBIT_QBANK_BITS =      3, // number of bits to control quantization table page
        parameter CMPRS_CBIT_DCSUB =           8, // bit # to control extracting DC components bypassing DCT
        parameter CMPRS_CBIT_DCSUB_BITS =      1, // bit # to control extracting DC components bypassing DCT
        parameter CMPRS_CBIT_CMODE =          13, // bit # to control compressor color modes
        parameter CMPRS_CBIT_CMODE_BITS =      4, // number of bits to control compressor color modes
        parameter CMPRS_CBIT_FRAMES =         15, // bit # to control compressor multi/single frame buffer modes
        parameter CMPRS_CBIT_FRAMES_BITS =     1, // number of bits to control compressor multi/single frame buffer modes
        parameter CMPRS_CBIT_BAYER =          20, // bit # to control compressor Bayer shift mode
        parameter CMPRS_CBIT_BAYER_BITS =      2, // number of bits to control compressor Bayer shift mode
        parameter CMPRS_CBIT_FOCUS =          23, // bit # to control compressor focus display mode
        parameter CMPRS_CBIT_FOCUS_BITS =      2, // number of bits to control compressor focus display mode
        // compressor bit-fields decode
        parameter CMPRS_CBIT_RUN_RST =         2'h0, // reset compressor, stop immediately
//      parameter CMPRS_CBIT_RUN_DISABLE =     2'h1, // disable compression of the new frames, finish any already started
        parameter CMPRS_CBIT_RUN_STANDALONE =  2'h2, // enable compressor, compress single frame from memory (async)
        parameter CMPRS_CBIT_RUN_ENABLE =      2'h3, // enable compressor, enable synchronous compression mode
        parameter CMPRS_CBIT_CMODE_JPEG18 =    4'h0, // color 4:2:0
        parameter CMPRS_CBIT_CMODE_MONO6 =     4'h1, // mono 4:2:0 (6 blocks)
        parameter CMPRS_CBIT_CMODE_JP46 =      4'h2, // jp4, 6 blocks, original
        parameter CMPRS_CBIT_CMODE_JP46DC =    4'h3, // jp4, 6 blocks, dc -improved
        parameter CMPRS_CBIT_CMODE_JPEG20 =    4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
        parameter CMPRS_CBIT_CMODE_JP4 =       4'h5, // jp4,  4 blocks, dc-improved
        parameter CMPRS_CBIT_CMODE_JP4DC =     4'h6, // jp4,  4 blocks, dc-improved
        parameter CMPRS_CBIT_CMODE_JP4DIFF =   4'h7, // jp4,  4 blocks, differential
        parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
        parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
        parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
        parameter CMPRS_CBIT_CMODE_MONO1 =     4'hb, // mono JPEG (not yet implemented)
        parameter CMPRS_CBIT_CMODE_MONO4 =     4'he, // mono 4 blocks
        parameter CMPRS_CBIT_FRAMES_SINGLE =   0, //1, // use a single-frame buffer for images

        parameter CMPRS_COLOR18 =              0, // JPEG 4:2:0 with 18x18 overlapping tiles for de-bayer
        parameter CMPRS_COLOR20 =              1, // JPEG 4:2:0 with 18x18 overlapping tiles for de-bayer (not implemented)
        parameter CMPRS_MONO16 =               2, // JPEG 4:2:0 with 16x16 non-overlapping tiles, color components zeroed
        parameter CMPRS_JP4 =                  3, // JP4 mode with 16x16 macroblocks
        parameter CMPRS_JP4DIFF =              4, // JP4DIFF mode TODO: see if correct
        parameter CMPRS_MONO8 =                7,  // Regular JPEG monochrome with 8x8 macroblocks (not yet implemented)
        
        parameter CMPRS_FRMT_MBCM1 =           0, // bit # of number of macroblock columns minus 1 field in format word
        parameter CMPRS_FRMT_MBCM1_BITS =     13, // number of bits in number of macroblock columns minus 1 field in format word
        parameter CMPRS_FRMT_MBRM1 =          13, // bit # of number of macroblock rows minus 1 field in format word
        parameter CMPRS_FRMT_MBRM1_BITS =     13, // number of bits in number of macroblock rows minus 1 field in format word
        parameter CMPRS_FRMT_LMARG =          26, // bit # of left margin field in format word
        parameter CMPRS_FRMT_LMARG_BITS =      5, // number of bits in left margin field in format word
        parameter CMPRS_CSAT_CB =              0, // bit # of number of blue scale field in color saturation word
        parameter CMPRS_CSAT_CB_BITS =        10, // number of bits in blue scale field in color saturation word
        parameter CMPRS_CSAT_CR =             12, // bit # of number of red scale field in color saturation word
        parameter CMPRS_CSAT_CR_BITS =        10, // number of bits in red scale field in color saturation word
        parameter CMPRS_CORING_BITS =          3,  // number of bits in coring mode
        
        parameter CMPRS_TIMEOUT_BITS=         12,
        parameter CMPRS_TIMEOUT=            1000,   // mclk cycles
        
        parameter CMPRS_AFIMUX_EN=            'h0, // enables (gl;obal and per-channel)
        parameter CMPRS_AFIMUX_RST=           'h1, // per-channel resets
        parameter CMPRS_AFIMUX_MODE=          'h2, // per-channel select - which register to return as status
        parameter CMPRS_AFIMUX_STATUS_CNTRL=  'h4, // .. 'h7
        parameter CMPRS_AFIMUX_SA_LEN=        'h8, // .. 'hf
    
        parameter CMPRS_AFIMUX_WIDTH =         26, // maximal for status: currently only works with 26)
        parameter CMPRS_AFIMUX_CYCBITS =        3,
        parameter AFI_MUX_BUF_LATENCY =         2  // buffers read latency from fifo_ren* to fifo_rdata* valid : 2 if no register layers are used

)(
    input                         rst,    // global reset
    input                         xclk,   // global clock input, compressor single clock rate
    input                         xclk2x, // global clock input, compressor double clock rate, nominally rising edge aligned
    // programming interface
    input                         mclk,     // global system/memory clock
    input                   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                         cmd_stb,     // strobe (with first byte) for the command a/d
    output                  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                        status_rq,   // input request to send status downstream
    input                         status_start, // Acknowledge of the first status packet byte (address)
    
    // Buffer interfaces 
    input                         xfer_reset_page_rd_chn0,  // from mcntrl_tiled_rw (
    input                         buf_wpage_nxt_chn0,       // advance to next page memory interface writes to
    input                         buf_we_chn0,              // @!mclk write buffer from memory, increment write
    input                  [63:0] buf_din_chn0,             // data out 
    input                         page_ready_chn0,          // single mclk (posedge)
    output                        next_page_chn0,           // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 

    input                         xfer_reset_page_rd_chn1,  // from mcntrl_tiled_rw (
    input                         buf_wpage_nxt_chn1,       // advance to next page memory interface writes to
    input                         buf_we_chn1,              // @!mclk write buffer from memory, increment write
    input                  [63:0] buf_din_chn1,             // data out 
    input                         page_ready_chn1,          // single mclk (posedge)
    output                        next_page_chn1,           // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 

    input                         xfer_reset_page_rd_chn2,  // from mcntrl_tiled_rw (
    input                         buf_wpage_nxt_chn2,       // advance to next page memory interface writes to
    input                         buf_we_chn2,              // @!mclk write buffer from memory, increment write
    input                  [63:0] buf_din_chn2,             // data out 
    input                         page_ready_chn2,          // single mclk (posedge)
    output                        next_page_chn2,           // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 

    input                         xfer_reset_page_rd_chn3,  // from mcntrl_tiled_rw (
    input                         buf_wpage_nxt_chn3,       // advance to next page memory interface writes to
    input                         buf_we_chn3,              // @!mclk write buffer from memory, increment write
    input                  [63:0] buf_din_chn3,             // data out 
    input                         page_ready_chn3,          // single mclk (posedge)
    output                        next_page_chn3,           // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 

// statistics data was not used in late nc353    
//    input                         dccout,         //enable output of DC and HF components for brightness/color/focus adjustments
//    input                   [2:0] hfc_sel,        // [2:0] (for autofocus) only components with both spacial frequencies higher than specified will be added
//    output                        statistics_dv,
//    output                 [15:0] statistics_do,

// Timestamp messages (@mclk) - combine to a single ts_data?    
    input                         ts_pre_stb_chn0,  // @mclk - 1 cycle before receiving 8 bytes of timestamp data
    input                   [7:0] ts_data_chn0,     // timestamp data (s0,s1,s2,s3,us0,us1,us2,us3==0)
    
    input                         ts_pre_stb_chn1,  // @mclk - 1 cycle before receiving 8 bytes of timestamp data
    input                   [7:0] ts_data_chn1,     // timestamp data (s0,s1,s2,s3,us0,us1,us2,us3==0)
    
    input                         ts_pre_stb_chn2,  // @mclk - 1 cycle before receiving 8 bytes of timestamp data
    input                   [7:0] ts_data_chn2,     // timestamp data (s0,s1,s2,s3,us0,us1,us2,us3==0)
    
    input                         ts_pre_stb_chn3,  // @mclk - 1 cycle before receiving 8 bytes of timestamp data
    input                   [7:0] ts_data_chn3,     // timestamp data (s0,s1,s2,s3,us0,us1,us2,us3==0)

// Outputs for interrupts generation    
    output                        eof_written_mclk_chn0,
    output                        stuffer_done_mclk_chn0,
    
    output                        eof_written_mclk_chn1,
    output                        stuffer_done_mclk_chn1,
    
    output                        eof_written_mclk_chn2,
    output                        stuffer_done_mclk_chn2,
    
    output                        eof_written_mclk_chn3,
    output                        stuffer_done_mclk_chn3,
    
    // frame input synchronization
    input                         vsync_late_chn0,         // delayed start of frame, @xclk. In 353 it was 16 lines after VACT active
                                                      // source channel should already start, some delay give time for sequencer commands
                                                      // that should arrive before it
    input                         vsync_late_chn1,                                                  
    input                         vsync_late_chn2,                                                  
    input                         vsync_late_chn3,                                                  
    
    // master (sensor) with slave (compressor) synchronization I/Os
    output                        frame_start_dst_chn0,    // @mclk - trigger receive (tiledc) memory channel (it will take care of single/repetitive
                                                           // these output either follows vsync_late (reclocks it) or generated in non-bonded mode
                                                           // (compress from memory)
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_src_chn0,// number of the current (unfinished ) line, in the source (sensor) channel (RELATIVE TO FRAME, NOT WINDOW?)
    input   [LAST_FRAME_BITS-1:0] frame_number_src_chn0,   // current frame number (for multi-frame ranges) in the source (sensor) channel
    input                         frame_done_src_chn0,     // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory 
                                                            // frame_done_src is later than line_unfinished_src/ frame_number_src changes
                                                           // Used withe a single-frame buffers
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_dst_chn0,// number of the current (unfinished ) line in this (compressor) channel
    input   [LAST_FRAME_BITS-1:0] frame_number_dst_chn0,   // current frame number (for multi-frame ranges) in this (compressor channel
    input                         frame_done_dst_chn0,     // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory
                                                           // use as 'eot_real' in 353 
    output                        suspend_chn0,            // suspend reading data for this channel - waiting for the source data

    output                        frame_start_dst_chn1,
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_src_chn1,
    input   [LAST_FRAME_BITS-1:0] frame_number_src_chn1,
    input                         frame_done_src_chn1, 
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_dst_chn1,
    input   [LAST_FRAME_BITS-1:0] frame_number_dst_chn1,
    input                         frame_done_dst_chn1,
    output                        suspend_chn1,

    output                        frame_start_dst_chn2,
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_src_chn2,
    input   [LAST_FRAME_BITS-1:0] frame_number_src_chn2,
    input                         frame_done_src_chn2, 
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_dst_chn2,
    input   [LAST_FRAME_BITS-1:0] frame_number_dst_chn2,
    input                         frame_done_dst_chn2,
    output                        suspend_chn2,

    output                        frame_start_dst_chn3,
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_src_chn3,
    input   [LAST_FRAME_BITS-1:0] frame_number_src_chn3,
    input                         frame_done_src_chn3, 
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_dst_chn3,
    input   [LAST_FRAME_BITS-1:0] frame_number_dst_chn3,
    input                         frame_done_dst_chn3,
    output                        suspend_chn3,
    // AXI_HP inteface (single/dual). afi indices - relative (0,1) may actually be connected to 1,2 (or only to 1)
    input                         hclk,
    
    // write address
    output                 [31:0] afi0_awaddr,
    output                        afi0_awvalid,
    input                         afi0_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output                 [ 5:0] afi0_awid,
    output                 [ 1:0] afi0_awlock,
    output                 [ 3:0] afi0_awcache,
    output                 [ 2:0] afi0_awprot,
    output                 [ 3:0] afi0_awlen,
    output                 [ 2:0] afi0_awsize,
    output                 [ 1:0] afi0_awburst,
    output                 [ 3:0] afi0_awqos,
    // write data
    output                 [63:0] afi0_wdata,
    output                        afi0_wvalid,
    input                         afi0_wready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output                 [ 5:0] afi0_wid,
    output                        afi0_wlast,
    output                 [ 7:0] afi0_wstrb,
    // write response
    input                         afi0_bvalid,
    output                        afi0_bready,
    input                  [ 5:0] afi0_bid,
    input                  [ 1:0] afi0_bresp,    // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input                  [ 7:0] afi0_wcount,
    input                  [ 5:0] afi0_wacount,
    output                        afi0_wrissuecap1en,
    
    // write address, second channel
    output                 [31:0] afi1_awaddr,
    output                        afi1_awvalid,
    input                         afi1_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output                 [ 5:0] afi1_awid,
    output                 [ 1:0] afi1_awlock,
    output                 [ 3:0] afi1_awcache,
    output                 [ 2:0] afi1_awprot,
    output                 [ 3:0] afi1_awlen,
    output                 [ 2:0] afi1_awsize,
    output                 [ 1:0] afi1_awburst,
    output                 [ 3:0] afi1_awqos,
    // write data
    output                 [63:0] afi1_wdata,
    output                        afi1_wvalid,
    input                         afi1_wready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output                 [ 5:0] afi1_wid,
    output                        afi1_wlast,
    output                 [ 7:0] afi1_wstrb,
    // write response
    input                         afi1_bvalid,
    output                        afi1_bready,
    input                  [ 5:0] afi1_bid,
    input                  [ 1:0] afi1_bresp,    // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input                  [ 7:0] afi1_wcount,
    input                  [ 5:0] afi1_wacount,
    output                        afi1_wrissuecap1en
);

    wire   [47:0] status_ad_mux; 
    wire    [5:0] status_rq_mux;
    wire    [5:0] status_start_mux;

    wire    [3:0] xfer_reset_page_rd = {xfer_reset_page_rd_chn3, xfer_reset_page_rd_chn2, xfer_reset_page_rd_chn1, xfer_reset_page_rd_chn0};
    wire    [3:0] buf_wpage_nxt =      {buf_wpage_nxt_chn3,      buf_wpage_nxt_chn2,      buf_wpage_nxt_chn1,      buf_wpage_nxt_chn0};
    wire    [3:0] buf_we =             {buf_we_chn3,             buf_we_chn2,             buf_we_chn1,             buf_we_chn0};
    wire  [255:0] buf_din =            {buf_din_chn3,            buf_din_chn2,            buf_din_chn1,            buf_din_chn0}; 
    wire    [3:0] page_ready =         {page_ready_chn3,         page_ready_chn2,         page_ready_chn1,         page_ready_chn0};
    wire    [3:0] next_page;
    assign {next_page_chn3, next_page_chn2, next_page_chn1, next_page_chn0} = next_page;
    
   // Timestamp messages (@mclk) - combine to a single ts_data?    
    wire    [3:0] ts_pre_stb =         {ts_pre_stb_chn3,         ts_pre_stb_chn2,         ts_pre_stb_chn1,         ts_pre_stb_chn0};
    wire   [31:0] ts_data =            {ts_data_chn3,            ts_data_chn2,            ts_data_chn1,            ts_data_chn0};

// Outputs for interrupts generation    
    wire    [3:0] eof_written_mclk;
    wire    [3:0] stuffer_done_mclk;
    assign {eof_written_mclk_chn3,  eof_written_mclk_chn2,  eof_written_mclk_chn1,  eof_written_mclk_chn0} =  eof_written_mclk;
    assign {stuffer_done_mclk_chn3, stuffer_done_mclk_chn2, stuffer_done_mclk_chn1, stuffer_done_mclk_chn0} = stuffer_done_mclk;
    // frame input synchronization
    wire    [3:0] vsync_late =         {vsync_late_chn3,         vsync_late_chn2,         vsync_late_chn1,         vsync_late_chn0}; 

    // master (sensor) with slave (compressor) synchronization I/Os
    wire                     [3:0] frame_start_dst;
    assign  {frame_start_dst_chn3, frame_start_dst_chn2, frame_start_dst_chn1, frame_start_dst_chn0} = frame_start_dst;
    wire [4*FRAME_HEIGHT_BITS-1:0] line_unfinished_src = {line_unfinished_src_chn3, line_unfinished_src_chn2, line_unfinished_src_chn1, line_unfinished_src_chn0};
    wire   [4*LAST_FRAME_BITS-1:0] frame_number_src =    {frame_number_src_chn3,    frame_number_src_chn2,    frame_number_src_chn1,    frame_number_src_chn0};
    wire                     [3:0] frame_done_src =      {frame_done_src_chn3,      frame_done_src_chn2,      frame_done_src_chn1,      frame_done_src_chn0}; 
    wire [4*FRAME_HEIGHT_BITS-1:0] line_unfinished_dst = {line_unfinished_dst_chn3, line_unfinished_dst_chn2, line_unfinished_dst_chn1, line_unfinished_dst_chn0};
    wire   [4*LAST_FRAME_BITS-1:0] frame_number_dst =    {frame_number_dst_chn3,    frame_number_dst_chn2,    frame_number_dst_chn1,    frame_number_dst_chn0};
    wire                     [3:0] frame_done_dst =      {frame_done_dst_chn3,      frame_done_dst_chn2,      frame_done_dst_chn1,      frame_done_dst_chn0};
    wire                     [3:0] suspend;
    assign {suspend_chn3, suspend_chn2, suspend_chn1, suspend_chn0} = suspend;
    
    // signals to connect to AFI multiplexers
    wire    [3:0] fifo_rst;
    wire    [3:0] fifo_ren;
    wire  [255:0] fifo_rdata; 
    wire    [3:0] fifo_eof; //SuppressThisWarning VEditor : Not used?
    wire    [3:0] eof_written;
    wire    [3:0] fifo_flush;
    wire   [31:0] fifo_count; 

    /* Instance template for module status_router8 */
    status_router8 status_router8_i (
        .rst         (rst),                     // input
        .clk         (mclk),                    // input
        .db_in0      (status_ad_mux[  0 +: 8]), // input[7:0] 
        .rq_in0      (status_rq_mux[0]),        // input
        .start_in0   (status_start_mux[0]),     // output
        
        .db_in1      (status_ad_mux[  8 +: 8]), // input[7:0] 
        .rq_in1      (status_rq_mux[1]),        // input
        .start_in1   (status_start_mux[1]),     // output
        
        .db_in2      (status_ad_mux[ 16 +: 8]), // input[7:0] 
        .rq_in2      (status_rq_mux[2]),        // input
        .start_in2   (status_start_mux[2]),     // output
        
        .db_in3      (status_ad_mux[ 24 +: 8]), // input[7:0] 
        .rq_in3      (status_rq_mux[3]),        // input
        .start_in3   (status_start_mux[3]),     // output
        
        .db_in4      (status_ad_mux[ 32 +: 8]), // input[7:0] 
        .rq_in4      (status_rq_mux[4]),        // input
        .start_in4   (status_start_mux[4]),     // output
        
        .db_in5      (status_ad_mux[ 40 +: 8]), // input[7:0] 
        .rq_in5      (status_rq_mux[5]),        // input
        .start_in5   (status_start_mux[5]),     // output
        
        .db_in6      (0),                       // input[7:0] 
        .rq_in6      (0),                       // input
        .start_in6   (),                        // output
        
        .db_in7      (0),                       // input[7:0] 
        .rq_in7      (0),                       // input
        .start_in7   (),                        // output
        
        .db_out      (status_ad),               // output[7:0] 
        .rq_out      (status_rq),               // output
        .start_out   (status_start)             // input
    );

    generate
        genvar i;
        for (i=0; i < 4; i=i+1) begin: cmprs_channel_block
            jp_channel #(
                .CMPRS_NUMBER                    (i),
                .CMPRS_GROUP_ADDR                (CMPRS_GROUP_ADDR),
                .CMPRS_BASE_INC                  (CMPRS_BASE_INC),
                .CMPRS_STATUS_REG_BASE           (CMPRS_STATUS_REG_BASE),
                .CMPRS_HIFREQ_REG_BASE           (CMPRS_HIFREQ_REG_BASE),
                .CMPRS_STATUS_REG_INC            (CMPRS_STATUS_REG_INC),
                .CMPRS_HIFREQ_REG_INC            (CMPRS_HIFREQ_REG_INC),
                .CMPRS_MASK                      (CMPRS_MASK),
                .CMPRS_CONTROL_REG               (CMPRS_CONTROL_REG),
                .CMPRS_STATUS_CNTRL              (CMPRS_STATUS_CNTRL),
                .CMPRS_FORMAT                    (CMPRS_FORMAT),
                .CMPRS_COLOR_SATURATION          (CMPRS_COLOR_SATURATION),
                .CMPRS_CORING_MODE               (CMPRS_CORING_MODE),
                .CMPRS_TABLES                    (CMPRS_TABLES),
                .FRAME_HEIGHT_BITS               (FRAME_HEIGHT_BITS),
                .LAST_FRAME_BITS                 (LAST_FRAME_BITS),
                .CMPRS_CBIT_RUN                  (CMPRS_CBIT_RUN),
                .CMPRS_CBIT_RUN_BITS             (CMPRS_CBIT_RUN_BITS),
                .CMPRS_CBIT_QBANK                (CMPRS_CBIT_QBANK),
                .CMPRS_CBIT_QBANK_BITS           (CMPRS_CBIT_QBANK_BITS),
                .CMPRS_CBIT_DCSUB                (CMPRS_CBIT_DCSUB),
                .CMPRS_CBIT_DCSUB_BITS           (CMPRS_CBIT_DCSUB_BITS),
                .CMPRS_CBIT_CMODE                (CMPRS_CBIT_CMODE),
                .CMPRS_CBIT_CMODE_BITS           (CMPRS_CBIT_CMODE_BITS),
                .CMPRS_CBIT_FRAMES               (CMPRS_CBIT_FRAMES),
                .CMPRS_CBIT_FRAMES_BITS          (CMPRS_CBIT_FRAMES_BITS),
                .CMPRS_CBIT_BAYER                (CMPRS_CBIT_BAYER),
                .CMPRS_CBIT_BAYER_BITS           (CMPRS_CBIT_BAYER_BITS),
                .CMPRS_CBIT_FOCUS                (CMPRS_CBIT_FOCUS),
                .CMPRS_CBIT_FOCUS_BITS           (CMPRS_CBIT_FOCUS_BITS),
                .CMPRS_CBIT_RUN_RST              (CMPRS_CBIT_RUN_RST),
                .CMPRS_CBIT_RUN_STANDALONE       (CMPRS_CBIT_RUN_STANDALONE),
                .CMPRS_CBIT_RUN_ENABLE           (CMPRS_CBIT_RUN_ENABLE),
                .CMPRS_CBIT_CMODE_JPEG18         (CMPRS_CBIT_CMODE_JPEG18),
                .CMPRS_CBIT_CMODE_MONO6          (CMPRS_CBIT_CMODE_MONO6),
                .CMPRS_CBIT_CMODE_JP46           (CMPRS_CBIT_CMODE_JP46),
                .CMPRS_CBIT_CMODE_JP46DC         (CMPRS_CBIT_CMODE_JP46DC),
                .CMPRS_CBIT_CMODE_JPEG20         (CMPRS_CBIT_CMODE_JPEG20),
                .CMPRS_CBIT_CMODE_JP4            (CMPRS_CBIT_CMODE_JP4),
                .CMPRS_CBIT_CMODE_JP4DC          (CMPRS_CBIT_CMODE_JP4DC),
                .CMPRS_CBIT_CMODE_JP4DIFF        (CMPRS_CBIT_CMODE_JP4DIFF),
                .CMPRS_CBIT_CMODE_JP4DIFFHDR     (CMPRS_CBIT_CMODE_JP4DIFFHDR),
                .CMPRS_CBIT_CMODE_JP4DIFFDIV2    (CMPRS_CBIT_CMODE_JP4DIFFDIV2),
                .CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 (CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2),
                .CMPRS_CBIT_CMODE_MONO1          (CMPRS_CBIT_CMODE_MONO1),
                .CMPRS_CBIT_CMODE_MONO4          (CMPRS_CBIT_CMODE_MONO4),
                .CMPRS_CBIT_FRAMES_SINGLE        (CMPRS_CBIT_FRAMES_SINGLE),
                .CMPRS_COLOR18                   (CMPRS_COLOR18),
                .CMPRS_COLOR20                   (CMPRS_COLOR20),
                .CMPRS_MONO16                    (CMPRS_MONO16),
                .CMPRS_JP4                       (CMPRS_JP4),
                .CMPRS_JP4DIFF                   (CMPRS_JP4DIFF),
                .CMPRS_MONO8                     (CMPRS_MONO8),
                .CMPRS_FRMT_MBCM1                (CMPRS_FRMT_MBCM1),
                .CMPRS_FRMT_MBCM1_BITS           (CMPRS_FRMT_MBCM1_BITS),
                .CMPRS_FRMT_MBRM1                (CMPRS_FRMT_MBRM1),
                .CMPRS_FRMT_MBRM1_BITS           (CMPRS_FRMT_MBRM1_BITS),
                .CMPRS_FRMT_LMARG                (CMPRS_FRMT_LMARG),
                .CMPRS_FRMT_LMARG_BITS           (CMPRS_FRMT_LMARG_BITS),
                .CMPRS_CSAT_CB                   (CMPRS_CSAT_CB),
                .CMPRS_CSAT_CB_BITS              (CMPRS_CSAT_CB_BITS),
                .CMPRS_CSAT_CR                   (CMPRS_CSAT_CR),
                .CMPRS_CSAT_CR_BITS              (CMPRS_CSAT_CR_BITS),
                .CMPRS_CORING_BITS               (CMPRS_CORING_BITS),
                .CMPRS_TIMEOUT_BITS              (CMPRS_TIMEOUT_BITS),
                .CMPRS_TIMEOUT                   (CMPRS_TIMEOUT)
            ) jp_channel_i (
                .rst                                  (rst),                       // input
                .xclk                                 (xclk),                      // input
                .xclk2x                               (xclk2x),                    // input
                .mclk                                 (mclk),                      // input
                .cmd_ad                               (cmd_ad),                    // input[7:0] 
                .cmd_stb                              (cmd_stb),                   // input
                .status_ad                            (status_ad_mux[8 * i +: 8]), // output[7:0] 
                .status_rq                            (status_rq_mux[i]),          // output
                .status_start                         (status_start_mux[i]),       // input
                .xfer_reset_page_rd                   (xfer_reset_page_rd[i]),     // input
                .buf_wpage_nxt                        (buf_wpage_nxt[i]),          // input
                .buf_we                               (buf_we[i]),                 // input
                .buf_din                              (buf_din[64 * i +: 64]),     // input[63:0] 
                .page_ready_chn                       (page_ready[i]),             // input
                .next_page_chn                        (next_page[i]),              // output
                .dccout                               (1'b0), // input
                .hfc_sel                              (3'b0), // input[2:0] 
                .statistics_dv                        (), // output
                .statistics_do                        (), // output[15:0] 
                .ts_pre_stb                           (ts_pre_stb[i]),             // input
                .ts_data                              (ts_data[8*i +: 8]),         // input[7:0] 
                .eof_written_mclk                     (eof_written_mclk[i]),       // output
                .stuffer_done_mclk                    (stuffer_done_mclk[i]),      // output
                .vsync_late                           (vsync_late[i]),             // input
                .frame_start_dst                      (frame_start_dst[i]),        // output
                .line_unfinished_src                  (line_unfinished_src[FRAME_HEIGHT_BITS * i +: FRAME_HEIGHT_BITS]), // input[15:0] 
                .frame_number_src                     (frame_number_src[LAST_FRAME_BITS * i +: LAST_FRAME_BITS]), // input[15:0] 
                .frame_done_src                       (frame_done_src[i]),         // input
                .line_unfinished_dst                  (line_unfinished_dst[FRAME_HEIGHT_BITS * i +: FRAME_HEIGHT_BITS]), // input[15:0] 
                .frame_number_dst                     (frame_number_dst[LAST_FRAME_BITS * i +: LAST_FRAME_BITS]), // input[15:0] 
                .frame_done_dst                       (frame_done_dst[i]),         // input
                .suspend                              (suspend[i]),                // output
                
                .hclk                                 (hclk),                      // input
                .fifo_rst                             (fifo_rst[i]),               // input
                .fifo_ren                             (fifo_ren[i]),               // input
                .fifo_rdata                           (fifo_rdata[64 * i +: 64]),  // output[63:0]
                 
                .fifo_eof                             (fifo_eof[i]),               // output
                .eof_written                          (eof_written[i]),            // input
                .fifo_flush                           (fifo_flush[i]),             // output
                .fifo_count                           (fifo_count[8* i +: 8])      // output[7:0] 
            );
        end
    endgenerate
    
    generate
        if (CMPRS_NUM_AFI_CHN > 1) begin
            cmprs_afi_mux #(
                .CMPRS_AFIMUX_ADDR            (CMPRS_GROUP_ADDR + CMPRS_AFIMUX_RADDR0),
                .CMPRS_AFIMUX_MASK            (CMPRS_AFIMUX_MASK),
                .CMPRS_AFIMUX_EN              (CMPRS_AFIMUX_EN),
                .CMPRS_AFIMUX_RST             (CMPRS_AFIMUX_RST),
                .CMPRS_AFIMUX_MODE            (CMPRS_AFIMUX_MODE),
                .CMPRS_AFIMUX_STATUS_CNTRL    (CMPRS_AFIMUX_STATUS_CNTRL),
                .CMPRS_AFIMUX_SA_LEN          (CMPRS_AFIMUX_SA_LEN),
                .CMPRS_AFIMUX_STATUS_REG_ADDR (CMPRS_AFIMUX_REG_ADDR0), //***********
                .CMPRS_AFIMUX_WIDTH           (CMPRS_AFIMUX_WIDTH),
                .CMPRS_AFIMUX_CYCBITS         (CMPRS_AFIMUX_CYCBITS),
                .AFI_MUX_BUF_LATENCY          (AFI_MUX_BUF_LATENCY)
            ) cmprs_afi0_mux_i (
                .rst              (rst),                    // input
                .mclk             (mclk),                   // input
                .hclk             (hclk),                   // input
                .cmd_ad           (cmd_ad),                 // input[7:0] 
                .cmd_stb          (cmd_stb),                // input
                .status_ad        (status_ad_mux[32 +: 8]), // output[7:0]
                .status_rq        (status_rq_mux[4]),       // output
                .status_start     (status_start_mux[4]),    // input
                .fifo_rst0        (fifo_rst[0]),            // output
                .fifo_ren0        (fifo_ren[0]),            // output
                .fifo_rdata0      (fifo_rdata[0 +: 64]),    // input[63:0] 
                
                .eof_written0     (eof_written[0]),            // output //?
                .fifo_flush0      (fifo_flush[0]),          // input  
                .fifo_count0      (fifo_count[0 +: 8]),     // input[7:0]
                 
                .fifo_rst1        (fifo_rst[1]),            // output
                .fifo_ren1        (fifo_ren[1]),            // output
                .fifo_rdata1      (fifo_rdata[64 +: 64]),   // input[63:0] 
                .eof_written1     (eof_written[1]),            // output
                .fifo_flush1      (fifo_flush[1]),          // input
                .fifo_count1      (fifo_count[8 +: 8]),     // input[7:0] 
                .fifo_rst2        (),                       // output
                .fifo_ren2        (),                       // output
                .fifo_rdata2      (0),                      // input[63:0] 
                .eof_written2     (),                       // output
                .fifo_flush2      (0),                      // input
                .fifo_count2      (0),                      // input[7:0] 
                .fifo_rst3        (),                       // output
                .fifo_ren3        (),                       // output
                .fifo_rdata3      (0),                      // input[63:0] 
                .eof_written3     (),                       // output
                .fifo_flush3      (0),                      // input
                .fifo_count3      (0),                      // input[7:0] 
                .afi_awaddr       (afi0_awaddr),            // output[31:0] 
                .afi_awvalid      (afi0_awvalid),           // output
                .afi_awready      (afi0_awready),           // input
                .afi_awid         (afi0_awid),              // output[5:0] 
                .afi_awlock       (afi0_awlock),            // output[1:0] 
                .afi_awcache      (afi0_awcache),           // output[3:0] 
                .afi_awprot       (afi0_awprot),            // output[2:0] 
                .afi_awlen        (afi0_awlen),             // output[3:0] 
                .afi_awsize       (afi0_awsize),            // output[2:0] 
                .afi_awburst      (afi0_awburst),           // output[1:0] 
                .afi_awqos        (afi0_awqos),             // output[3:0] 
                .afi_wdata        (afi0_wdata),             // output[63:0] 
                .afi_wvalid       (afi0_wvalid),            // output
                .afi_wready       (afi0_wready),            // input
                .afi_wid          (afi0_wid),               // output[5:0] 
                .afi_wlast        (afi0_wlast),             // output
                .afi_wstrb        (afi0_wstrb),             // output[7:0] 
                .afi_bvalid       (afi0_bvalid),            // input
                .afi_bready       (afi0_bready),            // output
                .afi_bid          (afi0_bid),               // input[5:0] 
                .afi_bresp        (afi0_bresp),             // input[1:0] 
                .afi_wcount       (afi0_wcount),            // input[7:0] 
                .afi_wacount      (afi0_wacount),           // input[5:0] 
                .afi_wrissuecap1en(afi0_wrissuecap1en)      // output
            );
        
            cmprs_afi_mux #(
                .CMPRS_AFIMUX_ADDR            (CMPRS_GROUP_ADDR + CMPRS_AFIMUX_RADDR1),
                .CMPRS_AFIMUX_MASK            (CMPRS_AFIMUX_MASK),
                .CMPRS_AFIMUX_EN              (CMPRS_AFIMUX_EN),
                .CMPRS_AFIMUX_RST             (CMPRS_AFIMUX_RST),
                .CMPRS_AFIMUX_MODE            (CMPRS_AFIMUX_MODE),
                .CMPRS_AFIMUX_STATUS_CNTRL    (CMPRS_AFIMUX_STATUS_CNTRL),
                .CMPRS_AFIMUX_SA_LEN          (CMPRS_AFIMUX_SA_LEN),
                .CMPRS_AFIMUX_STATUS_REG_ADDR (CMPRS_AFIMUX_REG_ADDR1),
                .CMPRS_AFIMUX_WIDTH           (CMPRS_AFIMUX_WIDTH),
                .CMPRS_AFIMUX_CYCBITS         (CMPRS_AFIMUX_CYCBITS),
                .AFI_MUX_BUF_LATENCY          (AFI_MUX_BUF_LATENCY)
            ) cmprs_afi1_mux_i (
                .rst              (rst),                    // input
                .mclk             (mclk),                   // input
                .hclk             (hclk),                   // input
                .cmd_ad           (cmd_ad),                 // input[7:0] 
                .cmd_stb          (cmd_stb),                // input
                .status_ad        (status_ad_mux[40 +: 8]), // output[7:0]
                .status_rq        (status_rq_mux[5]),       // output
                .status_start     (status_start_mux[5]),    // input
                .fifo_rst0        (fifo_rst[2]),            // output
                .fifo_ren0        (fifo_ren[2]),            // output
                .fifo_rdata0      (fifo_rdata[128 +: 64]),  // input[63:0] 
                .eof_written0     (eof_written[2]),            // output
                .fifo_flush0      (fifo_flush[2]),          // input
                .fifo_count0      (fifo_count[16 +: 8]),    // input[7:0] 
                .fifo_rst1        (fifo_rst[3]),            // output
                .fifo_ren1        (fifo_ren[3]),            // output
                .fifo_rdata1      (fifo_rdata[192 +: 64]),  // input[63:0] 
                .eof_written1     (eof_written[3]),            // output
                .fifo_flush1      (fifo_flush[3]),          // input
                .fifo_count1      (fifo_count[24 +: 8]),     // input[7:0] 
                .fifo_rst2        (),                       // output
                .fifo_ren2        (),                       // output
                .fifo_rdata2      (0),                      // input[63:0] 
                .eof_written2     (),                       // output
                .fifo_flush2      (0),                      // input
                .fifo_count2      (0),                      // input[7:0] 
                .fifo_rst3        (),                       // output
                .fifo_ren3        (),                       // output
                .fifo_rdata3      (0),                      // input[63:0] 
                .eof_written3     (),                       // output
                .fifo_flush3      (0),                      // input
                .fifo_count3      (0),                      // input[7:0] 
                .afi_awaddr       (afi1_awaddr),            // output[31:0] 
                .afi_awvalid      (afi1_awvalid),           // output
                .afi_awready      (afi1_awready),           // input
                .afi_awid         (afi1_awid),              // output[5:0] 
                .afi_awlock       (afi1_awlock),            // output[1:0] 
                .afi_awcache      (afi1_awcache),           // output[3:0] 
                .afi_awprot       (afi1_awprot),            // output[2:0] 
                .afi_awlen        (afi1_awlen),             // output[3:0] 
                .afi_awsize       (afi1_awsize),            // output[2:0] 
                .afi_awburst      (afi1_awburst),           // output[1:0] 
                .afi_awqos        (afi1_awqos),             // output[3:0] 
                .afi_wdata        (afi1_wdata),             // output[63:0] 
                .afi_wvalid       (afi1_wvalid),            // output
                .afi_wready       (afi1_wready),            // input
                .afi_wid          (afi1_wid),               // output[5:0] 
                .afi_wlast        (afi1_wlast),             // output
                .afi_wstrb        (afi1_wstrb),             // output[7:0] 
                .afi_bvalid       (afi1_bvalid),            // input
                .afi_bready       (afi1_bready),            // output
                .afi_bid          (afi1_bid),               // input[5:0] 
                .afi_bresp        (afi1_bresp),             // input[1:0] 
                .afi_wcount       (afi1_wcount),            // input[7:0] 
                .afi_wacount      (afi1_wacount),           // input[5:0] 
                .afi_wrissuecap1en(afi1_wrissuecap1en)      // output
            );
        end else begin
            cmprs_afi_mux #(
                .CMPRS_AFIMUX_ADDR            (CMPRS_GROUP_ADDR + CMPRS_AFIMUX_RADDR0),
                .CMPRS_AFIMUX_MASK            (CMPRS_AFIMUX_MASK),
                .CMPRS_AFIMUX_EN              (CMPRS_AFIMUX_EN),
                .CMPRS_AFIMUX_RST             (CMPRS_AFIMUX_RST),
                .CMPRS_AFIMUX_MODE            (CMPRS_AFIMUX_MODE),
                .CMPRS_AFIMUX_STATUS_CNTRL    (CMPRS_AFIMUX_STATUS_CNTRL),
                .CMPRS_AFIMUX_SA_LEN          (CMPRS_AFIMUX_SA_LEN),
                .CMPRS_AFIMUX_STATUS_REG_ADDR (CMPRS_AFIMUX_REG_ADDR0),
                .CMPRS_AFIMUX_WIDTH           (CMPRS_AFIMUX_WIDTH),
                .CMPRS_AFIMUX_CYCBITS         (CMPRS_AFIMUX_CYCBITS),
                .AFI_MUX_BUF_LATENCY          (AFI_MUX_BUF_LATENCY)
            ) cmprs_afi0_mux_i (
                .rst              (rst),                    // input
                .mclk             (mclk),                   // input
                .hclk             (hclk),                   // input
                .cmd_ad           (cmd_ad),                 // input[7:0] 
                .cmd_stb          (cmd_stb),                // input
                .status_ad        (status_ad_mux[32 +: 8]), // output[7:0]
                .status_rq        (status_rq_mux[4]),       // output
                .status_start     (status_start_mux[4]),    // input
                .fifo_rst0        (fifo_rst[0]),            // output
                .fifo_ren0        (fifo_ren[0]),            // output
                .fifo_rdata0      (fifo_rdata[0 +: 64]),    // input[63:0] 
                .eof_written0     (eof_written[0]),            // output
                .fifo_flush0      (fifo_flush[0]),          // input
                .fifo_count0      (fifo_count[0 +: 8]),     // input[7:0] 
                .fifo_rst1        (fifo_rst[1]),            // output
                .fifo_ren1        (fifo_ren[1]),            // output
                .fifo_rdata1      (fifo_rdata[64 +: 64]),   // input[63:0] 
                .eof_written1     (eof_written[1]),            // output
                .fifo_flush1      (fifo_flush[1]),          // input
                .fifo_count1      (fifo_count[8 +: 8]),     // input[7:0] 
                .fifo_rst2        (fifo_rst[2]),            // output
                .fifo_ren2        (fifo_ren[2]),            // output
                .fifo_rdata2      (fifo_rdata[128 +: 64]),  // input[63:0] 
                .eof_written2     (eof_written[2]),            // output
                .fifo_flush2      (fifo_flush[2]),          // input
                .fifo_count2      (fifo_count[16 +: 8]),    // input[7:0] 
                .fifo_rst3        (fifo_rst[3]),            // output
                .fifo_ren3        (fifo_ren[3]),            // output
                .fifo_rdata3      (fifo_rdata[192 +: 64]),  // input[63:0] 
                .eof_written3     (eof_written[3]),            // output
                .fifo_flush3      (fifo_flush[3]),          // input
                .fifo_count3      (fifo_count[24 +: 8]),    // input[7:0] 
                .afi_awaddr       (afi0_awaddr),            // output[31:0] 
                .afi_awvalid      (afi0_awvalid),           // output
                .afi_awready      (afi0_awready),           // input
                .afi_awid         (afi0_awid),              // output[5:0] 
                .afi_awlock       (afi0_awlock),            // output[1:0] 
                .afi_awcache      (afi0_awcache),           // output[3:0] 
                .afi_awprot       (afi0_awprot),            // output[2:0] 
                .afi_awlen        (afi0_awlen),             // output[3:0] 
                .afi_awsize       (afi0_awsize),            // output[2:0] 
                .afi_awburst      (afi0_awburst),           // output[1:0] 
                .afi_awqos        (afi0_awqos),             // output[3:0] 
                .afi_wdata        (afi0_wdata),             // output[63:0] 
                .afi_wvalid       (afi0_wvalid),            // output
                .afi_wready       (afi0_wready),            // input
                .afi_wid          (afi0_wid),               // output[5:0] 
                .afi_wlast        (afi0_wlast),             // output
                .afi_wstrb        (afi0_wstrb),             // output[7:0] 
                .afi_bvalid       (afi0_bvalid),            // input
                .afi_bready       (afi0_bready),            // output
                .afi_bid          (afi0_bid),               // input[5:0] 
                .afi_bresp        (afi0_bresp),             // input[1:0] 
                .afi_wcount       (afi0_wcount),            // input[7:0] 
                .afi_wacount      (afi0_wacount),           // input[5:0] 
                .afi_wrissuecap1en(afi0_wrissuecap1en)      // output
            );
            assign afi1_awaddr = 0;
            assign afi1_awvalid = 0;
            assign afi1_awid = 0; 
            assign afi1_awlock = 0; 
            assign afi1_awcache = 0; 
            assign afi1_awprot = 0; 
            assign afi1_awlen = 0; 
            assign afi1_awsize = 0; 
            assign afi1_awburst = 0; 
            assign afi1_awqos = 0; 
            assign afi1_wdata = 0; 
            assign afi1_wvalid = 0;
            assign afi1_wid = 0; 
            assign afi1_wlast = 0;
            assign afi1_wstrb = 0; 
            assign afi1_bready = 0;
            assign afi1_wrissuecap1en = 0;
        end
    endgenerate



endmodule
