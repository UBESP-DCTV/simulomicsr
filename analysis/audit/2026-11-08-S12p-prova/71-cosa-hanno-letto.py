#!/usr/bin/env python3
# S12p, cancello L3: che cosa hanno aperto e scritto i 42 lettori. Base: analysis/audit/2026-08-21-S3-test-retest/
# 25-cosa-hanno-letto.py. Legge i transcript degli agenti (un JSONL per agente) e confronta ogni chiamata di strumento
# con cio' che la scheda permette: SCHEDA.md, il proprio lotto, i propri pacchetti, il proprio file di risposta.
# Uso: python3 -I 71-cosa-hanno-letto.py <cartella-transcript> <cartella-lettori>
import json, glob, os, re, sys, collections
TR, LET = sys.argv[1], sys.argv[2]
def testi(o, acc):
    if isinstance(o, str): acc.append(o)
    elif isinstance(o, dict): [testi(v, acc) for v in o.values()]
    elif isinstance(o, list): [testi(v, acc) for v in o]
risultati = {}; fuori = []; strumenti = collections.Counter()
for f in sorted(glob.glob(os.path.join(TR, '*.output'))):
    lotto = None; chiamate = []
    try:
        righe = open(os.path.realpath(f), encoding='utf-8', errors='replace').read().splitlines()
    except Exception:
        continue
    for line in righe:
        try: j = json.loads(line)
        except Exception: continue
        m = j.get('message') or {}
        c = m.get('content') if isinstance(m, dict) else None
        if lotto is None:
            acc = []; testi(c, acc)
            for t in acc:
                mm = re.search(r'Il tuo lotto è il (\d\d)', t)
                if mm: lotto = mm.group(1); break
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'tool_use':
                    chiamate.append((b.get('name'), b.get('input', {})))
    if lotto is None: continue
    ids = set(open(os.path.join(LET, f'lotto-{lotto}.txt')).read().split())
    ok_path = {os.path.join(LET, 'SCHEDA.md'), os.path.join(LET, f'lotto-{lotto}.txt'), os.path.join(LET, 'risposte', f'lotto-{lotto}.jsonl')}
    ok_path |= {os.path.join(LET, 'pacchetti', f'{i}.txt') for i in ids}
    letti = set(); estranei = []
    for nome, inp in chiamate:
        strumenti[nome] += 1
        if nome in ('Read', 'Write', 'Edit'):
            p = inp.get('file_path', '')
            if p not in ok_path: estranei.append(f'{nome} {p}')
            elif '/pacchetti/' in p: letti.add(os.path.basename(p)[:-4])
        elif nome == 'SubagentHandback':
            pass  # il rapporto finale dell'agente: non apre file
        elif nome == 'Bash':
            cmd = inp.get('command', '')
            cmd = re.sub(r"<<\s*'?(\w+)'?\n.*?\n\1\b", '<<TESTO', cmd, flags=re.S)  # il testo scritto con cat >> non e' un percorso
            percorsi = set(re.findall(r'(/(?:home|mnt|tmp|etc|root|var|opt|usr|proc)/[\w./-]*)', cmd))
            cattivi = [p for p in percorsi if p not in ok_path and not p.startswith(('/usr/', '/bin/', '/dev/null'))]
            if cattivi: estranei.append(f'Bash {cmd[:160]}')
        else:
            estranei.append(f'{nome} {json.dumps(inp)[:160]}')
    risultati[lotto] = (len(ids), len(letti & ids), estranei)
    fuori += [(lotto, e) for e in estranei]
print(f'transcript di lettori trovati: {len(risultati)} (attesi 42)')
print(f'pacchetti aperti / assegnati: {sum(v[1] for v in risultati.values())} / {sum(v[0] for v in risultati.values())}')
print('strumenti usati:', dict(strumenti))
print(f'chiamate fuori da cio\' che la scheda permette: {len(fuori)}')
for lotto, e in fuori: print(f'  lotto {lotto}: {e}')
mancanti = sorted(set(f'{i:02d}' for i in range(1, 43)) - set(risultati))
if mancanti: print('lotti senza transcript:', ' '.join(mancanti))
