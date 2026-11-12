/*
 * Host test of the STM32 receiver. The real src/main.c and src/uart_fpga.c
 * run on the PC with fake registers, LCD and I2C (host_mocks.c). Bytes go in
 * through the real USART6 interrupt handler; main() takes them out of the
 * ring buffer as on the board. Each case runs main() in its own process and
 * compares the printed lines that start with '#', "LCD_" or "@LCD" (the LCD
 * rows at the end) with the expected lines.
 *
 * main.c is built with -Dmain=stm32_main -Duart_fpga_get=host_uart_get:
 * host_uart_get() returns the next ring entry; when the ring is empty it feeds
 * the next step of the case, and after the last step it ends main().
 * Build and run: bash host_test/run_host_test.sh
 */
#define _DEFAULT_SOURCE
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include "stm32f4xx.h"
#include "uart_fpga.h"
#include "host_mocks.h"

int  stm32_main(void);
void USART6_IRQHandler(void);
int  host_uart_get(uint16_t *entry);

/* In a step, MARK_PE / MARK_FE before a byte give that byte a parity /
   framing error. */
#define MARK_PE '\x01'
#define MARK_FE '\x02'

#define MAX_STEPS   8
#define EXPECT_SIZE 8192

typedef struct {
    const char *bytes;
    int write_fail;          /* LCD writes that fail while this step is read */
} step_t;

static step_t  steps[MAX_STEPS];
static int     nsteps, next_step;
static char    expected[EXPECT_SIZE];
static jmp_buf done_jmp;

static void step(const char *bytes, int write_fail)
{
    if (nsteps >= MAX_STEPS) {
        fprintf(stderr, "too many steps\n");
        exit(2);
    }
    steps[nsteps].bytes = bytes;
    steps[nsteps].write_fail = write_fail;
    nsteps++;
}

static void expect(const char *fmt, ...)
{
    size_t n = strlen(expected);
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(expected + n, sizeof expected - n, fmt, ap);
    va_end(ap);
    strncat(expected, "\n", sizeof expected - strlen(expected) - 1U);
}

/* Each byte of the step through the USART6 interrupt, as the hardware would
   give it: SR with RXNE (and an error flag when marked), then DR. */
static void feed(const step_t *s)
{
    mock_write_fail = s->write_fail;
    for (const char *p = s->bytes; *p; p++) {
        uint32_t flags = 0U;
        if (*p == MARK_PE || *p == MARK_FE) {
            flags = (*p == MARK_PE) ? USART_SR_PE : USART_SR_FE;
            p++;
            if (!*p) {
                break;
            }
        }
        host_usart6.SR = USART_SR_RXNE | flags;
        host_usart6.DR = (uint8_t)*p;
        USART6_IRQHandler();
    }
}

int host_uart_get(uint16_t *entry)
{
    if (uart_fpga_get(entry)) {
        return 1;
    }
    if (next_step < nsteps) {
        feed(&steps[next_step++]);
        return 0;
    }
    longjmp(done_jmp, 1);
}

/* ---- cases -------------------------------------------------------------- */
static char big[1024];

static void repeat(const char *text, int n)
{
    big[0] = '\0';
    for (int i = 0; i < n; i++) {
        strncat(big, text, sizeof big - strlen(big) - 1U);
    }
}

static void c_valid(void)
{
    step("ADD:30\r\n", 0);
    step("DIV Q:-10 R:-10\r\n", 0);
    expect("#1 FPGA> ADD:30");
    expect("#2 FPGA> DIV Q:-10 R:-10");
    expect("@LCD row0=\"DIV Q:-10 R:-10\" row1=\"\" writes=6");
}

static void c_empty_lines(void)
{
    step("\r\n", 0);
    step("\n", 0);
    step("ADD:3\r\n", 0);
    expect("#1 FPGA> ADD:3");
    expect("@LCD row0=\"ADD:3\" row1=\"\" writes=4");
}

static void c_len16_17(void)
{
    step("0123456789ABCDEF\r\n", 0);
    step("0123456789ABCDEFG\r\n", 0);
    expect("#1 FPGA> 0123456789ABCDEF");
    expect("#2 RX LONG (first 16: \"0123456789ABCDEF\")");
    expect("@LCD row0=\"RX LONG\" row1=\"\" writes=6");
}

static void c_lf_only(void)
{
    step("ADD:30\n", 0);
    step("SUB:1\r\n", 0);
    expect("#1 RX ERR (got \"ADD:30\") eol pe=0 fe=0 nf=0 ore=0 drop=0");
    expect("#2 FPGA> SUB:1");
    expect("@LCD row0=\"SUB:1\" row1=\"\" writes=6");
}

static void c_cr_only(void)
{
    step("ADD:30\rSUB:1\r\n", 0);
    expect("#1 RX ERR (got \"ADD:30\") eol pe=0 fe=0 nf=0 ore=0 drop=0");
    expect("#2 FPGA> SUB:1");
    expect("@LCD row0=\"SUB:1\" row1=\"\" writes=6");
}

static void c_uart_error(void)
{
    static const char pe_line[] = { 'A', 'D', MARK_PE, 'D', ':', '3', '0', '\r', '\n', 0 };
    static const char fe_line[] = { 'S', 'U', 'B', ':', '1', MARK_FE, '\r', '\n', 0 };
    step(pe_line, 0);
    step(fe_line, 0);
    step("MUL:2\r\n", 0);
    expect("#1 RX ERR (got \"ADD:30\") pe=1 fe=0 nf=0 ore=0 drop=0");
    expect("#2 RX ERR (got \"SUB:1\") pe=1 fe=1 nf=0 ore=0 drop=0");
    expect("#3 FPGA> MUL:2");
    expect("@LCD row0=\"MUL:2\" row1=\"\" writes=8");
}

/* 40 lines at once: 254 bytes fit (31 lines + "ADD:30"), the 255th (the CR)
   becomes the LOST mark, the other 65 are only counted (drop = 66). */
static void c_overflow(void)
{
    repeat("ADD:30\r\n", 40);
    step(big, 0);
    step("SUB:1\r\n", 0);
    step("MUL:2\r\n", 0);
    for (int i = 1; i <= 31; i++) {
        expect("#%d FPGA> ADD:30", i);
    }
    expect("#32 RX ERR (got \"ADD:30SUB:1\") lost pe=0 fe=0 nf=0 ore=0 drop=66");
    expect("#33 FPGA> MUL:2");
    expect("@LCD row0=\"MUL:2\" row1=\"\" writes=68");
}

/* VR-014 I6 stimulus: 83 x "X" CR LF, LF, "ADD:30" at once; the '3' becomes
   the LOST mark and the '0' is dropped; then CR LF. */
static void c_overflow_vr014(void)
{
    repeat("X\r\n", 83);
    strncat(big, "\nADD:30", sizeof big - strlen(big) - 1U);
    step(big, 0);
    step("\r\n", 0);
    step("SUB:1\r\n", 0);
    for (int i = 1; i <= 83; i++) {
        expect("#%d FPGA> X", i);
    }
    expect("#84 RX ERR (got \"ADD:\") lost pe=0 fe=0 nf=0 ore=0 drop=2");
    expect("#85 FPGA> SUB:1");
    expect("@LCD row0=\"SUB:1\" row1=\"\" writes=172");
}

/* The LOST mark falls between a CR and its LF: that line has no LF (eol),
   and the next line may have lost bytes, so both are errors. */
static void c_overflow_at_crlf(void)
{
    repeat("X\r\n", 84);
    strncat(big, "Y\r\n", sizeof big - strlen(big) - 1U);
    step(big, 0);
    step("SUB:1\r\n", 0);
    step("MUL:2\r\n", 0);
    for (int i = 1; i <= 84; i++) {
        expect("#%d FPGA> X", i);
    }
    expect("#85 RX ERR (got \"Y\") eol lost pe=0 fe=0 nf=0 ore=0 drop=1");
    expect("#86 RX ERR (got \"SUB:1\") lost pe=0 fe=0 nf=0 ore=0 drop=1");
    expect("#87 FPGA> MUL:2");
    expect("@LCD row0=\"MUL:2\" row1=\"\" writes=176");
}

static void c_lcd_missing(void)
{
    mock_lcd_addr = 0;
    step("ADD:30\r\n", 0);
    expect("LCD_NOT_FOUND: no PCF8574 address answered (check SDA/SCL/VCC/GND)");
    expect("#1 LCD_FAIL FPGA> ADD:30");
    expect("@LCD row0=\"\" row1=\"\" writes=0");
}

static void c_lcd_write_fail(void)
{
    step("ADD:30\r\n", 2);       /* the write and its retry fail */
    step("SUB:1\r\n", 0);        /* the next line recovers the LCD */
    expect("LCD_WRITE_FAIL first_err=-2 retry_err=-2 sda_before=1");
    expect("#1 LCD_FAIL FPGA> ADD:30");
    expect("LCD_RECOVERED first_err=-3 sda_before=1");
    expect("#2 FPGA> SUB:1");
    expect("@LCD row0=\"SUB:1\" row1=\"\" writes=4");
}

static const struct { const char *name; void (*setup)(void); } cases[] = {
    { "valid", c_valid },
    { "empty_lines", c_empty_lines },
    { "len16_17", c_len16_17 },
    { "lf_only", c_lf_only },
    { "cr_only", c_cr_only },
    { "uart_error", c_uart_error },
    { "overflow", c_overflow },
    { "overflow_vr014", c_overflow_vr014 },
    { "overflow_at_crlf", c_overflow_at_crlf },
    { "lcd_missing", c_lcd_missing },
    { "lcd_write_fail", c_lcd_write_fail },
};

/* Keep the lines that start with '#', "LCD_" or "@LCD"; drop CR. */
static void filter(const char *in, char *out, size_t size)
{
    out[0] = '\0';
    while (*in) {
        const char *end = strchr(in, '\n');
        size_t n = end ? (size_t)(end - in) : strlen(in);
        if (n > 0U && in[n - 1U] == '\r') {
            n--;
        }
        if (in[0] == '#' || strncmp(in, "LCD_", 4) == 0 || strncmp(in, "@LCD", 4) == 0) {
            strncat(out, in, n < size - strlen(out) - 2U ? n : size - strlen(out) - 2U);
            strncat(out, "\n", size - strlen(out) - 1U);
        }
        in = end ? end + 1 : in + strlen(in);
    }
}

/* main() until host_uart_get() ends it (kept apart so no local variable of
   run_case lives across setjmp) */
static void run_main(void)
{
    if (setjmp(done_jmp) == 0) {
        stm32_main();
    }
}

static int run_case(int k)
{
    static char raw[65536], got[EXPECT_SIZE];
    int fd[2];

    nsteps = next_step = 0;
    expected[0] = '\0';
    mock_lcd_addr = 0x27;
    cases[k].setup();

    if (pipe(fd) != 0) {
        perror("pipe");
        return 0;
    }
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        close(fd[0]);
        dup2(fd[1], 1);
        run_main();
        mock_print_lcd();
        fflush(stdout);
        _exit(0);
    }
    close(fd[1]);
    size_t n = 0;
    ssize_t r;
    while (n < sizeof raw - 1U && (r = read(fd[0], raw + n, sizeof raw - 1U - n)) > 0) {
        n += (size_t)r;
    }
    raw[n] = '\0';
    close(fd[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    filter(raw, got, sizeof got);

    int ok = WIFEXITED(status) && WEXITSTATUS(status) == 0 && strcmp(got, expected) == 0;
    int lines = 0;
    for (const char *p = got; *p; p++) {
        lines += (*p == '\n');
    }
    printf("HOST_CASE %s %s lines=%d\n", cases[k].name, ok ? "ok" : "WRONG", lines);
    if (!ok) {
        printf("--- expected\n%s--- got (exit status %d)\n%s---\n", expected, status, got);
    }
    return ok;
}

int main(void)
{
    int n = (int)(sizeof cases / sizeof cases[0]), good = 0;
    for (int k = 0; k < n; k++) {
        good += run_case(k);
    }
    printf("%s cases=%d wrong=%d\n", good == n ? "STM32_HOST_PASS" : "STM32_HOST_FAIL", n, n - good);
    return good == n ? 0 : 1;
}
