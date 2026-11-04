# Out-of-context synthesis of the board memory path: dram_controller_core
# with the BRAM-based DRAM model dram_bram_model (M4), as on the board.
# Usage: vivado -mode batch -nojournal -source scripts/synth_dram_bram.tcl
# Environment (optional):
#   SOC8_SYNTH_BUILD  output folder (default build/synth_dram_bram)
#   SOC8_FPGA_PART    part (default xc7z020clg400-1, Zybo Z7-20)
# The pair top (host port of the core as top ports, DRAM pins internal) is
# written to the output folder. Checks: the model array is block RAM, no
# latch primitives, no combinational loop (DRC LUTLP-1). Reports: utilization
# of the pair and of the model, setup WNS with a 10 ns (100 MHz) clock.
# Synthesis estimate only: no placement/routing or board timing claim.
set root [file normalize [file join [file dirname [info script]] ..]]
set library [file normalize [file join $root .. .. 1_RTL 2_TINY_PROJECT]]
set out [file join $root build synth_dram_bram]
if {[info exists ::env(SOC8_SYNTH_BUILD)]} {set out $::env(SOC8_SYNTH_BUILD)}
file mkdir $out
set part xc7z020clg400-1
if {[info exists ::env(SOC8_FPGA_PART)]} {set part $::env(SOC8_FPGA_PART)}

set top [file join $out dram_bram_pair.v]
set fd [open $top w]
puts $fd {`default_nettype none
module dram_bram_pair (
    input  wire        i_clk, i_rst_n, i_req, i_write, i_line,
    input  wire [10:0] i_addr,
    input  wire [7:0]  i_wdata,
    input  wire [63:0] i_line_wdata,
    output wire        o_ready, o_busy, o_initialized,
    output wire [7:0]  o_rdata,
    output wire [63:0] o_line_rdata
);
    wire ck_t, ck_c, cke, csn, actn, dq_oe, dqs_t, dqs_c, dqs_oe, m_dq_oe;
    wire [1:0] bg, ba;
    wire [17:0] a;
    wire [7:0] dq_o, m_dq;
    dram_controller_core u_core (
        .i_clk(i_clk), .i_rst_n(i_rst_n), .i_req(i_req), .i_write(i_write),
        .i_line(i_line), .i_addr(i_addr), .i_wdata(i_wdata), .i_line_wdata(i_line_wdata),
        .o_ready(o_ready), .o_rdata(o_rdata), .o_line_rdata(o_line_rdata), .o_error(),
        .o_busy(o_busy), .o_initialized(o_initialized),
        .o_dram_ck_t(ck_t), .o_dram_ck_c(ck_c), .o_dram_cke(cke), .o_dram_csn(csn),
        .o_dram_actn(actn), .o_dram_bg(bg), .o_dram_ba(ba), .o_dram_a(a),
        .o_dram_dq(dq_o), .o_dram_dq_oe(dq_oe), .i_dram_dq(m_dq),
        .o_dram_dqs_t(dqs_t), .o_dram_dqs_c(dqs_c), .o_dram_dqs_oe(dqs_oe));
    dram_bram_model u_model (
        .i_clk(i_clk), .i_ck_t(ck_t), .i_ck_c(ck_c), .i_cke(cke), .i_csn(csn),
        .i_actn(actn), .i_bg(bg), .i_ba(ba), .i_a(a), .i_dq(dq_o),
        .o_dq(m_dq), .o_dq_oe(m_dq_oe), .i_dqs_t(dqs_t), .i_dqs_c(dqs_c));
endmodule
`default_nettype wire}
close $fd

set src [list [file join $library DRAM_CONTEOLLER dram_controller.v] \
              [file join $library DRAM dram_bram_model.v] $top]
foreach name $src { if {![file exists $name]} { error "Missing input: $name" } }
read_verilog $src
synth_design -top dram_bram_pair -part $part -mode out_of_context

set latches [get_cells -hierarchical -filter {REF_NAME == LDCE || REF_NAME == LDPE}]
if {[llength $latches] != 0} {error "Unexpected latch primitives: $latches"}
report_drc -name dram_loops -checks {LUTLP-1} -file [file join $out drc_loops.rpt]
set loops [llength [get_drc_violations -quiet -name dram_loops]]
if {$loops != 0} {error "Combinational loops: $loops (see drc_loops.rpt)"}
set rams [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.bram.* && NAME =~ u_model/*}]
if {[llength $rams] == 0} {error "The model array is not block RAM"}

create_clock -name i_clk -period 10.000 [get_ports i_clk]
report_utilization -file [file join $out utilization.rpt]
report_utilization -cells [get_cells u_model] -file [file join $out utilization_model.rpt]
report_timing_summary -file [file join $out timing_summary.rpt]
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
proc used {util name} {
    if {[regexp "\\|\\s*$name\\*?\\s*\\|\\s*(\\d+(\\.\\d+)?)" $util -> n]} {return $n}
    return "?"
}
set util [report_utilization -return_string]
set mutil [report_utilization -cells [get_cells u_model] -return_string]
set result [format "DRAM_BRAM_SYNTH_PASS part=%s pair_lut=%s pair_ff=%s pair_bram=%s model_lut=%s model_ff=%s model_bram=%s ram_cells=%s latch=0 loops=0 wns_100mhz=%s" \
    $part [used $util "Slice LUTs"] [used $util "Slice Registers"] [used $util "Block RAM Tile"] \
    [used $mutil "Slice LUTs"] [used $mutil "Slice Registers"] [used $mutil "Block RAM Tile"] \
    [join [lsort -unique [get_property REF_NAME $rams]] ","] $wns]
set fd [open [file join $out status.txt] w]
puts $fd $result
puts $fd "Synthesis estimate only; no placement/routing, pin constraints or board timing claim."
close $fd
puts $result
