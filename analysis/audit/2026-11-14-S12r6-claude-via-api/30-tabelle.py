#!/usr/bin/env python3
"""S12r6: le tabelle del finding, generate dai CSV della misura e della lettura. Non calcola niente di nuovo:
rilegge i file e li scrive in markdown. Uso: python3 30-tabelle.py > 30-tabelle.md"""
import csv, os, collections
S6 = os.path.dirname(os.path.abspath(__file__))
def rd(f): return list(csv.DictReader(open(os.path.join(S6, f), encoding="utf-8")))
def it(x, n=1): return ("%+.*f" % (n, 100 * float(x))).replace(".", ",")
def tab(h, rows):
    print("| " + " | ".join(h) + " |"); print("|" + "---|" * len(h))
    for r in rows: print("| " + " | ".join(str(x) for x in r) + " |")
    print()
nome = lambda k: k.replace("-corsa", " corsa ")

C = {r["corsa"]: r for r in rd("24b-corse.csv")}
E = rd("29-errori-per-corsa.csv"); P = {r["corsa"]: r for r in rd("29-largo-col-precedente.csv")}
A = {(r["corsa"], r["contro"]): r for r in rd("24-appaiati.csv") if r["misura"].startswith("b_")}
# nella misura accanto (24b) la corsa completata porta il nome della corsa 1 di Fable con lo schema v1
A.update({("V-fable-corsa1b", r["contro"]): r for r in rd("24b-appaiati.csv") if r["misura"].startswith("b_") and r["corsa"] == "V-fable-corsa1"})
C["V-fable-corsa1b"] = C["V-fable-corsa1"]
C16 = {r["corsa"]: r for r in rd("24-corse.csv")}

print("## T1. Le 17 corse: chiusura e misure contro Atlas\n")
print("`V-fable corsa 1` è la corsa fermata dal limite di spesa (3 studi senza chiamata); `V-fable corsa 1b` è la stessa corsa con i tre studi completati.\n")
rows = []
for e in E:
    k = e["corsa"]; c = C16[k] if k in C16 else C[k]
    rows.append([nome(k), c["chiusi"], c["identici"], c["ritrovati"] + "/95", c["ritrovati97"] + "/97", c["errori_c"] + "/" + c["giudicabili_c"],
                 c["non_valide"], c["valide_non_chiuse"], c["rifiuti"], ("%.2f" % float(c["dollari"])).replace(".", ",")])
tab(["corsa", "chiusi su 47", "(a) gruppi identici su 47", "(b) ritrovati", "(b) su 97", "(c) errori / giudicabili", "non valide", "valide non chiuse", "rifiuti", "dollari"], rows)
print("Termini di paragone: metodo di oggi 14/47 e 13/95; Mistral-Small 3.2 forma `B0` 45 chiusi, 36/47, 68/95, 2/33; Mistral-Small 3.2 schema v1 34 chiusi, 31/47, 50/95, 0/4.\n")

print("## T2. Differenza appaiata nei confronti ritrovati (b), punti percentuali, IC95 per studio\n")
rows = []
for e in E:
    k = e["corsa"]; m = A[(k, "mistral_stessa_forma")]; o = A[(k, "oggi")]
    rows.append([nome(k), it(m["claude"])[1:] , it(m["altro"])[1:], "%s (%s, %s)" % (it(m["differenza"]), it(m["ic_basso"]), it(m["ic_alto"])),
                 "sopra 0" if float(m["ic_basso"]) > 0 else "a cavallo di 0", "%s (%s, %s)" % (it(o["differenza"]), it(o["ic_basso"]), it(o["ic_alto"]))])
tab(["corsa", "Claude %", "Mistral stessa forma %", "Claude meno Mistral", "esito", "Claude meno oggi"], rows)

print("## T3. Errori di lettura del modello per corsa (studi su 47)\n")
print("«Largo»: l'errore costa gruppi o confronti del lettore (regole R1-R4 scritte dopo la revisione). «Col precedente»: lo stesso conto se la base non scritta resta senza costo, come nella sessione sulle cause (S12r4). «Stretto»: l'errore cambia la misura contro Atlas.\n")
rows = [[nome(e["corsa"]), e["lettura_largo"], P[e["corsa"]]["largo_col_precedente_S12r4"], e["lettura_stretto"], e["lettura_senza_costo"], e["forma_studi"], e["rifiuti"], e["fermati"],
         e["studi_largo"], e["studi_stretto"], e["studi_forma"], e["studi_rifiuto"]] for e in E]
tab(["corsa", "largo", "col precedente", "stretto", "solo senza costo", "errori di forma", "rifiuti", "fermati", "studi (largo)", "studi (stretto)", "studi (forma)", "studi (rifiuto)"], rows)

print("## T4. Le due corse dello stesso modello e della stessa forma\n")
R = {(r["forma"], r["modello"]): r for r in rd("24-ripetibilita.csv")}
rows = []
for d in rd("29-due-corse.csv"):
    r = R[(d["forma"], d["modello"])] if d["corsa_a"].endswith("corsa1") else None
    rows.append([nome(d["corsa_a"]) + " e " + d["corsa_b"][-1], d["largo_a"] + " e " + d["largo_b"], d["largo_almeno_una"], d["largo_tutte_e_due"],
                 d["stretto_a"] + " e " + d["stretto_b"], d["stretto_almeno_una"], d["stretto_tutte_e_due"], d["ritrovati_a"] + " e " + d["ritrovati_b"],
                 r["identiche_al_carattere"] if r else "-", r["stessa_chiave"] if r else "-", r["stessi_gruppi"] if r else "-", r["stessi_confronti"] if r else "-"])
tab(["coppia", "largo", "largo, almeno una", "largo, tutte e due", "stretto", "stretto, almeno una", "stretto, tutte e due", "ritrovati su 95",
     "uscita identica al carattere (P14)", "stessa tabella, gruppi e confronti (P15)", "stessi gruppi", "stessi confronti"], rows)
print("La ripetibilità (ultime quattro colonne) è misurata dal programma depositato sulle 16 corse: per Fable con lo schema v1 confronta la corsa 1 fermata e la corsa 2.\n")

print("## T5. Per studio: in quante delle 17 corse c'è un errore di lettura che costa (largo)\n")
L = rd("29-classi-per-corsa.csv"); n = collections.Counter(); ns = collections.Counter()
for s, k in {(r["studio"], r["corsa"]) for r in L if r["classe"] == "lettura del modello" and r["costa"] == "si"}: n[s] += 1
for s, k in {(r["studio"], r["corsa"]) for r in L if r["classe"] == "lettura del modello" and r["costa_su_atlas"] == "si"}: ns[s] += 1
tab(["studio", "corse con l'errore (largo), su 17", "corse con l'errore (stretto), su 17"], [[s, c, ns[s]] for s, c in sorted(n.items(), key=lambda x: (-x[1], x[0]))])
corse_senza = [e["corsa"] for e in E if e["lettura_largo"] == "0"]
print("Studi con un errore che costa in almeno una corsa: %d su 47. Corse senza un errore di lettura che costa: %d su 17.\n" % (len(n), len(corse_senza)))

print("## T6. Previsioni depositate, corsa 1 (ordine: Haiku / Sonnet / Opus / Fable)\n")
V = rd("24-previsioni.csv"); P13 = {(r["forma"], r["modello"]): r for r in rd("27-P13.csv")}
def val(r):
    v = r["valore"]
    if r["codice"] in ("P6",): return str(round(47 * float(v)))
    if r["codice"] in ("P8", "P9"): return it(v)
    if r["codice"] == "P10": return it(v)[1:] + "%"
    return v
rows = []
for cod in ["P%d" % i for i in range(1, 16)]:
    for f in ("T", "V"):
        if cod == "P13":
            q = [P13[(f, m)] for m in ("haiku", "sonnet", "opus", "fable")]
            rows.append([cod, f, "studi con un errore di lettura che costa (largo; stretto)", " / ".join(x["P13_atteso"] for x in q),
                         " / ".join("%s; %s" % (x["P13_largo"], x["P13_stretto"]) for x in q), "smentita per i quattro (intervallo: 0)"]); continue
        q = [r for m in ("haiku", "sonnet", "opus", "fable") for r in V if r["codice"] == cod and r["forma"] == f and r["modello"] == m]
        if not q: continue
        es = [r["esito"] or "-" for r in q]
        rows.append([cod, f, q[0]["quantita"], " / ".join(r["atteso"] for r in q), " / ".join(val(r) for r in q), es[0] if len(set(es)) == 1 else " / ".join(es)])
tab(["", "forma", "quantità", "atteso", "misurato", "esito"], rows)
