; 8bit SoC calculator firmware (ROM). Protocol: 02_design/calculator.md.
;
; PC -> UART RX: lines "A,B" (two numbers -128..127) and "ADD"/"SUB"/"MUL"/"DIV"
; (any case), ended by CR, LF or CRLF. UART TX: one ASCII line per operation,
;   ADD:30   SUB:-10   MUL:200   DIV Q:0 R:10
; or ERR DIV0 / ERR RANGE / ERR SYNTAX / ERR NOARG. A valid number line has no
; reply; A and B stay until the next valid number line.
;
; Structure
; - main (bank 0): clear the variables, IRQ_EN = RX_VALID, EI, idle loop.
; - UART RX interrupt handler (vector word 2, register bank 1): one entry per
;   received character (RX_VALID stays high while bytes wait, so the next one
;   re-enters at once). It parses the line incrementally into RAM variables;
;   at the end of a line it checks, computes and sends the reply, then clears
;   the line state. Characters that arrive meanwhile wait in the RX FIFO.
; - X is the only address register and takes immediates only (LDXH/LDXL/INX),
;   so its value cannot be saved or computed. Variables therefore sit at fixed
;   addresses, and reply text is written character by character with LDI + ST
;   while X stays at TX_DATA (no string table in ROM).
; - TX: before a reply the handler waits for TX_EMPTY (16 free FIFO places);
;   the DIV reply (up to 17 bytes with CRLF) waits once more before " R:".
; - No CALL/RET and rel8 branches only (+-128 words): shared code is reached by
;   JMP, the number printer continues through V_PHASE, and far targets are
;   reached through t_*/s_* trampolines placed after unconditional jumps.
; Arithmetic: ADD/SUB in 16 bits after sign extension; MUL by repeated addition
; of |A|, |B| times; DIV by repeated subtraction (quotient toward zero,
; remainder with the sign of A, as C). All results fit in signed 16 bits.

; ---------------------------------------------------------------- addresses
        .equ U_PAGE, 0xFF       ; UART registers 0xFF00-0xFF04
        .equ U_RX, 0x00
        .equ U_TX, 0x01
        .equ U_ST, 0x02
        .equ U_EC, 0x03
        .equ U_IE, 0x04
        .equ ST_ERR, 0x38       ; STATUS OVERRUN | FRAME_ERR | PARITY_ERR
        .equ ST_TXE, 0x40       ; STATUS TX_EMPTY

        .equ V_PAGE, 0x80       ; variables in RAM 0x8000-0x8018
        .equ V_ST, 0x00         ; line state: 0 start, 1 number A, 2 number B, 3 letters
        .equ V_LEN, 0x01        ; characters in the line (terminator excluded)
        .equ V_ACC, 0x02        ; magnitude of the number being read
        .equ V_NEG, 0x03        ; 1: that number has a '-'
        .equ V_NDIG, 0x04       ; its digits so far
        .equ V_ESYN, 0x05       ; 1: syntax error (or UART receive error) in the line
        .equ V_ERNG, 0x06       ; 1: a number of the line is out of range
        .equ V_TA, 0x07         ; A of the line being read
        .equ V_A, 0x08          ; A and B in use
        .equ V_B, 0x09
        .equ V_ABOK, 0x0A       ; 1: A and B are valid
        .equ V_C1, 0x0B         ; letters of the operation line (upper case)
        .equ V_C2, 0x0C
        .equ V_C3, 0x0D
        .equ V_OP, 0x0E         ; 1 ADD, 2 SUB, 3 MUL, 4 DIV
        .equ V_PHASE, 0x0F      ; after printing: 0 CRLF, 1 remainder of DIV next
        .equ V_PSGN, 0x10       ; number to print: sign (0/1), magnitude 16 bits
        .equ V_PLO, 0x11
        .equ V_PHI, 0x12
        .equ V_RSGN, 0x13       ; remainder of DIV: sign, magnitude
        .equ V_RMAG, 0x14
        .equ V_MA, 0x15         ; |A|, |B| and their signs (MUL, DIV)
        .equ V_MB, 0x16
        .equ V_SA, 0x17
        .equ V_SB, 0x18

        .equ CR, 0x0D
        .equ LF, 0x0A
        .equ CH_COMMA, 0x2C
        .equ CH_COLON, 0x3A
        .equ CH_9P1, 0x3A       ; '9' + 1
        .equ CH_ZP1, 0x5B       ; 'Z' + 1
        .equ UPPER, 0xDF        ; AND mask: a-z -> A-Z

; ------------------------------------------------------------------ vectors
        .org 0
        JMP main
        .org 2
        JMP isr                 ; interrupt vector (word 2)

; --------------------------------------------------------------------- main
main:   LDXH V_PAGE
        LDI R0, 0
        LDXL V_ST
        ST [X], R0              ; clear V_ST .. V_ABOK (0x00 - 0x0A)
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        LDXH U_PAGE
        LDXL U_IE
        LDI R0, 1
        ST [X], R0              ; IRQ_EN = RX_VALID
        EI
idle:   JMP idle

; ---------------------------------------------- handler: one RX character
isr:    LDXH U_PAGE
        LDXL U_ST
        LD R0, [X]              ; STATUS
        LDI R1, ST_ERR
        AND R0, R1
        JZ isr_rd
        LDXL U_EC
        ST [X], R1              ; clear the receive error flags (W1C)
        LDXH V_PAGE
        LDXL V_ESYN
        LDI R0, 1
        ST [X], R0              ; the line is bad
        LDXH U_PAGE
isr_rd: LDXL U_RX
        LD R0, [X]              ; R0 = character (RX pop)
        LDI R1, CR
        CMP R0, R1
        JZ t_eol
        LDI R1, LF
        CMP R0, R1
        JZ t_eol
        ; Ordinary character: LEN += 1; 16 or more -> syntax error.
        LDXH V_PAGE
        LDXL V_LEN
        LD R1, [X]
        LDI R2, 1
        ADD R1, R2
        ST [X], R1
        LDI R2, 16
        CMP R1, R2
        JC syn
        LDXL V_ESYN
        LD R1, [X]
        AND R1, R1
        JZ by_state
        RETI                    ; bad line: ignore the rest until its end
t_eol:  JMP t_eol2

; Set the syntax error flag of the line (X page = variables).
syn:    LDXL V_ESYN
        LDI R1, 1
        ST [X], R1
        RETI

by_state:
        LDXL V_ST
        LD R1, [X]              ; R1 = state
        AND R1, R1
        JZ st_start
        LDI R2, 3
        CMP R1, R2
        JZ t_op
        JMP st_num              ; state 1 (A) or 2 (B)
t_op:   JMP t_op2

; State 0, first character: '-' or digit -> number A, letter -> operation.
st_start:
        LDI R1, '-'
        CMP R0, R1
        JZ ss_neg
        LDI R1, '0'
        CMP R0, R1
        JC ss_d1                ; c >= '0'
        JMP ss_letter
ss_d1:  LDI R1, CH_9P1
        CMP R0, R1
        JC ss_letter            ; c > '9'
        LDI R1, 1
        LDXL V_ST
        ST [X], R1              ; state 1
        JMP digit
ss_neg: LDI R1, 1
        LDXL V_ST
        ST [X], R1              ; state 1
        LDXL V_NEG
        ST [X], R1
        RETI
ss_letter:
        LDI R1, UPPER
        AND R0, R1
        LDI R1, 'A'
        CMP R0, R1
        JC ss_l1
        JMP syn
ss_l1:  LDI R1, CH_ZP1
        CMP R0, R1
        JC syn
        LDXL V_C1
        ST [X], R0
        LDI R1, 3
        LDXL V_ST
        ST [X], R1              ; state 3
        RETI

; States 1 and 2 (R1 = state): digit, ',' after A, '-' before the first digit.
st_num: LDI R2, '0'
        CMP R0, R2
        JC sn_d1
        JMP sn_other
sn_d1:  LDI R2, CH_9P1
        CMP R0, R2
        JC sn_other
        JMP digit
sn_other:
        LDI R2, CH_COMMA
        CMP R0, R2
        JZ comma
        LDI R2, '-'
        CMP R0, R2
        JZ minus
        JMP syn

; Digit (R0 = character): NDIG += 1 (4 -> syntax), ACC = ACC * 10 + d.
; With ACC >= 13 any next digit gives more than 128: range error.
digit:  LDI R1, '0'
        SUB R0, R1              ; R0 = digit value
        LDXL V_NDIG
        LD R1, [X]
        LDI R2, 1
        ADD R1, R2
        ST [X], R1
        LDI R2, 4
        CMP R1, R2
        JC syn
        LDXL V_ACC
        LD R1, [X]
        LDI R2, 13
        CMP R1, R2
        JC dg_rng
        MOV R2, R1
        ADD R2, R2              ; 2a
        MOV R3, R2
        ADD R3, R3              ; 4a
        ADD R3, R3              ; 8a
        ADD R3, R2              ; 10a
        ADD R3, R0              ; 10a + d (at most 129)
        ST [X], R3
        RETI
dg_rng: LDXL V_ERNG
        LDI R1, 1
        ST [X], R1
        RETI

; Trampolines (never executed in sequence: they follow a RETI).
t_eol2: JMP eol
t_op2:  JMP st_op
t_syn3: JMP syn

; '-': only before the first digit of a number without a sign.
minus:  LDXL V_NDIG
        LD R1, [X]
        AND R1, R1
        JZ mi1
        JMP syn
mi1:    LDXL V_NEG
        LD R1, [X]
        AND R1, R1
        JZ mi2
        JMP syn
mi2:    LDI R1, 1
        ST [X], R1              ; NEG = 1
        RETI

; ',' (R1 = state): only in state 1 after a digit. Finish A -> V_TA.
comma:  LDI R2, 1
        CMP R1, R2
        JZ co1
        JMP syn
co1:    LDXL V_NDIG
        LD R1, [X]
        AND R1, R1
        JZ t_syn1
        LDXL V_ACC
        LD R0, [X]              ; magnitude
        LDXL V_NEG
        LD R1, [X]
        LDI R2, 128
        ADD R2, R1              ; limit + 1: 128, or 129 with '-'
        CMP R0, R2
        JC co_rng
        AND R1, R1
        JZ co_pos
        LDI R2, 0
        SUB R2, R0
        MOV R0, R2              ; -magnitude
co_pos: LDXL V_TA
        ST [X], R0
        JMP co_next
t_syn1: JMP t_syn3
co_rng: LDXL V_ERNG
        LDI R1, 1
        ST [X], R1
co_next:
        LDI R1, 0
        LDXL V_ACC
        ST [X], R1
        LDXL V_NEG
        ST [X], R1
        LDXL V_NDIG
        ST [X], R1
        LDI R1, 2
        LDXL V_ST
        ST [X], R1              ; state 2
        RETI

; State 3: letters only; the 2nd and 3rd are kept, a 4th is a syntax error.
st_op:  LDI R1, UPPER
        AND R0, R1
        LDI R1, 'A'
        CMP R0, R1
        JC so1
        JMP t_syn3
so1:    LDI R1, CH_ZP1
        CMP R0, R1
        JC t_syn2
        LDXL V_LEN
        LD R1, [X]
        LDI R2, 2
        CMP R1, R2
        JZ so_c2
        LDI R2, 3
        CMP R1, R2
        JZ so_c3
t_syn2: JMP t_syn3
so_c2:  LDXL V_C2
        ST [X], R0
        RETI
so_c3:  LDXL V_C3
        ST [X], R0
        RETI

; ------------------------------------------------------------- end of line
eol:    LDXH V_PAGE
        LDXL V_ESYN
        LD R1, [X]
        AND R1, R1
        JZ eol_ok
        JMP t_r_syntax
eol_ok: LDXL V_LEN
        LD R1, [X]
        AND R1, R1
        JZ t_reset              ; empty line (e.g. LF of CRLF): no reply
        LDXL V_ST
        LD R1, [X]
        LDI R2, 2
        CMP R1, R2
        JZ eol_num
        LDI R2, 3
        CMP R1, R2
        JZ t_eol_op
        JMP t_r_syntax          ; state 1: no ','
t_eol_op:
        JMP eol_op
t_reset:
        JMP s_reset
t_r_syntax:
        JMP s_syntax
t_r_range:
        JMP s_range

; Number line: finish B, then commit A and B (no reply) or ERR RANGE.
eol_num:
        LDXL V_NDIG
        LD R1, [X]
        AND R1, R1
        JZ t_r_syntax           ; nothing after ',' (or only '-')
        LDXL V_ACC
        LD R0, [X]
        LDXL V_NEG
        LD R1, [X]
        LDI R2, 128
        ADD R2, R1
        CMP R0, R2
        JC t_r_range
        AND R1, R1
        JZ en_pos
        LDI R2, 0
        SUB R2, R0
        MOV R0, R2
en_pos: LDXL V_ERNG
        LD R1, [X]
        AND R1, R1
        JZ en_ok
        JMP t_r_range           ; A or a digit was out of range
en_ok:  LDXL V_B
        ST [X], R0
        LDXL V_TA
        LD R1, [X]
        LDXL V_A
        ST [X], R1
        LDI R1, 1
        LDXL V_ABOK
        ST [X], R1
        JMP t_reset

; Operation line: exactly three letters naming an operation, A/B valid.
eol_op: LDXL V_LEN
        LD R1, [X]
        LDI R2, 3
        CMP R1, R2
        JZ eo1
        JMP t_r_syntax
eo1:    LDXL V_C1
        LD R1, [X]
        LDXL V_C2
        LD R2, [X]
        LDXL V_C3
        LD R3, [X]
        LDI R0, 'A'
        CMP R1, R0
        JZ m_a
        LDI R0, 'S'
        CMP R1, R0
        JZ m_s
        LDI R0, 'M'
        CMP R1, R0
        JZ m_m
        LDI R0, 'D'
        CMP R1, R0
        JZ m_d
        JMP t_r_syntax
m_a:    LDI R0, 'D'
        CMP R2, R0
        JZ m_a2
        JMP t_r_syntax
m_a2:   CMP R3, R0
        JZ op_add
        JMP t_r_syntax
m_s:    LDI R0, 'U'
        CMP R2, R0
        JZ m_s2
        JMP t_r_syntax
m_s2:   LDI R0, 'B'
        CMP R3, R0
        JZ op_sub
        JMP t_r_syntax
m_m:    LDI R0, 'U'
        CMP R2, R0
        JZ m_m2
        JMP s_syntax
m_m2:   LDI R0, 'L'
        CMP R3, R0
        JZ op_mul
        JMP s_syntax
m_d:    LDI R0, 'I'
        CMP R2, R0
        JZ m_d2
        JMP s_syntax
m_d2:   LDI R0, 'V'
        CMP R3, R0
        JZ op_div
        JMP s_syntax

; Trampolines to the reply block (after an unconditional jump).
s_reset:
        JMP line_reset
s_syntax:
        JMP r_syntax
s_range:
        JMP r_range

op_add: LDI R3, 1
        JMP op_chk
op_sub: LDI R3, 2
        JMP op_chk
op_mul: LDI R3, 3
        JMP op_chk
op_div: LDI R3, 4
op_chk: LDXL V_OP
        ST [X], R3
        LDXL V_ABOK
        LD R1, [X]
        AND R1, R1
        JZ t_r_noarg
        LDI R1, 3
        CMP R3, R1
        JC t_absv               ; MUL, DIV
        LDI R1, 2
        CMP R3, R1
        JZ do_sub
; ADD, SUB: A in R1:R0 and B in R3:R2, sign-extended to 16 bits. The
; operation is tested first: loading the operands takes all four registers.
do_add: LDXL V_A
        LD R0, [X]
        LDI R1, 0
        LDI R2, 0x80
        AND R2, R0
        JZ ad1
        LDI R1, 0xFF
ad1:    LDXL V_B
        LD R2, [X]
        LDI R3, 0x80
        AND R3, R2              ; 0 if B >= 0
        JZ ad2
        LDI R3, 0xFF
ad2:    ADD R0, R2
        ADC R1, R3
        JMP res16
t_absv: JMP s_absv
t_r_noarg:
        JMP r_noarg
do_sub: LDXL V_A
        LD R0, [X]
        LDI R1, 0
        LDI R2, 0x80
        AND R2, R0
        JZ sb1
        LDI R1, 0xFF
sb1:    LDXL V_B
        LD R2, [X]
        LDI R3, 0x80
        AND R3, R2
        JZ sb2
        LDI R3, 0xFF
sb2:    SUB R0, R2
        SBC R1, R3

; Signed 16-bit result R1:R0 -> sign and magnitude in V_PSGN/V_PLO/V_PHI.
res16:  LDI R2, 0
        LDI R3, 0x80
        AND R3, R1
        JZ rs_pos
        LDI R2, 0
        SUB R2, R0
        MOV R0, R2              ; low byte negated
        LDI R3, 0
        SBC R3, R1
        MOV R1, R3              ; high byte negated with the borrow
        LDI R2, 1
rs_pos: LDXL V_PSGN
        ST [X], R2
        LDXL V_PLO
        ST [X], R0
        LDXL V_PHI
        ST [X], R1
        JMP s_prefix1

; ------------------------------------------- end of line: CR LF and reset
crlf:   LDXH U_PAGE
        LDXL U_TX
        LDI R0, CR
        ST [X], R0
        LDI R0, LF
        ST [X], R0
line_reset:
        LDXH V_PAGE
        LDI R0, 0
        LDXL V_ST
        ST [X], R0              ; V_ST .. V_ERNG (0x00 - 0x06)
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        RETI

; ------------------------------------------------------------ error replies
r_syntax:
        LDI R3, 1
        JMP err_pre
r_range:
        LDI R3, 2
        JMP err_pre
r_noarg:
        LDI R3, 3
        JMP err_pre
r_div0: LDI R3, 4
; "ERR " then the name for R3 (1 SYNTAX, 2 RANGE, 3 NOARG, 4 DIV0).
err_pre:
        LDXH U_PAGE
er_w:   LDXL U_ST
        LD R0, [X]
        LDI R1, ST_TXE
        AND R0, R1
        JZ er_w
        LDXL U_TX
        LDI R0, 'E'
        ST [X], R0
        LDI R0, 'R'
        ST [X], R0
        ST [X], R0
        LDI R0, ' '
        ST [X], R0
        LDI R1, 1
        CMP R3, R1
        JZ e_syn
        LDI R1, 2
        CMP R3, R1
        JZ e_rng
        LDI R1, 3
        CMP R3, R1
        JZ e_noarg
        LDI R0, 'D'
        ST [X], R0
        LDI R0, 'I'
        ST [X], R0
        LDI R0, 'V'
        ST [X], R0
        LDI R0, '0'
        ST [X], R0
        JMP crlf

; Trampolines (after an unconditional jump).
s_prefix1:
        JMP s_prefix2
s_absv: JMP absvals
s_div0: JMP r_div0

e_syn:  LDI R0, 'S'
        ST [X], R0
        LDI R0, 'Y'
        ST [X], R0
        LDI R0, 'N'
        ST [X], R0
        LDI R0, 'T'
        ST [X], R0
        LDI R0, 'A'
        ST [X], R0
        LDI R0, 'X'
        ST [X], R0
        JMP crlf
e_rng:  LDI R0, 'R'
        ST [X], R0
        LDI R0, 'A'
        ST [X], R0
        LDI R0, 'N'
        ST [X], R0
        LDI R0, 'G'
        ST [X], R0
        LDI R0, 'E'
        ST [X], R0
        JMP crlf
e_noarg:
        LDI R0, 'N'
        ST [X], R0
        LDI R0, 'O'
        ST [X], R0
        LDI R0, 'A'
        ST [X], R0
        LDI R0, 'R'
        ST [X], R0
        LDI R0, 'G'
        ST [X], R0
        JMP crlf

; ------------------------------------------------------------ MUL and DIV
; |A|, |B| and their signs, then MUL (falls through) or DIV.
absvals:
        LDXL V_A
        LD R0, [X]
        LDI R1, 0
        LDI R2, 0x80
        AND R2, R0
        JZ ab1
        LDI R2, 0
        SUB R2, R0
        MOV R0, R2              ; -128 -> 128 (unsigned)
        LDI R1, 1
ab1:    LDXL V_MA
        ST [X], R0
        LDXL V_SA
        ST [X], R1
        LDXL V_B
        LD R0, [X]
        LDI R1, 0
        LDI R2, 0x80
        AND R2, R0
        JZ ab2
        LDI R2, 0
        SUB R2, R0
        MOV R0, R2
        LDI R1, 1
ab2:    LDXL V_MB
        ST [X], R0
        LDXL V_SB
        ST [X], R1
        LDXL V_OP
        LD R1, [X]
        LDI R2, 4
        CMP R1, R2
        JZ do_div

; MUL: R1:R0 = |A| added |B| times (product at most 16384).
do_mul: LDXL V_MB
        LD R2, [X]              ; count
        LDI R0, 0
        LDI R1, 0
        LDXL V_MA
        AND R2, R2
        JZ mu_done
mu_l:   LD R3, [X]              ; |A|
        ADD R0, R3
        JC mu_c
mu_n:   LDI R3, 1
        SUB R2, R3
        JZ mu_done
        JMP mu_l
mu_c:   LDI R3, 1
        ADD R1, R3
        JMP mu_n
mu_done:
        LDXL V_PLO
        ST [X], R0
        LDXL V_PHI
        ST [X], R1
        LDXL V_SA
        LD R0, [X]
        LDXL V_SB
        LD R1, [X]
        ADD R0, R1
        LDI R1, 1
        AND R0, R1              ; sign = sA xor sB
        LDXL V_PSGN
        ST [X], R0
        JMP prefix
s_prefix2:
        JMP prefix

; DIV: |A| / |B| by repeated subtraction. B = 0 -> ERR DIV0.
do_div: LDXL V_MB
        LD R1, [X]              ; |B|
        AND R1, R1
        JZ s_div0
        LDXL V_MA
        LD R0, [X]              ; remainder
        LDI R2, 0               ; quotient
        LDI R3, 1
dv_l:   CMP R0, R1
        JC dv_s                 ; remainder >= |B|
        JMP dv_done
dv_s:   SUB R0, R1
        ADD R2, R3
        JMP dv_l
dv_done:
        LDXL V_RMAG
        ST [X], R0
        LDXL V_SA
        LD R0, [X]
        LDXL V_RSGN
        ST [X], R0              ; remainder sign = sign of A
        LDXL V_PLO
        ST [X], R2
        LDI R1, 0
        LDXL V_PHI
        ST [X], R1
        LDXL V_SB
        LD R1, [X]
        ADD R0, R1
        LDI R1, 1
        AND R0, R1              ; quotient sign = sA xor sB
        LDXL V_PSGN
        ST [X], R0

; ------------------------------------------------------------- reply text
; Wait for an empty TX FIFO, write the operation name, then the number.
prefix: LDXL V_OP
        LD R3, [X]              ; R3 = operation
        LDXH U_PAGE
px_w:   LDXL U_ST
        LD R0, [X]
        LDI R1, ST_TXE
        AND R0, R1
        JZ px_w
        LDXL U_TX
        LDI R1, 1
        CMP R3, R1
        JZ px_add
        LDI R1, 2
        CMP R3, R1
        JZ px_sub
        LDI R1, 3
        CMP R3, R1
        JZ px_mul
        LDI R0, 'D'
        ST [X], R0
        LDI R0, 'I'
        ST [X], R0
        LDI R0, 'V'
        ST [X], R0
        LDI R0, ' '
        ST [X], R0
        LDI R0, 'Q'
        ST [X], R0
        LDI R0, CH_COLON
        ST [X], R0
        LDI R0, 1               ; the remainder follows the quotient
        JMP px_end
px_add: LDI R0, 'A'
        ST [X], R0
        LDI R0, 'D'
        ST [X], R0
        ST [X], R0
        JMP px_colon
px_sub: LDI R0, 'S'
        ST [X], R0
        LDI R0, 'U'
        ST [X], R0
        LDI R0, 'B'
        ST [X], R0
        JMP px_colon
px_mul: LDI R0, 'M'
        ST [X], R0
        LDI R0, 'U'
        ST [X], R0
        LDI R0, 'L'
        ST [X], R0
px_colon:
        LDI R0, CH_COLON
        ST [X], R0
        LDI R0, 0
px_end: LDXH V_PAGE
        LDXL V_PHASE
        ST [X], R0

; Print V_PSGN/V_PLO/V_PHI in decimal ('-' only for a non-zero magnitude,
; no leading zeros). R1:R0 = magnitude, X = TX_DATA.
print:  LDXH V_PAGE
        LDXL V_PLO
        LD R0, [X]
        LDXL V_PHI
        LD R1, [X]
        LDXL V_PSGN
        LD R2, [X]
        LDXH U_PAGE
        LDXL U_TX
        AND R2, R2
        JZ pr_mag
        AND R0, R0
        JZ pr_z
        JMP pr_minus
pr_z:   AND R1, R1
        JZ pr_mag
pr_minus:
        LDI R3, '-'
        ST [X], R3
; First digit: the largest power of ten not above the magnitude.
pr_mag: MOV R2, R0
        LDI R3, 0x10
        SUB R2, R3
        MOV R2, R1
        LDI R3, 0x27
        SBC R2, R3
        JC d10000               ; >= 10000
        MOV R2, R0
        LDI R3, 0xE8
        SUB R2, R3
        MOV R2, R1
        LDI R3, 0x03
        SBC R2, R3
        JC d1000                ; >= 1000
        MOV R2, R0
        LDI R3, 100
        SUB R2, R3
        MOV R2, R1
        LDI R3, 0
        SBC R2, R3
        JC t_d100               ; >= 100
        MOV R2, R0
        LDI R3, 10
        SUB R2, R3
        MOV R2, R1
        LDI R3, 0
        SBC R2, R3
        JC t_d10                ; >= 10
        JMP t_d1
t_d100: JMP d100
t_d10:  JMP d10
t_d1:   JMP d1

; Digit for one power p: R2 = number of times p fits; subtract, restore the
; last failed subtraction, write '0' + R2.
d10000: LDI R2, 0
d4_l:   LDI R3, 0x10
        SUB R0, R3
        LDI R3, 0x27
        SBC R1, R3
        JC d4_c
        LDI R3, 0x10
        ADD R0, R3
        LDI R3, 0x27
        ADC R1, R3
        LDI R3, '0'
        ADD R3, R2
        ST [X], R3
        JMP d1000
d4_c:   LDI R3, 1
        ADD R2, R3
        JMP d4_l
d1000:  LDI R2, 0
d3_l:   LDI R3, 0xE8
        SUB R0, R3
        LDI R3, 0x03
        SBC R1, R3
        JC d3_c
        LDI R3, 0xE8
        ADD R0, R3
        LDI R3, 0x03
        ADC R1, R3
        LDI R3, '0'
        ADD R3, R2
        ST [X], R3
        JMP d100
d3_c:   LDI R3, 1
        ADD R2, R3
        JMP d3_l
t_print2:
        JMP print               ; trampoline (after an unconditional jump)
d100:   LDI R2, 0
d2_l:   LDI R3, 100
        SUB R0, R3
        LDI R3, 0
        SBC R1, R3
        JC d2_c
        LDI R3, 100
        ADD R0, R3
        LDI R3, 0
        ADC R1, R3
        LDI R3, '0'
        ADD R3, R2
        ST [X], R3
        JMP d10
d2_c:   LDI R3, 1
        ADD R2, R3
        JMP d2_l
d10:    LDI R2, 0
d1_l:   LDI R3, 10
        SUB R0, R3
        LDI R3, 0
        SBC R1, R3
        JC d1_c
        LDI R3, 10
        ADD R0, R3
        LDI R3, 0
        ADC R1, R3
        LDI R3, '0'
        ADD R3, R2
        ST [X], R3
        JMP d1
d1_c:   LDI R3, 1
        ADD R2, R3
        JMP d1_l
d1:     LDI R3, '0'
        ADD R3, R0
        ST [X], R3
        ; Continue: remainder of DIV, or end of line.
        LDXH V_PAGE
        LDXL V_PHASE
        LD R0, [X]
        AND R0, R0
        JZ crlf2
        LDI R0, 0
        ST [X], R0              ; PHASE = 0
        LDXL V_RSGN
        LD R0, [X]
        LDXL V_PSGN
        ST [X], R0
        LDXL V_RMAG
        LD R0, [X]
        LDXL V_PLO
        ST [X], R0
        LDI R0, 0
        LDXL V_PHI
        ST [X], R0
        LDXH U_PAGE
rm_w:   LDXL U_ST
        LD R0, [X]
        LDI R1, ST_TXE
        AND R0, R1
        JZ rm_w                 ; room for " R:" and the remainder
        LDXL U_TX
        LDI R0, ' '
        ST [X], R0
        LDI R0, 'R'
        ST [X], R0
        LDI R0, CH_COLON
        ST [X], R0
        JMP t_print2

; CR LF and line reset for the printer (a copy of crlf/line_reset, which are
; out of rel8 reach from here).
crlf2:  LDXH U_PAGE
        LDXL U_TX
        LDI R0, CR
        ST [X], R0
        LDI R0, LF
        ST [X], R0
        LDXH V_PAGE
        LDI R0, 0
        LDXL V_ST
        ST [X], R0              ; V_ST .. V_ERNG (0x00 - 0x06)
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        INX
        ST [X], R0
        RETI
