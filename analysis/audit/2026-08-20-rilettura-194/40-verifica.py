#!/usr/bin/env python3
# analysis/audit/2026-08-20-rilettura-194/40-verifica.py
#
# DUE CONTROLLI SUL LAVORO DEI LETTORI, non sui dati.
#
# 1. ANTI-INVENZIONE. La regola era «un difetto si dichiara solo se e' leggibile
#    nell'etichetta che citi». Qui si verifica che le etichette citate ESISTANO
#    davvero nel materiale: si estraggono le stringhe fra apici dalla citazione e
#    si cercano nel file del blocco. Una citazione che non si trova e' un difetto
#    dichiarato su un'etichetta inventata, e va tolto.
#
# 2. SIMMETRIA DEI CRITICI. La trappola numero 5 del handout: un critico solo,
#    spinto alla severita', produce solo condanne (2026-08-05: 24 verdetti
#    cambiati, TUTTI verso il peggio, zero assoluzioni). Qui si misura quanti
#    rilievi ha prodotto ciascuno dei due e in che direzione, per vedere se la
#    simmetria ha funzionato davvero o se e' rimasta sulla carta.
#
# Uso: python3 analysis/audit/2026-08-20-rilettura-194/40-verifica.py

import json, glob, re, os, collections, csv

OUT = 'analysis/audit/2026-08-20-rilettura-194'
SRC = '/tmp/claude-1000/-home-user-simulomicsr/98fab4d5-ca37-4d30-8001-f1ce8293c5bc/tasks/whdbnu1wb.output'

# tutto il materiale, in un'unica stringa per blocco e una complessiva
blocchi = {}
for f in sorted(glob.glob(os.path.join(OUT, 'blocco-*.txt'))):
    blocchi[os.path.basename(f)] = open(f, errors='ignore').read()
tutto = "\n".join(blocchi.values())

# indice cluster -> blocco, per cercare nel posto giusto
dove = {}
for nome, txt in blocchi.items():
    for cid in re.findall(r'^## GRUPPO (\S+)', txt, re.M):
        dove[cid] = nome

def norm(s):
    # gli arbitri riscrivono gli apici e gli spazi; il confronto va fatto su un
    # testo normalizzato, altrimenti si contano differenze tipografiche
    s = s.replace('’', "'").replace('‘', "'")
    s = s.replace('“', '"').replace('”', '"')
    s = s.replace('→', ' ').replace(' ', ' ')
    return re.sub(r'\s+', ' ', s).strip().lower()

blocchi_n = {k: norm(v) for k, v in blocchi.items()}
tutto_n = norm(tutto)

d = json.load(open(SRC, errors='ignore'))
gruppi = d['result']['gruppi']

tot = 0; trovate = 0; mancanti = []
for g in gruppi:
    cid = g['cluster_id']
    bl = blocchi_n.get(dove.get(cid, ''), tutto_n)
    for s in g.get('studi_difettosi', []):
        cit = s['etichetta_citata']
        # LE ETICHETTE VERE SONO FRA VIRGOLETTE, e gli arbitri ne usano di cinque
        # tipi diversi: ' ' " " « » ` ` e le curve. La prima versione di questo
        # controllo cercava solo ' e ", quindi su una citazione scritta con « »
        # cercava l'INTERA frase («TRATTATO «X» vs CONTROLLO «Y»») come un unico
        # letterale, che ovviamente non si trova: 21 falsi «non ritrovati» su 21.
        # E' lo stesso errore che il progetto ha gia' pagato tre volte: lo
        # strumento vedeva meno del dato.
        pezzi = []
        for apri, chiudi in [("'", "'"), ('"', '"'), ('«', '»'), ('`', '`'),
                             ('‘', '’'), ('“', '”')]:
            pezzi += re.findall(re.escape(apri) + r'([^' + re.escape(chiudi) + r']{4,})' + re.escape(chiudi), cit)
        if not pezzi:
            pezzi = [cit]
        # un frammento con i puntini di sospensione e' un'ABBREVIAZIONE dell'arbitro,
        # non una citazione: si spezza sui puntini e si cercano i tronconi.
        espansi = []
        for p in pezzi:
            espansi += [q for q in re.split(r'\s*\.\.\.\s*|\s*…\s*', p) if len(q.strip()) >= 4]
        pezzi = espansi or pezzi
        for p in pezzi:
            tot += 1
            if norm(p) in bl:
                trovate += 1
            else:
                mancanti.append({'cluster_id': cid, 'study_id': s['study_id'],
                                 'frammento': p, 'categoria': s['categoria']})

print("=== 1. LE ETICHETTE CITATE ESISTONO NEL MATERIALE? ===")
print(f"  frammenti citati e cercati : {tot}")
print(f"  ritrovati nel blocco       : {trovate}  ({100*trovate/max(1,tot):.1f}%)")
print(f"  NON ritrovati              : {len(mancanti)}")
if mancanti:
    print("\n  I frammenti non ritrovati (vanno guardati uno per uno):")
    for m in mancanti[:40]:
        print(f"    [{m['study_id']}] {m['cluster_id']}  <<{m['frammento'][:90]}>>")
    with open(os.path.join(OUT, 'citazioni-non-ritrovate.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['cluster_id', 'study_id', 'frammento', 'categoria'])
        w.writeheader(); w.writerows(mancanti)

# --- 2. simmetria dei due critici --------------------------------------------
print("\n=== 2. I DUE CRITICI HANNO PESATO UGUALE? ===")
WF = ('/home/user/.claude/projects/-home-user-simulomicsr/'
      'ce316c82-cbaa-4950-aa30-cb91868fde08/subagents/workflows/wf_40052108-a99')
conte = collections.Counter(); direzioni = collections.defaultdict(collections.Counter)
for f in glob.glob(os.path.join(WF, 'agent-*.jsonl')):
    txt = open(f, errors='ignore').read()
    if 'CRITICO A' in txt: ruolo = 'critico A (accusato troppo)'
    elif 'CRITICO B' in txt: ruolo = 'critico B (accusato troppo poco)'
    else: continue
    # l'ultimo oggetto con "rilievi" e' l'output strutturato
    ril = None
    for m in re.finditer(r'\{"rilievi":\s*\[.*?\]\}', txt, re.S):
        try: ril = json.loads(m.group(0))
        except Exception: pass
    if ril is None: continue
    conte[ruolo] += len(ril['rilievi'])
    for r in ril['rilievi']:
        direzioni[ruolo][r.get('verdetto_proposto', '?')] += 1

for k in sorted(conte):
    print(f"  {k}: {conte[k]} rilievi   -> {dict(direzioni[k])}")
if len(conte) == 2:
    a, b = [conte[k] for k in sorted(conte)]
    print(f"  rapporto fra i due: {a}/{b} = {a/max(1,b):.2f}")
    print("  (un rapporto molto lontano da 1 vuol dire che la simmetria e' rimasta sulla carta)")
