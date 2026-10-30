#!/usr/bin/env python3
"""Run existing CPU/RAM checks; compile/elaborate the existing UART inputs."""
import argparse, json, os, re, shutil, subprocess
from pathlib import Path
from datetime import datetime, timezone, timedelta

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('block',choices=['cpu','ram','uart','all'])
    p.add_argument('--vivado-bin',type=Path)
    p.add_argument('--build-dir',type=Path)
    a=p.parse_args()
    configs=json.loads((ROOT/'sources.json').read_text())
    build=(a.build_dir or ROOT/'build/unit').resolve();build.mkdir(parents=True,exist_ok=True)
    def tool(name):
        path=a.vivado_bin/name if a.vivado_bin else shutil.which(name)
        if not path or not Path(path).is_file(): raise RuntimeError('Vivado tool not found: '+name)
        return str(path)
    def run(cmd,cwd,label):
        result=subprocess.run(list(map(str,cmd)),cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
        text=result.stdout.decode('utf-8',errors='replace');log=cwd/(label+'.log');log.write_text(text)
        if result.returncode or re.search(r'(^|\n)(ERROR:|FATAL|FAIL)',text):
            raise RuntimeError('Command failed; see '+str(log)+'\n'+text[-1800:])
        return text
    records=[]
    for block in (['cpu','ram','uart'] if a.block=='all' else [a.block]):
        cfg=configs[block];cwd=build/block;cwd.mkdir(exist_ok=True)
        inputs=[ROOT/x for group in ['rtl','models','tb','board'] for x in cfg.get(group,[])]
        includes=[v for x in cfg['include'] for v in ['-i',ROOT/x]]
        run([tool('xvlog'),'--sv','--work','work',*includes,*inputs],cwd,'compile')
        tops=[cfg['top']] if 'top' in cfg else cfg['tops']
        for top in tops:
            timing=['--timescale','1ns/1ps','--override_timeunit','--override_timeprecision'] if block=='uart' else []
            run([tool('xelab'),'work.'+top,'--snapshot',top,'--debug','typical',*timing],cwd,top+'_elaborate')
            if block=='uart':
                print('UART_ELABORATION_PASS:',top)
                records.append({'block':block,'top':top,'result':'compile/elaboration PASS','function_test':False})
            else:
                text=run([tool('xsim'),top,'-runall'],cwd,top+'_run')
                if cfg['expected'] not in text: raise RuntimeError('Missing PASS marker for '+top)
                markers=[x.strip() for x in text.splitlines() if 'PASS' in x]
                print('\n'.join(markers))
                records.append({'block':block,'top':top,'result':'simulation PASS','markers':markers})
    report={'recorded_at':datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds'),'results':records}
    (build/('result_'+a.block+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('UNIT_CHECKS_DONE:',a.block,'logs:',build)

if __name__=='__main__':main()
