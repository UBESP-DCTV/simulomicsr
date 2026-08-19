#!/usr/bin/env python3
# analysis/audit/2026-08-20-rilettura-194/60-meccanismi.py
#
# I MECCANISMI DELLA DIVERGENZA, che sono la parte utile al metodo.
#
# Sapere che il 26,5% degli studi sta peggio e il 21,9% meglio non dice cosa
# correggere. Qui si guarda PERCHE': si raggruppano i motivi dei giudizi
# comparativi per meccanismo, e si separa il caso A (il nuovo peggiora) dal caso
# B (il nuovo migliora), perche' portano a due azioni diverse.
#
# Come sempre: si conta per STUDIO, non per destinazione.
#
# Uso: python3 analysis/audit/2026-08-20-rilettura-194/60-meccanismi.py

import csv, re, collections, os

OUT = 'analysis/audit/2026-08-20-rilettura-194'
righe = list(csv.DictReader(open(os.path.join(OUT, 'comparativo.csv'))))

MECC = [
 ('il tipo di controllo e stato normalizzato diversamente',
  r'tipo di controllo|control_key|vehicle_untreated|unknown|normalizzat.*controllo|chiave di controllo'),
 ('lo studio cambia gruppo / entita',
  r'spostat|altra chiave|cambia gruppo|altra entit|entita.*divers|riassegnat'),
 ('lo studio entra o esce dal pooling',
  r'entrato|uscito|non era poolat|non e.? piu.? poolat|non compare|caduto|scomparso'),
 ('cambia quali confronti dello studio sopravvivono',
  r'confronti cambian|numero di confronti|un confronto in piu|in meno|n_min|scartat'),
 ('solo la formulazione dell etichetta cambia',
  r'formulazion|riscritt|solo il testo|piu.? esplicit|stesso contrasto|cambia il verbo|sinonim|verbale|dicitura'),
 ('l appaiamento del braccio di controllo cambia',
  r'appaia|controllo divers|stesso controllo|controllo condiviso|braccio di controllo'),
 ('cambia la granularita: etichetta piu ricca o piu povera',
  r'piu.? ricc|piu.? povera|prefiss|linea cellulare.*aggiunt|granularit|dettagli|specific'),
 ('il tempo o la dose vengono dichiarati o persi',
  r'tempo|dose|durat|\bh\b|ore|concentraz'),
]

def mecc(t):
    t = t.lower()
    for nome, rx in MECC:
        if re.search(rx, t, re.I):
            return nome
    return 'altro'

# per STUDIO: un motivo per studio, prendendo il caso peggiore (A > B > C) come
# nel resto dell'analisi, e il meccanismo del giudizio corrispondente
per_studio = {}
for r in righe:
    sid, caso = r['study_id'], r['caso']
    prec = per_studio.get(sid)
    rank = {'A': 0, 'B': 1, 'C': 2}
    if prec is None or rank[caso] < rank[prec['caso']]:
        per_studio[sid] = {'caso': caso, 'motivo': r['motivo']}

print(f"studi con un giudizio comparativo: {len(per_studio)}")
print(f"giudizi totali (coppie gruppo-studio): {len(righe)}\n")

for caso, titolo in [('A', "CASO A — il NUOVO sbaglia dove il vecchio azzeccava"),
                     ('B', "CASO B — il NUOVO azzecca dove il vecchio sbagliava"),
                     ('C', "CASO C — entrambe difendibili, l'etichetta e' ambigua")]:
    sub = [v for v in per_studio.values() if v['caso'] == caso]
    print(f"=== {titolo}  ({len(sub)} studi) ===")
    c = collections.Counter(mecc(v['motivo']) for v in sub)
    for k, v in c.most_common():
        print(f"   {v:4d}  ({100*v/max(1,len(sub)):5.1f}%)  {k}")
    print()

# il meccanismo dominante complessivo, e quanto pesa
tuttic = collections.Counter(mecc(v['motivo']) for v in per_studio.values())
tot = sum(tuttic.values())
print("=== TUTTI I MECCANISMI, su tutti gli studi che divergono ===")
for k, v in tuttic.most_common():
    print(f"   {v:4d}  ({100*v/tot:5.1f}%)  {k}")

with open(os.path.join(OUT, 'meccanismi-divergenza.csv'), 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['study_id', 'caso', 'meccanismo', 'motivo'])
    for sid, v in sorted(per_studio.items()):
        w.writerow([sid, v['caso'], mecc(v['motivo']), v['motivo']])
print("\nScritto meccanismi-divergenza.csv")
