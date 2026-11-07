#!/usr/bin/env python3
"""45-perche-non-visti.py - S10b: per ogni difetto che M non vede, che cosa scrive lo Stadio 1.

Diagnostica, dopo la misura: NON cambia la regola. Usa le funzioni di 10-regola.py (congelata)
per scrivere, per ogni confronto difettoso taciuto da M, i valori dei due bracci nei campi della
sua famiglia, e una causa per famiglia:
  agente   : n_delta = agenti del trattato (maggioranza) assenti dal controllo; n_unione = agenti
             in almeno un trattato e in nessun controllo
  tempo    : tempi dei due bracci; tempo zero del controllo
  soggetto : sesso, etnia, donatore dei due bracci (insiemi)
  materiale: context_kind e linea dei due bracci
  sede     : parole della sede dei due bracci
Uscite: 45-perche-non-visti.csv, 45-out.txt.

Uso: python3 -I analysis/audit/2026-11-07-S10b-metadati-campioni/45-perche-non-visti.py
"""
import collections
import csv
import gzip
import importlib.util
import json
import os

OUT = "analysis/audit/2026-11-07-S10b-metadati-campioni"
sp = importlib.util.spec_from_file_location("regola", os.path.join(OUT, "10-regola.py"))
R = importlib.util.module_from_spec(sp)
sp.loader.exec_module(R)

fatti = {}
with gzip.open(os.path.join(OUT, "20-fatti.jsonl.gz"), "rt", encoding="utf-8") as g:
    for line in g:
        r = json.loads(line)
        fatti[r["record_id"]] = r["parsed_json"]
conf = {r["record_id"]: r for r in csv.DictReader(open(os.path.join(OUT, "20-confronti.csv"), encoding="utf-8"))}
es = list(csv.DictReader(open(os.path.join(OUT, "40-esiti.csv"), encoding="utf-8")))

FAM = {"secondo agente solo nel trattato": "agente", "tempo non appaiato": "tempo",
       "donatore / soggetto / sesso / etnia diversi": "soggetto",
       "materiale / tipo cellulare diverso fra i bracci": "materiale", "sede anatomica diversa": "sede"}


def s(x):
    return "|".join(sorted(str(v) for v in x))


righe = []
for e in es:
    if e["insieme"] != "difettoso" or e["M"] == "1" or e["famiglia"] not in FAM:
        continue
    c = conf[e["record_id"]]
    T = [fatti[g] for g in c["gsm_t"].split(",")]
    C = [fatti[g] for g in c["gsm_c"].split(",")]
    fam = FAM[e["famiglia"]]
    d = {"record_id": e["record_id"], "study": e["study"], "famiglia": fam, "classe": c["classe"],
         "trattato": c["tl"], "controllo": c["cl"]}
    if fam == "agente":
        aT = [set(R.agenti(p)) for p in T]
        uC = set().union(*[set(R.agenti(p)) for p in C])
        delta = R.maggioranza(T, lambda p: set(R.agenti(p))) - uC
        unione = set().union(*aT) - uC
        d.update(T=s(set().union(*aT)), C=s(uC), n_delta=len(delta), n_unione=len(unione))
        if len(delta) >= 2:
            d["causa"] = "due agenti in piu', ma classe malattia o COMBO"
        elif len(unione) >= 2:
            d["causa"] = "il secondo agente sta in meno della meta' dei trattati"
        elif len(delta) == 1:
            d["causa"] = "un solo agente in piu': il secondo non e' scritto come perturbazione"
        else:
            d["causa"] = "nessun agente in piu' (l'agente sta anche nel controllo o manca)"
    elif fam == "tempo":
        tT, tC = R.valori(T, R.tempi), R.valori(C, R.tempi)
        zC = all(R.zero(p) for p in C)
        d.update(T=s(tT), C=s(tC), ctrl_zero=zC)
        if not tT and not tC:
            d["causa"] = "nessun tempo su nessun braccio"
        elif not tT or not tC:
            d["causa"] = "tempo su un braccio solo"
        else:
            d["causa"] = "tempi con un valore in comune"
    elif fam == "soggetto":
        parti = []
        for nome, fn in (("sesso", R.sesso), ("etnia", R.etnia), ("donatore", R.donatore)):
            a, b = R.valori(T, fn), R.valori(C, fn)
            parti.append(f"{nome}: {s(a)} vs {s(b)}")
        d.update(T="; ".join(parti), C="")
        sx = [(R.valori(T, fn), R.valori(C, fn)) for fn in (R.sesso, R.etnia, R.donatore)]
        if not any(a and b for a, b in sx):
            d["causa"] = "nessun campo del soggetto su entrambi i bracci"
        elif any(a and b and (a & b) for a, b in sx):
            d["causa"] = "bracci misti: un valore in comune"
        else:
            d["causa"] = "solo il donatore differisce, e la classe e' malattia o infezione"
    elif fam == "materiale":
        a, b = R.valori(T, R.tipo_materiale), R.valori(C, R.tipo_materiale)
        la, lb = R.valori(T, R.linea), R.valori(C, R.linea)
        d.update(T=f"{s(a)} / linea {s(la)}", C=f"{s(b)} / linea {s(lb)}")
        d["causa"] = ("stesso tipo di materiale scritto sui due bracci" if a & b
                      else "tipo di materiale mancante su un braccio")
    elif fam == "sede":
        sT = set().union(*[R.sede_parole(p) for p in T])
        sC = set().union(*[R.sede_parole(p) for p in C])
        d.update(T=s(sT), C=s(sC))
        d["causa"] = ("sede su un braccio solo o generica" if not sT or not sC
                      else "una parola della sede in comune")
    righe.append(d)

campi = ["record_id", "study", "famiglia", "classe", "trattato", "controllo", "causa", "T", "C",
         "n_delta", "n_unione", "ctrl_zero"]
with open(os.path.join(OUT, "45-perche-non-visti.csv"), "w", newline="", encoding="utf-8") as o:
    w = csv.DictWriter(o, fieldnames=campi)
    w.writeheader()
    for d in righe:
        w.writerow({k: d.get(k, "") for k in campi})

with open(os.path.join(OUT, "45-out.txt"), "w", encoding="utf-8") as o:
    def p(t):
        print(t)
        o.write(t + "\n")
    p("Difettosi taciuti da M, per famiglia e causa (famiglie con una sotto-regola)")
    cnt = collections.Counter((d["famiglia"], d["causa"]) for d in righe)
    for (f, c), n in sorted(cnt.items()):
        p(f"  {f:10s} {n:3d}  {c}")
    p(f"totale: {len(righe)}")
