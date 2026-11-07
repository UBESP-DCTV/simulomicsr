#!/usr/bin/env python3
"""22-confronto-geo.py — S12: confronta con GEO in rete (formato testo, brief) i
campioni scelti da 21-taglio-e-codifica.R. Per ogni campo: lunghezza nell'H5 e in
GEO, uguaglianza dopo la normalizzazione degli spazi, e le differenze (difflib).
GEO ha una riga per paragrafo: si uniscono con «,» come nell'H5.
Uso: python3 -I 22-confronto-geo.py 21-campioni-per-geo.json > 22-out.txt"""
import json, re, sys, time, urllib.request, difflib
def norm(s): return re.sub(r"\s+", " ", s).strip()
def norm_virgole(s): return re.sub(r"\s+,", ",", norm(s))
x = json.load(open(sys.argv[1]))
campi = (("source", "source_name_ch1"), ("extract", "extract_protocol_ch1"), ("processing", "data_processing"))
for r in x:
    url = f"https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc={r['gsm']}&targ=self&form=text&view=brief"
    t = urllib.request.urlopen(url, timeout=30).read().decode("utf-8", "replace")
    for campo, k in campi:
        if r["quale"].startswith("source") != (campo == "source") and not r["quale"].endswith("_max"):
            continue
        g = norm_virgole(",".join(m.group(1) for m in re.finditer(r"^!Sample_%s = (.*)$" % k, t, re.M)))
        h = norm_virgole(r[campo])
        h_rip = h
        try:
            h_rip = h.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            pass
        print(f"{r['gsm']} {r['quale']:18s} {campo:10s} H5={len(h):6d} GEO={len(g):6d} "
              f"uguale={g == h} uguale_dopo_riparazione={g == h_rip} GEO_finisce_con_puntini={g.endswith('...')}")
        if g != h_rip:
            sm = difflib.SequenceMatcher(None, h_rip, g, autojunk=False)
            for op, a1, a2, b1, b2 in sm.get_opcodes()[:6]:
                if op != "equal":
                    print("    ", op, repr(h_rip[max(0, a1 - 12):a2 + 12]), "->", repr(g[max(0, b1 - 12):b2 + 12]))
    time.sleep(0.4)
