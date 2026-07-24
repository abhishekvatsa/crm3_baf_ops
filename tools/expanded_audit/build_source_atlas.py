#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import csv, re, json, collections

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / 'lib'
TEST = ROOT / 'test'
FUN = ROOT / 'functions'

DART_IMPORT = re.compile(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]")
TS_IMPORT = re.compile(r"(?:from\s+|require\()['\"]([^'\"]+)['\"]")


def lines(p: Path) -> list[str]:
    try:
        return p.read_text(encoding='utf-8', errors='ignore').splitlines()
    except Exception:
        return []


def resolve_dart(source: Path, spec: str) -> Path | None:
    if spec.startswith('dart:') or spec.startswith('package:flutter') or spec.startswith('package:firebase') or spec.startswith('package:cloud_') or spec.startswith('package:isar') or spec.startswith('package:riverpod') or spec.startswith('package:connectivity') or spec.startswith('package:shared_') or spec.startswith('package:path_') or spec.startswith('package:crypto') or spec.startswith('package:uuid') or spec.startswith('package:intl'):
        return None
    if spec.startswith('package:crm3_baf_ops/'):
        return ROOT / 'lib' / spec.removeprefix('package:crm3_baf_ops/')
    if spec.startswith('package:'):
        return None
    return (source.parent / spec).resolve()


def resolve_ts(source: Path, spec: str) -> Path | None:
    if not spec.startswith('.'):
        return None
    base = (source.parent / spec).resolve()
    candidates = [base, base.with_suffix('.ts'), base / 'index.ts', base.with_suffix('.js')]
    for c in candidates:
        if c.exists(): return c
    return None

sources: list[Path] = []
for p in LIB.rglob('*.dart'):
    if p.name.endswith('.g.dart'): continue
    sources.append(p)
for p in (FUN/'src').rglob('*.ts'):
    sources.append(p)
for p in [ROOT/'firestore.rules', ROOT/'firestore.indexes.json', ROOT/'firebase.json', ROOT/'pubspec.yaml', ROOT/'analysis_options.yaml']:
    if p.exists(): sources.append(p)
for p in (ROOT/'android').rglob('*'):
    if p.is_file() and p.suffix in {'.kts','.kt','.xml','.properties'}:
        sources.append(p)
for p in (ROOT/'.github').rglob('*'):
    if p.is_file() and p.suffix in {'.yml','.yaml'}: sources.append(p)
for p in (ROOT/'tools').rglob('*'):
    if p.is_file() and p.suffix in {'.py','.mjs','.js','.ps1'} and 'expanded_audit' not in p.parts:
        sources.append(p)

sources = sorted(set(p.resolve() for p in sources))
source_set = set(sources)
incoming: dict[Path, set[Path]] = collections.defaultdict(set)
outgoing: dict[Path, set[Path]] = collections.defaultdict(set)

for p in sources:
    txt='\n'.join(lines(p))
    if p.suffix == '.dart':
        specs=DART_IMPORT.findall(txt)
        resolver=resolve_dart
    elif p.suffix == '.ts':
        specs=TS_IMPORT.findall(txt)
        resolver=resolve_ts
    else:
        specs=[]; resolver=None
    for spec in specs:
        q=resolver(p,spec) if resolver else None
        if q and q.exists():
            q=q.resolve()
            outgoing[p].add(q)
            incoming[q].add(p)

# Test text/index
all_tests=[]
for p in TEST.rglob('*.dart'):
    all_tests.append((p, '\n'.join(lines(p))))
for p in (FUN/'test').rglob('*'):
    if p.suffix in {'.js','.ts'}: all_tests.append((p,'\n'.join(lines(p))))

rows=[]
for p in sources:
    ls=lines(p); txt='\n'.join(ls); rel=p.relative_to(ROOT).as_posix()
    tags=[]; score=0
    def add(tag,w):
        nonlocal_score[0]+=w
        tags.append(tag)
    nonlocal_score=[0]
    low=txt.lower()
    if any(x in low for x in ['role','permission','authority','isauthorized','isapproved','canview','cansubmit']): add('authority',4)
    if any(x in txt for x in ['FirebaseFirestore','firestore','writeTxn','Isar','toMap()','fromMap']): add('persistence',4)
    if any(x in low for x in ['sync','watermark','tombstone','retry','outbox','pull','push']): add('sync',4)
    if any(x in low for x in ['assign','complete','close','archive','restore','publish','lifecycle']): add('lifecycle',3)
    if any(x in low for x in ['notification','firebase_messaging','fcm','messaging']): add('notification',3)
    if any(x in low for x in ['appcheck','security','token','signing','keystore','applicationid','namespace','release']): add('security_identity',4)
    if p.name in {'main.dart','home_screen.dart','firestore.rules','firestore.indexes.json','pubspec.yaml','settings.gradle.kts','build.gradle.kts'}: add('platform_root',5)
    if len(ls)>1000: add('large',3)
    elif len(ls)>500: add('medium_large',1)
    broad_catches=len(re.findall(r'catch\s*\((?:_|e|error)\)',txt)) + len(re.findall(r'catch\s*\{',txt))
    empty_catches=len(re.findall(r'catch\s*\([^)]*\)\s*\{\s*\}',txt,re.S))
    direct_writes=len(re.findall(r'\.(?:set|update|delete|add)\s*\(',txt)) if p.suffix in {'.dart','.ts'} else 0
    serializers=len(re.findall(r'\b(?:toMap|fromMap|toJson|fromJson)\b',txt))
    if empty_catches: add('empty_catch',5)
    if direct_writes>=5: add('many_remote_writes',3)
    if serializers>=4: add('serialization_hub',3)
    inc=len(incoming.get(p,set())); out=len(outgoing.get(p,set()))
    nonlocal_score[0]+=min(inc,15)
    test_hits=[]
    stem=p.stem.replace('.','_')
    rel_import='package:crm3_baf_ops/'+rel.removeprefix('lib/') if rel.startswith('lib/') else rel
    for tp,tt in all_tests:
        if rel_import in tt or p.name in tt or stem in tp.name:
            test_hits.append(tp.relative_to(ROOT).as_posix())
    if not test_hits and ('lib/' in rel or 'functions/src/' in rel):
        nonlocal_score[0]+=2
        tags.append('no_direct_test_reference')
    rows.append({
        'risk_score':nonlocal_score[0], 'file':rel,'lines':len(ls),'incoming':inc,'outgoing':out,
        'direct_writes':direct_writes,'serializers':serializers,'broad_catches':broad_catches,'empty_catches':empty_catches,
        'test_refs':len(test_hits),'tags':','.join(dict.fromkeys(tags)),
        'sample_tests':' | '.join(test_hits[:4]) or '-',
    })
rows.sort(key=lambda r:(-r['risk_score'],-r['incoming'],-r['lines'],r['file']))
out=ROOT/'docs/expanded_audit/WHOLE_APP_SOURCE_ATLAS.tsv'
with out.open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=rows[0].keys(),delimiter='\t',lineterminator='\n'); w.writeheader(); w.writerows(rows)

summary=collections.Counter()
for r in rows:
    for t in r['tags'].split(','):
        if t: summary[t]+=1
md=ROOT/'docs/expanded_audit/WHOLE_APP_SOURCE_ATLAS.md'
with md.open('w',encoding='utf-8') as f:
    f.write('# Whole-App Source Atlas\n\n')
    f.write(f'- Source/config files inventoried: **{len(rows)}**\n')
    f.write(f'- Application Dart source (excluding generated): **{sum(1 for p in sources if p.suffix==".dart")}**\n')
    f.write(f'- Functions TypeScript source: **{sum(1 for p in sources if p.suffix==".ts")}**\n')
    f.write(f'- Test files indexed: **{len(all_tests)}**\n\n')
    f.write('## Risk-tag counts\n\n')
    for k,v in summary.most_common(): f.write(f'- `{k}`: {v}\n')
    f.write('\n## Highest-priority source surfaces\n\n')
    f.write('| Score | File | Lines | Incoming | Tests | Tags |\n|---:|---|---:|---:|---:|---|\n')
    for r in rows[:80]:
        f.write(f"| {r['risk_score']} | `{r['file']}` | {r['lines']} | {r['incoming']} | {r['test_refs']} | {r['tags']} |\n")
print(out)
print(md)
