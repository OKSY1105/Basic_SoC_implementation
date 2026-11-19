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
   earlier reply that comes in the quiet time after a BTN0 step of the
   automatic test is not judged, a BTN0 confirmed again during the quiet
   time starts it again (automatic test and manual mode: no line goes out
   and no reply is judged before the quiet time of the latest BTN0 ends), an
   LF-only reply fails in manual mode,
   and the STM32 "LCD_FAIL" /
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
    """App on a fake port; BTN0 first (A/B known), then past the quiet time."""
    app = ui.App(port, None, True, timeout, "E", "O", "fake", "fake", reply_from, fault)
    threading.Thread(target=app.reader, args=(port, app.on_pc_line), daemon=True).start()
    app.btn0_pressed()
    time.sleep(ui.RESYNC_QUIET + 0.1)
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


class HoldPort(ui.LockedFake):
    """Keeps every reply line until the test releases it (in order); with
    passthrough set, replies go through at once."""

    def __init__(self):
        super().__init__(None)
        self.held = bytearray()
        self.out = bytearray()
        self.mu = threading.Lock()
        self.passthrough = False

    def read(self, n=1):
        data = super().read(n)
        with self.mu:
            self.held += data
            if self.passthrough:
                self.out += self.held
                self.held = bytearray()
            out, self.out = bytes(self.out), bytearray()
        return out

    def release_line(self):
        t0 = time.monotonic()
        while time.monotonic() - t0 < 2:
            with self.mu:
                if b"\n" in self.held:
                    i = self.held.index(b"\n") + 1
                    self.out += self.held[:i]
                    del self.held[:i]
                    return True
            time.sleep(0.01)
        return False


class BtnLatePort(ui.LockedFake):
    """VR-014_r2-I1, VR-014_r3-I1: every reply is kept back until arm() (that
    request times out); after arm() the first new reply line is lost and the
    rest pass; release_old() then delivers the kept reply. Records the time of
    every write."""

    def __init__(self):
        super().__init__(None)
        self.mu = threading.Lock()
        self.old = bytearray()
        self.buf = bytearray()
        self.out = bytearray()
        self.state = "keep"
        self.dropped = b""
        self.writes = []

    def write(self, data):
        self.writes.append(time.monotonic())
        super().write(data)

    def first_write_after(self, t):
        later = [w for w in self.writes if w > t]
        return later[0] - t if later else None

    def read(self, n=1):
        data = super().read(n)
        with self.mu:
            if self.state == "keep":
                self.old += data
            else:
                self.buf += data
                if self.state == "drop_first" and b"\n" in self.buf:
                    i = self.buf.index(b"\n") + 1
                    self.dropped = bytes(self.buf[:i])
                    del self.buf[:i]
                    self.state = "pass"
                if self.state == "pass":
                    self.out += self.buf
                    self.buf = bytearray()
            out, self.out = bytes(self.out), bytearray()
        return out

    def arm(self):
        with self.mu:
            self.state = "drop_first"

    def release_old(self):
        with self.mu:
            self.out += self.old
            self.old = bytearray()


def concurrent_calc():
    port = GatePort(b"1,2\r\n")
    app = make_app(port)
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
          and len(late) == 1 and late[0]["text"] == "ADD:30" and "match" not in late[0] and not app.synced)
    report("late_reply_auto", ok, "summary=%s rows=%d why=%r late=%r synced=%s"
           % (t.get("summary"), len(t["rows"]), reply_rows[0]["why"] if reply_rows else None,
              [(e["text"], e.get("note")) for e in late], app.synced))


def late_reply_manual(mode):
    """VR-014_r1-I1: A = 1,2 ADD gets no reply in time; B = 2,1 ADD (same
    expected text ADD:3) is sent; A's late reply comes while B waits, B's own
    reply after that. Neither may count as a match. Then BTN0 resyncs."""
    port = HoldPort()
    app = make_app(port, timeout=0.2, reply_from=mode)
    kind = "rx" if mode == "pc" else "stm"
    e1 = app.calc("1", "2", "ADD")              # A: reply held -> timeout after 0.2 s
    synced_after_a = app.synced
    res = {}
    tb = threading.Thread(target=lambda: res.update(b=app.calc("2", "1", "ADD")))
    tb.start()
    time.sleep(0.05)                            # B is waiting for its reply
    r1 = port.release_line()                    # A's late ADD:3 comes while B waits
    tb.join(2)
    r2 = port.release_line()                    # B's own ADD:3 comes after B
    time.sleep(0.2)
    refused = app.start_test(False, False, 0, 1)
    before = [(e["text"], e.get("match"), e.get("note", "")) for e in entries(app, kind)]
    port.passthrough = True
    app.btn0_pressed()                          # resync
    synced_after_btn0 = app.synced
    e3 = app.calc("5", "3", "SUB")              # waits out the quiet time, then SUB:2 on time
    time.sleep(0.2)
    app.alive = False
    after = [(e["text"], e.get("expected"), e.get("match")) for e in entries(app, kind)][len(before):]
    timeouts = [e["text"] for e in entries(app, "err") if e["text"].startswith("응답 없음")]
    ok = (e1 == "" and res.get("b") == "" and e3 == "" and r1 and r2 and not synced_after_a
          and len(before) == 2 and not any(m is True for _, m, _ in before)
          and before[0][0] == "ADD:3" and before[0][2] == ui.UNSYNCED_NOTE
          and before[1][0] == "ADD:3" and before[1][2] == ui.UNPAIRED_NOTE
          and bool(refused) and synced_after_btn0 and after == [("SUB:2", "SUB:2", True)]
          and len(timeouts) == 1)
    report("late_reply_manual mode=%s" % mode, ok,
           "replies_before_btn0=%r refused_auto_start=%s after_btn0=%r timeouts=%d"
           % (before, bool(refused), after, len(timeouts)))


# the note the page shows (calc_ui.QUIET_NOTE), as text so that the check also
# runs on older calc_ui.py versions
QUIET_NOTE = "BTN0 직후에 받은 줄: BTN0 전 요청의 응답으로 보고 판정하지 않음"


def quiet_lines(app):
    """(kind, text) of the lines logged as received in the BTN0 quiet time."""
    with app.state_lock:
        return [(e["kind"], e["text"]) for e in app.log if e.get("note") == QUIET_NOTE]


def btn_auto_case(name, mode, again):
    """A manual ADD before BTN0 times out (unsynced); then an automatic test
    with BTN0 steps. At its first BTN0 step BTN0 is confirmed once (again =
    False) or twice, 0.2 s apart (again = True). The earlier ERR NOARG comes
    0.3 s (0.36 s) after the latest confirm, and the reply of the first new
    line (ADD, also ERR NOARG) is lost. The first line must go out
    RESYNC_QUIET after the latest confirm, the old line is not judged, and the
    test stops at the first line's timeout."""
    port = BtnLatePort()
    app = make_app(port, timeout=0.2, reply_from=mode)
    e1 = app.manual_send("ADD")                 # reply kept back -> timeout, unsynced
    port.arm()
    err = app.start_test(True, False, 0, 1)
    t0 = time.monotonic()
    while not app.test["waiting_btn"] and time.monotonic() - t0 < 5:
        time.sleep(0.005)
    tb = time.monotonic()
    app.btn0_pressed()                          # stands for pressing BTN0 on the board
    presses = 1
    if again:
        time.sleep(max(0.0, tb + 0.2 - time.monotonic()))
        tb = time.monotonic()
        app.btn0_pressed()                      # confirmed again during the quiet time
        presses = 2
    time.sleep(max(0.0, tb + (0.36 if again else 0.3) - time.monotonic()))
    port.release_old()                          # the earlier ERR NOARG comes now
    while app.test["running"] and time.monotonic() - t0 < 30:
        if app.test["waiting_btn"]:
            app.btn0_pressed()
            presses += 1
            t1 = time.monotonic()
            while app.test["waiting_btn"] and time.monotonic() - t1 < 1:
                time.sleep(0.005)
        time.sleep(0.02)
    time.sleep(0.2)
    app.alive = False
    t = app.test
    first = t["rows"][0] if t["rows"] else {}
    first_send = port.first_write_after(tb)
    late_ok = first_send is not None and first_send >= ui.RESYNC_QUIET
    quiet = quiet_lines(app)
    want_quiet = [("rx", "ERR NOARG"), ("stm", "ERR NOARG")] if mode == "pc" else [("stm", "ERR NOARG")]
    before = [e["text"] for e in entries(app, "info") if e["text"].startswith("BTN0 확인 전")]
    ok = (e1 == "" and err == "" and t["result"] == "FAIL" and t["aborted"] == "reply_timeout"
          and first.get("line") == "ADD" and not first.get("ok") and not any(r["ok"] for r in t["rows"])
          and late_ok and quiet == want_quiet and not before and port.dropped == b"ERR NOARG\r\n")
    report("%s mode=%s" % (name, mode), ok,
           "result=%s aborted=%s rows=%d first=%r why=%r first_send_after_quiet=%s not_judged=%r presses=%d"
           % (t.get("result"), t.get("aborted"), len(t["rows"]), first.get("line"), first.get("why"),
              late_ok, quiet, presses))


def late_reply_btn_auto(mode):
    """VR-014_r2-I1: one BTN0 confirm, the earlier reply 0.3 s after it."""
    btn_auto_case("late_reply_btn_auto", mode, again=False)


def repeated_btn0_auto(mode):
    """VR-014_r3-I1: BTN0 confirmed again 0.2 s after the first confirm, the
    earlier reply 0.36 s after the second one."""
    btn_auto_case("repeated_btn0_auto", mode, again=True)


def repeated_btn0_manual(mode):
    """VR-014_r3-I1 in manual mode: after a timeout BTN0 is confirmed, a line
    (SUB) is sent 0.1 s later and waits for the quiet time, and BTN0 is
    confirmed again 0.2 s after the first confirm. The earlier ERR NOARG comes
    0.36 s after the second confirm and the reply of SUB is lost. SUB must go
    out RESYNC_QUIET after the second confirm and no reply may count as a
    match."""
    port = BtnLatePort()
    app = make_app(port, timeout=0.2, reply_from=mode)
    kind = "rx" if mode == "pc" else "stm"
    e1 = app.manual_send("ADD")                 # reply kept back -> timeout, unsynced
    port.arm()
    t1 = time.monotonic()
    app.btn0_pressed()
    res = {}
    ts = threading.Thread(target=lambda: res.update(s=app.manual_send("SUB")))
    time.sleep(max(0.0, t1 + 0.1 - time.monotonic()))
    ts.start()                                  # SUB waits for the quiet time
    time.sleep(max(0.0, t1 + 0.2 - time.monotonic()))
    t2 = time.monotonic()
    tb = threading.Thread(target=app.btn0_pressed)   # own thread: it may have to wait for tx_lock
    tb.start()
    time.sleep(max(0.0, t2 + 0.36 - time.monotonic()))
    port.release_old()                          # the earlier ERR NOARG comes now
    ts.join(3)
    tb.join(3)
    time.sleep(0.2)
    app.alive = False
    sub_send = port.first_write_after(t2)
    late_ok = sub_send is not None and sub_send >= ui.RESYNC_QUIET
    got = [(e["text"], e.get("match"), e.get("note", "")) for e in entries(app, kind)]
    timeouts = [e["text"] for e in entries(app, "err") if e["text"].startswith("응답 없음")]
    ok = (e1 == "" and res.get("s") == "" and not ts.is_alive() and not tb.is_alive() and late_ok
          and got == [("ERR NOARG", None, QUIET_NOTE)] and len(timeouts) == 2)
    report("repeated_btn0_manual mode=%s" % mode, ok,
           "send_after_latest_quiet=%s replies=%r timeouts=%d" % (late_ok, got, len(timeouts)))


def lf_only_manual():
    port = ui.LockedFake("lf_only")
    app = make_app(port, fault="lf_only")
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
    late_reply_manual("pc")
    late_reply_manual("stm32")
    late_reply_btn_auto("pc")
    late_reply_btn_auto("stm32")
    repeated_btn0_auto("pc")
    repeated_btn0_auto("stm32")
    repeated_btn0_manual("pc")
    repeated_btn0_manual("stm32")
    lf_only_manual()
    lcd_lines()
    http_inputs()
    if not quick:
        matrix()
    print("UI_SELFTEST_PASS" if bad == 0 else "UI_SELFTEST_FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
