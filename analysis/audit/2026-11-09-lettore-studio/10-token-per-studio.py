# Misura esplorativa: quanti token servono per dare al modello la tabella intera di uno studio (titolo, sorgente,
# caratteristiche di ogni campione). Token stimati = caratteri / 2,29 (pendenza misurata su 1.903 prompt Mistral).
import json, re, sys, collections
CPT = 2.29
studi = collections.defaultdict(list)
for l in open(sys.argv[1], encoding="utf-8"):
    r = json.loads(l); studi[r["series_id"]].append((r["geo_accession"], r["string"]))
rif = set(l.strip() for l in open(sys.argv[2])) if len(sys.argv) > 2 else set()
SPLIT = re.compile(r",(?=[^,:]{1,60}: )")
def campi(s):
    d = collections.OrderedDict()
    for p in SPLIT.split(s):
        k, _, v = p.partition(": "); d[k.strip()] = v.strip()
    return d
righe = []
for sid, cc in studi.items():
    n = len(cc)
    ingenuo = sum(len(g) + 3 + len(s) + 1 for g, s in cc)
    D = [(g, campi(s)) for g, s in cc]
    chiavi = list(collections.OrderedDict((k, 1) for _, d in D for k in d))
    costanti = [k for k in chiavi if len(set(d.get(k, "") for _, d in D)) == 1]
    variabili = [k for k in chiavi if k not in costanti]
    testa = sum(len(k) + 2 + len(D[0][1].get(k, "")) + 1 for k in costanti) + sum(len(k) + 3 for k in variabili)
    corpo = sum(len(g) + sum(len(d.get(k, "")) + 3 for k in variabili) + 1 for g, d in D)
    tabella = testa + corpo
    # righe uguali tranne il titolo e il GSM: una riga per gruppo, con l'elenco dei GSM
    var_nt = [k for k in variabili if k != "title"]
    gruppi = collections.OrderedDict()
    for g, d in D: gruppi.setdefault(tuple(d.get(k, "") for k in var_nt), []).append((g, d.get("title", "")))
    compatta = testa + sum(sum(len(v) + 3 for v in key) + sum(len(g) + len(t) + 4 for g, t in mem) + 1 for key, mem in gruppi.items())
    righe.append((sid, n, ingenuo / CPT, tabella / CPT, compatta / CPT, len(gruppi), sid in rif))
def riassunto(R, nome):
    print(f"\n== {nome}: {len(R)} studi, {sum(r[1] for r in R)} campioni ==")
    for i, lab in [(2, "testo campione per campione"), (3, "tabella (colonne costanti una volta)")]:
        v = sorted(r[i] for r in R); q = lambda p: v[min(len(v) - 1, int(p * len(v)))]
        print(f"  {lab}: mediana {q(.5):.0f}, 90° {q(.9):.0f}, 99° {q(.99):.0f}, max {v[-1]:.0f} token")
        for s in [8000, 16000, 32000, 64000, 100000, 128000]:
            k = [r for r in R if r[i] > s]
            print(f"    oltre {s:>6}: {len(k):>5} studi ({100*len(k)/len(R):.2f}%), {sum(r[1] for r in k):>7} campioni")
    for s in [100, 200, 500, 1000]:
        k = [r for r in R if r[1] > s]; print(f"  studi con piu' di {s} campioni: {len(k)}")
riassunto(righe, "tutti gli studi")
if rif: riassunto([r for r in righe if r[6]], "i 993 studi dei confronti letti")
big = sorted(righe, key=lambda r: -r[3])[:15]
print("\n== i 15 studi piu' grandi (tabella) ==")
for r in big: print(f"  {r[0]:<12} campioni {r[1]:>5}  tabella {r[3]:>8.0f}  testo {r[2]:>8.0f}  condizioni distinte {r[5]:>5}")
