#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/25-lettura-allargata.py
# L'esito della lettura dei 27 candidati del censimento allargato (24-candidati-allargati.csv). Ogni esito e' scritto
# a mano dopo aver letto titoli e caratteristiche GEO dei due bracci (24-out.txt e i titoli per braccio). Questo file
# registra la lettura: non e' una regola.
# Uso: python3 -I analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/25-lettura-allargata.py
import csv
from collections import Counter
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
v = {
 'GSE186341__GSE186341__grp_0003_vs_grp_0004__1': ('giusto', '', '-', 'titolo controllo "UNTREATED_0_24": dose 0 e 24 h, come il trattato "Lapatinib_2.5_24"; non e\' un tempo zero', ''),
 'GSE221563__GSE221563__grp_0007_vs_grp_0003__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO titoli: trattato "D13_IL2", controllo "D0"', ''),
 'GSE139393__GSE139393__grp_0002_vs_grp_0001__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO titoli: trattato "R5020_12h", controllo "Untreated_T0"', ''),
 'GSE255958__GSE255958__grp_LungCancerOrganoid_Osimertinib_2_vs_grp_LungCancerOrganoid_DMSO__1': ('giusto', '', '-', '"Osim 3d" contro "ctrl 3d": stesso tempo; la forma "untreated 0.1% DMSO" non e\' un tempo', ''),
 'GSE255958__GSE255958__grp_PC9_Osimertinib_VT104_vs_grp_PC9_DMSO__1': ('sbagliato', 'etichetta', 'secondo agente solo nel trattato', 'gia\' accusato (VT104). Anche il tempo non e\' appaiato: "9d" contro "ctrl 48h"', ''),
 'GSE193133__GSE193133__grp_0001_vs_grp_0002__1': ('incerto', 'metadato', 'tempo zero', 'GEO titoli "WT24" (ipossia 24 h) contro "WT0" (untreated): lo "0" e\' probabilmente il tempo, ma la caratteristica dice solo "untreated"', ''),
 'GSE135458__GSE135458__grp_0002_vs_grp_0001__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO titoli "KI1_24h" contro "KI1_0h"', ''),
 'GSE135458__GSE135458__grp_0004_vs_grp_0003__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO titoli "WT1_24h" contro "WT1_0h"', ''),
 'GSE184891__GSE184891__grp_HL60_Azacitidine_24h_vs_grp_HL60_no_treatment__1': ('sbagliato', 'metadato', 'tempo zero; braccio misto', 'GEO controllo "HL60day0"; il trattato "24h" contiene Day 1, Day 2 e Day 3', ''),
 'GSE184891__GSE184891__grp_HL60_Azacitidine_4d_vs_grp_HL60_no_treatment__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO "AZA Day 4" contro "HL60day0"', ''),
 'GSE184891__GSE184891__grp_HL60_Azacitidine_8d_vs_grp_HL60_no_treatment__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO "AZA Day 8" contro "HL60day0"', ''),
 'GSE184891__GSE184891__grp_OCIAML3_Azacitidine_4d_vs_grp_OCIAML3_no_treatment__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO "AZA Day 4" contro "OCIday0"', ''),
 'GSE184891__GSE184891__grp_OCIAML3_Azacitidine_8d_vs_grp_OCIAML3_no_treatment__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO "AZA Day 8" contro "OCIday0"', ''),
 'GSE142381__GSE142381__grp_0008_vs_grp_0005__1': ('giusto', '', '-', 'titoli "D300" contro "D0": dose di decitabina (300 nM, 0), non tempo', ''),
 'GSE198670__GSE198670__group_0002_vs_group_0001__1': ('sbagliato', 'metadato', 'tempo zero', 'GEO titoli "786O_EV_Day5" contro "786O_EV_Day0"', ''),
 'GSE198670__GSE198670__group_0028_vs_group_0027__1': ('sbagliato', 'metadato', 'tempo zero; braccio misto', 'etichetta "A-704 DAC" contro "A-704 untreated"; GEO trattato 6 A-704 e 4 769-P a 5, 15 e 25 giorni, controllo "769P_Day0"', ''),
 'GSE65335__GSE65335__grp_0004_vs_grp_0002__1': ('sbagliato', 'metadato', 'tempo zero; formato di coltura', 'GEO trattato "Day6_IL13", "ALI (day 14)"; controllo "Day0", "submerged (day 8)"', ''),
 'GSE132958__GSE132958__grp_0002_vs_grp_0001__1': ('giusto', '', '-', 'GEO "0ng/ml TNF-alpha": dose zero, non tempo; stessa linea non-targeting', ''),
 'GSE202576__GSE202576__grp_0002_vs_grp_0001__1': ('giusto', '', '-', '"RT4, treated, 24h" contro "RT4, control, 24h": stesso tempo', ''),
}
out = []
for r in csv.DictReader(open(D + '24-candidati-allargati.csv')):
    rid = r['record_id']
    if rid in v: e = v[rid]
    elif rid.startswith('GSE186341__GSE186341__NCI-H1793_'):
        e = ('giusto', '', '-', 'titolo controllo "UNTREATED_0_24": dose 0 e 24 h, come il trattato; non e\' un tempo zero', '')
    else: raise SystemExit('manca ' + rid)
    out.append(dict(record_id=rid, esito=e[0], fonte=e[1], famiglia=e[2], motivo=e[3], causa=e[4]))
w = csv.DictWriter(open(D + '25-lettura-allargata.csv', 'w'), fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out), Counter(o['esito'] for o in out))
