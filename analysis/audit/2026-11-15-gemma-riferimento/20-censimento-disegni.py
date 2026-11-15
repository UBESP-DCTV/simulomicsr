#!/usr/bin/env python3
"""Censimento dei disegni curati di Gemma scaricati da 12-scarica-disegni.py.
Uso: python3 -I 20-censimento-disegni.py DIR_DISEGNI 20-censimento.csv
Una riga per studio: campioni, fattori del disegno (senza il blocco tecnico), analisi, sottoinsiemi,
insiemi di risultati con e senza livello di base, interazioni, fattori continui."""
import csv, glob, gzip, json, os, sys
d, out = sys.argv[1], sys.argv[2]
def blocco(fv):
    return any((c.get("category") or "") == "block" for c in (fv.get("characteristics") or []))
righe = []
for f in sorted(glob.glob(os.path.join(d, "*.samples.json.gz"))):
    gse = os.path.basename(f)[:-len(".samples.json.gz")]  # il nome breve di Gemma: una parte di uno studio GEO ha un suffisso (GSE101521.2)
    s = json.load(gzip.open(f))["data"]
    a = json.load(gzip.open(os.path.join(d, gse + ".analyses.json.gz")))["data"]
    gsm = [(x.get("accession") or {}).get("accession") for x in s]
    fatt = {}
    senza = 0
    for x in s:
        fv = [v for v in ((x.get("sample") or {}).get("fvbasicVOs") or []) if not blocco(v)]
        if not fv: senza += 1
        for v in fv:
            fatt.setdefault(v["experimentalFactorId"], {"tipo": v.get("experimentalFactorType"), "liv": set(),
                            "cat": (v.get("experimentalFactorCategory") or {}).get("category")})["liv"].add(v["id"])
    n_rs = n_base = n_inter = n_sub = 0
    f_an = set()
    for an in a:
        if an.get("isSubset"): n_sub += 1
        for rs in an.get("resultSets") or []:
            ef = rs.get("experimentalFactors") or []
            n_rs += 1
            if len(ef) > 1: n_inter += 1
            elif rs.get("baselineGroup"): n_base += 1; f_an.add(ef[0]["id"])
    righe.append(dict(gse=gse, campioni=len(s), gsm_validi=sum(bool(g) and g.startswith("GSM") for g in gsm),
        gsm_doppi=len(gsm) - len(set(gsm)), campioni_senza_fattori=senza, fattori=len(fatt),
        fattori_continui=sum(v["tipo"] == "continuous" for v in fatt.values()),
        livelli_max=max([len(v["liv"]) for v in fatt.values()] or [0]),
        categorie="|".join(sorted({str(v["cat"]) for v in fatt.values()})),
        analisi=len(a), analisi_su_sottoinsieme=n_sub, insiemi=n_rs, insiemi_con_base=n_base, interazioni=n_inter,
        fattori_con_base=len(f_an & set(fatt)), fattori_analisi_fuori_campioni=len(f_an - set(fatt))))
with open(out, "w", newline="") as h:
    w = csv.DictWriter(h, fieldnames=list(righe[0])); w.writeheader(); w.writerows(righe)
n = len(righe)
def q(c, p): return sum(1 for r in righe if p(r[c]))
print("studi", n)
for nome, c, p in [("senza analisi", "analisi", lambda v: v == 0), ("con analisi su sottoinsiemi", "analisi_su_sottoinsieme", lambda v: v > 0),
                   ("senza fattori nei campioni", "fattori", lambda v: v == 0), ("con un fattore continuo", "fattori_continui", lambda v: v > 0),
                   ("con interazioni", "interazioni", lambda v: v > 0), ("con GSM doppi", "gsm_doppi", lambda v: v > 0),
                   ("con campioni senza fattori", "campioni_senza_fattori", lambda v: v > 0),
                   ("con fattori dell'analisi fuori dai campioni", "fattori_analisi_fuori_campioni", lambda v: v > 0)]:
    print(f"  {nome}: {q(c, p)}")
print("  tutti i fattori categorici con un livello di base:", sum(1 for r in righe if r["fattori"] > 0 and r["fattori_con_base"] == r["fattori"] - r["fattori_continui"]))
print("  GSM non validi:", sum(r["campioni"] - r["gsm_validi"] for r in righe))
import collections
print("  fattori per studio:", sorted(collections.Counter(r["fattori"] for r in righe).items()))
print("  categorie piu' frequenti:", collections.Counter(c for r in righe for c in r["categorie"].split("|") if c).most_common(15))
