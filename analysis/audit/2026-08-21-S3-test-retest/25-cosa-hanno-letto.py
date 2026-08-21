#!/usr/bin/env python3
# analysis/audit/2026-08-21-S3-test-retest/25-cosa-hanno-letto.py
# Che cosa hanno letto gli agenti, per ruolo, in ciascun run: i tool usati e le
# fonti toccate OLTRE il blocco-XX.txt assegnato. Serve a dire se due run hanno
# visto lo stesso materiale — condizione del test-retest che il prompt da solo
# non garantisce.
# Uso: python3 25-cosa-hanno-letto.py <nome>=<dir_transcript_workflow> [...]
import json, glob, re, collections, os, sys
RUOLI = [('LETTORE', 'Sei il LETTORE'), ('CRITICO A', 'Sei il CRITICO A'),
         ('CRITICO B', 'Sei il CRITICO B'), ('ARBITRO', "Sei l'ARBITRO")]
CONTAMINANTI = ('verdetti-194', 'difetti.csv', 'INDICE-194', 'quadro-194', 'tassonomia', 'comparativo',
                'schede/', 'campioni-per-meta-analisi', 'master-innestato', 'per_study_de', 'deliverable-annotato',
                'verdetti-retest', 'risultato-')
def testi(obj, acc):
    if isinstance(obj, str): acc.append(obj)
    elif isinstance(obj, dict):
        for v in obj.values(): testi(v, acc)
    elif isinstance(obj, list):
        for v in obj: testi(v, acc)
def analizza(d):
    per = collections.defaultdict(lambda: {'n': 0, 'tool': collections.Counter(), 'fonti': collections.Counter(),
                                           'oltre': 0, 'contaminati': 0, 'file': []})
    for f in sorted(glob.glob(os.path.join(d, 'agent-*.jsonl'))):
        ruolo = '?'; tools = collections.Counter(); fonti = set()
        for line in open(f):
            try: j = json.loads(line)
            except Exception: continue
            m = j.get('message') or {}
            c = m.get('content') if isinstance(m, dict) else None
            acc = []; testi(c, acc)
            if ruolo == '?':
                for r, k in RUOLI:
                    if any(k in t for t in acc): ruolo = r; break
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get('type') == 'tool_use':
                        tools[b['name']] += 1
                        s = json.dumps(b.get('input', {}), ensure_ascii=False)
                        for mm in re.findall(r'[\w./~-]*[\w-]+\.(?:csv|rds|parquet|jsonl|json|R|py|txt|md|gz|h5)\b|schede/', s):
                            fonti.add(mm)
        oltre = {x for x in fonti if not re.search(r'blocco-\d\d\.txt$', x)}
        x = per[ruolo]; x['n'] += 1; x['tool'].update(tools); x['fonti'].update(os.path.basename(o.rstrip('/')) or o for o in oltre)
        if oltre: x['oltre'] += 1
        if any(any(k in o for k in CONTAMINANTI) for o in oltre): x['contaminati'] += 1; x['file'].append(os.path.basename(f))
    return per
for arg in sys.argv[1:]:
    nome, d = arg.split('=', 1)
    per = analizza(d)
    print(f"\n===== {nome} ({sum(x['n'] for x in per.values())} agenti) =====")
    for r in [r for r, _ in RUOLI] + ['?']:
        if r not in per: continue
        x = per[r]
        print(f"{r:10s} n={x['n']:2d}  tool={dict(x['tool'])}")
        print(f"{'':10s} leggono OLTRE il blocco: {x['oltre']}/{x['n']}   con fonti CONTAMINANTI (verdetti, schede, stringhe grezze): {x['contaminati']}/{x['n']}")
        if x['fonti']: print(f"{'':10s} fonti: {dict(x['fonti'].most_common(10))}")
