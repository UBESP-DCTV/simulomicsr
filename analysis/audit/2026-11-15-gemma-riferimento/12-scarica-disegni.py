#!/usr/bin/env python3
"""Scarica da Gemma (UBC) il disegno curato di ogni studio dell'elenco:
campioni con i valori dei fattori, e analisi differenziali con il livello di base.
Uso: python3 12-scarica-disegni.py 11-da-scaricare.csv DIR_USCITA
Gli studi di giudizio (parte giudizio_A, giudizio_B) NON si scaricano: restano chiusi.
Riprende da dove si era fermato (salta i file che esistono)."""
import csv, gzip, json, os, sys, time, urllib.request
elenco, dest = sys.argv[1], sys.argv[2]
B = "https://gemma.msl.ubc.ca/rest/v2/"
def get(u):
    for t in range(5):
        try:
            b = urllib.request.urlopen(B + u, timeout=300).read()
            if b[:2] == b"\x1f\x8b": b = gzip.decompress(b)
            json.loads(b); return b
        except Exception as e:
            err = e; time.sleep(10 * (t + 1))
    raise err
righe = [r for r in csv.DictReader(open(elenco)) if not r["parte"].startswith("giudizio")]
fatti = errori = 0
for i, r in enumerate(righe):
    for pezzo, url in (("samples", f"datasets/{r['id']}/samples"), ("analyses", f"datasets/{r['id']}/analyses/differential")):
        f = os.path.join(dest, f"{r['shortName']}.{pezzo}.json.gz")
        if os.path.exists(f): continue
        try:
            b = get(url)
            with gzip.open(f + ".tmp", "wb") as h: h.write(b)
            os.rename(f + ".tmp", f); fatti += 1
        except Exception as e:
            errori += 1; print("ERRORE", r["shortName"], pezzo, e, flush=True)
        time.sleep(0.4)
    if i % 100 == 0: print(time.strftime("%H:%M:%S"), i, "di", len(righe), "file nuovi", fatti, "errori", errori, flush=True)
print("FINE", len(righe), "studi, file nuovi", fatti, "errori", errori, flush=True)
