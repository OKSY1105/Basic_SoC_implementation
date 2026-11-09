#!/usr/bin/env python3
"""Measure clocks per instruction of cpu8_top in tb_cpu8_top (XSim).

Each case repeats a short instruction block N times after a common setup and
ends with HALT. The steady-state cost is taken from two runs,
(cycles with 2N blocks - cycles with N blocks) / N, so the setup, the first
block's start-up and HALT cancel out. Memory is the TB's zero-wait model
(delay mode 0): ROM and RAM answer in the first data-phase clock, like the
SoC ROM and a cache hit. Every program's final state is also checked against
the ISA model of run_cpu8_tests.py.

Usage (WSL, Vivado 2024.2):
  python3 TOOLS/measure_cpu8_cycles.py --vivado-bin /home/sean/Vivado/2024.2/bin \
      --build-dir /tmp/claude_runs/cpu_cycles [--json result.json]
Prints one CYCLES line per case and CPU8_CYCLES_PASS at the end.
"""
import argparse, json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cpu8_asm import assemble, write_mem          # noqa: E402
from run_cpu8_tests import model, run              # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
N = 16
SETUP = "LDI R0,1\nLDI R1,2\nLDI R2,3\nLDI R3,4\nLDXL 16"
SETUP_Z = SETUP + "\nCMP R0,R0"            # Z=1, C=1 (no borrow) for taken JZ/JC

# (name, instruction, what the block shows, block text, setup)
CASES = [
    ("ldi", "LDI", "연속, 의존 없음", "LDI R0,5", SETUP),
    ("mov", "MOV", "연속, 의존 없음", "MOV R1,R2", SETUP),
    ("mov_dep", "MOV", "바로 앞 결과 사용", "MOV R1,R2\nMOV R2,R1", SETUP),
    ("add_dep1", "ADD", "바로 앞 결과 사용(ADD R0,R1 반복)", "ADD R0,R1", SETUP),
    ("add_dep2", "ADD", "두 명령 앞 결과 사용", "ADD R0,R1\nADD R2,R3", SETUP),
    ("sub_dep2", "SUB", "두 명령 앞 결과 사용", "SUB R0,R1\nSUB R2,R3", SETUP),
    ("and_dep2", "AND", "두 명령 앞 결과 사용", "AND R0,R1\nAND R2,R3", SETUP),
    ("adc_flags", "ADC", "바로 앞 C flag 사용", "ADC R0,R1\nADC R2,R3", SETUP),
    ("sbc_flags", "SBC", "바로 앞 C flag 사용", "SBC R0,R1\nSBC R2,R3", SETUP),
    ("cmp", "CMP", "연속(flag만 씀)", "CMP R0,R1", SETUP),
    ("ld", "LD", "연속, 결과 미사용", "LD R0,[X]", SETUP),
    ("ld_use", "LD", "읽은 값을 바로 사용", "LD R0,[X]\nADD R1,R0", SETUP),
    ("st", "ST", "연속", "ST [X],R0", SETUP),
    ("st_after_write", "ST", "바로 앞에서 쓴 레지스터 저장", "LDI R0,5\nST [X],R0", SETUP),
    ("ldxl", "LDXL", "연속(X 하위 바이트만 바꿔도 X 의존)", "LDXL 16", SETUP),
    ("inx", "INX", "연속(X 의존)", "INX", SETUP),
    ("inx_ld", "INX", "바로 다음 LD가 X 사용", "INX\nLD R0,[X]", SETUP),
    ("jmp", "JMP", "분기함(다음 명령으로)", "JMP 0", SETUP),
    ("jz_not", "JZ", "분기 안 함(Z=0)", "JZ 0", SETUP),
    ("jz_taken", "JZ", "분기함(Z=1)", "JZ 0", SETUP_Z),
    ("jc_not", "JC", "분기 안 함(C=0)", "JC 0", SETUP),
    ("jc_taken", "JC", "분기함(C=1)", "JC 0", SETUP_Z),
    ("cmp_jz", "CMP+JZ", "비교 바로 뒤 조건 분기(분기함)", "CMP R0,R0\nJZ 0", SETUP),
    ("ei", "EI", "연속", "EI", SETUP),
    ("di", "DI", "연속", "DI", SETUP),
]


def program(setup, block, blocks):
    return setup + "\n" + "\n".join([block] * blocks) + "\nHALT"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--vivado-bin", type=Path, required=True)
    ap.add_argument("--build-dir", type=Path, required=True)
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()
    build = args.build_dir.resolve()
    (build / "cases").mkdir(parents=True, exist_ok=True)
    tool = lambda name: args.vivado_bin / name
    rtl = sorted((ROOT / "RTL").glob("*.v"))
    tb = [ROOT / "TB" / "cpu8_ahb_checker.sv", ROOT / "TB" / "cpu8_irq_checker.sv", ROOT / "TB" / "tb_cpu8_top.sv"]
    run([tool("xvlog"), "--sv", "-d", "CPU8_SVA", "-i", ROOT / "RTL", *rtl, *tb], build, "xvlog.log")
    run([tool("xelab"), "tb_cpu8_top", "-s", "tb_cpu8_top_snapshot"], build, "xelab.log")

    lines, expect = [], {}
    for name, _, _, block, setup in CASES:
        for blocks in (N, 2 * N):
            tag = "%s_%d" % (name, blocks)
            words = assemble(program(setup, block, blocks))
            rp, dp = build / "cases" / (tag + ".mem"), build / "cases" / (tag + ".data")
            write_mem(words, rp)
            write_mem({0: 0}, dp, 2)
            lines.append("%s %s %s 0 0 -1 -1 0 1 0" % (tag, rp.as_posix(), dp.as_posix()))
            expect[tag] = model(words)
    manifest = build / "cases.txt"
    manifest.write_text("\n".join(lines) + "\n", encoding="ascii")
    out = run([tool("xsim"), "tb_cpu8_top_snapshot", "-runall", "-testplusarg", "CASES=" + manifest.as_posix()],
              build, "xsim.log")

    ends, current = {}, None
    for line in out.splitlines():
        m = re.match(r"CASE (\S+)", line)
        if m:
            current = m.group(1)
        m = re.match(r"END (\d+) (\d+) (\d+) ([0-9a-f]{4}) ([0-9a-f]{8}) ([0-9a-f]{4}) ([0-9a-f]) (\d+) (\d+)", line)
        if m and current:
            ends[current] = m.groups()
    bad = 0
    results = []
    for name, ins, what, block, _ in CASES:
        cyc, stl = {}, {}
        for blocks in (N, 2 * N):
            tag = "%s_%d" % (name, blocks)
            e, ref = ends.get(tag), expect[tag]
            if e is None:
                print("MISSING %s" % tag)
                bad += 1
                continue
            cycles, halted, fault, pc, regs, x, flags, code, stalls = e
            state = (int(halted), int(fault), int(pc, 16), int(regs, 16), int(x, 16), int(flags, 16))
            want = (1, 0, ref["pc"], ref["registers"], ref["x"], ref["flags"])
            if state != want or ref["fault"]:
                print("STATE_MISMATCH %s rtl=%s model=%s" % (tag, state, want))
                bad += 1
            cyc[blocks], stl[blocks] = int(cycles), int(stalls)
        if len(cyc) < 2:
            continue
        k = len(block.splitlines())
        per_block = (cyc[2 * N] - cyc[N]) / N
        stall_block = (stl[2 * N] - stl[N]) / N
        results.append(dict(case=name, instruction=ins, condition=what, block=block.replace("\n", " / "),
                            clocks_per_block=per_block, instructions_per_block=k,
                            clocks_per_instruction=per_block / k, stalls_per_block=stall_block))
        print("CYCLES case=%s block=\"%s\" clocks_per_block=%.2f per_instruction=%.2f stalls_per_block=%.2f"
              % (name, block.replace("\n", " / "), per_block, per_block / k, stall_block))
    if args.json:
        args.json.write_text(json.dumps(dict(n=N, memory="zero-wait (TB delay mode 0)", cases=results),
                                        ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("CPU8_CYCLES_%s cases=%d programs=%d" % ("PASS" if bad == 0 else "FAIL", len(results), len(lines)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
