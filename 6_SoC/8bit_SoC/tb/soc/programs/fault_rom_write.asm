; Integration test: a store to the ROM region (byte 0x0010) gets ROM port B's
; two-cycle ERROR with no side effect; the CPU stops with fault code 3 at that
; ST. The default slave is not involved (bus error count stays 0).
        .org 0
        JMP main
        .org 2
isr:    RETI                    ; not reached
main:   LDXH 0x00
        LDXL 0x10
        LDI R0, 0x55
        ST [X], R0              ; ROM is read only: ERROR -> fault code 3
        HALT                    ; not reached
