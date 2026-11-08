#!/usr/bin/env python3
"""27-estrai-campi-geo.py — S12, seconda parte: estrae dai testi GEO congelati
(26-scarica-geo.py) i campi dei 15.559 campioni dei bracci.

Campi: title (per il controllo P10), description, treatment_protocol_ch1,
growth_protocol_ch1 (decisione 1 del PI), last_update_date (provenienza).
Piu' righe dello stesso campo si uniscono con «,», come fa l'H5 di ARCHS4.
Il testo non si normalizza qui: la riparazione della codifica e degli spazi la fa
l'ingresso (.s2b_norm_testo), uguale per i campi dell'H5 e per quelli di GEO.

Cancelli (00-previsioni-parte2.md):
  G2  ogni campione dei bracci ha il suo blocco nel testo scaricato; un campione
      senza blocco con la pagina «was deleted by the GEO staff» salvata da
      26-scarica-geo.py si conta a parte (27-cancellati-da-geo.json);
  G3  controllo positivo: sui 40 studi di 24-studi-scelti.json, «presente» e
      «cambia» per description e i due protocolli coincidono con 24-out.txt.

Uso: python3 -I 27-estrai-campi-geo.py 26-studi-gsm.json <cartella_testi> \
       24-studi-scelti.json 24-out.txt 27-campi-geo-campioni.jsonl.gz > 27-out.txt
"""
import gzip, json, os, re, sys

studi = json.load(open(sys.argv[1]))
TESTI = sys.argv[2]
scelti = json.load(open(sys.argv[3]))
out24 = open(sys.argv[4]).read()
USCITA = sys.argv[5]
CAMPI = ["title", "description", "treatment_protocol_ch1", "growth_protocol_ch1", "last_update_date"]
GEO = ["description", "treatment_protocol_ch1", "growth_protocol_ch1"]

non_utf8 = []
def leggi(nome):
    b = open(os.path.join(TESTI, nome), "rb").read()
    try:
        t = b.decode("utf-8")
    except UnicodeDecodeError:
        non_utf8.append(nome)
        t = b.decode("utf-8", "replace")
    return t.replace("\r\n", "\n")

def blocchi(t):
    return {m.group(1): m.group(2) for m in re.finditer(
        r"^\^SAMPLE = (GSM\d+)\n(.*?)(?=^\^|\Z)", t, re.M | re.S)}

# Il valore si copia com'e' nel testo GEO (solo il fine riga \r\n e' tolto alla
# lettura): la normalizzazione degli spazi la fa l'ingresso, uguale per H5 e GEO.
# pulisci=True replica 24-campi-geo-assenti.py (str.strip, che toglie anche lo
# spazio non separabile U+00A0) e serve solo al controllo G3.
def campo(b, c, sep=",", pulisci=False):
    righe = [m.group(1) for m in re.finditer(r"^!Sample_%s = (.*)$" % re.escape(c), b, re.M)]
    if pulisci:
        righe = [r.strip() for r in righe]
    return sep.join(righe), len(righe)

testo_studio = {}
def blocchi_studio(gse):
    if gse not in testo_studio:
        testo_studio[gse] = blocchi(leggi(f"{gse}.soft.txt"))
    return testo_studio[gse]

# ---------------------------------------------------------------- G2 e uscita
righe = []
senza_blocco = []
cancellati = {}
da_ripiego = 0
for gse, gsms in sorted(studi.items()):
    gsms = gsms if isinstance(gsms, list) else [gsms]
    bl = blocchi_studio(gse)
    for g in gsms:
        b = bl.get(g)
        fonte = f"{gse}.soft.txt"
        if b is None and os.path.exists(os.path.join(TESTI, f"{g}.soft.txt")):
            b = blocchi(leggi(f"{g}.soft.txt")).get(g)
            fonte = f"{g}.soft.txt"
            da_ripiego += b is not None
        if b is None:
            canc = os.path.join(TESTI, f"{g}.cancellato.txt")
            if os.path.exists(canc):
                m = re.search(r"was deleted by the GEO staff on ([A-Z][a-z]{2} \d{1,2}, \d{4})", leggi(f"{g}.cancellato.txt"))
                if m:
                    cancellati[g] = {"study_id": gse, "cancellato_da_geo": m.group(1), "file": f"{g}.cancellato.txt"}
                    continue
            senza_blocco.append(g)
            continue
        r = {"gsm": g, "study_id": gse, "file": fonte}
        for c in CAMPI:
            r[c], r["n_righe_" + c] = campo(b, c)
        righe.append(r)

with gzip.open(USCITA, "wt", encoding="utf-8") as f:
    for r in righe:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
json.dump(cancellati, open(USCITA.replace("campi-geo-campioni.jsonl.gz", "cancellati-da-geo.json"), "w"), indent=1)

n_tot = sum(len(v) if isinstance(v, list) else 1 for v in studi.values())
print(f"studi: {len(studi)}; campioni dei bracci: {n_tot}; con blocco: {len(righe)} "
      f"(dal ripiego per campione: {da_ripiego}); senza blocco: {len(senza_blocco)} {senza_blocco[:20]}")
print(f"file non UTF-8 valido: {len(non_utf8)} {non_utf8[:10]}")
for c in GEO:
    pres = sum(1 for r in righe if r[c])
    multi = sum(1 for r in righe if r["n_righe_" + c] > 1)
    print(f"  {c:24s} non vuoto in {pres:5d} campioni su {len(righe)}; con piu' righe: {multi}")
print(f"campioni cancellati da GEO (pagina salvata): {len(cancellati)} {cancellati}")
print(f"G2  {'PASSA' if not senza_blocco and len(righe) == n_tot else 'FALLISCE'}  "
      f"{len(righe)} campioni su {n_tot} con il loro blocco; cancellati da GEO {len(cancellati)}; "
      f"senza blocco e senza prova di cancellazione {len(senza_blocco)}")

# ------------------------------------------- G3: controllo positivo su 40 studi
# Ricalcolo con la stessa definizione di 24-campi-geo-assenti.py (righe unite
# con uno spazio; «cambia» = piu' di un valore fra i campioni scelti, vuoto compreso).
attesi = {}
for m in re.finditer(r"^(GSE\d+) \d+ mancanti:\d+ (.*)$", out24, re.M):
    attesi[m.group(1)] = dict(x.split(":", 1) for x in m.group(2).split())
diversi = []
for gse, gsms in sorted(scelti.items()):
    gsms = gsms if isinstance(gsms, list) else [gsms]
    bl = blocchi(leggi(f"{gse}.soft.txt")) if os.path.exists(os.path.join(TESTI, f"{gse}.soft.txt")) else {}
    for c in GEO:
        val = [campo(bl.get(g, ""), c, " ", pulisci=True)[0] for g in gsms]
        ora = f"{'pres' if any(val) else '-'}/{'varia' if len(set(val)) > 1 else 'fisso'}"
        prima = attesi.get(gse, {}).get(c)
        if ora != prima:
            diversi.append((gse, c, prima, ora))
print(f"G3  {'PASSA' if len(attesi) == 40 and not diversi else 'FALLISCE'}  "
      f"{len(attesi)} studi letti in 24-out.txt; differenze: {len(diversi)} {diversi[:10]}")
