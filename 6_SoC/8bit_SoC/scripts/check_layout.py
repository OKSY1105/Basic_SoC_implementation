#!/usr/bin/env python3
"""Check explicit source lists, compatibility aliases and Vivado input paths."""
import json, re, xml.etree.ElementTree as ET
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]

def main():
    errors=[];checked=0
    cfg=json.loads((ROOT/'sources.json').read_text())
    for block in ['cpu','ram','uart']:
        for group in ['rtl','models','tb','board','headers','include']:
            for name in cfg[block].get(group,[]):
                checked+=1
                if not (ROOT/name).exists():errors.append('Missing input: '+name)
    migration=json.loads((ROOT/'03_setup/migration.json').read_text())
    for pair in migration['aliases']:
        old=REPO/pair['old'];new=REPO/pair['new'];checked+=1
        if not old.is_symlink() or old.resolve()!=new.resolve():errors.append('Broken alias: '+pair['old'])
    for name in migration['projects']:
        project=ROOT/name
        for node in ET.parse(project).iter('File'):
            value=node.get('Path','')
            if not value:continue
            checked+=1
            resolved=value.replace('$PPRDIR',str(project.parent)).replace('$PSRCDIR',str(project.parent/(project.stem+'.srcs')))
            if not Path(resolved).exists():errors.append('Missing XPR input: '+value)
    # Check the new navigation documents; legacy CPU documents remain historic evidence.
    for name in migration['new_markdown']:
        path=ROOT/name
        text=path.read_text(encoding='utf-8')
        for target in re.findall(r'\]\(([^)]+)\)',text):
            if target.startswith(('https://','http://','#')):continue
            target=target.split('#',1)[0]
            checked+=1
            if not (path.parent/target).exists():errors.append(str(path.relative_to(ROOT))+': '+target)
    if errors:raise SystemExit('\n'.join(errors))
    print('LAYOUT_PASS:',checked,'source/link/project checks; CPU/RAM simulation is separate')

if __name__=='__main__':main()
