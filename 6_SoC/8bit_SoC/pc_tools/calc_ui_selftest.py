#!/usr/bin/env python3
"""Self-test of calc_ui.py without hardware.

1. HTTP matrix: calc_ui.py --fake runs the automatic test (BTN0 steps, parity
   case, 300 random lines, seed 1) through the page's HTTP API, with the
   replies read from the PC side and from the fake STM32 side, on the correct
   fake device and on six faulty ones: four calculator faults, lf_only (reply
   ends with LF alone) and lcd_missing (the fake STM32 has no LCD).
2. HTTP input checks: a bad seed or line count, A or B out of range, and a
   request that cannot be read get an error reply; the connection and the
   idle state stay, and a normal calculation still works afterwards.
3. In-process checks with gated or delayed fake ports: one calculation is one
   transaction (two concurrent calculations), a late reply stops the
   automatic test and is not paired with another line in manual mode, an
   LF-only reply fails in manual mode, and the STM32 "LCD_FAIL" /
   "LCD_NOT_FOUND" lines fail the LCD check.

Usage (8bit_SoC folder): python3 pc_tools/calc_ui_selftest.py [--quick]
  --quick  skip the HTTP matrix (about 5 minutes)
Prints one UI_SELFTEST line per check and UI_SELFTEST_PASS / UI_SELFTEST_FAIL.
"""
import http.client
import json
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import calc_ui as ui   # noqa: E402

UI = os.path.join(HERE, "calc_ui.py")
bad = 0


def report(name, ok, detail=""):
    global bad
    bad += not ok
    print("UI_SELFTEST %s %s%s" % (name, "ok" if ok else "WRONG", " | " + detail if detail else ""))
    sys.stdout.flush()


# ---- HTTP helpers -----------------------------------------------------------
def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class Server:
    def __init__(self, fault=None, mode="pc", timeout=0.3):
        self.port = free_port()
        cmd = [sys.executable, "-B", UI, "--fake", "--no-open", "--http-port", str(self.port),
               "--timeout", str(timeout), "--reply-from", mode]
        if fault:
            cmd += ["--fake-fault", fault]
        self.p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)
        self.ready = self.p.stdout.readline().startswith("CALC_UI_READY")

    def call(self, path, body=None):
        url = "http://127.0.0.1:%d%s" % (self.port, path)
        req = urllib.request.Request(url) if body is None else urllib.request.Request(
            url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
        return json.loads(urllib.request.urlopen(req, timeout=5).read())

    def close(self):
        self.p.terminate()
        self.p.wait()


def matrix():
    for mode in ("pc", "stm32"):
        for fault, want in [(None, "PASS"), ("rem_sign_of_b", "FAIL"), ("silent", "FAIL"),
                            ("parity_ignored", "FAIL"), ("range_overwrites", "FAIL"),
                            ("lf_only", "FAIL"), ("lcd_missing", "FAIL")]:
            srv = Server(fault, mode)
            try:
                srv.call("/api/test/start", {"btn0": True, "parity": True, "random": 300, "seed": 1})
                while True:
                    s = srv.call("/api/state?since=999999")
                    t = s["test"]
                    if t["waiting_btn"]:
                        srv.call("/api/btn0", {})      # stands for pressing BTN0 on the board
                    if not t["running"]:
                        break
                    time.sleep(0.1)
            finally:
                srv.close()
            lcd = sum(1 for r in s["rows"] if r["lcd"] is not None)
            report("matrix mode=%s device=%s" % (mode, fault or "correct"), t["result"] == want,
                   "result=%s failures=%d rows=%d lcd_rows=%d expected=%s | %s"
                   % (t["result"], t["failures"], len(s["rows"]), lcd, want, t["summary"]))


def http_inputs():
    srv = Server()
    try:
        if not srv.ready:
            report("http_server_ready", False)
            return
        r1 = srv.call("/api/test/start", {"btn0": False, "parity": False, "random": 0, "seed": "bad"})
        r2 = srv.call("/api/test/start", {"btn0": False, "parity": False, "random": "x", "seed": 1})
        s = srv.call("/api/state?since=0")
        report("http_bad_seed_and_random", bool(r1["error"]) and bool(r2["error"]) and not s["test"]["running"],
               "errors=%r,%r running=%s" % (r1["error"], r2["error"], s["test"]["running"]))

        errs = [srv.call("/api/calc", {"a": a, "b": b, "op": "ADD"})["error"]
                for a, b in (("200", "1"), ("-129", "1"), ("1", "128"), ("1.5", "1"))]
        time.sleep(0.3)
        s = srv.call("/api/state?since=0")
        sent = [e["text"] for e in s["log"] if e["kind"] == "tx"]
        report("http_out_of_range", all(errs) and sent == [], "errors=%r sent=%r" % (errs, sent))

        conn = http.client.HTTPConnection("127.0.0.1", srv.port, timeout=5)
        conn.putrequest("POST", "/api/calc")
        conn.putheader("Content-Length", "abc")
        conn.endheaders()
        resp = conn.getresponse()
        body = json.loads(resp.read())
        conn.close()
        report("http_unreadable_request", resp.status == 500 and bool(body.get("error")),
               "status=%d error=%r" % (resp.status, body.get("error")))

        err = srv.call("/api/calc", {"a": "10", "b": "20", "op": "ADD"})["error"]
        time.sleep(0.4)
        s = srv.call("/api/state?since=0")
        rx = [(e["text"], e.get("expected"), e.get("match")) for e in s["log"] if e["kind"] == "rx"]
        report("http_calc_after_errors", err == "" and rx == [("ADD:30", "ADD:30", True)],
               "error=%r rx=%r" % (err, rx))
    finally:
        srv.close()


# ---- in-process helpers -----------------------------------------------------
def make_app(port, timeout=0.3, reply_from="pc", fault=None):
    app = ui.App(port, None, True, timeout, "E", "O", "fake", "fake", reply_from, fault)
    threading.Thread(target=app.reader, args=(port, app.on_pc_line), daemon=True).start()
    threading.Thread(target=app.expire_loop, daemon=True).start()
    return app


def entries(app, kind):
    with app.state_lock:
        return [e for e in app.log if e["kind"] == kind]


class GatePort(ui.LockedFake):
    """Records each line written; holds the write of one given line until go."""

    def __init__(self, hold):
        super().__init__(None)
        self.lines = []
        self.hold = hold
        self.held = threading.Event()
        self.go = threading.Event()

    def write(self, data):
        if data == self.hold:
            self.hold = None
            self.held.set()
            self.go.wait(5)
        self.lines.append(data.decode().rstrip("\r\n"))
        super().write(data)


class LatePort(ui.LockedFake):
    """Holds the first reply bytes for `delay` seconds, then passes everything."""

    def __init__(self, delay):
        super().__init__(None)
        self.delay = delay
        self.first = None
        self.kept = bytearray()
        self.released = False

    def read(self, n=1):
        data = super().read(n)
        if self.released:
            return data
        if data:
            self.kept += data
            if self.first is None:
                self.first = time.monotonic()
        if self.first is not None and time.monotonic() - self.first >= self.delay:
            self.released = True
            out = bytes(self.kept)
            self.kept = bytearray()
            return out
        return b""


def concurrent_calc():
    port = GatePort(b"1,2\r\n")
    app = make_app(port)
    app.btn0_pressed()
    res = {}
    ta = threading.Thread(target=lambda: res.update(a=app.calc("1", "2", "ADD")))
    ta.start()
    port.held.wait(5)                       # A is inside the write of its numbers line
    tb = threading.Thread(target=lambda: res.update(b=app.calc("10", "20", "MUL")))
    tb.start()
    time.sleep(0.3)
    b_waited = tb.is_alive()                # B must wait for A's transaction
    port.go.set()
    ta.join(5)
    tb.join(5)
    time.sleep(0.5)
    app.alive = False
    rx = [(e["text"], e.get("expected"), e.get("match")) for e in entries(app, "rx")]
    want_wire = ["1,2", "ADD", "10,20", "MUL"]
    want_rx = [("ADD:3", "ADD:3", True), ("MUL:200", "MUL:200", True)]
    report("concurrent_calc", b_waited and port.lines == want_wire and rx == want_rx
           and res == {"a": "", "b": ""},
           "b_waited=%s wire=%r rx=%r errors=%r" % (b_waited, port.lines, rx, res))


def late_reply_auto():
    app = make_app(LatePort(0.5), timeout=0.2)
    app.btn0_pressed()
    err = app.start_test(False, False, 0, 1)
    t0 = time.monotonic()
    while app.test["running"] and time.monotonic() - t0 < 10:
        time.sleep(0.05)
    time.sleep(0.8)                         # the late reply arrives after the stop
    app.alive = False
    t = app.test
    reply_rows = [r for r in t["rows"] if r["expected"] is not None]
    late = [e for e in entries(app, "rx") if "짝이 없는" in e.get("note", "")]
    ok = (err == "" and t["result"] == "FAIL" and t["aborted"] == "reply_timeout"
          and len(reply_rows) == 1 and not reply_rows[0]["ok"] and not any(r["ok"] for r in reply_rows)
          and len(late) == 1 and late[0]["text"] == "ADD:30" and "match" not in late[0])
    report("late_reply_auto", ok, "summary=%s rows=%d why=%r late=%r"
           % (t.get("summary"), len(t["rows"]), reply_rows[0]["why"] if reply_rows else None,
              [(e["text"], e.get("note")) for e in late]))


def late_reply_manual():
    app = make_app(LatePort(0.5), timeout=0.2)
    app.btn0_pressed()
    e1 = app.calc("1", "2", "ADD")          # reply ADD:3 comes after 0.5 s (timeout 0.2 s)
    time.sleep(0.9)
    e2 = app.calc("5", "3", "SUB")          # reply SUB:2 on time
    time.sleep(0.4)
    app.alive = False
    rx = [(e["text"], e.get("expected"), e.get("match"), e.get("note", "")) for e in entries(app, "rx")]
    timeouts = [e["text"] for e in entries(app, "err") if e["text"].startswith("응답 없음")]
    ok = (e1 == e2 == "" and len(rx) == 2 and rx[0][0] == "ADD:3" and rx[0][1] is None
          and "짝이 없는" in rx[0][3] and rx[1][:3] == ("SUB:2", "SUB:2", True) and len(timeouts) == 1)
    report("late_reply_manual", ok, "rx=%r timeouts=%r" % (rx, timeouts))


def lf_only_manual():
    port = ui.LockedFake("lf_only")
    app = make_app(port, fault="lf_only")
    app.btn0_pressed()
    err = app.calc("1", "2", "ADD")
    time.sleep(0.4)
    app.alive = False
    rx = [(e["text"], e.get("match"), e.get("note")) for e in entries(app, "rx")]
    stm = [e["text"] for e in entries(app, "stm")]
    report("lf_only_manual", err == "" and rx == [("ADD:3", False, ui.BAD_EOL)] and stm == ["RX ERR"],
           "rx=%r stm=%r" % (rx, stm))


def lcd_lines():
    app = ui.App(None, None, False, 0.3, "E", "O", "x", "y")
    app.on_stm_line("#5 LCD_FAIL FPGA> ADD:30")
    first = app.last_stm
    app.on_stm_line("#6 FPGA> SUB:1")
    app.on_stm_line("LCD_NOT_FOUND: no PCF8574 address answered (check SDA/SCL/VCC/GND)")
    app.on_stm_line("#7 FPGA> MUL:2")
    missing = app.lcd_missing
    app.on_stm_line("8bit SoC STM32 LCD receiver")
    app.on_stm_line("#1 RX ERR (got \"ADD:30\") eol pe=0 fe=0 nf=0 ore=0 drop=0")
    got = [(e["text"], e.get("note", "")) for e in entries(app, "stm")]
    want = [("ADD:30", "LCD에 표시 못 함"), ("SUB:1", ""), ("MUL:2", "LCD에 표시 못 함"), ("RX ERR", "")]
    report("lcd_fail_lines", got == want and missing and not app.lcd_missing and first.endswith("(LCD 표시 실패)"),
           "stm=%r lcd_missing_after_not_found=%s" % (got, missing))


def main():
    quick = "--quick" in sys.argv[1:]
    concurrent_calc()
    late_reply_auto()
    late_reply_manual()
    lf_only_manual()
    lcd_lines()
    http_inputs()
    if not quick:
        matrix()
    print("UI_SELFTEST_PASS" if bad == 0 else "UI_SELFTEST_FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
