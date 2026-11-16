#!/usr/bin/env python3
"""10-elenco.py — l'elenco di tutti gli studi del bacino di ARCHS4 (24.393), con la classe di ogni studio, la
cartella dei suoi testi GEO, il campione della prova piccola e l'ordine dello scarico.

Nessun modello gira qui. Nessun disegno curato (Gemma, Atlas) si legge qui: si leggono solo i numeri GEO e le parti.

Classi (una per studio, per costruzione):
  giudizio      gli 82 studi di giudizio di Atlas (30-divisione.tsv, parti giudizio_A e giudizio_B). CHIUSI: niente
                testi, niente vista, niente ingresso, niente modello in questa sessione.
  sviluppo      i 47 studi di sviluppo di Atlas. Testi congelati il 2026-11-09 (si riusano).
  gemma_aperta  i 2.024 studi di Gemma della parte aperta (21-divisione.csv). Testi congelati il 2026-11-15.
  gemma_chiusa  i 991 studi di Gemma della parte chiusa. Testi congelati il 2026-11-15. Nessun modello.
  nuovo         tutti gli altri: i testi GEO si scaricano adesso (11-scarica-geo.py).

Campione della prova piccola (seme 20261116, la data della sessione):
  casuale    500 studi estratti a caso fra i `nuovo` (random.Random(20261116).sample sull'elenco ordinato);
  grandi     i 40 studi `nuovo` con piu' campioni nel bacino, fuori dai 500 (a parita', numero GEO crescente);
  controllo  50 studi estratti a caso (random.Random(20261116 + 1)) fra gli studi `gemma_aperta` che ieri sono
             entrati nell'ingresso del lettore (22-per-studio.csv, esito al_modello): hanno gia' le uscite dei due
             lettori locali.
Ordine dello scarico: prima il campione della prova (casuale, poi grandi), poi gli altri `nuovo` per numero GEO.

Uso: python3 -I analysis/audit/2026-11-16-archs4-intero/10-elenco.py     (dalla radice del repository)
Uscite: 10-elenco.csv, 10-out.txt.
"""
import collections, csv, hashlib, random, re, sys
DIR = "analysis/audit/2026-11-16-archs4-intero"
BACINO = "analysis/input/archs4-human-stage1-input-v2.jsonl"
ATLAS = "analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv"
GEMMA = "analysis/audit/2026-11-15-lettori-su-gemma/21-divisione.csv"
GEMMA_PER = "analysis/audit/2026-11-15-lettori-su-gemma/22-per-studio.csv"
TESTI = {"sviluppo": "analysis/input/geo-testi-lettore-2026-11-09", "gemma_aperta": "analysis/input/geo-testi-gemma-2026-11-15",
         "gemma_chiusa": "analysis/input/geo-testi-gemma-2026-11-15", "nuovo": "analysis/input/geo-testi-archs4-2026-11-16", "giudizio": ""}
SEME = 20261116; N_CASUALE = 500; N_GRANDI = 40; N_CONTROLLO = 50

n = collections.Counter()
with open(BACINO, encoding="utf-8") as f:
    for r in f:
        n[re.search(r'"series_id":"([^"]*)"', r).group(1)] += 1
assert sum(n.values()) == 508037 and len(n) == 24393 and all(re.fullmatch(r"GSE\d+", g) for g in n)

atlas = {r["gse"]: r["parte"] for r in csv.DictReader(open(ATLAS), delimiter="\t")}
gemma = {r["gse"]: r["parte"] for r in csv.DictReader(open(GEMMA))}
assert len(atlas) == 129 and len(gemma) == 3015 and not (set(atlas) & set(gemma)) and set(atlas) <= set(n) and set(gemma) <= set(n)

def classe(g):
    if g in atlas: return "sviluppo" if atlas[g] == "sviluppo" else "giudizio"
    if g in gemma: return "gemma_" + gemma[g]
    return "nuovo"
cl = {g: classe(g) for g in n}
num = lambda g: int(g[3:])
nuovi = sorted((g for g in n if cl[g] == "nuovo"), key=num)
casuale = set(random.Random(SEME).sample(nuovi, N_CASUALE))
grandi = set(sorted((g for g in nuovi if g not in casuale), key=lambda g: (-n[g], num(g)))[:N_GRANDI])
ieri = sorted((r["gse"] for r in csv.DictReader(open(GEMMA_PER)) if r["parte"] == "aperta" and r["esito"] == "al_modello"), key=num)
assert len(ieri) == 2016 and all(cl[g] == "gemma_aperta" for g in ieri)
controllo = set(random.Random(SEME + 1).sample(ieri, N_CONTROLLO))
prova = lambda g: "casuale" if g in casuale else "grandi" if g in grandi else "controllo" if g in controllo else ""
ordine = {g: i + 1 for i, g in enumerate(sorted(nuovi, key=lambda g: (0 if g in casuale else 1 if g in grandi else 2, num(g))))}

righe = [{"gse": g, "campioni_bacino": n[g], "classe": cl[g], "testi": TESTI[cl[g]], "prova": prova(g), "ordine_scarico": ordine.get(g, "")}
         for g in sorted(n, key=num)]
with open(f"{DIR}/10-elenco.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(righe[0])); w.writeheader(); w.writerows(righe)
sha = hashlib.sha256(open(f"{DIR}/10-elenco.csv", "rb").read()).hexdigest()
c = collections.Counter(cl.values()); p = collections.Counter(r["prova"] for r in righe)
q = lambda v: (lambda s: f"minimo {s[0]}, mediana {s[len(s)//2]}, 95% {s[int(.95*len(s))]}, 99% {s[int(.99*len(s))]}, massimo {s[-1]}")(sorted(v))
out = [f"10-elenco.py: studi del bacino {len(n)}, campioni {sum(n.values())}",
       "classi: " + ", ".join(f"{k} {c[k]}" for k in ("nuovo", "gemma_aperta", "gemma_chiusa", "sviluppo", "giudizio")),
       f"campione della prova: casuale {p['casuale']}, grandi {p['grandi']}, controllo {p['controllo']}",
       f"campioni per studio, nuovo: {q([n[g] for g in nuovi])}",
       f"campioni per studio, casuale: {q([n[g] for g in casuale])}",
       f"campioni per studio, grandi: {q([n[g] for g in grandi])}",
       f"studi di giudizio con una cartella dei testi: {sum(1 for r in righe if r['classe'] == 'giudizio' and r['testi'])}",
       f"SHA-256 di 10-elenco.csv: {sha}"]
open(f"{DIR}/10-out.txt", "w").write("\n".join(out) + "\n"); print("\n".join(out))
