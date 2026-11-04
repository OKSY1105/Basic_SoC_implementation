; Integration test I02: interrupt-driven UART echo, delayed by one byte.
; IRQ_EN = RX_VALID only, EI, then an idle loop. The handler (vector word
; 0x0002, register bank 1) pushes the byte saved in R1 by the previous entry to
; TX_DATA, then pops the new byte from RX_DATA into R1 and returns. The pop is
; the last access before RETI on purpose: it is the case with zero clocks of
; margin between the IRQ falling and RETI taking effect (H059 6-1), so a
; spurious re-entry would show as an extra entry and a repeated byte.
; Bank-1 R1 starts at 0, so for sent bytes b0..bn-1 the TB expects
; 00, b0, ..., bn-2 on TX and exactly n handler entries.
        .org 0
        JMP main
        .org 2
isr:    LDXH 0xFF
        LDXL 0x01
        ST [X], R1              ; TX_DATA: byte of the previous entry
        LDXL 0x00
        LD R1, [X]              ; RX_DATA pop: RX_VALID falls if it was the last
        RETI
main:   LDXH 0xFF
        LDXL 0x04
        LDI R0, 1
        ST [X], R0              ; IRQ_EN = RX_VALID
        EI
idle:   JMP idle
