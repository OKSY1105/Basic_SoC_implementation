; Integration test I01: ROM -> CPU -> AHB bus -> cache/DRAM, ROM data reads,
; UART TX. Interrupts stay disabled.
; 1. Write 256 bytes 0x8000-0x80FF with v(i) = 3 + 7*i (mod 256). 32 lines are
;    four times the 8-line cache, so dirty lines are evicted and written back.
; 2. Read them back, add them up (mod 256) and send the sum to TX_DATA.
; 3. Read 4 bytes of the ROM table at word 0x0100 (byte address 0x0200) and
;    send them. Little endian: the TB expects 12 34 56 78.
; 4. HALT. The TB expects the UART bytes: sum, 12, 34, 56, 78.
        .org 0
        JMP main
        .org 2
isr:    RETI                    ; not reached (IE stays 0)
main:   LDXH 0x80
        LDXL 0x00
        LDI R0, 3               ; value
        LDI R1, 0               ; counter: 256 iterations
        LDI R2, 7               ; step
        LDI R3, 1
wloop:  ST [X], R0
        INX
        ADD R0, R2
        ADD R1, R3              ; Z after 256 iterations
        JZ wdone
        JMP wloop
wdone:  LDXH 0x80
        LDXL 0x00
        LDI R0, 0               ; sum
        LDI R1, 0
rloop:  LD R2, [X]
        ADD R0, R2
        INX
        ADD R1, R3
        JZ rdone
        JMP rloop
rdone:  LDXH 0xFF
        LDXL 0x01
        ST [X], R0              ; TX_DATA: sum
        LDXH 0x02
        LDXL 0x00
        LD R0, [X]              ; ROM byte 0x0200
        INX
        LD R1, [X]
        INX
        LD R2, [X]
        INX
        LD R3, [X]
        LDXH 0xFF
        LDXL 0x01
        ST [X], R0
        ST [X], R1
        ST [X], R2
        ST [X], R3
        HALT
        .org 0x100
table:  .word 0x3412
        .word 0x7856
