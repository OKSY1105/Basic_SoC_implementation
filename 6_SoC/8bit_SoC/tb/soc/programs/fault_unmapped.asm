; Integration test: a load from an unmapped address (0x4000) gets the default
; slave's two-cycle ERROR; the CPU stops with fault code 3 at that LD.
; The TB expects UART byte 0x41 first, bus error address 0x4000, count 1.
        .org 0
        JMP main
        .org 2
isr:    RETI                    ; not reached
main:   LDXH 0xFF
        LDXL 0x01
        LDI R0, 0x41
        ST [X], R0              ; TX_DATA: 'A'
        LDXH 0x40
        LDXL 0x00
        LD R1, [X]              ; unmapped: ERROR -> fault code 3
        HALT                    ; not reached
