#!/usr/bin/env python3
"""Compile RTL, run an independent ISA/retirement comparison and ALU/reset tests."""
import argparse,json,os,random,re,shutil,subprocess,sys
from pathlib import Path
from cpu8_asm import assemble,write_mem,OPS,RR,BR,NOARG,IRQ_VECTOR

ROOT=Path(__file__).resolve().parents[1]
SIGNED=lambda x:x if x<128 else x-256

def arithmetic(op,a,b,carry):
    if op in {"ADD","ADC"}:
        extra=carry if op=="ADC" else 0
        total=a+b+extra;st=SIGNED(a)+SIGNED(b)+extra;c=total>255
    elif op in {"SUB","SBC","CMP"}:
        extra=1-carry if op=="SBC" else 0
        total=a-b-extra;st=SIGNED(a)-SIGNED(b)-extra;c=total>=0
    else:
        total=a&b;st=0;c=False
    value=total%256
    v=(st< -128 or st>127) if op!="AND" else False
    return value,((value==0)<<3)|((value>=128)<<2)|(int(c)<<1)|int(v)

def model(words,data=None,ierror=-1,derror=-1,ints=()):
    """ISA model. Register bank 0 runs the program, bank 1 the interrupt
    handler (R0-R3, X, FLAGS each). `ints` lists, for each interrupt the RTL
    took, how many instructions had retired before it; the model enters the
    handler there and checks that entry was legal (IE=1, not in the handler).
    Interrupt timing is the RTL's; the program-visible effect is the model's."""
    r=[[0]*4,[0]*4];x=[0,0];f=[0,0];bank=0;ie=0;epc=0;pc=0
    traces=[];reads=[];writes=[];memory=dict(data or {});rx=0;fault=0;taken=[];ints=list(ints)
    reverse={v:k for k,v in OPS.items()}
    for step in range(10000):
        if len(taken)<len(ints) and len(traces)==ints[len(taken)]:
            if not ie or bank:
                raise AssertionError(f"interrupt entry at pc {pc:04x} with IE={ie} handler={bank}")
            taken.append((len(traces),pc));epc=pc;bank=1;ie=0;pc=IRQ_VECTOR
        if pc not in words or pc==ierror:fault=2;break
        ins=words[pc];op=reverse.get(ins>>10);rd=(ins>>8)&3;imm=ins&255;rs=imm&3
        legal=op is not None
        if op in RR:legal=legal and imm<4
        elif op in {"LD","ST"}:legal=legal and imm==0
        elif op in {"LDXL","LDXH"}|BR:legal=legal and rd==0
        elif op in NOARG:legal=legal and (ins&1023)==0
        if op=="RETI" and not bank:legal=False   # RETI only in the handler
        if not legal:fault=1;break
        b=bank;R=r[b]
        nextpc=(pc+1)&65535;rw=0;value=0
        if op=="LDI":value=imm;rw=1
        elif op=="MOV":value=R[rs];rw=1
        elif op in {"ADD","ADC","SUB","SBC","CMP","AND"}:
            value,f[b]=arithmetic(op,R[rd],R[rs],(f[b]>>1)&1);rw=op!="CMP"
        elif op=="LDXL":x[b]=(x[b]&65280)|imm
        elif op=="LDXH":x[b]=(imm<<8)|(x[b]&255)
        elif op=="INX":x[b]=(x[b]+1)&65535
        elif op in BR:
            take=op=="JMP" or (op=="JZ" and bool(f[b]&8)) or (op=="JC" and bool(f[b]&2))
            if take:nextpc=(nextpc+SIGNED(imm))&65535
        elif op=="EI":ie=1
        elif op=="DI":ie=0
        elif op=="RETI":nextpc=epc
        elif op in {"LD","ST"}:
            a=x[b]
            mapped=a<2048 or (op=="LD" and a in (0xff00,0xff02)) or (op=="ST" and a in (0xff01,0xff04))
            if not mapped or a==derror:fault=3;break
            if op=="LD":
                value=memory.get(a,0) if a<2048 else (64+rx if a==0xff00 else 1)
                value%=256;rw=1;reads.append((a,value))
                if a==0xff00:rx+=1
            else:
                value=R[rd];writes.append((a,value))
                if a<2048:memory[a]=value
        if rw:R[rd]=value
        regs=sum(v<<(8*i) for i,v in enumerate(R))
        traces.append((pc,ins,regs,x[b],f[b],nextpc,int(rw),rd,value if rw else None))
        if op=="RETI":bank=0;ie=1
        pc=nextpc
        if op=="HALT":break
    else:raise AssertionError("reference watchdog")
    if len(taken)!=len(ints):raise AssertionError("interrupt reported after the program ended")
    regs=sum(v<<(8*i) for i,v in enumerate(r[0]))
    return dict(trace=traces,reads=reads,writes=writes,pc=pc,registers=regs,x=x[0],flags=f[0],
                fault=fault,rx=rx,ints=taken)

def cases():
    directed=[
      ("first_add","LDI R0,10\nLDI R1,20\nADD R0,R1\nHALT",{}),
      ("four_writable","LDI R0,255\nLDI R1,-128\nLDI R2,127\nLDI R3,42\nMOV R2,R0\nMOV R0,R3\nADD R3,R3\nHALT",{}),
      ("carry_chain","LDI R0,255\nLDI R1,1\nLDI R2,0\nLDI R3,0\nADD R0,R1\nADC R2,R3\nHALT",{}),
      ("borrow_chain","LDI R0,0\nLDI R1,1\nLDI R2,0\nLDI R3,0\nSUB R0,R1\nSBC R2,R3\nHALT",{}),
      ("signed_flags","LDI R0,127\nLDI R1,1\nADD R0,R1\nLDI R2,128\nSUB R2,R1\nCMP R0,R2\nHALT",{}),
      ("flags_branches","LDI R0,7\nLDI R1,7\nCMP R0,R1\nJZ equal\nLDI R2,99\nequal: JC carry\nLDI R2,98\ncarry: LDI R2,128\nAND R0,R2\nJZ zero\nLDI R3,97\nzero: CMP R1,R2\nJC bad\nJMP done\nbad: LDI R3,96\ndone: HALT",{}),
      ("x_bytes","LDXH 0\nLDXL 255\nLDI R0,90\nST [X],R0\nINX\nLD R1,[X]\nLDXL 1\nLD R2,[X]\nLDXH 0\nLD R3,[X]\nHALT",{256:123,257:45,1:67}),
      ("ram_edges","LDXH 0\nLDXL 0\nLDI R3,171\nST [X],R3\nLD R0,[X]\nLDXH 7\nLDXL 255\nST [X],R0\nLD R1,[X]\nHALT",{}),
      ("x_wrap","LDXH 255\nLDXL 255\nINX\nLD R0,[X]\nHALT",{0:56}),
      ("load_use_store","LDXL 32\nLD R0,[X]\nADD R0,R0\nST [X],R0\nINX\nST [X],R0\nHALT",{32:63}),
      ("loop","LDI R0,0\nLDI R1,7\nLDI R2,5\nLDI R3,1\nloop: ADD R0,R1\nSUB R2,R3\nJZ done\nJMP loop\ndone: HALT",{}),
      ("branch_flush","LDI R0,19\nCMP R0,R0\nJZ target\nST [X],R0\n.word 0\ntarget: JMP stop\nST [X],R0\nstop: HALT\nST [X],R0\n.word 0",{}),
      ("mmio_once","LDXH 255\nLDXL 0\nLD R0,[X]\nLD R1,[X]\nLDXL 1\nST [X],R0\nST [X],R1\nHALT",{}),
      ("illegal_opcode","LDI R0,31\n.word 0\nLDI R1,99",{}),
      ("illegal_rr","LDI R0,31\n.word 0x2440\nLDI R1,99",{}),
      ("illegal_halt","LDI R0,31\n.word 0x0401\nLDI R1,99",{}),
      ("illegal_load","LDI R0,31\n.word 0x1001\nLDI R1,99",{}),
      ("illegal_branch","LDI R0,31\n.word 0x5100\nLDI R1,99",{}),
      ("fetch_missing","LDI R0,31",{}),
      ("fetch_negative","JMP -2",{}),
      ("fetch_wrap","JMP -2\n.org 0xffff\nLDI R0,1",{}),
      ("data_unmapped","LDXH 8\nLDXL 0\nLD R0,[X]\nHALT",{}),
      ("data_fault_older","LDXL 32\nLD R0,[X]\nJMP skip\nLDI R1,99\nskip: HALT",{32:20}),
      ("fetch_error","LDI R0,31\nLDI R1,99\nHALT",{}),
      ("store_error","LDI R0,31\nST [X],R0\nHALT",{}),
      # The second LD's address phase waits behind the first LD's ERROR and
      # must be cancelled: no access to 0x0800 may complete.
      ("data_error_cancel","LDXH 8\nLDXL 0\nLD R0,[X]\nLD R1,[X]\nHALT",{}),
    ]
    # The wrap case exits through an explicit injected fetch error after revisiting 0.
    # Instead use HALT at address ffff to exercise a wrapping next-PC of zero.
    directed[20]=("fetch_wrap","JMP -2\n.org 0xffff\nHALT",{})
    for mode in (0,1):
        for name,text,data in directed:
            cfg={"name":name+f"_wait{mode}","words":assemble(text),"data":data,"mode":mode,"seed":7,"ierror":-1,"derror":-1}
            if name=="fetch_error":cfg["ierror"]=1
            if name=="data_fault_older":cfg["derror"]=32
            if name=="store_error":cfg["derror"]=0
            yield cfg
    # Interrupt programs: word 0 jumps to main, the handler starts at the vector
    # (word 2), acknowledges by writing 0xFF04 and counts in RAM 0x0100 using
    # its own register bank. The TB raises the request at start + k*period.
    head="JMP main\nHALT\n"
    handler=("LDXH 255\nLDXL 4\nST [X],R0\nLDXH 1\nLDXL 0\nLD R1,[X]\nLDI R2,1\n"
             "ADD R1,R2\nST [X],R1\nRETI\n")
    work=("LDI R0,0\nLDI R1,3\nLDI R2,40\nLDI R3,1\nLDXH 0\nLDXL 64\n"
          "loop: ADD R0,R1\nST [X],R0\nINX\nSUB R2,R3\nJZ done\nJMP loop\ndone: LD R1,[X]\nHALT")
    irq_directed=[
      # name, program, irq (start, period, count), minimum interrupts taken
      ("irq_basic",head+handler+"main: EI\n"+work,(20,37,6),3),
      ("irq_disabled",head+handler+"main: "+work,(10,25,8),0),
      ("irq_reentry",head+handler+"main: EI\n"+work,(15,6,10),3),
      ("irq_di_window",head+handler+"main: EI\nDI\nLDI R0,0\nLDI R1,5\nLDI R2,20\nLDI R3,1\n"
       "crit: ADD R0,R1\nSUB R2,R3\nJZ open\nJMP crit\nopen: EI\n"+work,(12,23,8),2),
      # The program and the handler both pop the RX FIFO at 0xFF00: a dropped
      # LD must not pop, so the popped values must match the model exactly.
      ("irq_mmio",head+"LDXH 255\nLDXL 4\nST [X],R0\nLDXL 0\nLD R1,[X]\nRETI\n"
       "main: EI\nLDXH 255\nLDXL 0\nLDI R1,0\nLDI R2,30\nLDI R3,1\n"
       "loop: LD R0,[X]\nADD R1,R0\nSUB R2,R3\nJZ done\nJMP loop\ndone: HALT",(18,29,8),3),
      ("irq_after_halt",head+handler+"main: EI\nLDI R0,9\nHALT",(40,10,3),0),
      ("irq_reti_outside",head+handler+"main: LDI R0,1\nRETI\nHALT",(0,1,0),0),
      ("irq_ei_reserved",head+handler+"main: LDI R0,1\n.word 0x6001\nHALT",(0,1,0),0),
    ]
    for mode in (0,1):
        for name,text,irq,min_ints in irq_directed:
            yield dict(name=name+f"_wait{mode}",words=assemble(text),data={},mode=mode,seed=7,
                       ierror=-1,derror=-1,irq=irq,min_ints=min_ints)
    for seed in range(8):
        rng=random.Random(100+seed);lines=[head+handler+"main: EI"]
        for rd in range(4):lines.append(f"LDI R{rd},{rng.randrange(256)}")
        lines+=["LDXH 0","LDXL 64"]
        for _ in range(70):
            op=rng.choice(["LDI","MOV","ADD","ADC","SUB","SBC","CMP","AND","LD","ST","LD","ST","INX","JZ","JC","DI_EI"])
            a,b=rng.randrange(4),rng.randrange(4)
            if op=="LDI":lines.append(f"LDI R{a},{rng.randrange(256)}")
            elif op in RR:lines.append(f"{op} R{a},R{b}")
            elif op=="LD":lines.append(f"LD R{a},[X]")
            elif op=="ST":lines.append(f"ST [X],R{a}")
            elif op in {"JZ","JC"}:lines.extend([f"{op} 1",f"LDI R{a},{rng.randrange(256)}"])
            elif op=="DI_EI":lines.extend(["DI",f"ADD R{a},R{b}","EI"])
            else:lines.append(op)
        lines.append("HALT")
        irq=(rng.randrange(10,40),rng.randrange(9,40),12)
        yield dict(name=f"irq_random_{seed}",words=assemble("\n".join(lines)),
                   data={64+i:rng.randrange(256) for i in range(100)},mode=1,seed=seed,
                   ierror=-1,derror=-1,irq=irq,min_ints=1)
    for seed in range(12):
        rng=random.Random(seed);lines=[]
        for rd in range(4):lines.append(f"LDI R{rd},{rng.randrange(256)}")
        lines+=["LDXH 0","LDXL 64"]
        for _ in range(90):
            op=rng.choice(["LDI","MOV","ADD","ADC","SUB","SBC","CMP","AND","LD","ST","INX","JZ","JC"])
            a,b=rng.randrange(4),rng.randrange(4)
            if op=="LDI":lines.append(f"LDI R{a},{rng.randrange(256)}")
            elif op in RR:lines.append(f"{op} R{a},R{b}")
            elif op=="LD":lines.append(f"LD R{a},[X]")
            elif op=="ST":lines.append(f"ST [X],R{a}")
            elif op in {"JZ","JC"}:lines.extend([f"{op} 1",f"LDI R{a},{rng.randrange(256)}"])
            else:lines.append(op)
        lines.append("HALT")
        yield dict(name=f"random_{seed}",words=assemble("\n".join(lines)),data={64+i:rng.randrange(256) for i in range(100)},mode=1,seed=seed,ierror=-1,derror=-1)

def run(command,build,log,cwd=None):
    command=list(map(str,command))
    if str(command[0]).lower().endswith(".bat"):
        # cmd.exe splits unquoted batch arguments at '=', ',', ';' and spaces
        # (e.g. CASES=C:/...), so quote those arguments explicitly.
        quote=lambda a:'"'+a+'"' if re.search(r"[=,; ]",a) else a
        line=" ".join(['"'+command[0]+'"']+[quote(a) for a in command[1:]])
        command='"'+os.environ.get("COMSPEC","cmd.exe")+'" /d /s /c "'+line+'"'
    p=subprocess.run(command,cwd=(cwd or build),input=b"",stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
    output=p.stdout.decode("utf-8",errors="replace")
    (build/log).write_text(output,encoding="utf-8")
    if p.returncode or re.search(r"(^|\n)(FATAL|ERROR:|FAIL)",output):
        raise RuntimeError(f"command failed rc={p.returncode}; see {build/log}\n{output[-7000:]}")
    return output

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--simulator",choices=["auto","iverilog","xsim"],default="auto")
    ap.add_argument("--vivado-bin",type=Path)
    ap.add_argument("--build-dir",type=Path)
    args=ap.parse_args()
    build=(args.build_dir or ROOT/"BUILD").resolve();build.mkdir(parents=True,exist_ok=True);fixtures=build/"cases";fixtures.mkdir(exist_ok=True)
    rtl=list(sorted((ROOT/"RTL").glob("*.v")))
    tops=["tb_cpu8_top","tb_cpu8_alu","tb_cpu8_reset"]
    # AHB protocol and interrupt checkers: concurrent SVA is enabled for XSim (CPU8_SVA).
    checkers=[ROOT/"TB"/"cpu8_ahb_checker.sv",ROOT/"TB"/"cpu8_irq_checker.sv"]
    sim=args.simulator
    if sim=="auto":sim="iverilog" if shutil.which("iverilog") else "xsim"
    outputs={}
    def tool(name):
        if args.vivado_bin:
            q=args.vivado_bin/(name+(".bat" if os.name=="nt" else ""))
            if not q.exists():raise RuntimeError("tool not found: "+str(q))
            return q
        q=shutil.which(name)
        if not q:raise RuntimeError("Install Icarus or source Vivado settings; no "+name)
        return q
    if sim=="iverilog":
        for top in tops:
            command=["iverilog","-g2012","-I",str(ROOT/"RTL"),"-s",top,"-o",str(build/(top+".vvp")),*map(str,rtl),*map(str,checkers),str(ROOT/"TB"/(top+".sv"))]
            run(command,build,top+"_compile.log")
    else:
        run([tool("xvlog"),"--sv","-d","CPU8_SVA","-i",ROOT/"RTL",*rtl,*checkers,*[ROOT/"TB"/(t+".sv") for t in tops]],build,"xvlog_cpu8.log")
        for top in tops:run([tool("xelab"),top,"-s",top+"_snapshot"],build,top+"_elaborate.log")
    suite=list(cases());lines=[]
    for cfg in suite:
        rp=fixtures/(cfg["name"]+".mem");dp=fixtures/(cfg["name"]+".data")
        write_mem(cfg["words"],rp);write_mem(cfg["data"] or {0:0},dp,2)
        start,period,count=cfg.get("irq",(0,1,0))
        lines.append(f'{cfg["name"]} {rp.as_posix()} {dp.as_posix()} {cfg["mode"]} {cfg["seed"]} {cfg["ierror"]} {cfg["derror"]} {start} {period} {count}')
    manifest=build/"cases.txt";manifest.write_text("\n".join(lines)+"\n",encoding="ascii")
    for top in tops:
        if sim=="iverilog":
            plus=["+CASES="+manifest.as_posix()] if top=="tb_cpu8_top" else []
            outputs[top]=run(["vvp",build/(top+".vvp"),*plus],build,top+"_run.log")
        else:
            plus=["-testplusarg","CASES="+manifest.as_posix()] if top=="tb_cpu8_top" else []
            outputs[top]=run([tool("xsim"),top+"_snapshot","-runall",*plus],build,top+"_run.log")
    # Exercise the GUI/default path as well: no CASES argument and no ROM files.
    if sim=="iverilog":
        demo_command=["vvp",build/"tb_cpu8_top.vvp"]
    else:
        demo_command=[tool("xsim"),"tb_cpu8_top_snapshot","-runall"]
    demo_output=run(demo_command,build,"tb_cpu8_default_demo_run.log")
    if "CPU8_DEMO_PASS: 10 + 20 = 30" not in demo_output or "ALL_CASES_DONE 1" not in demo_output:
        raise AssertionError("default no-argument demo did not finish")
    if "ALU_PASS 786432" not in outputs["tb_cpu8_alu"]:raise AssertionError("ALU test did not finish")
    if "RESET_PASS" not in outputs["tb_cpu8_reset"]:raise AssertionError("reset test did not finish")
    got={};current=None;cover={};max_latency=None
    for raw in outputs["tb_cpu8_top"].splitlines():
        line=raw.strip();p=line.split()
        if not p:continue
        if p[0]=="COVER":cover.update({k:int(v) for k,v in (s.split("=") for s in p[1:])})
        elif p[0]=="IRQ_LATENCY":max_latency=int(p[1].split("=")[1])
        elif p[0]=="CASE":current={"trace":[],"reads":[],"writes":[],"ints":[]};got[p[1]]=current
        elif current is not None and p[0]=="INT":current["ints"].append((len(current["trace"]),int(p[1],16)))
        elif current is not None and p[0] in {"READ","WRITE"}:current["reads" if p[0]=="READ" else "writes"].append(tuple(int(x,16) for x in p[1:]))
        elif current is not None and p[0]=="RET":
            t=tuple(int(x,16) for x in p[1:7])+tuple(int(x) for x in p[7:9])+(int(p[9],16),)
            if not t[6]:t=t[:-1]+(None,)
            current["trace"].append(t)
        elif current is not None and p[0]=="END":
            current["end"]=[int(v,16) if i in (3,4,5,6) else int(v) for i,v in enumerate(p[1:])]
    result=[];covered=set()
    for cfg in suite:
        a=got.get(cfg["name"])
        if not a or "end" not in a:raise AssertionError("case did not finish: "+cfg["name"])
        # The model enters the handler where the RTL did and checks the rest.
        e=model(cfg["words"],cfg["data"],cfg["ierror"],cfg["derror"],ints=[k for k,_ in a["ints"]])
        if a["ints"]!=e["ints"]:
            raise AssertionError(f'{cfg["name"]}: interrupt return PCs differ\nactual={a["ints"]}\nexpected={e["ints"]}')
        if len(a["ints"])<cfg.get("min_ints",0):
            raise AssertionError(f'{cfg["name"]}: {len(a["ints"])} interrupts, expected at least {cfg["min_ints"]}')
        if cfg.get("irq",(0,1,0))[2]==0 and a["ints"]:raise AssertionError(cfg["name"]+": interrupt without a request")
        for key in ("trace","reads","writes"):
            if a[key]!=e[key]:
                mismatch=next((i for i,(x,y) in enumerate(zip(a[key],e[key])) if x!=y),min(len(a[key]),len(e[key])))
                raise AssertionError(f'{cfg["name"]}: {key} mismatch at {mismatch}\nactual={a[key][max(0,mismatch-1):mismatch+2]}\nexpected={e[key][max(0,mismatch-1):mismatch+2]}')
        z=a["end"]
        expected_end=[1,int(bool(e["fault"])),e["pc"],e["registers"],e["x"],e["flags"],e["fault"]]
        if z[1:8]!=expected_end:raise AssertionError((cfg["name"],z,expected_end))
        if z[10:13]!=[len(e["reads"]),len(e["writes"]),e["rx"]]:raise AssertionError("bus count mismatch "+cfg["name"])
        if cfg["name"]=="first_add_wait0" and (z[8]<1 or z[9]<1):raise AssertionError("pipeline overlap/RAW stall not observed")
        covered.update(t[1]>>10 for t in e["trace"])
        result.append(dict(name=cfg["name"],retired=len(e["trace"]),cycles=z[0],stalls=z[8],three_stages=z[9],fault=e["fault"],interrupts=len(e["ints"])))
    assert covered==set(OPS.values()),("missing supported opcode",set(OPS.values())-covered)
    # Each AHB and interrupt corner case must have occurred at least once in the suite.
    if not cover or "int_taken" not in cover or min(cover.values())<1:
        raise AssertionError("corner case not exercised: "+str(cover))
    summary=dict(simulator=sim,default_demo_passed=True,program_cases=len(result),alu_cases=786432,reset_inflight_passed=True,all_20_opcodes_covered=True,total_retired=sum(x["retired"] for x in result),interrupts_taken=sum(x["interrupts"] for x in result),max_irq_latency_cycles=max_latency,corner_cases=cover,cases=result)
    (build/"results.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in summary.items() if k!="cases"},indent=2))
if __name__=="__main__":main()
