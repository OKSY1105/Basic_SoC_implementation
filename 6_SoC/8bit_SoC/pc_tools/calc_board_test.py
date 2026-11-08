#!/usr/bin/env python3
"""Board test of the 8bit SoC calculator over UART (PC side).

Sends the calculator protocol cases (02_design/calculator.md section 5, the
same cases as tb/board/tb_soc8_zybo_top.sv) to the Zybo Z7-20 through a
3.3 V USB-UART adapter on Pmod JC at 115200 bps 8E1, and compares every
reply line with a reference model of the protocol written here.

Wiring (Pmod JC, reference manual table 16.1 and fpga/constraints XDC):
  adapter TX -> JC pin 2 (W15, FPGA RX)   adapter RX -> JC pin 1 (V15, FPGA TX)
  adapter GND -> JC pin 5 (GND)           use a 3.3 V adapter only

Usage (Ubuntu on WSL2; attach the adapter first with scripts/wsl_usb.sh):
  python3 calc_board_test.py --list-ports
  python3 calc_board_test.py --port /dev/ttyUSB0         fixed cases (asks for BTN0 resets)
  python3 calc_board_test.py --port /dev/ttyUSB0 --random 300 --seed 1 --log result.txt
  python3 calc_board_test.py --selftest                  no hardware: fake devices
Options: --no-prompt (skip the BTN0 steps and the reset-dependent cases),
         --no-parity-case, --timeout SEC (reply timeout, default 1.0).
Pace (calculator.md section 2): after an operation line the tool waits for
its reply before sending the next line; number lines have no reply.
Exit status 0 only if every check passes (CALC_BOARD_PASS).
"""
import argparse
import random
import re
import sys
import time

BAUD = 115200
OPS = ("ADD", "SUB", "MUL", "DIV")
NUM_RE = re.compile(r"^(-?\d{1,3}),(-?\d{1,3})$")
MAX_LINE = 15

# Fixed cases: (line, expected reply or None for no reply). The expected
# strings are copied from 02_design/calculator.md section 5 and the board TB;
# the reference model below must reproduce every one of them.
FIXED_AFTER_RESET_1 = [("ADD", "ERR NOARG")]
FIXED = [
    ("10,20", None), ("ADD", "ADD:30"), ("sub", "SUB:-10"), ("Mul", "MUL:200"),
    ("DIV", "DIV Q:0 R:10"),
    ("20,10", None), ("DIV", "DIV Q:2 R:0"),
    ("-128,-128", None), ("MUL", "MUL:16384"),
    ("-128,-1", None), ("DIV", "DIV Q:128 R:0"),
    ("-7,2", None), ("DIV", "DIV Q:-3 R:-1"),
    ("-120,11", None), ("DIV", "DIV Q:-10 R:-10"),
    ("10,0", None), ("DIV", "ERR DIV0"),
    ("200,1", "ERR RANGE"), ("ADD", "ADD:10"),
    ("10 ,20", "ERR SYNTAX"), ("1020", "ERR SYNTAX"), ("ADDX", "ERR SYNTAX"),
    ("1234567890123456", "ERR SYNTAX"),
]
FIXED_AFTER_RESET_2 = [("ADD", "ERR NOARG"), ("7,-2", None), ("DIV", "DIV Q:-3 R:1")]
# Parity case: the text goes out with odd parity (receive errors), the CRLF
# with even parity; reply ERR SYNTAX and A/B kept, then the next line is normal.
PARITY_CASE = ("ADD", "ERR SYNTAX")
PARITY_NEXT = ("SUB", "SUB:9")          # A/B = 7, -2 after FIXED_AFTER_RESET_2


class CalcModel:
    """Reference model of the calculator protocol (calculator.md sections 2-4)."""

    def __init__(self):
        self.a = None
        self.b = None

    def reset(self):
        self.a = None
        self.b = None

    def line(self, s, rx_error=False):
        """Reply string for one received line (CR/LF removed), or None."""
        if s == "" and not rx_error:
            return None
        if rx_error or len(s) > MAX_LINE:
            return "ERR SYNTAX"
        m = NUM_RE.match(s)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if not (-128 <= a <= 127 and -128 <= b <= 127):
                return "ERR RANGE"
            self.a, self.b = a, b
            return None
        op = s.upper()
        if op not in OPS:
            return "ERR SYNTAX"
        if self.a is None:
            return "ERR NOARG"
        a, b = self.a, self.b
        if op == "ADD":
            return "ADD:%d" % (a + b)
        if op == "SUB":
            return "SUB:%d" % (a - b)
        if op == "MUL":
            return "MUL:%d" % (a * b)
        if b == 0:
            return "ERR DIV0"
        q = abs(a) // abs(b)
        if (a < 0) != (b < 0):
            q = -q
        return "DIV Q:%d R:%d" % (q, a - b * q)   # quotient toward 0, remainder sign of A


def check_model_against_table():
    """The model must give exactly the reply strings of the fixed table."""
    model = CalcModel()
    seq = ([("reset", None)] + FIXED_AFTER_RESET_1 + FIXED + [("reset", None)] + FIXED_AFTER_RESET_2)
    bad = []
    for line, exp in seq:
        if line == "reset":
            model.reset()
            continue
        got = model.line(line)
        if got != exp:
            bad.append((line, got, exp))
    got = model.line(PARITY_CASE[0], rx_error=True)
    if got != PARITY_CASE[1]:
        bad.append((PARITY_CASE[0] + " (parity)", got, PARITY_CASE[1]))
    got = model.line(PARITY_NEXT[0])
    if got != PARITY_NEXT[1]:
        bad.append(PARITY_NEXT + (got,))
    return bad


def random_lines(rng, count):
    """Random request lines: valid numbers, operations, and error forms."""
    lines = []
    for _ in range(count):
        k = rng.random()
        if k < 0.30:
            b = 0 if rng.random() < 0.1 else rng.randint(-128, 127)
            lines.append("%d,%d" % (rng.randint(-128, 127), b))
        elif k < 0.85:
            op = rng.choice(OPS)
            lines.append("".join(c.lower() if rng.random() < 0.3 else c for c in op))
        elif k < 0.92:
            big = rng.choice([rng.randint(128, 999), rng.randint(-999, -129)])
            pair = [big, rng.randint(-128, 127)]
            rng.shuffle(pair)
            lines.append("%d,%d" % tuple(pair))
        else:
            lines.append(rng.choice(["1,2,3", "12", "ADD ", " SUB", "MULX", "1,-", "-,1", "1,+2", "DIV0"]))
    return lines


class Report:
    def __init__(self, log_path=None):
        self.failures = 0
        self.log = open(log_path, "w", encoding="ascii", errors="replace") if log_path else None

    def out(self, text):
        print(text)
        sys.stdout.flush()
        if self.log:
            self.log.write(text + "\n")
            self.log.flush()

    def fail(self, text):
        self.failures += 1
        self.out("  FAIL " + text)

    def close(self):
        if self.log:
            self.log.close()


class Tester:
    def __init__(self, port, report, timeout, prompt_reset, even, odd):
        self.port = port
        self.report = report
        self.timeout = timeout
        self.prompt_reset = prompt_reset
        self.even = even
        self.odd = odd
        self.model = CalcModel()
        self.lines = 0
        self.replies = 0
        self.latency = []

    def read_reply(self):
        deadline = time.monotonic() + self.timeout
        buf = bytearray()
        while time.monotonic() < deadline:
            b = self.port.read(1)
            if not b:
                continue
            buf += b
            if buf.endswith(b"\r\n"):
                return bytes(buf[:-2]).decode("ascii", "replace"), True
        return bytes(buf).decode("ascii", "replace"), False

    def send(self, line, parity_error=False):
        exp = self.model.line(line, rx_error=parity_error)
        if parity_error:
            self.port.flush()
            self.port.parity = self.odd
            self.port.write(line.encode("ascii"))
            self.port.flush()
            self.port.parity = self.even
            self.port.write(b"\r\n")
        else:
            self.port.write(line.encode("ascii") + b"\r\n")
        t0 = time.monotonic()
        self.lines += 1
        shown = repr(line) + (" (odd parity)" if parity_error else "")
        if exp is None:
            self.report.out("  ok   %s" % shown)
            return
        got, complete = self.read_reply()
        self.replies += 1
        self.latency.append(time.monotonic() - t0)
        if not complete:
            self.report.fail("%s -> no complete reply within %.1f s (got %r), expected %r"
                             % (shown, self.timeout, got, exp))
        elif got != exp:
            self.report.fail("%s -> %r, expected %r" % (shown, got, exp))
        else:
            self.report.out("  ok   %s -> %r" % (shown, got))

    def reset_board(self, why):
        self.prompt_reset(why)
        self.model.reset()
        time.sleep(0.2)
        self.port.reset_input_buffer()

    def check_quiet(self, where):
        time.sleep(0.3)
        n = self.port.in_waiting
        if n:
            extra = self.port.read(n)
            self.report.fail("%d unexpected byte(s) %s: %r" % (n, where, extra))

    def run(self, use_reset, parity_case, random_count, seed):
        self.port.reset_input_buffer()
        if use_reset:
            self.reset_board("start: A/B cleared")
            self.report.out("[fixed cases after reset]")
            for line, _ in FIXED_AFTER_RESET_1:
                self.send(line)
        else:
            self.report.out("[fixed cases, no reset step]")
        for line, _ in FIXED:
            self.send(line)
        self.check_quiet("after the fixed cases")
        if use_reset:
            self.reset_board("middle: BTN0 reset, A/B cleared again")
            self.report.out("[after the BTN0 reset]")
            for line, _ in FIXED_AFTER_RESET_2:
                self.send(line)
        if parity_case:
            if self.model.a is None:
                self.send("7,-2")
            self.report.out("[parity error line, then a normal line]")
            self.send(PARITY_CASE[0], parity_error=True)
            self.send(PARITY_NEXT[0])
        if random_count:
            rng = random.Random(seed)
            self.report.out("[random lines: %d, seed %d]" % (random_count, seed))
            for line in random_lines(rng, random_count):
                self.send(line)
        self.check_quiet("at the end")


class FakePort:
    """No-hardware stand-in for serial.Serial: a calculator device model with
    optional injected faults, used by --selftest to check the checker."""

    def __init__(self, fault=None):
        self.fault = fault
        self.parity = "E"
        self.rx = bytearray()       # bytes from the PC not yet ended by a line end
        self.rx_err = False
        self.tx = bytearray()       # bytes waiting for the PC to read
        self.a = None
        self.b = None
        self.timeout = 0.01

    def reset_board(self):
        self.a = self.b = None
        self.rx = bytearray()
        self.rx_err = False

    def reset_input_buffer(self):
        self.tx = bytearray()

    def flush(self):
        pass

    @property
    def in_waiting(self):
        return len(self.tx)

    def write(self, data):
        for c in data:
            if c in (0x0D, 0x0A):
                line, err = self.rx.decode("ascii", "replace"), self.rx_err
                self.rx = bytearray()
                self.rx_err = False
                reply = self.reply(line, err)
                if reply is not None:
                    end = b"\n" if self.fault == "lf_only" else b"\r\n"
                    self.tx += reply.encode("ascii") + end
            else:
                if self.parity != "E":
                    self.rx_err = True
                self.rx.append(c)
                if self.fault == "echo":
                    self.tx.append(c)

    def reply(self, line, err):
        if self.fault == "parity_ignored":
            err = False
        if self.fault == "silent":
            return None
        if line == "" and not err:
            return None
        if err or len(line) > MAX_LINE:
            return "ERR SYNTAX"
        if "," in line and self.fault != "comma_space_ok":
            parts = line.split(",")
        elif "," in line:
            parts = line.replace(" ", "").split(",")
        else:
            parts = None
        if parts is not None and len(parts) == 2 and all(re.fullmatch(r"-?\d{1,3}", p) for p in parts):
            a, b = int(parts[0]), int(parts[1])
            if self.fault == "range_overwrites" and not (-128 <= a <= 127 and -128 <= b <= 127):
                self.a, self.b = a, b
                return "ERR RANGE"
            if not (-128 <= a <= 127 and -128 <= b <= 127):
                return "ERR RANGE"
            self.a, self.b = a, b
            return None
        op = line.upper()
        if op not in OPS:
            return "ERR SYNTAX"
        if self.a is None:
            return "ERR NOARG"
        a, b = self.a, self.b
        if op == "ADD":
            return "ADD:%d" % (a + b)
        if op == "SUB":
            return "SUB:%d" % (a - b)
        if op == "MUL":
            return "MUL:%d" % (a * b)
        if b == 0:
            return "ERR DIV0"
        q = int(a / b)
        r = a - b * q
        if self.fault == "rem_sign_of_b" and r != 0 and (r < 0) != (b < 0):
            r += b
            q -= 1
        return "DIV Q:%d R:%d" % (q, r)

    def read(self, n=1):
        if not self.tx:
            time.sleep(0.001)
            return b""
        out = bytes(self.tx[:n])
        del self.tx[:n]
        return out


def selftest():
    bad = check_model_against_table()
    for line, got, exp in bad:
        print("MODEL_TABLE_MISMATCH %r -> %r, table %r" % (line, got, exp))
    if bad:
        return 1
    print("MODEL_TABLE_MATCH cases=%d" % (len(FIXED_AFTER_RESET_1) + len(FIXED) + len(FIXED_AFTER_RESET_2) + 2))
    # (fault, expected verdict): the correct fake device must pass; every fault must be caught.
    scenarios = [(None, True), ("rem_sign_of_b", False), ("silent", False), ("lf_only", False),
                 ("echo", False), ("parity_ignored", False), ("comma_space_ok", False),
                 ("range_overwrites", False)]
    status = 0
    for fault, want_pass in scenarios:
        port = FakePort(fault)

        class Quiet(Report):
            def out(self, text):
                pass

        rep = Quiet()
        t = Tester(port, rep, timeout=0.05, prompt_reset=lambda why, p=port: p.reset_board(),
                   even="E", odd="O")
        t.run(use_reset=True, parity_case=True, random_count=400, seed=7)
        passed = rep.failures == 0
        ok = passed == want_pass
        status |= 0 if ok else 1
        print("SELFTEST device=%s verdict=%s failures=%d expected=%s %s"
              % (fault or "correct", "PASS" if passed else "FAIL", rep.failures,
                 "PASS" if want_pass else "FAIL", "ok" if ok else "WRONG"))
    print("SELFTEST_PASS" if status == 0 else "SELFTEST_FAIL")
    return status


def main():
    ap = argparse.ArgumentParser(description="8bit SoC calculator board test over UART (115200 8E1)")
    ap.add_argument("--port", help="serial port of the USB-UART adapter, e.g. /dev/ttyUSB0")
    ap.add_argument("--list-ports", action="store_true", help="list serial ports and exit")
    ap.add_argument("--selftest", action="store_true", help="check the checker with fake devices (no hardware)")
    ap.add_argument("--random", type=int, default=0, metavar="N", help="also send N random lines")
    ap.add_argument("--seed", type=int, default=1, help="seed of the random lines (default 1)")
    ap.add_argument("--timeout", type=float, default=1.0, help="reply timeout in seconds (default 1.0)")
    ap.add_argument("--no-prompt", action="store_true", help="skip the BTN0 reset steps and their cases")
    ap.add_argument("--no-parity-case", action="store_true", help="skip the odd-parity line")
    ap.add_argument("--log", help="also write the output to this file")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    import serial                      # pyserial; imported here so --selftest needs no package
    if args.list_ports:
        from serial.tools import list_ports
        for p in list_ports.comports():
            print("%s  %s" % (p.device, p.description))
        return 0
    if not args.port:
        ap.error("--port is required (see --list-ports)")
    bad = check_model_against_table()
    if bad:
        for line, got, exp in bad:
            print("MODEL_TABLE_MISMATCH %r -> %r, table %r" % (line, got, exp))
        return 2

    report = Report(args.log)
    report.out("CALC_BOARD_TEST port=%s %d 8E1 timeout=%.1fs random=%d seed=%d"
               % (args.port, BAUD, args.timeout, args.random, args.seed))

    def prompt(why):
        input("  >> Press and release BTN0 on the board (%s), then press Enter: " % why)

    try:
        port = serial.Serial(args.port, BAUD, bytesize=serial.EIGHTBITS, parity=serial.PARITY_EVEN,
                             stopbits=serial.STOPBITS_ONE, timeout=0.02, xonxoff=False, rtscts=False)
    except serial.SerialException as e:
        report.out("CALC_BOARD_FAIL cannot open %s: %s (see --list-ports)" % (args.port, e))
        report.close()
        return 2
    try:
        t = Tester(port, report, args.timeout, prompt, serial.PARITY_EVEN, serial.PARITY_ODD)
        t.run(use_reset=not args.no_prompt, parity_case=not args.no_parity_case,
              random_count=args.random, seed=args.seed)
    finally:
        port.close()
    lat = ("reply_ms min=%.1f max=%.1f" % (1000 * min(t.latency), 1000 * max(t.latency))) if t.latency else ""
    if report.failures == 0:
        report.out("CALC_BOARD_PASS lines=%d replies=%d %s" % (t.lines, t.replies, lat))
    else:
        report.out("CALC_BOARD_FAIL failures=%d lines=%d replies=%d %s" % (report.failures, t.lines, t.replies, lat))
    report.close()
    return 0 if report.failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
