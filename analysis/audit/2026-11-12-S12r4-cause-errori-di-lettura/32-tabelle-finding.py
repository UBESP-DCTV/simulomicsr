#!/usr/bin/env python3
# S12r4 - le tabelle del finding, generate dai CSV (nessun numero scritto a mano).
# Uso: python3 32-tabelle-finding.py <cartella dell'audit> > 32-tabelle.md
import csv, sys, collections
D = sys.argv[1].rstrip("/") + "/"
rd = lambda f: list(csv.DictReader(open(D + f, encoding="utf-8")))
forme = [r for r in rd("24-forme.csv") if r["corsa"] != "B0-corsa2"]
pf = {r["corsa"]: r for r in rd("27-per-forma.csv")}
ep = {r["corsa"]: r for r in rd("29-errori-presenti-per-forma.csv")}
sn = lambda x: {"TRUE": "sì", "FALSE": "no"}.get(x, x)
print("## T1. Le 31 forme\n")
print("| forma | cambi | base | chiusi | identici | ritrovati su 95 | firme diverse dalla base | migliorati | peggiorati | studi con un errore nuovo (stretto) | errori presenti (che costano) | GSE57945 | GSE60340 | GSE49155 | GSE46665 |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for r in forme:
    k = r["corsa"]; p = pf.get(k)
    print(f"| `{k}` | {r['cambi'] or 'nessuno'} | {r['base']} | {r['chiusi']} | {r['identici']} | {r['ritrovati']} | {r['firme_diverse'] or '-'} | "
          f"{p['migliorati'] if p else '-'} | {p['peggiorati'] if p else '-'} | {(p['studi_con_errore_nuovo'] + ' (' + p['studi_con_errore_nuovo_stretto'] + ')') if p else '-'} | "
          f"{ep[k]['errori_presenti']} ({ep[k]['errori_che_costano']}) | {sn(r['GSE57945'])} | {sn(r['GSE60340'])} | {sn(r['GSE49155'])} | {sn(r['GSE46665'])} |")
print("\n## T1b. Misure accanto, per forma\n")
print("| forma | ritrovati su 97 | ritrovati meno la base (IC 95%) | uscite non finite | fattori doppi | studi con un soggetto costante nei gruppi |")
print("|---|---|---|---|---|---|")
fmt = lambda x: f"{float(x):g}".replace(".", ",")
for r in forme:
    ic = r["d_ritrovati_ic"].split()
    print(f"| `{r['corsa']}` | {r['ritrovati97']} | {r['d_ritrovati']} ({fmt(ic[0])}, {fmt(ic[1])}) | {r['fine_length']} | {r['fattori_doppi']} | {r['studi_con_soggetto_costante']} |")
dg = rd("27-diagnosi.csv"); costa = {r["errore"]: r["costa"] for r in rd("26-errori-nelle-basi.csv")}
print(f"\n## T2. I {len(dg)} errori di lettura e l'esito della regola\n")
print("esito alla lettera:", dict(collections.Counter(r["esito"].split(" (")[0].split(":")[0] for r in dg)))
print("\nlettura severa:", dict(collections.Counter(r["esito_severo"].split(" (")[0].split(":")[0] for r in dg)))
print("\nesito alla lettera, per esteso:", dict(collections.Counter(r["esito"] for r in dg)))
print("\nlettura severa, per esteso:", dict(collections.Counter(r["esito_severo"] for r in dg)))
print("\n| errore | costa | in B0 | in A0 | presente / assente / non valutabile (su 31 forme) | esito alla lettera | lettura severa | verso delle prove doppie |")
print("|---|---|---|---|---|---|---|---|")
for r in dg:
    verso = "; ".join(sorted({x.split("|")[1] + " " + x.split("|")[0] for x in r["prove_doppie"].split("; ") if "|" in x}))
    print(f"| {r['errore']} | {costa.get(r['errore'], 'si')} | {r['B0']} | {r['A0']} | {r['presente']} / {r['assente']} / {r['non_valutabile']} | {r['esito']} | {r['esito_severo']} | {verso or '-'} |")
print("\n## T3. Le previsioni\n")
print("| n. | quantità | atteso | intervallo | osservato | esito | accanto |\n|---|---|---|---|---|---|---|")
pv = rd("24-previsioni.csv") + rd("27-previsioni.csv")
key = lambda r: (int("".join(c for c in r["n"] if c.isdigit())), r["n"])
for r in sorted(pv, key=key):
    print("| " + " | ".join(r[c].replace("|", "/") for c in ("n", "quantita", "atteso", "intervallo", "osservato", "esito", "accanto")) + " |")
print("\nesiti:", dict(collections.Counter(r["esito"] for r in pv)))
pg = rd("27-peggioramenti.csv")
print("\n## T4. I peggioramenti letti\n")
print(f"righe {len(pg)}; schede distinte {len({r['scheda'] for r in pg})}; cause: {dict(collections.Counter(r['causa'] for r in pg))}; errore nuovo {sum(r['errore_nuovo']=='TRUE' for r in pg)}, stretto {sum(r['errore_nuovo_stretto']=='TRUE' for r in pg)}")
