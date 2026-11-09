#!/usr/bin/env python3
"""Web UI for the 8bit SoC calculator board test (PC side).

Runs a small web server in Ubuntu (WSL2); open the page in a Windows browser.
The page sends calculator lines to the FPGA through the USB-UART adapter
(115200 8E1, 02_design/calculator.md) and shows the replies. Optionally it
also reads the STM32 debug port (ST-LINK virtual COM, 115200 8N1), where the
STM32 prints every line it received from the FPGA and showed on the LCD
("#n FPGA> ADD:30"), so the page can compare the PC reply and the LCD line.

The automatic test uses the same cases and reference model as
calc_board_test.py (fixed cases, BTN0 reset steps, parity case, random lines).

Usage (8bit_SoC folder, Ubuntu; attach the USB devices first with scripts/wsl_usb.sh):
  python3 pc_tools/calc_ui.py --list-ports
  python3 pc_tools/calc_ui.py --port /dev/ttyUSB0 [--stm32-port /dev/ttyACM0] [--http-port 8765]
  python3 pc_tools/calc_ui.py --port /dev/ttyUSB0 --stm32-port /dev/ttyACM0 --reply-from stm32
      wiring without the adapter RX (FPGA TX goes only to the STM32 D0): the
      replies are taken from the STM32 debug output
  python3 pc_tools/calc_ui.py --fake          no hardware: fake calculator and fake STM32
Then open http://localhost:8765 in the browser. Stop with Ctrl+C.
Only one program may use a serial port: close miniterm and calc_board_test.py first.
"""
import argparse
import json
import os
import queue
import random
import re
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import calc_board_test as cbt   # noqa: E402  (same folder: cases, reference model, fake device)

STM_LINE_RE = re.compile(r"^#\d+ (?:FPGA> (.*)|(RX ERR|RX LONG)\b.*)$")
LOG_KEEP = 3000


class LockedFake:
    """calc_board_test.FakePort shared by the reader thread and the senders."""

    def __init__(self, fault=None):
        self.dev = cbt.FakePort(fault)
        self.lock = threading.Lock()

    def write(self, data):
        with self.lock:
            self.dev.write(data)

    def read(self, n=1):
        with self.lock:
            out = self.dev.read(n)
        if not out:
            time.sleep(0.005)
        return out

    def flush(self):
        pass

    @property
    def parity(self):
        return self.dev.parity

    @parity.setter
    def parity(self, value):
        with self.lock:
            self.dev.parity = value

    def reset_board(self):
        with self.lock:
            self.dev.reset_board()

    def close(self):
        pass


class App:
    def __init__(self, pc_port, stm_port, fake, timeout, even, odd, pc_name, stm_name, reply_from="pc"):
        self.pc = pc_port
        self.stm = stm_port
        self.fake = fake
        self.timeout = timeout
        self.even = even
        self.odd = odd
        self.pc_name = pc_name
        self.stm_name = stm_name
        self.has_lcd = stm_port is not None or fake
        self.reply_stm = reply_from == "stm32"   # adapter RX not wired: replies come from the STM32 output
        self.lcd_fail = 0                        # LCD_WRITE_FAIL lines from the STM32
        self.write_lock = threading.Lock()
        self.state_lock = threading.Lock()
        self.model = cbt.CalcModel()
        self.log = []
        self.next_id = 1
        self.pending_exp = []           # manual mode: expected replies of sent operation lines
        self.pc_q = queue.Queue()        # PC replies (automatic test)
        self.stm_q = queue.Queue()       # STM32 lines (automatic test)
        self.last_pc = ""
        self.last_stm = ""
        self.test = {"running": False, "waiting_btn": "", "rows": [], "failures": 0,
                     "result": "", "lines": 0, "replies": 0}
        self.btn_event = threading.Event()
        self.stop_flag = threading.Event()
        self.alive = True

    # ---- log -------------------------------------------------------------
    def add_log(self, kind, text, extra=None):
        with self.state_lock:
            e = {"id": self.next_id, "t": time.strftime("%H:%M:%S"), "kind": kind, "text": text}
            if extra:
                e.update(extra)
            self.next_id += 1
            self.log.append(e)
            if len(self.log) > LOG_KEEP:
                del self.log[:len(self.log) - LOG_KEEP]

    # ---- readers ---------------------------------------------------------
    def reader(self, port, on_line):
        buf = bytearray()
        while self.alive:
            try:
                b = port.read(64)
            except Exception as e:          # port unplugged etc.
                self.add_log("err", "read error: %s" % e)
                time.sleep(1.0)
                continue
            if not b:
                continue
            buf += b
            while b"\n" in buf:
                i = buf.index(b"\n")
                raw = bytes(buf[:i])
                del buf[:i + 1]
                if raw.endswith(b"\r"):
                    raw = raw[:-1]
                on_line(raw.decode("ascii", "replace"))

    def on_pc_line(self, text):
        self.last_pc = text
        if self.reply_stm:
            self.add_log("rx", text)          # not used for judging in this mode
        elif self.test["running"]:
            self.add_log("rx", text)
            self.pc_q.put(text)
        else:
            extra = {}
            with self.state_lock:
                exp = self.pending_exp.pop(0) if self.pending_exp else None
            if exp is not None:
                extra = {"expected": exp, "match": text == exp}
            self.add_log("rx", text, extra)
        if self.fake:                        # fake STM32: the same line reaches the "LCD"
            self.on_stm_line("#0 FPGA> " + text)

    def on_stm_line(self, text):
        m = STM_LINE_RE.match(text)
        if not m:
            if text.startswith("LCD_WRITE_FAIL"):
                self.lcd_fail += 1
                self.add_log("err", "STM32: " + text)
            else:
                self.add_log("stm_info", text)
            return
        shown = m.group(1) if m.group(1) is not None else m.group(2)
        self.last_stm = shown
        extra = {}
        if self.reply_stm and not self.test["running"]:
            with self.state_lock:
                exp = self.pending_exp.pop(0) if self.pending_exp else None
            if exp is not None:
                extra = {"expected": exp, "match": shown == exp}
        self.add_log("stm", shown, extra)
        if self.test["running"]:
            self.stm_q.put(shown)

    # ---- sending ---------------------------------------------------------
    def write_line(self, line, parity_error=False):
        data = line.encode("ascii", "replace")
        with self.write_lock:
            if parity_error:
                self.pc.flush()
                self.pc.parity = self.odd
                self.pc.write(data)
                self.pc.flush()
                self.pc.parity = self.even
                self.pc.write(b"\r\n")
            else:
                self.pc.write(data + b"\r\n")

    def manual_send(self, line):
        if self.test["running"]:
            return "자동 시험 중에는 보낼 수 없습니다"
        if len(line) > 40 or any(ord(c) < 0x20 or ord(c) > 0x7E for c in line):
            return "ASCII 40자 이하의 한 줄만 보낼 수 있습니다"
        exp = self.model.line(line)
        if exp is not None:
            with self.state_lock:
                self.pending_exp.append(exp)
        self.add_log("tx", line, {"expected": exp} if exp is not None else {"note": "응답 없음(숫자 저장)" if cbt.NUM_RE.match(line) else ""})
        self.write_line(line)
        return ""

    def btn0_pressed(self):
        """User pressed BTN0 on the board: A/B cleared."""
        if self.fake:
            self.pc.reset_board()
        self.model.reset()
        with self.state_lock:
            self.pending_exp = []
        if self.test["running"] and self.test["waiting_btn"]:
            self.btn_event.set()
        else:
            self.add_log("info", "BTN0 눌림: A·B를 지운 상태로 기대값을 계산합니다")

    # ---- automatic test -------------------------------------------------
    def start_test(self, use_btn0, parity, random_count, seed):
        if self.test["running"]:
            return "이미 실행 중입니다"
        random_count = max(0, min(int(random_count), 2000))
        self.test = {"running": True, "waiting_btn": "", "rows": [], "failures": 0,
                     "result": "", "lines": 0, "replies": 0, "lcd_fail_seen": self.lcd_fail}
        self.stop_flag.clear()
        self.btn_event.clear()
        threading.Thread(target=self.run_test, args=(use_btn0, parity, random_count, int(seed)),
                         daemon=True).start()
        return ""

    def drain(self):
        for q in (self.pc_q, self.stm_q):
            while True:
                try:
                    q.get_nowait()
                except queue.Empty:
                    break

    def wait_btn(self, why):
        self.btn_event.clear()
        self.test["waiting_btn"] = why
        self.add_log("info", "자동 시험: 보드의 BTN0을 눌렀다 뗀 뒤 화면의 [BTN0 눌렀음]을 누르세요 (%s)" % why)
        while not self.btn_event.wait(0.2):
            if self.stop_flag.is_set():
                self.test["waiting_btn"] = ""
                return False
        self.test["waiting_btn"] = ""
        time.sleep(0.2)
        self.model.reset()
        self.drain()
        return True

    def test_case(self, line, parity_error=False):
        exp = self.model.line(line, rx_error=parity_error)
        row = {"line": line + (" (odd parity)" if parity_error else ""), "expected": exp,
               "pc": None, "lcd": None, "ok": True, "why": ""}
        self.add_log("tx", row["line"], {"expected": exp} if exp is not None else {})
        self.write_line(line, parity_error)
        self.test["lines"] += 1
        if exp is not None and self.reply_stm:
            self.test["replies"] += 1
            try:
                row["lcd"] = self.stm_q.get(timeout=self.timeout)
            except queue.Empty:
                row["ok"] = False
                row["why"] = "STM32가 받은 줄 없음"
            if row["lcd"] is not None and row["lcd"] != exp:
                row["ok"] = False
                row["why"] = "STM32가 받은 줄이 기대값과 다름"
        elif exp is not None:
            self.test["replies"] += 1
            try:
                row["pc"] = self.pc_q.get(timeout=self.timeout)
            except queue.Empty:
                row["ok"] = False
                row["why"] = "PC 응답 없음"
            if row["pc"] is not None and row["pc"] != exp:
                row["ok"] = False
                row["why"] = "PC 응답이 기대값과 다름"
            if self.has_lcd:
                try:
                    row["lcd"] = self.stm_q.get(timeout=0.5)
                except queue.Empty:
                    row["lcd"] = None
                if row["lcd"] != exp:
                    row["ok"] = False
                    row["why"] = (row["why"] + ", " if row["why"] else "") + (
                        "LCD 줄 없음" if row["lcd"] is None else "LCD 줄이 기대값과 다름")
        if not row["ok"]:
            self.test["failures"] += 1
        self.test["rows"].append(row)

    def check_quiet(self, where):
        time.sleep(0.3)
        extra = []
        for q in ((self.pc_q, self.stm_q) if self.has_lcd else (self.pc_q,)):
            while True:
                try:
                    extra.append(q.get_nowait())
                except queue.Empty:
                    break
        if self.lcd_fail != self.test.get("lcd_fail_seen", 0):
            n = self.lcd_fail - self.test.get("lcd_fail_seen", 0)
            self.test["lcd_fail_seen"] = self.lcd_fail
            self.test["failures"] += 1
            self.test["rows"].append({"line": "(%s)" % where, "expected": None, "pc": None, "lcd": None,
                                      "ok": False, "why": "STM32 LCD 쓰기 실패 %d회" % n})
        if extra:
            self.test["failures"] += 1
            self.test["rows"].append({"line": "(%s)" % where, "expected": None, "pc": " | ".join(extra),
                                      "lcd": None, "ok": False, "why": "기대하지 않은 응답"})

    def run_test(self, use_btn0, parity, random_count, seed):
        steps = []
        if use_btn0:
            steps.append(("btn", "시작: A·B 지우기"))
            steps += [("case", l) for l, _ in cbt.FIXED_AFTER_RESET_1]
        steps += [("case", l) for l, _ in cbt.FIXED]
        steps.append(("quiet", "고정 사례 뒤"))
        if use_btn0:
            steps.append(("btn", "중간: A·B 다시 지우기"))
            steps += [("case", l) for l, _ in cbt.FIXED_AFTER_RESET_2]
        if parity:
            steps.append(("parity", None))
        if random_count:
            rng = random.Random(seed)
            steps += [("case", l) for l in cbt.random_lines(rng, random_count)]
        steps.append(("quiet", "끝"))
        self.test["total"] = sum(1 for s in steps if s[0] == "case") + (3 if parity else 0)
        self.add_log("info", "자동 시험 시작 (BTN0 단계 %s, parity 사례 %s, 무작위 %d줄 seed %d)"
                     % ("포함" if use_btn0 else "제외", "포함" if parity else "제외", random_count, seed))
        self.drain()
        try:
            for kind, arg in steps:
                if self.stop_flag.is_set():
                    break
                if kind == "btn":
                    if not self.wait_btn(arg):
                        break
                elif kind == "case":
                    self.test_case(arg)
                elif kind == "quiet":
                    self.check_quiet(arg)
                else:
                    if self.model.a is None:
                        self.test_case("7,-2")
                    self.test_case(cbt.PARITY_CASE[0], parity_error=True)
                    self.test_case(cbt.PARITY_NEXT[0])
        except Exception as e:
            self.test["failures"] += 1
            self.add_log("err", "자동 시험 오류: %s" % e)
        t = self.test
        if self.stop_flag.is_set():
            t["result"] = "STOPPED"
        elif t["failures"] == 0:
            t["result"] = "PASS"
        else:
            t["result"] = "FAIL"
        summary = "CALC_UI_%s lines=%d replies=%d failures=%d lcd=%s reply_from=%s" % (
            t["result"], t["lines"], t["replies"], t["failures"], "on" if self.has_lcd else "off",
            "stm32" if self.reply_stm else "pc")
        t["summary"] = summary
        self.add_log("info", summary)
        t["running"] = False

    def state(self, since):
        with self.state_lock:
            log = [e for e in self.log if e["id"] > since]
        t = dict(self.test)
        rows = t.pop("rows")
        return {"pc_port": self.pc_name, "stm_port": self.stm_name, "fake": self.fake,
                "reply_stm": self.reply_stm,
                "last_pc": self.last_pc, "last_stm": self.last_stm, "log": log,
                "a": self.model.a, "b": self.model.b,
                "test": t, "rows": rows}


PAGE = r"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>8bit SoC 계산기 시험</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--fg:#1d2330;--muted:#677085;--line:#dde1e8;--acc:#2f6fdf;--ok:#1d8a4a;--bad:#c93636;--warn:#b7791f;--mono:Consolas,"D2Coding",monospace}
@media (prefers-color-scheme:dark){:root{--bg:#14171d;--card:#1d222b;--fg:#e6e9ef;--muted:#99a2b4;--line:#2e3542;--acc:#6a9cff;--ok:#4cc27b;--bad:#ff6b6b;--warn:#e0a84a}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 "Malgun Gothic",system-ui,sans-serif}
header{padding:12px 20px;border-bottom:1px solid var(--line);display:flex;gap:16px;flex-wrap:wrap;align-items:center}
header h1{font-size:18px;margin:0}.tag{font:12px var(--mono);color:var(--muted);border:1px solid var(--line);border-radius:6px;padding:2px 8px}
main{display:grid;grid-template-columns:minmax(320px,420px) 1fr;gap:16px;padding:16px 20px;max-width:1400px}
@media (max-width:900px){main{grid-template-columns:1fr;padding:12px 16px}}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin-bottom:16px}
.card h2{font-size:15px;margin:0 0 10px}.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:6px 0}
input[type=number],input[type=text]{font:15px var(--mono);padding:6px 8px;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--fg);width:90px}
input[type=text]{width:200px}button{font:inherit;padding:6px 12px;border-radius:6px;border:1px solid var(--line);background:var(--bg);color:var(--fg);cursor:pointer}
button.pri{background:var(--acc);border-color:var(--acc);color:#fff}button:disabled{opacity:.45;cursor:default}
.op{min-width:62px;font-family:var(--mono);font-weight:600}
.big{font:600 22px var(--mono);padding:8px 10px;border-radius:6px;background:var(--bg);min-height:44px;word-break:break-all}
.lbl{font-size:12px;color:var(--muted)}.muted{color:var(--muted);font-size:13px}
.banner{display:none;background:var(--warn);color:#111;border-radius:8px;padding:10px 12px;margin:8px 0;font-weight:600}
.res{font:600 16px var(--mono)}.ok{color:var(--ok)}.bad{color:var(--bad)}
table{border-collapse:collapse;width:100%;font:13px var(--mono)}th,td{border-bottom:1px solid var(--line);padding:4px 6px;text-align:left;white-space:nowrap}
th{color:var(--muted);font-weight:600;position:sticky;top:0;background:var(--card)}
.scroll{max-height:420px;overflow:auto}#log div{font:13px var(--mono);padding:1px 0;white-space:pre-wrap;word-break:break-all}
.k-tx{color:var(--acc)}.k-rx{color:var(--fg)}.k-stm{color:var(--ok)}.k-info,.k-stm_info{color:var(--muted)}.k-err{color:var(--bad)}
</style></head><body>
<header><h1>8bit SoC 계산기 시험</h1><span class="tag" id="pcport"></span><span class="tag" id="stmport"></span></header>
<main>
<section>
 <div class="card"><h2>1. 계산 보내기</h2>
  <div class="row"><span class="lbl">A</span><input type="number" id="a" value="10" min="-128" max="127">
   <span class="lbl">B</span><input type="number" id="b" value="20" min="-128" max="127">
   <button class="pri" id="sendnum">숫자 보내기</button></div>
  <div class="row"><button class="op" data-op="ADD">ADD</button><button class="op" data-op="SUB">SUB</button>
   <button class="op" data-op="MUL">MUL</button><button class="op" data-op="DIV">DIV</button></div>
  <div class="row"><input type="text" id="free" placeholder="직접 입력 (예: 7,-2)"><button id="sendfree">보내기</button></div>
  <div class="muted" id="ab"></div>
  <div class="muted">숫자 줄은 응답이 없고 A·B로 저장됩니다. 연산 버튼을 누르면 FPGA가 결과를 보냅니다.</div>
 </div>
 <div class="card"><h2>2. 결과</h2>
  <div class="lbl" id="pclbl">FPGA → PC (변환기)</div><div class="big" id="lastpc"></div>
  <div class="lbl" style="margin-top:8px" id="lcdlbl">STM32가 받아 LCD에 표시한 줄</div><div class="big" id="laststm"></div>
 </div>
 <div class="card"><h2>3. BTN0</h2>
  <div class="banner" id="btnbanner"></div>
  <div class="row"><button id="btn0">BTN0 눌렀음 (A·B 지움)</button></div>
  <div class="muted">보드의 BTN0을 눌렀다 뗀 뒤 이 버튼을 누르면, 화면도 A·B가 없는 상태로 기대값을 계산합니다.</div>
 </div>
 <div class="card"><h2>4. 자동 시험</h2>
  <div class="row"><label><input type="checkbox" id="t_btn" checked> BTN0 단계 포함</label>
   <label><input type="checkbox" id="t_par" checked> parity 오류 사례</label></div>
  <div class="row"><span class="lbl">무작위 줄</span><input type="number" id="t_rand" value="0" min="0" max="2000">
   <span class="lbl">seed</span><input type="number" id="t_seed" value="1"></div>
  <div class="row"><button class="pri" id="tstart">자동 시험 시작</button><button id="tstop">중지</button></div>
  <div class="res" id="tres"></div>
 </div>
</section>
<section>
 <div class="card"><h2>자동 시험 결과</h2><div class="scroll"><table><thead><tr><th>#</th><th>보낸 줄</th><th>기대</th><th id="pcth">PC 응답</th><th id="lcdth">LCD 줄</th><th>판정</th></tr></thead><tbody id="rows"></tbody></table></div></div>
 <div class="card"><h2>기록</h2><div class="row"><button id="clear">화면 기록 지우기</button></div><div class="scroll" id="log"></div></div>
</section>
</main>
<script>
let since=0, rowsShown=0, hasStm=false, replyStm=false;
const $=id=>document.getElementById(id);
async function post(url,body){const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body||{})});const j=await r.json();if(j.error)alert(j.error);return j;}
function send(line){return post('/api/send',{line});}
$('sendnum').onclick=()=>send($('a').value+','+$('b').value);
document.querySelectorAll('.op').forEach(b=>b.onclick=()=>send(b.dataset.op));
$('sendfree').onclick=()=>{const v=$('free').value;if(v!=='')send(v);};
$('free').onkeydown=e=>{if(e.key==='Enter')$('sendfree').click();};
$('btn0').onclick=()=>post('/api/btn0');
$('tstart').onclick=()=>{rowsShown=0;$('rows').innerHTML='';post('/api/test/start',{btn0:$('t_btn').checked,parity:$('t_par').checked,random:+$('t_rand').value,seed:+$('t_seed').value});};
$('tstop').onclick=()=>post('/api/test/stop');
$('clear').onclick=()=>{$('log').innerHTML='';};
const esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
const KIND={tx:'PC → FPGA ',rx:'FPGA → PC ',stm:'LCD       ',stm_info:'STM32     ',info:'안내      ',err:'오류      '};
function logLine(e){let s=e.t+'  '+(KIND[e.kind]||e.kind)+' '+e.text;
 if(e.kind==='tx'&&e.expected)s+='   (기대 '+e.expected+')';
 if(e.kind==='tx'&&e.note)s+='   ('+e.note+')';
 if((e.kind==='rx'||e.kind==='stm')&&e.expected!==undefined)s+=e.match?'   ✓ 기대와 같음':'   ✗ 기대 '+e.expected;
 const d=document.createElement('div');d.className='k-'+e.kind;d.textContent=s;return d;}
async function poll(){
 try{const r=await fetch('/api/state?since='+since);const s=await r.json();
  $('pcport').textContent='FPGA 변환기: '+s.pc_port+(s.fake?' (가짜 장치)':'')+(s.reply_stm?' — 응답은 STM32에서 받음':'');
  hasStm=!!s.stm_port;$('stmport').textContent='STM32: '+(s.stm_port||'연결 안 함');
  $('lcdlbl').style.display=$('laststm').style.display=$('lcdth').style.display=hasStm?'':'none';
  replyStm=!!s.reply_stm;$('pclbl').style.display=$('lastpc').style.display=$('pcth').style.display=replyStm?'none':'';
  if(replyStm)$('lcdlbl').textContent='FPGA 응답 (STM32가 받아 LCD에 표시한 줄)';
  $('lastpc').textContent=s.last_pc;$('laststm').textContent=s.last_stm;
  $('ab').textContent='화면이 아는 A·B: '+(s.a===null?'없음':s.a+', '+s.b);
  const log=$('log'),atEnd=log.scrollTop+log.clientHeight>=log.scrollHeight-20;
  for(const e of s.log){log.appendChild(logLine(e));since=e.id;}
  while(log.childNodes.length>3000)log.removeChild(log.firstChild);
  if(atEnd)log.scrollTop=log.scrollHeight;
  const t=s.test,run=t.running;
  document.querySelectorAll('#sendnum,.op,#sendfree,#tstart').forEach(b=>b.disabled=run);$('tstop').disabled=!run;
  const bn=$('btnbanner');if(t.waiting_btn){bn.style.display='block';bn.textContent='자동 시험 대기: 보드의 BTN0을 눌렀다 뗀 뒤 아래 버튼을 누르세요 ('+t.waiting_btn+')';}else bn.style.display='none';
  const tb=$('rows');for(let i=rowsShown;i<s.rows.length;i++){const w=s.rows[i];const tr=document.createElement('tr');
   tr.innerHTML='<td>'+(i+1)+'</td><td>'+esc(w.line)+'</td><td>'+esc(w.expected??'(응답 없음)')+'</td>'+(replyStm?'':'<td>'+esc(w.pc??'')+'</td>')+(hasStm?'<td>'+esc(w.lcd??'')+'</td>':'')+'<td class="'+(w.ok?'ok':'bad')+'">'+(w.ok?'ok':'FAIL '+esc(w.why))+'</td>';tb.appendChild(tr);}
  if(s.rows.length>rowsShown){rowsShown=s.rows.length;tb.parentNode.parentNode.scrollTop=1e9;}
  const res=$('tres');if(run){res.className='res';res.textContent='실행 중 '+t.lines+'/'+(t.total||'?')+' 줄, 실패 '+t.failures;}
  else if(t.result){res.className='res '+(t.result==='PASS'?'ok':'bad');res.textContent=t.result+' — '+t.summary;}
 }catch(e){$('tres').textContent='서버 연결 끊김: Ubuntu에서 calc_ui.py가 실행 중인지 확인하세요';$('tres').className='res bad';}
 setTimeout(poll,300);}
poll();
</script></body></html>
"""


def make_handler(app):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass

        def reply(self, code, body, ctype="application/json; charset=utf-8"):
            data = body if isinstance(body, bytes) else body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path == "/" or self.path.startswith("/index"):
                self.reply(200, PAGE, "text/html; charset=utf-8")
            elif self.path.startswith("/api/state"):
                m = re.search(r"since=(\d+)", self.path)
                self.reply(200, json.dumps(app.state(int(m.group(1)) if m else 0)))
            else:
                self.reply(404, json.dumps({"error": "not found"}))

        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            try:
                body = json.loads(self.rfile.read(n) or b"{}")
            except ValueError:
                body = {}
            err = ""
            if self.path == "/api/send":
                err = app.manual_send(str(body.get("line", "")))
            elif self.path == "/api/btn0":
                app.btn0_pressed()
            elif self.path == "/api/test/start":
                err = app.start_test(bool(body.get("btn0", True)), bool(body.get("parity", True)),
                                     body.get("random", 0) or 0, body.get("seed", 1) or 1)
            elif self.path == "/api/test/stop":
                app.stop_flag.set()
            else:
                self.reply(404, json.dumps({"error": "not found"}))
                return
            self.reply(200, json.dumps({"error": err}))
    return Handler


def main():
    ap = argparse.ArgumentParser(description="Web UI for the 8bit SoC calculator board test")
    ap.add_argument("--port", help="USB-UART adapter on Pmod JC, e.g. /dev/ttyUSB0 (115200 8E1)")
    ap.add_argument("--stm32-port", help="optional: STM32 ST-LINK virtual COM, e.g. /dev/ttyACM0 (115200 8N1)")
    ap.add_argument("--fake", action="store_true", help="no hardware: fake calculator and fake STM32")
    ap.add_argument("--reply-from", choices=["pc", "stm32"], default="pc",
                    help="where the FPGA replies are read: pc = adapter RX (default), "
                         "stm32 = STM32 debug output (adapter RX not wired; needs --stm32-port)")
    ap.add_argument("--fake-fault", choices=["rem_sign_of_b", "silent", "lf_only", "echo", "parity_ignored",
                                             "comma_space_ok", "range_overwrites"],
                    help="with --fake: give the fake calculator this fault (checks that the UI test catches it)")
    ap.add_argument("--http-port", type=int, default=8765, help="web page port (default 8765)")
    ap.add_argument("--timeout", type=float, default=1.0, help="reply timeout in seconds (default 1.0)")
    ap.add_argument("--list-ports", action="store_true", help="list serial ports and exit")
    args = ap.parse_args()

    if args.list_ports:
        from serial.tools import list_ports
        for p in list_ports.comports():
            print("%s  %s" % (p.device, p.description))
        return 0
    bad = cbt.check_model_against_table()
    if bad:
        print("MODEL_TABLE_MISMATCH %r" % (bad,))
        return 2

    if args.reply_from == "stm32" and not (args.stm32_port or args.fake):
        ap.error("--reply-from stm32 needs --stm32-port (or --fake)")
    stm = None
    if args.fake:
        pc = LockedFake(args.fake_fault)
        pc_name, stm_name, even, odd = "fake", "fake", "E", "O"
    else:
        if not args.port:
            ap.error("--port is required (see --list-ports), or use --fake")
        import serial
        even, odd = serial.PARITY_EVEN, serial.PARITY_ODD
        try:
            pc = serial.Serial(args.port, cbt.BAUD, bytesize=serial.EIGHTBITS, parity=serial.PARITY_EVEN,
                               stopbits=serial.STOPBITS_ONE, timeout=0.05, xonxoff=False, rtscts=False,
                               exclusive=True)
            if args.stm32_port:
                stm = serial.Serial(args.stm32_port, 115200, timeout=0.05, exclusive=True)
        except serial.SerialException as e:
            print("CALC_UI_FAIL cannot open port: %s" % e)
            print("Close miniterm / calc_board_test.py that use the port, and check --list-ports.")
            return 2
        pc_name, stm_name = args.port, args.stm32_port

    app = App(pc, stm, args.fake, args.timeout, even, odd, pc_name, stm_name, args.reply_from)
    threading.Thread(target=app.reader, args=(pc, app.on_pc_line), daemon=True).start()
    if stm is not None:
        stm.reset_input_buffer()
        threading.Thread(target=app.reader, args=(stm, app.on_stm_line), daemon=True).start()
    app.add_log("info", "시작: FPGA 변환기 %s, STM32 %s, 응답 읽는 곳 %s" % (
        pc_name, stm_name or "연결 안 함", "STM32 출력" if args.reply_from == "stm32" else "PC 변환기 RX"))

    server = ThreadingHTTPServer(("127.0.0.1", args.http_port), make_handler(app))
    print("CALC_UI_READY open http://localhost:%d in the browser (Ctrl+C to stop)" % args.http_port)
    sys.stdout.flush()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        app.alive = False
        server.server_close()
        pc.close()
        if stm is not None:
            stm.close()
        print("CALC_UI_STOPPED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
