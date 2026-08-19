#!/usr/bin/env python3
# analysis/audit/2026-08-20-rilettura-194/30-consolida.py
#
# Consolida i verdetti degli arbitri in tabelle, e costruisce la TASSONOMIA.
#
# DUE REGOLE DI CONTEGGIO, entrambe gia' costate al progetto:
#  - si conta per STUDIO, non per destinazione: uno studio di screening con
#    duecento composti dominerebbe da solo qualunque conteggio per destinazione.
#    Quindi il difetto "GSE199800 ha il donatore diverso" vale UNO, anche se
#    quello studio compare in trenta meta-analisi;
#  - i verdetti che l'etichetta NON ha chiuso si contano e si dichiarano, non si
#    nascondono dentro "corretta".
#
# Uso: python3 analysis/audit/2026-08-20-rilettura-194/30-consolida.py <file-workflow>

import json, sys, csv, collections, re, os

SRC = sys.argv[1] if len(sys.argv) > 1 else \
    '/tmp/claude-1000/-home-user-simulomicsr/98fab4d5-ca37-4d30-8001-f1ce8293c5bc/tasks/whdbnu1wb.output'
OUT = 'analysis/audit/2026-08-20-rilettura-194'

d = json.load(open(SRC, errors='ignore'))
gruppi = d['result']['gruppi']
print(f"gruppi con un verdetto: {len(gruppi)}")

# ---- 1. un verdetto per gruppo ------------------------------------------------
with open(os.path.join(OUT, 'verdetti-194.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['cluster_id', 'verdetto_finale', 'n_studi_difettosi', 'etichetta_non_chiude',
                'rilievi_accettati', 'rilievi_respinti', 'motivo'])
    for g in gruppi:
        w.writerow([g['cluster_id'], g['verdetto_finale'], len(g.get('studi_difettosi', [])),
                    g.get('etichetta_non_chiude', False), g.get('rilievi_accettati', ''),
                    g.get('rilievi_respinti', ''), g['motivo']])

c = collections.Counter(g['verdetto_finale'] for g in gruppi)
print("\n=== VERDETTO, per gruppo ===")
for k, v in c.most_common():
    print(f"  {k:12s} {v:4d}   ({100*v/len(gruppi):.1f}%)")

nc = sum(1 for g in gruppi if g.get('etichetta_non_chiude'))
print(f"\nverdetti che l'etichetta NON ha chiuso: {nc} su {len(gruppi)} ({100*nc/len(gruppi):.1f}%)")

acc = sum(g.get('rilievi_accettati') or 0 for g in gruppi)
resp = sum(g.get('rilievi_respinti') or 0 for g in gruppi)
print(f"rilievi dei critici: {acc} accettati, {resp} respinti")

# ---- 2. i difetti, contati per STUDIO ----------------------------------------
righe = []
for g in gruppi:
    for s in g.get('studi_difettosi', []):
        righe.append({'cluster_id': g['cluster_id'], 'study_id': s['study_id'],
                      'categoria': s['categoria'], 'etichetta': s['etichetta_citata']})
with open(os.path.join(OUT, 'difetti.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=['cluster_id', 'study_id', 'categoria', 'etichetta'])
    w.writeheader(); w.writerows(righe)

print(f"\n=== DIFETTI ===")
print(f"  segnalazioni (coppie gruppo-studio) : {len(righe)}")
print(f"  STUDI distinti con almeno un difetto: {len(set(r['study_id'] for r in righe))}")
print(f"  gruppi con almeno un difetto        : {len(set(r['cluster_id'] for r in righe))}")

# ---- 3. LA TASSONOMIA: le categorie libere si raggruppano in famiglie ---------
# Le categorie arrivano in testo libero dagli arbitri. Raggrupparle a mano una per
# una sarebbe una lista; qui si mappano con parole chiave, e cio' che non cade in
# nessuna famiglia resta "altro" ed e' stampato per esteso, non nascosto.
FAM = [
 ('secondo agente solo nel trattato', r'secondo agente|due agenti|agente aggiuntiv|combinaz|co-trattam|insieme'),
 ('materiale / tipo cellulare diverso fra i bracci', r'materiale|tipo cellular|linea cellular|iPSC|primar'),
 ('donatore / soggetto / sesso / etnia diversi', r'donator|soggett|sesso|etni|paziente divers|individu'),
 ('tempo non appaiato', r'tempo|durat|\bh\b|ore|timepoint|giorni'),
 ('sede anatomica diversa', r'sede|anatom|tessut.*divers|regione'),
 ('passaggio di coltura non appaiato', r'passagg|passage'),
 ('genotipo / perturbazione genetica su un braccio solo', r'genotip|knockout|\bKO\b|knockdown|shRNA|siRNA|mutant|transgen|overexpress'),
 ('entita del gruppo non isolata dal confronto', r'entit|non isol|non e.? l.entit|contrasto non|misura altro|diversa entit'),
 ('controllo non e un controllo / tipo di controllo sbagliato', r'controllo non|non e.? un controllo|tipo di controllo|veicolo|vehicle|baseline'),
 ('direzione opposta nello stesso gruppo', r'direzion|agonist|antagonist|verso opposto|segno opposto'),
 ('dose non appaiata', r'dose|concentraz|\buM\b|ng/ml'),
]
def famiglia(cat):
    c = cat.lower()
    for nome, rx in FAM:
        if re.search(rx, c, re.I):
            return nome
    return 'altro'

# per STUDIO: uno studio con lo stesso difetto in dieci gruppi vale UNO
per_studio = collections.defaultdict(set)
for r in righe:
    per_studio[r['study_id']].add(famiglia(r['categoria']))
fam_studi = collections.Counter()
for sid, fams in per_studio.items():
    for f in fams:
        fam_studi[f] += 1

print("\n=== TASSONOMIA DEI DIFETTI (contata per STUDIO) ===")
tot = sum(fam_studi.values())
for k, v in fam_studi.most_common():
    print(f"  {v:4d}  ({100*v/tot:5.1f}%)  {k}")

print("\n  --- le categorie finite in 'altro', per esteso ---")
altre = collections.Counter(r['categoria'] for r in righe if famiglia(r['categoria']) == 'altro')
for k, v in altre.most_common(30):
    print(f"     {v:3d}  {k}")

with open(os.path.join(OUT, 'tassonomia.csv'), 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['famiglia', 'n_studi', 'quota'])
    for k, v in fam_studi.most_common():
        w.writerow([k, v, round(100*v/tot, 1)])

# ---- 4. il giudizio comparativo ----------------------------------------------
div = []
for g in gruppi:
    for x in g.get('divergenze', []):
        div.append({'cluster_id': g['cluster_id'], 'study_id': x['study_id'],
                    'caso': x['caso'], 'motivo': x['motivo']})
with open(os.path.join(OUT, 'comparativo.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=['cluster_id', 'study_id', 'caso', 'motivo'])
    w.writeheader(); w.writerows(div)

ETI = {'A': 'A = il NUOVO sbaglia dove il vecchio azzeccava',
       'B': 'B = il NUOVO azzecca dove il vecchio sbagliava',
       'C': 'C = entrambe difendibili, l\'etichetta sorgente e\' ambigua'}
print(f"\n=== GIUDIZIO COMPARATIVO ===")
print(f"  giudizi espressi (coppie gruppo-studio): {len(div)}")
cc = collections.Counter(x['caso'] for x in div)
for k in ('A', 'B', 'C'):
    v = cc.get(k, 0)
    print(f"  {v:4d}  ({100*v/max(1,len(div)):5.1f}%)  {ETI[k]}")

# per STUDIO
ps = collections.defaultdict(set)
for x in div:
    ps[x['study_id']].add(x['caso'])
print(f"\n  lo stesso, contato per STUDIO ({len(ps)} studi):")
cs = collections.Counter()
for sid, casi in ps.items():
    cs['A' if 'A' in casi else ('B' if 'B' in casi else 'C')] += 1
for k in ('A', 'B', 'C'):
    v = cs.get(k, 0)
    print(f"  {v:4d}  ({100*v/max(1,len(ps)):5.1f}%)  {ETI[k]}")

print("\nScritti verdetti-194.csv, difetti.csv, tassonomia.csv, comparativo.csv")
