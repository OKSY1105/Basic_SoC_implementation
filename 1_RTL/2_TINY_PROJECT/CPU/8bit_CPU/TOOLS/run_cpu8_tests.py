#!/usr/bin/env python3
"""Compile RTL, run an independent ISA/retirement comparison and ALU/reset tests."""
import argparse,json,os,random,re,shutil,subprocess,sys
from pathlib import Path
from cpu8_asm import assemble,write_mem,OPS,RR,BR

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

def model(words,data=None,ierror=-1,derror=-1):
    r=[0]*4;x=0;f=0;pc=0;traces=[];reads=[];writes=[];memory=dict(data or {});rx=0
    fault=0
    reverse={v:k for k,v in OPS.items()}
    for step in range(10000):
        if pc not in words or pc==ierror:fault=2;break
        ins=words[pc];op=reverse.get(ins>>10);rd=(ins>>8)&3;imm=ins&255;rs=imm&3
        legal=op is not None
        if op in RR:legal=legal and imm<4
        elif op in {"LD","ST"}:legal=legal and imm==0
        elif op in {"LDXL","LDXH"}|BR:legal=legal and rd==0
        elif op in {"HALT","INX"}:legal=legal and (ins&1023)==0
        if not legal:fault=1;break
        nextpc=(pc+1)&65535;rw=0;value=0
        if op=="LDI":value=imm;rw=1
        elif op=="MOV":value=r[rs];rw=1
        elif op in {"ADD","ADC","SUB","SBC","CMP","AND"}:
            value,f=arithmetic(op,r[rd],r[rs],(f>>1)&1);rw=op!="CMP"
        elif op=="LDXL":x=(x&65280)|imm
        elif op=="LDXH":x=(imm<<8)|(x&255)
        elif op=="INX":x=(x+1)&65535
        elif op in BR:
            take=op=="JMP" or (op=="JZ" and bool(f&8)) or (op=="JC" and bool(f&2))
            if take:nextpc=(nextpc+SIGNED(imm))&65535
        elif op in {"LD","ST"}:
            mapped=x<2048 or (op=="LD" and x in (0xff00,0xff02)) or (op=="ST" and x==0xff01)
            if not mapped or x==derror:fault=3;break
            if op=="LD":
                value=memory.get(x,0) if x<2048 else (64+rx if x==0xff00 else 1)
                value%=256;rw=1;reads.append((x,value))
                if x==0xff00:rx+=1
            else:
                value=r[rd];writes.append((x,value))
                if x<2048:memory[x]=value
        if rw:r[rd]=value
        regs=sum(v<<(8*i) for i,v in enumerate(r))
        traces.append((pc,ins,regs,x,f,nextpc,int(rw),rd,value if rw else None))
        pc=nextpc
        if op=="HALT":break
    else:raise AssertionError("reference watchdog")
    regs=sum(v<<(8*i) for i,v in enumerate(r))
    return dict(trace=traces,reads=reads,writes=writes,pc=pc,registers=regs,x=x,flags=f,fault=fault,rx=rx)

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
        command=[os.environ.get("COMSPEC","cmd.exe"),"/d","/c",*command]
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
            command=["iverilog","-g2012","-I",str(ROOT/"RTL"),"-s",top,"-o",str(build/(top+".vvp")),*map(str,rtl),str(ROOT/"TB"/(top+".sv"))]
            run(command,build,top+"_compile.log")
    else:
        run([tool("xvlog"),"--sv","-i",ROOT/"RTL",*rtl,*[ROOT/"TB"/(t+".sv") for t in tops]],build,"xvlog_cpu8.log")
        for top in tops:run([tool("xelab"),top,"-s",top+"_snapshot"],build,top+"_elaborate.log")
    suite=list(cases());lines=[]
    for cfg in suite:
        rp=fixtures/(cfg["name"]+".mem");dp=fixtures/(cfg["name"]+".data")
        write_mem(cfg["words"],rp);write_mem(cfg["data"] or {0:0},dp,2)
        cfg["expected"]=model(cfg["words"],cfg["data"],cfg["ierror"],cfg["derror"])
        lines.append(f'{cfg["name"]} {rp.as_posix()} {dp.as_posix()} {cfg["mode"]} {cfg["seed"]} {cfg["ierror"]} {cfg["derror"]}')
    manifest=build/"cases.txt";manifest.write_text("\n".join(lines)+"\n",encoding="ascii")
    for top in tops:
        if sim=="iverilog":
            plus=["+CASES="+manifest.as_posix()] if top=="tb_cpu8_top" else []
            outputs[top]=run(["vvp",build/(top+".vvp"),*plus],build,top+"_run.log")
        else:
            plus=["-testplusarg","CASES="+manifest.as_posix()] if top=="tb_cpu8_top" else []
            outputs[top]=run([tool("xsim"),top+"_snapshot","-runall",*plus],build,top+"_run.log")
    if "ALU_PASS 786432" not in outputs["tb_cpu8_alu"]:raise AssertionError("ALU test did not finish")
    if "RESET_PASS" not in outputs["tb_cpu8_reset"]:raise AssertionError("reset test did not finish")
    got={};current=None
    for raw in outputs["tb_cpu8_top"].splitlines():
        line=raw.strip();p=line.split()
        if not p:continue
        if p[0]=="CASE":current={"trace":[],"reads":[],"writes":[]};got[p[1]]=current
        elif current is not None and p[0] in {"READ","WRITE"}:current["reads" if p[0]=="READ" else "writes"].append(tuple(int(x,16) for x in p[1:]))
        elif current is not None and p[0]=="RET":
            t=tuple(int(x,16) for x in p[1:7])+tuple(int(x) for x in p[7:9])+(int(p[9],16),)
            if not t[6]:t=t[:-1]+(None,)
            current["trace"].append(t)
        elif current is not None and p[0]=="END":
            current["end"]=[int(v,16) if i in (3,4,5,6) else int(v) for i,v in enumerate(p[1:])]
    result=[];covered=set()
    for cfg in suite:
        a=got.get(cfg["name"]);e=cfg["expected"]
        if not a or "end" not in a:raise AssertionError("case did not finish: "+cfg["name"])
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
        result.append(dict(name=cfg["name"],retired=len(e["trace"]),cycles=z[0],stalls=z[8],three_stages=z[9],fault=e["fault"]))
    assert covered==set(OPS.values()),("missing supported opcode",set(OPS.values())-covered)
    summary=dict(simulator=sim,program_cases=len(result),alu_cases=786432,reset_inflight_passed=True,all_17_opcodes_covered=True,total_retired=sum(x["retired"] for x in result),cases=result)
    (build/"results.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in summary.items() if k!="cases"},indent=2))
if __name__=="__main__":main()
