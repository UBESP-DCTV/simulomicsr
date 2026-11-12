#!/usr/bin/env python3
"""S12r5 - l'aggiudicazione dei disaccordi fra la lettura dell'agente e la lettura del revisore indipendente.
AUDIT INTERNO, dichiarato dopo i numeri: nessuna etichetta entra nella pipeline.

Legge   prima/26-letture.csv        (la lettura dell'agente prima della revisione, commit ca32886)
        26-letture-revisore.csv     (la lettura del revisore, 38 schede, materiale congelato fuori dal repository)
Scrive  ../26-letture.csv           (la lettura dell'agente dopo l'aggiudicazione)
        35-aggiudicazione.csv/.md   (i disaccordi uno per uno: io, il revisore, l'esito, il motivo)
Ferma se le schede in disaccordo non sono esattamente quelle aggiudicate qui sotto.
Uso: python3 analysis/audit/2026-11-12-S12r5-piu-letture/34-revisione-indipendente/35-aggiudica.py

Criteri dell'aggiudicazione (scritti dopo la revisione, perche' le istruzioni del revisore non li portavano):
 C1  un errore di lettura si conta anche se non cambia gruppi e confronti, come S12r4 ha fatto per i 9 errori di B0
     (`source_name_ch1` come donatore; NA di gender non dichiarato). Il criterio di prima («un'omissione senza
     effetto che S12r4 non ha contato non si conta») non era scritto: cade.
 C2  la causa di una scheda e' la causa della DIFFERENZA da B0, non di ogni difetto della lettura nuova.
 C3  un errore che B0 e la lettura nuova hanno in forma speculare (una delle due colonne del tempo) ha UNA etichetta
     sola ed e' un errore di B0: non e' nuovo. Il conto con le due etichette del revisore sta accanto.
 C4  leggere un fattore vero da una colonna col ruolo sbagliato e' forma, non lettura.

Un errore in piu', che ne' l'agente ne' il revisore avevano etichettato (il revisore lo ha scritto fra le osservazioni
«non verificabili»: ruxolitinib a 6 campioni in L4 e L8 contro 3 in L3). Verificato dall'agente sulla vista
(60-viste-v0.jsonl) e sulle uscite dopo la revisione: i 6 valori di `description` sono BN4-BN9, cioe' GSM4486160-65;
il ruxolitinib e' scritto solo nel `source_name_ch1` di GSM4486163-65 (BN7-BN9). L4 e L8 lo assegnano anche a
GSM4486160-62. Etichetta RUX, aggiunta alle due schede.
"""
import csv, os, sys
qui = os.path.dirname(os.path.abspath(__file__))
def leggi(p): return list(csv.DictReader(open(os.path.join(qui, p), encoding="utf-8")))
def et(s): return sorted(x.strip() for x in s.replace("|", ";").split(";") if x.strip())
io, rev = leggi("prima/26-letture.csv"), {r["scheda"]: r for r in leggi("26-letture-revisore.csv")}
if [r["scheda"] for r in io] and set(r["scheda"] for r in io) != set(rev): sys.exit("le schede non coincidono")

TEMPO = "GSE147507:tempo letto da una sola delle due colonne"
RUX = "GSE147507:ruxolitinib assegnato a 3 campioni che non lo ricevono"
# scheda -> (causa, dove, etichette finali, esito, motivo, descrizione finale o None per tenere la mia)
A = {
 "GSE112057|76a7c486113f|05690bdd": ("lettura del modello", "nella lettura nuova",
   ["GSE112057:NA di gender non dichiarato mancante", "GSE112057:NA di ancestry non dichiarato mancante"],
   "ha ragione il revisore", "La mia descrizione nomina gender e ancestry, la mia etichetta solo gender: omissione mia.", None),
 "GSE112057|d62cd9d66170|c25deea5": ("lettura del modello", "nella lettura nuova",
   ["GSE112057:NA di ancestry non dichiarato mancante"],
   "ha ragione il revisore (criterio C1)", "B0 dichiara NA mancante per ancestry, la lettura nuova no: e' un errore senza effetto (5/5), e S12r4 conta errori senza effetto fra i 9 di B0. S12r4 non aveva contato questa firma.",
   "L2, L4, L8: il NA di ancestry (11 campioni) non e' dichiarato mancante, B0 lo dichiara; senza effetto su gruppi e confronti (5/5 come B0). Dopo la revisione: errore di lettura senza effetto (criterio C1); S12r4 ha visto la stessa firma senza contarlo"),
 "GSE147507|176d2a969095|0c9f8029": ("lettura del modello", "in tutte e due",
   ["GSE147507:trattamento diviso in due fattori (infezione, IFNB)", "GSE147507:tempi di 4 e 6 ore a non applicabile",
    "GSE147507:fattore organism inventato da cell type", TEMPO],
   "in parte: 3 punti al revisore, 1 a me", "Al revisore: organism (descritto da me e non etichettato), il tempo letto da una colonna sola (verificato sulle uscite), ACE2 e ruxolitinib da source_name_ch1 sono fattori veri con un ruolo incoerente (forma, criterio C4: tolgo la mia etichetta). A me: in L3 la colonna treatment e' divisa in infection e interferon_beta_treatment (verificato sull'uscita), il revisore non lo etichetta.",
   "L3: 8 fattori; treatment divisa in infection (IFNB a non applicabile) e interferon_beta_treatment (gli infettati a non applicabile); il tempo letto solo da time after treatment, con 4 e 6 ore a non applicabile (B0 lo legge solo da time point); un fattore organism da cell type con un livello ferret che la colonna non ha; ACE2 e ruxolitinib letti da source_name_ch1, che ha ruolo uninformative (non chiuso: forma); 0/2 (B0 2/2)"),
 "GSE147507|6e8f57fbd9a5|2060fa8c": ("lettura del modello", "in tutte e due",
   ["GSE147507:trattamento diviso in due fattori (infezione, IFNB)", TEMPO, RUX],
   "ha ragione il revisore; in piu' un errore che nessuno dei due aveva etichettato", "La sua etichetta «IFNB non applicabile sull'infezione» e' la mia «trattamento diviso in due fattori». In piu' il tempo e' letto da una colonna sola, come in B0 ma dall'altra colonna (verificato). In piu', verificato sulla vista dopo la revisione: il ruxolitinib e' assegnato a 6 campioni (GSM4486160-65) e solo GSM4486163-65 lo ricevono.",
   "L4: treatment divisa in infection (IFNB a non applicabile) e interferon_beta (gli infettati al livello mock): nasce il confronto IFNB contro i gruppi IAV e IAVdNS1 (fuori dall'universo di Atlas); il tempo letto solo da time after treatment (B0 solo da time point); ruxolitinib letto dalla description con base dichiarata, assegnato a 6 campioni (GSM4486160-65) mentre lo ricevono solo GSM4486163-65; i 2 confronti di Atlas restano (2/2)"),
 "GSE147507|9f155929b5d0|0c9f8029": ("lettura del modello", "nella lettura nuova",
   ["GSE147507:controlli senza livello (ruxolitinib, strain)", TEMPO, RUX],
   "ha ragione il revisore; in piu' un errore che nessuno dei due aveva etichettato", "L8 ha la lettura del tempo di B0 (solo time point): l'errore e' presente anche qui e non fa la differenza da B0. In piu', verificato sulla vista dopo la revisione: il ruxolitinib e' assegnato a 6 campioni (GSM4486160-65) e solo GSM4486163-65 lo ricevono.",
   "L8: fattori di B0 piu' Ruxolitinib dalla description, senza base e con 71 campioni a non applicabile, assegnato a 6 campioni (GSM4486160-65) mentre lo ricevono solo GSM4486163-65; non chiude (cell type con ruolo factor e nessun fattore la legge); 0/2; il tempo letto solo da time point, come B0; come RP di S12r4"),
 "GSE147507|b738508cf3df|d937fe8f": ("lettura del modello", "in tutte e due", [TEMPO],
   "ha ragione il revisore", "Verificato sulle 9 uscite: time point (20 campioni con un valore) e time after treatment (45) sono complementari e ogni lettura ne legge una sola, l'altra ha ruolo uninformative. B0 dichiara 12hrs, 4hrs e 6hrs senza campioni. E' il limite «una variabile scritta in piu' colonne» della spec (S12r3, punto 5): il modello doveva leggere una colonna intera o scrivere not_understood, e non lo fa. S12r3 e S12r4 non lo hanno contato come errore.",
   "L2: come B0, con il tempo letto da time after treatment (45 campioni con un valore) al posto di time point (20); le due colonne sono complementari e ogni lettura ne legge una sola; gruppi sui campioni comuni e confronti di Atlas uguali, 2/2. Dopo la revisione: errore di lettura in tutte e due"),
 "GSE60340|f88c0bb58658|0c9f8029": ("lettura del modello", "in B0", [],
   "ha ragione il revisore (criterio C2)", "La lettura di L7 e' giusta e B0 non vede il trattamento: la differenza nasce dall'errore di B0, come nella scheda di L6 con la stessa firma. Che L7 non chiuda e' forma, ma non e' la causa della differenza.",
   "L7: due fattori, il trattamento e' letto da treated with con base none: l'errore di B0 e' assente; non chiude perche' induced_senescence e induced_quiescence mancano dall'elenco dichiarato (forma); S12r4 ha scritto forma per la stessa firma. Dopo la revisione: la differenza da B0 e' l'errore di B0"),
 "GSE63816|17660776ac46|0c9f8029": ("lettura del modello", "nella lettura nuova", ["GSE63816:age come donatore"],
   "ha ragione il revisore (criterio C1)", "age come subject/donor al posto di subject/age: stesso tipo di errore di «source_name_ch1 come donatore», che S12r4 conta fra i 9 di B0. Senza effetto.",
   "L6: fattori, voci e motivi di non chiusura uguali a B0; il ruolo di age e' subject/donor al posto di subject/age, senza effetto. Dopo la revisione: errore di lettura senza effetto (criterio C1)"),
 "GSE63816|41564f163411|0c9f8029": ("non errore", "in nessuna", [],
   "ha ragione il revisore (criterio C2)", "Il motivo di forma (not_applicable) e' uguale in B0 e non fa la differenza. La differenza e' l'unione dei due shRNA in un livello, come fa Atlas: difendibile.",
   "L7: come B0, non chiuso per il nome riservato scritto not_applicable (uguale a B0); il fattore shRNA unisce i due shRNA in un livello knockdown, come il gruppo di Atlas; S12r4 ha scritto forma per la stessa firma (B0pl2). Dopo la revisione: non errore"),
}
diversi = [r["scheda"] for r in io if (r["causa"], r["dove"], et(r["etichette"])) != (rev[r["scheda"]]["causa"], rev[r["scheda"]]["dove"], et(rev[r["scheda"]]["etichette"]))]
if sorted(diversi) != sorted(A): sys.exit("schede in disaccordo diverse da quelle aggiudicate: %s" % sorted(set(diversi) ^ set(A)))

righe = []
for r in io:
    k = r["scheda"]
    if k in A:
        c, d, e, esito, motivo, desc = A[k]; v = rev[k]
        righe.append(dict(scheda=k, io_causa=r["causa"], io_dove=r["dove"], io_etichette=r["etichette"],
                          rev_causa=v["causa"], rev_dove=v["dove"], rev_etichette=v["etichette"],
                          dopo_causa=c, dopo_dove=d, dopo_etichette=";".join(e), esito=esito, motivo=motivo))
        r.update(causa=c, dove=d, etichette=";".join(e)); r["descrizione"] = desc or r["descrizione"]
with open(os.path.join(qui, "..", "26-letture.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["scheda", "studio", "causa", "dove", "etichette", "descrizione"], quoting=csv.QUOTE_ALL)
    w.writeheader(); w.writerows(io)
with open(os.path.join(qui, "35-aggiudicazione.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(righe[0]), quoting=csv.QUOTE_ALL); w.writeheader(); w.writerows(righe)

def conta(rr, campo, voci): return ", ".join("%s %d" % (v, sum(1 for r in rr if r[campo] == v)) for v in voci)
CAUSE, DOVE = ["lettura del modello", "forma", "non errore"], ["in B0", "nella lettura nuova", "in tutte e due", "in nessuna"]
prima = leggi("prima/26-letture.csv")
with open(os.path.join(qui, "35-aggiudicazione.md"), "w", encoding="utf-8") as f:
    p = lambda *a: print(*a, file=f)
    p("# S12r5 - i disaccordi fra l'agente e il revisore, uno per uno (generato da 35-aggiudica.py)\n")
    p("Schede: %d. In disaccordo su causa, dove o etichette: %d (causa %d, dove %d, etichette %d).\n" % (
      len(io), len(A), sum(1 for x in righe if x["io_causa"] != x["rev_causa"]), sum(1 for x in righe if x["io_dove"] != x["rev_dove"]),
      sum(1 for x in righe if et(x["io_etichette"]) != et(x["rev_etichette"]))))
    p("| lettura | cause | dove |\n|---|---|---|")
    p("| dell'agente, prima della revisione | %s | %s |" % (conta(prima, "causa", CAUSE), conta(prima, "dove", DOVE)))
    p("| del revisore | %s | %s |" % (conta(list(rev.values()), "causa", CAUSE), conta(list(rev.values()), "dove", DOVE)))
    p("| dell'agente, dopo l'aggiudicazione | %s | %s |\n" % (conta(io, "causa", CAUSE), conta(io, "dove", DOVE)))
    resta = [x["scheda"] for x in righe if (x["dopo_causa"], x["dopo_dove"]) != (x["rev_causa"], x["rev_dove"])]
    p("Dopo l'aggiudicazione causa e dove sono diversi dal revisore in %d schede%s.\n" % (len(resta), (": " + ", ".join(resta)) if resta else ""))
    for x in righe:
        p("## `%s`\n" % x["scheda"])
        p("- **io, prima:** %s; %s; %s" % (x["io_causa"], x["io_dove"], x["io_etichette"] or "nessuna etichetta"))
        p("- **il revisore:** %s; %s; %s" % (x["rev_causa"], x["rev_dove"], x["rev_etichette"] or "nessuna etichetta"))
        p("- **dopo:** %s; %s; %s" % (x["dopo_causa"], x["dopo_dove"], x["dopo_etichette"] or "nessuna etichetta"))
        p("- **esito:** %s. %s\n" % (x["esito"], x["motivo"]))
print("aggiudicate %d schede; scritti 26-letture.csv, 35-aggiudicazione.csv, 35-aggiudicazione.md" % len(A))
