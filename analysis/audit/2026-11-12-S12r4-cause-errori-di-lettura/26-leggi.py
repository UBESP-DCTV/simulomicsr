#!/usr/bin/env python3
"""Stampa in forma corta il materiale di uno studio (schede di 25-materiale.R): testa e basi (--testa), poi le schede
non ancora lette. Un fattore con la stessa riga di firma di una base si scrive in una riga («= B0»). --tutte: anche le lette.
--piena <prefisso firma>: la scheda intera."""
import sys, csv, os, re
S = os.path.dirname(os.path.abspath(__file__)); D = "/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura"
g = sys.argv[1]; testa = "--testa" in sys.argv; ST = "--larga" not in sys.argv; tutte = "--tutte" in sys.argv
piena = sys.argv[sys.argv.index("--piena") + 1] if "--piena" in sys.argv else None
lette = {}
f = os.path.join(D, "26-letture-schede.csv")
if os.path.exists(f):
    sta = {x["scheda"]: x["stato"] == "non chiuso" for x in csv.DictReader(open(os.path.join(D, "24-da-leggere-schede.csv"), encoding="utf-8"))}
    for r in csv.DictReader(open(f, encoding="utf-8")): lette[(r["studio"], r["firma"], sta.get(r["scheda"]))] = r
def tr(s, n): return s if len(s) <= n else s[:n] + "…"
t = open(os.path.join(S, os.environ.get("LEGGI_DIR", "schede"), g + ".txt"), encoding="utf-8").read()
pezzi = re.split(r"\n(?============ )", t)
def firme(p):
    out = {}; dentro = False
    for l in p.split("\n"):
        if l.startswith("FIRMA"): dentro = True; continue
        if dentro:
            if l.startswith("     ") and "|" in l and not l.strip().startswith("soggetti"):
                c = [x.strip() for x in l.split("|")]; k = (c[0], c[1]); out[k] = "DOPPIO" if k in out else l.strip()
            elif l.strip().startswith("soggetti"): out["soggetti"] = l.strip()
            else: dentro = False
    return out
basi = {}
for p in pezzi:
    m = re.match(r"=========== BASE (\S+)", p)
    if m: basi[m.group(1)] = firme(p)
def corta(p, con_basi=True):
    fi = firme(p); L = p.split("\n"); out = []; i = 0; ng = 0; nc = 0; ident = "classe identica" in p
    while i < len(L):
        l = L[i]
        if l.startswith("FATTORE"):
            m = re.match(r"FATTORE «(.*?)» \((\w+); colonne: (.*?); base «(.*?)»; prova «(.*)»\)", l)
            k = (m.group(2), m.group(3)) if m else None; riga = fi.get(k)
            uguali = [b for b in basi if con_basi and riga not in (None, "DOPPIO") and basi[b].get(k) == riga]
            if uguali:
                out.append("FATTORE «%s» (%s; %s; base «%s») = %s | %s" % (m.group(1), m.group(2), m.group(3), m.group(4), "+".join(uguali), tr(L[i + 2].strip(), 160)))
            else:
                if ST and m:
                    out.append("FATTORE «%s» (%s; %s; base «%s»)%s" % (m.group(1), m.group(2), m.group(3), m.group(4), "" if m.group(5) else " senza prova"))
                    out.append("   liv: " + tr(L[i + 1].strip().replace("livelli scritti: ", ""), 170)); out.append("   n: " + tr(L[i + 2].strip().replace("campioni per livello: ", ""), 200)); out.append("   " + tr(L[i + 3].strip(), 300))
                else:
                    out.append(tr(l, 300)); out.append(tr(L[i + 1], 260)); out.append(tr(L[i + 2], 360)); out.append(tr(L[i + 3], 420))
            i += 4; continue
        if l.startswith("  A["):
            ng += 1
            if ident: pass
            elif ng <= (4 if ST else 8): out.append(tr(l, 170 if ST else 230))
            elif ng == (5 if ST else 9) and not ident: out.append("  … altre righe dei gruppi")
        elif l.startswith("  LETTORE confronto"):
            nc += 1
            if nc <= (5 if ST else 8): out.append(tr(l, 130 if ST else 200))
            elif nc == (6 if ST else 9): out.append("  … altri confronti del lettore")
        elif l.startswith("FIRMA") or (l.startswith("     ") and "impronta" in l): pass
        elif l.strip().startswith("soggetti:"):
            u = [b for b in basi if con_basi and basi[b].get("soggetti") == l.strip()]
            out.append("soggetti" + (" = " + "+".join(u) if u else ": " + l.strip()[9:]))
        elif ST and (not l.strip() or l.startswith('NON CAPITO') or l.startswith('note:')): pass
        else: out.append(tr(l, 380 if ST else 700))
        i += 1
    return "\n".join(out)
for p in pezzi:
    m = re.match(r"=========== SCHEDA (\S+)", p)
    if m:
        st, fir, _ = m.group(1).split("|")
        if piena:
            if fir.startswith(piena): print(p)
            continue
        nc_ = "| stato non chiuso |" in p
        if (st, fir, nc_) in lette and not tutte:
            r = lette[(st, fir, nc_)]; print("\n=========== SCHEDA %s: firma gia' letta (%s; %s)" % (m.group(1), r["causa"], r["errore"]))
            print("\n".join(x for x in p.split("\n") if x.startswith("  in ") or x.startswith("UNITA'") or x.startswith("corsa ")))
        else: print("\n" + corta(p))
    elif testa and not piena:
        if p.startswith("####"): print("\n".join(tr(x, 230 if ST else 420) for x in p.split("\n") if not (ST and (x.startswith("  A[") or not x.strip()))))
        else: print("\n" + corta(p, con_basi=False))
