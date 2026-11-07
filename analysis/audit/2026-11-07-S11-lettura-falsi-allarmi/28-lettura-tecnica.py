#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/28-lettura-tecnica.py
# Decisione del PI del 2026-11-07, dopo il riassunto («si»): una differenza solo tecnica fra trattati e controlli
# (metodo di sequenziamento, kit, strumento, RNA marcato) e' un errore. Questo file registra la lettura degli 8
# candidati di 27-candidati-tecnici.csv e dei due confronti gia' letti (righe 4 e 22). 40-misura.py lo applica sopra
# la lettura: per un confronto gia' letto cambia l'esito, un confronto nuovo si aggiunge (sezione T).
# Uso: python3 -I analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/28-lettura-tecnica.py
import csv
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
R = [
 ('GSE105951__GSE105951__grp_0005_vs_grp_0007__1', 'sbagliato', 'metadato', 'differenza tecnica',
  'riga 4: GEO "library type: paired" nei 3 trattati, "library type: single" nei 2 controlli'),
 ('GSE132782__GSE132782__group_0023_vs_group_0035__1', 'sbagliato', 'metadato', 'differenza tecnica',
  'riga 22: GEO titoli "repl1.4SU" e "repl4.Total" nel trattato, "Total" nei controlli'),
 ('GSE122409__GSE122409__grp_0001_vs_grp_0003__1', 'sbagliato', 'metadato', 'differenza tecnica; donatore',
  'GEO trattato NovaSeq 6000 e kit Zymo Direct-zol, controllo HiSeq 2500 e kit QIAGEN RNeasy; donatori 4-5 contro 1-3'),
 ('GSE122409__GSE122409__grp_0005_vs_grp_0007__1', 'sbagliato', 'metadato', 'differenza tecnica; donatore',
  'come sopra, per CD94lo'),
 ('GSE150819__GSE150819__grp_human_bronchial_organoids_SARS_CoV_2_vs_grp_human_bronchial_organoids__1', 'sbagliato', 'metadato', 'differenza tecnica',
  'GEO trattato NovaSeq 6000 (TruSeq stranded mRNA), controllo NextSeq 500 (NEBNext Ultra II), dal protocollo dello studio'),
 ('GSE57116__GSE57116__DRB_vs_untreated__1', 'sbagliato', 'metadato', 'secondo agente solo nel trattato; braccio misto; differenza tecnica',
  'riga 85, gia\' errore: 4sU in 10 trattati su 10, in nessun controllo'),
 ('GSE101216__GSE101216__calcium_high_vs_control__1', 'sbagliato', 'metadato', 'tempo non appaiato; differenza tecnica',
  'riga 1, gia\' errore: 4 controlli su 7 sono librerie 4SU, i trattati sono Total'),
 ('GSE207821__GSE207821__', 'giusto', '', '-',
  'stesso strumento (NextSeq 500) e stesso kit (QuantSeq 3\' FWD); il protocollo cambia solo nella frase "bulk RNA-sequencing" contro "RNA-seq"'),
]
cand = {r['record_id']: r for r in csv.DictReader(open(D + '27-candidati-tecnici.csv'))}
out = []
for rid, esito, fonte, fam, motivo in R:
    if rid.endswith('__'):
        m = [k for k in cand if k.startswith(rid)]; assert len(m) == 1, (rid, m); rid = m[0]
    out.append(dict(record_id=rid, esito=esito, fonte=fonte, famiglia=fam, motivo=motivo))
assert {o['record_id'] for o in out} >= set(cand), set(cand) - {o['record_id'] for o in out}
w = csv.DictWriter(open(D + '28-lettura-tecnica.csv', 'w'), fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print('righe', len(out), '| candidati tecnici coperti', len(set(cand) & {o['record_id'] for o in out}), 'su', len(cand))
