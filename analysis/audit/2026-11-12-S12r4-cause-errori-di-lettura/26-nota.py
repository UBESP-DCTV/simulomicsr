#!/usr/bin/env python3
"""Scrive la lettura di una scheda in 26-letture-schede.csv e rigenera 26-letture.csv (una riga per scheda e base).
uso: nota.py <scheda o prefisso unico> <m|f|n> "<etichette separate da ;>" "<descrizione>"
     nota.py --rigenera          (eredita per (studio, firma) e riscrive 26-letture.csv)
     nota.py --errore "<GSE:etichetta>" <B0> <A0> <costa si|no> "<descrizione>"   (p|a|nv)"""
import sys, csv, os
D = "/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura"
FS = os.path.join(D, "26-letture-schede.csv"); FL = os.path.join(D, "26-letture.csv"); FB = os.path.join(D, "26-errori-nelle-basi.csv")
CAUSA = {"m": "lettura del modello", "f": "forma", "n": "non errore"}; ST = {"p": "presente", "a": "assente", "nv": "non valutabile"}
def leggi(f): return list(csv.DictReader(open(f, encoding="utf-8"))) if os.path.exists(f) else []
def scrivi(f, righe, campi):
    w = csv.DictWriter(open(f, "w", encoding="utf-8", newline=""), fieldnames=campi, quoting=csv.QUOTE_ALL); w.writeheader(); w.writerows(righe)
SCH = leggi(os.path.join(D, "24-da-leggere-schede.csv")); RIG = leggi(os.path.join(D, "24-da-leggere-righe.csv"))
def rigenera():
    let = leggi(FS); per = {r["scheda"]: r for r in let}; fir = {}; sta = {x["scheda"]: x["stato"] == "non chiuso" for x in SCH}
    for r in let: fir.setdefault((r["studio"], r["firma"], sta.get(r["scheda"])), r)
    out = []; visti = set(); ered = 0; manca = []
    for r in RIG:
        k = (r["scheda"], r["base"])
        if k in visti: continue
        visti.add(k); s = next(x for x in SCH if x["scheda"] == r["scheda"])
        l = per.get(r["scheda"])
        if l is None and (s["studio"], s["firma"], sta[s["scheda"]]) in fir:
            l = dict(fir[(s["studio"], s["firma"], sta[s["scheda"]])]); l["descrizione"] = "[eredita da %s] %s" % (l["scheda"], l["descrizione"]); ered += 1
        if l is None: manca.append(r["scheda"]); continue
        out.append({"scheda": r["scheda"], "base": r["base"], "studio": s["studio"], "firma": s["firma"], "causa": l["causa"], "errore": l["errore"], "descrizione": l["descrizione"]})
    scrivi(FL, out, ["scheda", "base", "studio", "firma", "causa", "errore", "descrizione"])
    m = sorted(set(manca)); print("schede %d, lette %d, righe scritte %d (ereditate %d), non lette %d" % (len(SCH), len(let), len(out), ered, len(m)))
    return m
a = sys.argv[1:]
if a[0] == "--rigenera":
    m = rigenera()
    if "-v" in a:
        from collections import Counter
        for g, n in sorted(Counter(x.split("|")[0] for x in m).items()): print(" ", g, n)
elif a[0] == "--errore":
    e, b0, a0, costa, desc = a[1:6]; bas = [r for r in leggi(FB) if r["errore"] != e]
    bas.append({"errore": e, "studio": e.split(":")[0], "B0": ST[b0], "A0": ST[a0], "costa": costa, "descrizione": desc})
    scrivi(FB, sorted(bas, key=lambda r: r["errore"]), ["errore", "studio", "B0", "A0", "costa", "descrizione"])
else:
    pre, c, err, desc = a[0:4]; ms = [s for s in SCH if s["scheda"].startswith(pre) or ("|" + pre) in s["scheda"]]
    if len(ms) != 1: sys.exit("scheda non unica o assente: %s -> %s" % (pre, [s["scheda"] for s in ms]))
    s = ms[0]; noti = {r["errore"] for r in leggi(FB)} | {"GSE57945:sesso come fattore", "GSE60340:colonna del trattamento non vista", "GSE49155:fattore doppio", "GSE46665:sigle dei pazienti come malattie"}
    for e in [x.strip() for x in err.split(";") if x.strip()]:
        if e not in noti: sys.exit("etichetta non in 26-errori-nelle-basi.csv: " + e)
        if e.split(":")[0] != s["studio"]: sys.exit("etichetta di un altro studio: " + e)
    if c == "m" and not err.strip(): sys.exit("causa m senza etichetta")
    let = [r for r in leggi(FS) if r["scheda"] != s["scheda"]]
    let.append({"scheda": s["scheda"], "studio": s["studio"], "firma": s["firma"], "causa": CAUSA[c], "errore": err, "descrizione": desc})
    scrivi(FS, sorted(let, key=lambda r: r["scheda"]), ["scheda", "studio", "firma", "causa", "errore", "descrizione"])
    rigenera()
