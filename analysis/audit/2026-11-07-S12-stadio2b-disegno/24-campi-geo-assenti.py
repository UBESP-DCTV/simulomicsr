#!/usr/bin/env python3
"""24-campi-geo-assenti.py — S12: per 40 studi scelti a caso, scarica da GEO il
testo (brief) di tutti i campioni dello studio (una richiesta per studio), tiene
i campioni dei bracci e misura i campi che l'H5 di ARCHS4 non
contiene: treatment_protocol_ch1, growth_protocol_ch1, description, label_ch1.
Per ogni campo: in quanti studi e campioni e' presente, e in quanti studi cambia
fra i campioni dei bracci (informazione per campione, non per studio).
Uso: python3 -I 24-campi-geo-assenti.py 24-studi-scelti.json > 24-out.txt"""
import json, re, sys, time, urllib.request
studi = json.load(open(sys.argv[1]))
campi = ["treatment_protocol_ch1", "growth_protocol_ch1", "description", "label_ch1"]
def scarica(url, tentativi=4):
    for k in range(tentativi):
        try:
            return urllib.request.urlopen(url, timeout=180).read().decode("utf-8", "replace").replace("\r\n", "\n")
        except Exception as e:
            print(f"  tentativo {k + 1} fallito: {e.__class__.__name__}", file=sys.stderr)
            time.sleep(5)
    raise RuntimeError("download fallito: " + url)
pres_st = {c: 0 for c in campi}; varia_st = {c: 0 for c in campi}; pres_cs = {c: 0 for c in campi}
n_cs = 0
for gse, gsms in sorted(studi.items()):
    gsms = gsms if isinstance(gsms, list) else [gsms]
    val = {c: [] for c in campi}
    url = f"https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc={gse}&targ=gsm&form=text&view=brief"
    t = scarica(url)
    blocchi = {m.group(1): m.group(2) for m in re.finditer(r"^\^SAMPLE = (GSM\d+)\n(.*?)(?=^\^SAMPLE = |\Z)", t, re.M | re.S)}
    for g in gsms:
        b = blocchi.get(g, "")
        n_cs += 1
        for c in campi:
            v = " ".join(m.group(1).strip() for m in re.finditer(r"^!Sample_%s = (.*)$" % c, b, re.M)).strip()
            val[c].append(v)
            if v: pres_cs[c] += 1
    mancanti = sum(1 for g in gsms if g not in blocchi)
    time.sleep(0.4)
    riga = [gse, str(len(gsms)), f'mancanti:{mancanti}']
    for c in campi:
        nz = [v for v in val[c] if v]
        if nz: pres_st[c] += 1
        if len(set(val[c])) > 1: varia_st[c] += 1
        riga.append(f"{c}:{'pres' if nz else '-'}/{'varia' if len(set(val[c]))>1 else 'fisso'}")
    print(" ".join(riga), flush=True)
    if len(set(val["description"])) > 1:
        es = sorted(set(val["description"]))[:3]
        print("    esempi di description:", " || ".join(e[:110] for e in es), flush=True)
print(f"\nstudi: {len(studi)}; campioni: {n_cs}")
for c in campi:
    print(f"{c:24s} presente in {pres_st[c]:2d} studi e {pres_cs[c]:4d} campioni; cambia fra i campioni dei bracci in {varia_st[c]:2d} studi")
