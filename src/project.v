/*
 * Tiny Tapeout SKY130 -- RO-PUF V4: 16 ring oscillators, two independent
 * 16:1 multiplexers, and two raw frequency outputs.
 *
 * Each oscillator has 22 SKY130 inverter cells and one enabling NAND,
 * giving 23 inverting stages when enabled. This is a structural design;
 * oscillation frequency, timing and physical PUF properties are not
 * validated by zero-delay digital simulation.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

(* keep_hierarchy = "yes" *)
module ro_puf_v4_ring_23 (
    input  wire en,
    output wire osc_out
);
    (* keep = "true" *) wire [22:0] ring;

    // The NAND supplies one inversion and disables oscillation when en=0.
    (* keep = "true", dont_touch = "true" *)
    sky130_fd_sc_hd__nand2_1 u_enable (
        .A(ring[22]),
        .B(en),
        .Y(ring[0])
    );

    genvar j;
    generate
        for (j = 0; j < 22; j = j + 1) begin : g_inv
            (* keep = "true", dont_touch = "true" *)
            sky130_fd_sc_hd__inv_2 u_inv (
                .A(ring[j]),
                .Y(ring[j + 1])
            );
        end
    endgenerate

    assign osc_out = ring[22];
endmodule

module tt_um_ro_puf_16_v4 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // ui_in[3:0] = selector A (0..15)
    // ui_in[7:4] = selector B (0..15)
    // uio_in[0]  = shared local RO enable (input only)
    // ena         = Tiny Tapeout project enable
    // rst_n       = active-low reset/disable
    // uo_out[0]   = direct frequency output A
    // uo_out[1]   = direct frequency output B
    // Selecting the same index on both MUXes selects the same physical RO.

    wire run = ena & rst_n & uio_in[0];
    (* keep = "true" *) wire [15:0] oscillator_signals;

    genvar ro_index;
    generate
        for (ro_index = 0; ro_index < 16; ro_index = ro_index + 1) begin : g_ro
            (* keep = "true", dont_touch = "true" *)
            ro_puf_v4_ring_23 u_ring (
                .en(run),
                .osc_out(oscillator_signals[ro_index])
            );
        end
    endgenerate

    // Two distinct 16:1 selection paths sharing the same bank of 16 ROs.
    (* keep = "true" *) wire selected_a = oscillator_signals[ui_in[3:0]];
    (* keep = "true" *) wire selected_b = oscillator_signals[ui_in[7:4]];

    // The gate masks the fixed logic level of disabled oscillators.
    assign uo_out = {6'b000000, (run & selected_b), (run & selected_a)};

    // All bidirectional Tiny Tapeout pins are inputs, including uio_in[0].
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    wire _unused = &{clk, uio_in[7:1], 1'b0};
endmodule

`default_nettype wire
