#!/usr/bin/env python3
"""Assembler for the documented 20-instruction CPU8 ISA; no dependencies.
Directives: .org ADDR, .word VALUE, .equ NAME, VALUE. Immediates take a
number, a .equ name or a character literal 'c'."""
import argparse,re
from pathlib import Path

OPS={"HALT":1,"LDI":2,"MOV":3,"LD":4,"ST":5,"LDXL":6,"LDXH":7,"INX":8,
     "ADD":9,"ADC":10,"SUB":11,"CMP":12,"AND":13,"JMP":20,"JZ":21,"JC":23,"SBC":26,
     "EI":24,"DI":25,"RETI":27}
RR={"MOV","ADD","ADC","SUB","SBC","CMP","AND"}
BR={"JMP","JZ","JC"}
NOARG={"HALT","INX","EI","DI","RETI"}
IRQ_VECTOR=2

def number(s):
    # 'c': character code (any printable character except , ; : which the
    # line parser splits on; use .equ for those).
    if len(s)==3 and s[0]==s[2]=="'":return ord(s[1])
    try:return int(s,0)
    except ValueError:
        if re.fullmatch(r"-?\d+",s):return int(s,10)
        raise ValueError("invalid integer: "+s)
def register(s):
    if not re.fullmatch(r"R[0-3]",s.upper()):raise ValueError("register must be R0..R3: "+s)
    return int(s[-1])
def assemble(text):
    labels={};consts={};rows=[];pc=0
    # Immediates, .org and .word take a number, a character or a .equ name.
    def value(s):
        return consts[s] if s in consts else number(s)
    for line_no,line in enumerate(text.splitlines(),1):
        line=line.split(";",1)[0].strip()
        if not line:continue
        if ":" in line:
            label,line=line.split(":",1);label=label.strip()
            if not re.fullmatch(r"[A-Za-z_]\w*",label) or label in labels:
                raise ValueError(f"line {line_no}: invalid/duplicate label")
            labels[label]=pc;line=line.strip()
            if not line:continue
        head,*tail=line.split(None,1);head=head.upper()
        args=[s.strip() for s in tail[0].split(",")] if tail else []
        if head==".EQU":
            # .equ NAME, value: a constant, defined before it is used.
            if len(args)!=2 or not re.fullmatch(r"[A-Za-z_]\w*",args[0]) or \
               args[0] in consts or re.fullmatch(r"[Rr][0-3]",args[0]):
                raise ValueError(f"line {line_no}: .equ takes a new name and a value")
            try:consts[args[0]]=value(args[1])
            except ValueError as e:raise ValueError(f"line {line_no}: {e}") from e
            continue
        if head==".ORG":
            if len(args)!=1:raise ValueError(".org takes one word address")
            pc=value(args[0])
            if not 0<=pc<=65535:raise ValueError(".org out of range")
            continue
        rows.append((pc,head,args,line_no));pc+=1
        if pc>65536:raise ValueError("program address overflow")
    clash=sorted(set(labels)&set(consts))
    if clash:raise ValueError("name used as both label and .equ: "+", ".join(clash))
    words={}
    for pc,op,a,line_no in rows:
        try:
            rd=0;operand=0
            if op==".WORD":
                if len(a)!=1:raise ValueError(".word takes one value")
                word=value(a[0])
                if not 0<=word<=65535:raise ValueError("word out of range")
            else:
                if op not in OPS:raise ValueError("unknown opcode "+op)
                if op in NOARG:
                    if a:raise ValueError("instruction takes no operands")
                elif op in RR:
                    if len(a)!=2:raise ValueError("two registers required")
                    rd=register(a[0]);operand=register(a[1])
                elif op=="LDI":
                    if len(a)!=2:raise ValueError("register and imm8 required")
                    rd=register(a[0]);operand=value(a[1])
                    if not -128<=operand<=255:raise ValueError("imm8 out of range")
                    operand&=255
                elif op in {"LDXL","LDXH"}:
                    if len(a)!=1:raise ValueError("one imm8 required")
                    operand=value(a[0])
                    if not 0<=operand<=255:raise ValueError("X byte out of range")
                elif op in {"LD","ST"}:
                    if len(a)!=2:raise ValueError("register and [X] required")
                    mem=a[1] if op=="LD" else a[0]
                    if mem.upper().replace(" ","")!="[X]":raise ValueError("address must be [X]")
                    rd=register(a[0] if op=="LD" else a[1])
                elif op in BR:
                    if len(a)!=1:raise ValueError("one label/displacement required")
                    if a[0] in labels:
                        operand=(labels[a[0]]-(pc+1))&65535
                        if operand>=32768:operand-=65536
                    else:operand=value(a[0])
                    if not -128<=operand<=127:raise ValueError("rel8 branch out of range")
                    operand&=255
                word=(OPS[op]<<10)|(rd<<8)|operand
            if pc in words:raise ValueError("overlapping .org addresses")
            words[pc]=word
        except ValueError as e:raise ValueError(f"line {line_no}: {e}") from e
    return words

def write_mem(words,path,width=4):
    lines=[];previous=-2
    for addr,value in sorted(words.items()):
        if addr!=previous+1:lines.append(f"@{addr:04x}")
        lines.append(f"{value:0{width}x}");previous=addr
    Path(path).write_text("\n".join(lines)+"\n",encoding="ascii")
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("source",type=Path);p.add_argument("-o","--output",required=True,type=Path)
    a=p.parse_args();a.output.parent.mkdir(parents=True,exist_ok=True)
    write_mem(assemble(a.source.read_text(encoding="utf-8")),a.output)
