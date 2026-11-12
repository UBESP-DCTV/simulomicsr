#!/usr/bin/env python3
# S12r4 - DICHIARATO DOPO I NUMERI: non entra in nessun esito della regola.
# Quanto sono stabili le tabelle dei fattori (firma) fra le forme e sotto i placebo, e dove
# stanno gli errori di lettura rispetto agli studi instabili.
# Uso: python3 31-stabilita.py <cartella dell'audit>
import csv, sys, collections
D = sys.argv[1].rstrip("/") + "/"
ps = [r for r in csv.DictReader(open(D + "24-per-studio.csv", encoding="utf-8")) if r["corsa"] != "B0-corsa2"]
fir = collections.defaultdict(dict); sta = collections.defaultdict(dict)
for r in ps: fir[r["studio"]][r["corsa"]] = r["firma"]; sta[r["studio"]][r["corsa"]] = r["stato"]
st = list(csv.DictReader(open(D + "27-stati.csv", encoding="utf-8")))
costa = {r["errore"]: r["costa"] for r in csv.DictReader(open(D + "26-errori-nelle-basi.csv", encoding="utf-8"))}
c = lambda e: costa.get(e, "si")   # i 4 predicati di S12r3 non stanno nel file: costano
assert len(fir) == 47
for base, pl in (("B0", ["B0pl1", "B0pl2"]), ("A0", ["A0pl1", "A0pl2"])):
    tri = [base] + pl
    div = sorted(g for g in fir if len({fir[g][k] for k in tri}) > 1)
    err = [r for r in st if r["corsa"] == base and r["stato"] == "presente"]
    e3 = {(r["errore"], r["studio"]) for r in st if r["corsa"] in tri and r["stato"] == "presente"}
    print(f"== {base} e i suoi due placebo ==")
    print(f"studi con la firma diversa in almeno una delle tre letture: {len(div)} su 47: {' '.join(div)}")
    print(f"errori presenti nella base: {len(err)} in {len({r['studio'] for r in err})} studi; che costano: {sum(c(r['errore'])=='si' for r in err)}")
    print("  in studi con la firma diversa: " + "; ".join(f"{r['errore']} (costa {c(r['errore'])})" for r in err if r["studio"] in div))
    print("  in studi con la firma uguale:  " + "; ".join(f"{r['errore']} (costa {c(r['errore'])})" for r in err if r["studio"] not in div))
    print(f"errori presenti in almeno una delle tre letture: {len(e3)}; in studi con la firma diversa: {sum(g in div for _, g in e3)}")
    print(f"stato nella base degli studi con la firma uguale: {dict(collections.Counter(sta[g][base] for g in fir if g not in div))}; con la firma diversa: {dict(collections.Counter(sta[g][base] for g in div))}\n")
allk = sorted({r["corsa"] for r in ps}); assert len(allk) == 31
nf = {g: len({fir[g][k] for k in allk}) for g in fir}
Bk = [k for k in allk if not k.startswith("A0")]; nfB = {g: len({fir[g][k] for k in Bk}) for g in fir}
print("== tutte le 31 forme ==")
print("firme distinte per studio (numero di firme: studi):", dict(sorted(collections.Counter(nf.values()).items())))
print(f"studi con una firma sola nelle 31 forme: {sum(v == 1 for v in nf.values())}; nelle 21 forme del lato B: {sum(v == 1 for v in nfB.values())}")
se = {r["studio"] for r in st if r["stato"] == "presente"}; sc = {r["studio"] for r in st if r["stato"] == "presente" and c(r["errore"]) == "si"}
print(f"studi con almeno un errore di lettura in almeno una forma: {len(se)} su 47; con un errore che costa: {len(sc)}; mai un errore: {47 - len(se)}")
pg = list(csv.DictReader(open(D + "27-peggioramenti.csv", encoding="utf-8")))
print(f"peggioramenti letti: {len(pg)}; per causa: {dict(collections.Counter(r['causa'] for r in pg))}; errore nuovo {sum(r['errore_nuovo']=='TRUE' for r in pg)} (stretto {sum(r['errore_nuovo_stretto']=='TRUE' for r in pg)}); studi distinti con un errore nuovo in almeno una forma: {len({r['studio'] for r in pg if r['errore_nuovo']=='TRUE'})}")
