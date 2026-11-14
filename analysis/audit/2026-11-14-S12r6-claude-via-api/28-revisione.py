#!/usr/bin/env python3
# PROVA DA BUTTARE
# 28-revisione.py — S12r6: confronta la lettura dell'agente (28-classi-prima-della-revisione.csv, commit 2ca3acd)
# con i due revisori indipendenti (28-revisore-A.csv: 20 schede, 3 studi; 28-revisore-B.csv: 54 schede, 16 studi),
# applica le decisioni scritte qui sotto e riscrive 27-classi.csv. Scrive 28-confronto.csv (una riga per differenza).
#   python3 analysis/audit/2026-11-14-S12r6-claude-via-api/28-revisione.py
import csv, collections
Q = "analysis/audit/2026-11-14-S12r6-claude-via-api"
k = lambda r: (r["classe"].strip(), r["costa"].strip(), (r.get("costa_su_atlas") or "").strip())
mio = collections.OrderedDict((r["scheda"], r) for r in csv.DictReader(open(f"{Q}/28-classi-prima-della-revisione.csv")))
rev = {}
for n in "AB":
    for r in csv.DictReader(open(f"{Q}/28-revisore-{n}.csv")): assert r["scheda"] not in rev; rev[r["scheda"]] = (n, r)
assert set(rev) == set(mio) and len(mio) == 74
L, N = "lettura del modello", "non errore"
# Regole uniche applicate dopo la revisione (dichiarate dopo i numeri):
#  R1  una colonna con un valore per campione letta come soggetto/donatore, senza effetto = lettura del modello senza
#      costo (precedente S12r4, GSE69597). Vale per tutte le schede dove la lettura lo aveva annotato.
#  R2  base non scritta dove la tabella ha un livello di riferimento, e un confronto del lettore si perde = lettura del
#      modello che costa nel conto largo, anche se la misura contro Atlas non cambia (lettera della convenzione sul
#      costo; il precedente S12r4 di GSE93624 la contava senza costo: il conto con quel precedente sta nel finding).
#  R3  forma T: un fattore legge una colonna sola e ogni valore ha una voce sola. Un fattore che nessuna colonna dichiara
#      per tutti i campioni e che il modello scrive in not_understood (prompt v2, righe 33, 35, 57) = forma, non lettura.
#  R4  due fattori dalla stessa colonna con la stessa partizione = fattore doppio = lettura del modello che costa
#      (precedente S12r3, GSE49155).
D = {  # scheda: (classe, costa, costa_su_atlas, chi ha ragione, motivo)
 "6e2328728f5fdd1a": ("forma", "si", "no", "revisore", "R3. Il tempo sta in tre colonne complementari; il modello lo dichiara in not_understood. Il confronto IFNB contro mock unisce 4, 6 e 12 h. Il 1/2 contro Atlas viene dal fattore tecnico della serie, che separa mock di esperimenti diversi uniti da Atlas: scelta dei curatori."),
 "c311c89312a00905": ("forma", "si", "no", "revisore", "R3. Tempo non scritto e dichiarato in not_understood; i gruppi uniscono tempi diversi."),
 "ed73f69c0e9a8f36": ("forma", "si", "no", "revisore", "R3. Come c311c89312a00905."),
 "811d1a52237507c7": (L, "no", "no", "revisore", "Il tempo dei 6 infetti della serie 16 sta in description («Time after treatment: 24 hours») e il modello non lo legge. Senza effetto."),
 "91a0df6b252bd637": (L, "no", "no", "revisore", "R1."),
 "764c3094bf5082c2": (L, "si", "no", "revisore", "R2. Si perdono ulcera profonda contro no (76/86) e microscopica contro normale (28/24)."),
 "b3a4dfdc5abb7bb3": (L, "si", "no", "revisore", "R2. Si perde microscopica contro normale (28/24)."),
 "19ec64fd35d6e60e": (L, "no", "no", "revisore", "R1."),
 "29826af1718c9156": (L, "no", "no", "revisore", "R1."),
 "c40de1afecf80490": (L, "no", "no", "revisore", "R1."),
 "50014f7380620132": (L, "no", "no", "revisore", "R1."),
 "9df86936cd89363a": (L, "no", "no", "revisore", "R1."),
 "eeb7c7209d8342c5": (L, "no", "no", "revisore", "R1."),
 "d22a8c0f99dfc805": (L, "si", "no", "revisore", "R2. Base della complicazione non scritta: si perde complicati contro non complicati (27/183). I controlli al livello «no complication» non sono un errore nella forma T (il valore «-» e' uno solo per 183 malati e 35 controlli)."),
 "400b62925c227072": (L, "si", "no", "in parte", "R2. Il revisore dice non errore (nessun livello sano dentro il fattore). Resta lettura del modello (precedente S12r4, stesso studio); il costo passa a si' per la regola R2: si perde complicati contro non complicati (27/183)."),
 "c0a84d79b09b2047": (L, "si", "no", "in parte", "R2. Come 400b62925c227072."),
 "6ac7f812ede943bf": (L, "no", "no", "in parte", "R1 per description come donatore. Il solo fattore tempo senza base resta non errore: il prelievo prima dell'impianto e' un controllo al tempo zero (regola del PI). Il revisore lo conta come lettura che costa i 2 confronti di Atlas, con un dubbio dichiarato."),
 "71d5f214368ea224": (N, "no", "", "agente", "Il solo fattore tempo senza base resta non errore: il prelievo prima dell'impianto e' un controllo al tempo zero (regola del PI). Il revisore lo conta come lettura che costa i 2 confronti di Atlas, con un dubbio dichiarato."),
 "74c2075a9c2a79fb": (L, "si", "si", "agente", "R4. Coltura e giorno hanno la stessa partizione nella stessa colonna. Il revisore dice non errore (la colonna scrive due variabili), con un dubbio dichiarato."),
 "63b03baa2b65d30d": (L, "no", "no", "agente", "Precedente S12r4 («immortali come non applicabile», errore senza effetto). Il revisore lo chiama imprecisione senza effetto."),
 "5ed8857f92d39b92": (N, "no", "", "agente", "Prompt, riga 42: quando l'agente e' assente il campione sta al livello di base, non a «not applicable»."),
 "2fb90d5c4fa09a68": (N, "no", "", "agente", "Lo stato di infiammazione sta nel nome del sito per 4 campioni su 134: nessuna colonna lo dichiara per tutti e il modello lo scrive in not_understood, come chiede il prompt. Il revisore lo conta come lettura che costa, con un dubbio dichiarato."),
 "8932b888ba7c7fd8": (N, "no", "", "agente", "Forma T: il valore «-» e' uno solo per 183 malati e 35 controlli e ha una voce sola. Uguale all'uscita di Mistral B0, giudicata non errore in S12r3. Il revisore ha dichiarato il dubbio sulla forma."),
 "a56a98225cdef23d": ("fermato dal limite di spesa", "si", "non giudicabile", "convenzione", "Stessa classe. Differenza di sola convenzione sul costo di una riga senza risposta."),
 "e8eabae9715b9922": ("fermato dal limite di spesa", "si", "non giudicabile", "convenzione", "Come a56a98225cdef23d."),
 "58d925d46269617d": ("fermato dal limite di spesa", "si", "non giudicabile", "convenzione", "Come a56a98225cdef23d."),
}
diversi = [s for s in mio if k(mio[s]) != k(rev[s][1])]
assert set(diversi) == set(D), (set(diversi) ^ set(D))
with open(f"{Q}/28-confronto.csv", "w", newline="") as o:
    w = csv.writer(o); w.writerow("scheda studio revisore agente_prima revisore_dice finale chi_ha_ragione motivo".split())
    for s in diversi:
        c = D[s]; w.writerow([s, mio[s]["studio"], rev[s][0], " / ".join(k(mio[s])), " / ".join(k(rev[s][1])), " / ".join(c[:3]), c[3], c[4]])
with open(f"{Q}/27-classi.csv", "w", newline="") as o:
    w = csv.DictWriter(o, fieldnames=["scheda", "studio", "classe", "costa", "costa_su_atlas", "descrizione"]); w.writeheader()
    for s, r in mio.items():
        r = dict(r)
        if s in D and k(r) != D[s][:3]:
            r["classe"], r["costa"], r["costa_su_atlas"] = D[s][:3]
            r["descrizione"] = r["descrizione"].rstrip() + " [DOPO LA REVISIONE: " + D[s][4] + "]"
        w.writerow(r)
for n in "AB":
    t = [s for s in mio if rev[s][0] == n]; d = [s for s in t if s in D]
    print(f"revisore {n}: {len(t)} schede, uguali {len(t) - len(d)}, diverse {len(d)}:", dict(collections.Counter(D[s][3] for s in d)))
print("classi cambiate:", sum(k(mio[s]) != D[s][:3] for s in D), "su", len(D))
