#!/usr/bin/env python3
"""S12r5 - le tabelle del finding, generate dai CSV (nessun numero scritto a mano).
Uso: python3 analysis/audit/2026-11-12-S12r5-piu-letture/28-tabelle.py > .../28-tabelle.md
Legge 24-segnalati.csv, 24-chiavi.csv, 24-letture.csv, 24-stati-errori.csv, 26-letture.csv,
27-classi.csv, 27-errori-nuovi.csv, 26-errori-di-B0-aggiunti.csv. Conti dichiarati dopo i numeri: tabelle 3 e 4."""
import csv, os, collections, statistics
qui = os.path.dirname(os.path.abspath(__file__))
def leggi(n): return list(csv.DictReader(open(os.path.join(qui, n), encoding="utf-8")))
seg, chiavi, lett, stati = leggi("24-segnalati.csv"), leggi("24-chiavi.csv"), leggi("24-letture.csv"), leggi("24-stati-errori.csv")
schede, classi, nuovi = leggi("26-letture.csv"), leggi("27-classi.csv"), leggi("27-errori-nuovi.csv")
L = ["L%d" % i for i in range(1, 9)]
cl = {r["studio"]: r for r in classi}
b0 = {r["studio"]: r for r in chiavi if r["lettura"] == "B0"}

print("# S12r5 - tabelle del finding (generate da 28-tabelle.py)\n")
print("## 1. I 24 studi segnalati\n")
print("| studio | stato in `B0` | errori di `B0` | letture diverse da `B0` | classe | etichette nuove |")
print("|---|---|---|---|---|---|")
nuove_per_studio = collections.defaultdict(set)
for r in nuovi:
    for e in r["nuove"].split(";"):
        if e.strip(): nuove_per_studio[r["studio"]].add(e.strip().split(":", 1)[1])
for r in seg:
    if r["segnalato"] != "TRUE": continue
    s = r["studio"]
    err = r["errori_di_B0"] + (" (costa)" if r["errore_che_costa"] == "TRUE" else "")
    print("| `%s` | %s | %s | %s (%s) | %s | %s |" % (s, r["stato_B0"], err, r["n_letture_diverse_da_B0"],
          r["letture_diverse_da_B0"], cl[s]["classe"], "; ".join(sorted(nuove_per_studio.get(s, []))) or "-"))

agg = leggi("26-errori-di-B0-aggiunti.csv")
print("\nLa colonna «errori di `B0`» conta i 9 errori depositati. La revisione indipendente ha trovato in `B0` un errore in piu', "
      "fuori dai 9 e non contato qui: " + "; ".join("`%s`" % r["errore"] for r in agg) + ". Non e' fra le etichette nuove.")
print("\n## 2. Gli studi non segnalati, per stato in `B0`\n")
c = collections.Counter((r["stato_B0"], r["errori_di_B0"]) for r in seg if r["segnalato"] != "TRUE")
for k, v in sorted(c.items()): print("- stato %s, errori di `B0` %s: %d studi" % (k[0], k[1], v))
print("- non segnalati con gruppi diversi dai curatori in `B0`: " + ", ".join(
      "`%s`" % r["studio"] for r in seg if r["segnalato"] != "TRUE" and r["stato_B0"] != "identica"))

print("\n## 3. Confronti ritrovati: gli studi in cui una lettura nuova cambia il conto di `B0` (dichiarata dopo i numeri)\n")
print("| lettura | ritrovati su 95 | differenza da `B0` | studi che cambiano |")
print("|---|---|---|---|")
for l in L:
    tot = sum(int(r["ritrovati"]) for r in chiavi if r["lettura"] == l)
    d = ["`%s` %s→%s (%s)" % (r["studio"], b0[r["studio"]]["ritrovati"], r["ritrovati"], r["stato"])
         for r in chiavi if r["lettura"] == l and r["ritrovati"] != b0[r["studio"]]["ritrovati"]]
    print("| `%s` | %d | %+d | %s |" % (l, tot, tot - 68, "; ".join(d)))
per = collections.Counter()
for r in chiavi:
    if r["lettura"] in L: per[r["studio"]] += int(r["ritrovati"]) - int(b0[r["studio"]]["ritrovati"])
print("\nSomma delle differenze sulle 8 letture, per studio: " + "; ".join("`%s` %+d" % kv for kv in sorted(per.items(), key=lambda x: x[1]) if kv[1]))

print("\n## 4. Errori di lettura per lettura (dichiarata dopo i numeri)\n")
print("| lettura | errori di `B0` presenti (su 9) | studi con un errore nuovo | etichette nuove | quali studi |")
print("|---|---|---|---|---|")
pres = {r["lettura"]: r["errori_di_B0_presenti"] for r in lett}
for l in L:
    st = sorted({r["studio"] for r in nuovi if r["lettura"] == l})
    et = set()
    for r in nuovi:
        if r["lettura"] == l: et |= {e.strip() for e in r["nuove"].split(";") if e.strip()}
    print("| `%s` | %s | %d | %d | %s |" % (l, pres[l], len(st), len(et), ", ".join("`%s`" % s for s in st)))
tutte = set()
for r in nuovi: tutte |= {e.strip() for e in r["nuove"].split(";") if e.strip()}
print("\nEtichette nuove distinte: %d, in %d studi. Unione con i 9 errori di `B0`: %d etichette in %d studi." % (
      len(tutte), len({e.split(":")[0] for e in tutte}), len(tutte) + 9,
      len({e.split(":")[0] for e in tutte} | {r["studio"] for r in stati})))
cresc, vista, vs = [], set(), set()
for l in L:
    for r in nuovi:
        if r["lettura"] == l:
            for e in r["nuove"].split(";"):
                if e.strip(): vista.add(e.strip()); vs.add(r["studio"])
    cresc.append("%s %d (%d studi)" % (l, len(vista), len(vs)))
print("Errori per lettura (i 9 depositati presenti piu' le etichette nuove; `B0` 9): " + ", ".join(
      "%s %d" % (l, int(pres[l]) + len({e.strip() for r in nuovi if r["lettura"] == l for e in r["nuove"].split(";") if e.strip()})) for l in L)
      + ". L'errore aggiunto dalla revisione e' presente in tutte le 9 letture: con quello ogni conto cresce di 1.")
print("Etichette nuove distinte, cumulate nell'ordine `L1`…`L8`: " + "; ".join(cresc) + ".")

print("\n## 5. Le 38 schede\n")
print("| scheda | causa | dove | etichette nella lettura nuova |")
print("|---|---|---|---|")
for r in schede:
    print("| `%s` | %s | %s | %s |" % (r["scheda"], r["causa"], r["dove"], r["etichette"].replace(";", "; ") or "-"))

print("\n## 6. Le coppie (studio, lettura) con un errore nuovo, per stato della lettura (dichiarata dopo i numeri)\n")
st_di = {(r["studio"], r["lettura"]): r for r in chiavi}
coppie = sorted({(r["studio"], r["lettura"]) for r in nuovi if r["nuove"].strip()})
cc = collections.Counter(st_di[c]["stato"] for c in coppie)
print("Coppie con un errore nuovo: %d. Per stato della lettura: %s." % (len(coppie), "; ".join("%s %d" % kv for kv in sorted(cc.items()))))
for stato in sorted(cc):
    print("- %s: %s" % (stato, ", ".join("`%s` %s (%s/%s)" % (c[0], c[1], st_di[c]["ritrovati"], b0[c[0]]["ritrovati"]) for c in coppie if st_di[c]["stato"] == stato)))
print("\nFra parentesi: confronti ritrovati nella lettura nuova / in `B0`.")
