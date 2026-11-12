# Passata di coerenza: una scheda (studio, firma, unita') letta una volta vale per piu' corse. La firma non vede il livello di
# base ne' il motivo per cui lo studio non chiude. Questo controllo riunisce le corse di ogni scheda per (motivi estesi, basi dei
# fattori) e scrive le schede in cui le corse non sono uguali: quelle vanno rilette corsa per corsa.
# Uso: python3 schede_condivise.py <cartella audit>
import csv,json,collections,sys,os
D=sys.argv[1].rstrip('/')+'/'
ps={(r['corsa'],r['studio']):r for r in csv.DictReader(open(D+"24-per-studio.csv"))}
raws={}
def basi(k,g):
    if (k,g) not in raws:
        raws[(k,g)]='uscita non leggibile'
        for l in open(f'analysis/p4-output/S12r4-forme/{k}.jsonl'):
            if g not in l: continue
            d=json.loads(l)
            try: x=json.loads(d['raw'])
            except Exception: continue
            if x.get('series_id')==g: raws[(k,g)]=' ; '.join(sorted(f"{str(f.get('name')).lower()}=«{str(f.get('baseline_level') or '').lower()}»" for f in x.get('factors',[])))
    return raws[(k,g)]
sch=collections.defaultdict(set)
for r in csv.DictReader(open(D+"24-da-leggere-righe.csv")): sch[r['scheda']].add((r['corsa'],r['studio']))
let={}
for r in csv.DictReader(open(D+"26-letture.csv")): let.setdefault(r['scheda'],(r['causa'],r['errore']))
n=0
for s,cc in sorted(sch.items()):
    if len(cc)<2: continue
    gr=collections.defaultdict(list)
    for k,g in sorted(cc): gr[(ps[(k,g)]['motivi_estesi'], basi(k,g))].append(k)
    if len(gr)>1:
        n+=1; print(f"\n=== {s} | {let.get(s)}")
        for (m,b),kk in gr.items(): print(f"   {' '.join(kk)}\n      motivi: {m[:300]}\n      basi: {b[:300]}")
print(f"\nschede condivise da piu' corse: {sum(len(c)>1 for c in sch.values())}; con corse non uguali: {n}")
