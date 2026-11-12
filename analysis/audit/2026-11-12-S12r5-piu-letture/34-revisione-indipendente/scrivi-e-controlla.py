# Scrive uscita/26-letture-revisore.csv dalle 38 letture del revisore e controlla le regole.
import csv, collections, sys
LM, FO, NE = "lettura del modello", "forma", "non errore"
B0, NU, TD, NS = "in B0", "nella lettura nuova", "in tutte e due", "in nessuna"
R = {}
def r(scheda, causa, dove, etichette, descrizione):
    assert scheda not in R, scheda
    R[scheda] = (causa, dove, ";".join(etichette), descrizione)

r("GSE103501|3d36c1a7730a|da51d3ac", NE, NS, [],
  "L5 aggiunge un fattore di contesto «group» (invitro 18, exvivo 11) dalla colonna vera group, che B0 scrive uninformative; ha la stessa partizione del tempo (06h contro 00h). I 6 gruppi e i confronti 3/3 non cambiano. Dubbio: il costruttore conta un fattore doppio.")
r("GSE112057|76a7c486113f|05690bdd", LM, NU,
  ["GSE112057:NA di gender non dichiarato mancante", "GSE112057:NA di ancestry non dichiarato mancante"],
  "B0 dichiara NA come mancante per gender (11), age at diagnosis (43) e ancestry (11); la lettura nuova lo dichiara solo per age at diagnosis. I controlli con NA diventano soggetti disgiunti: soggetti_disgiunti 5, confronti ritrovati 0/5 (B0 5/5). Fattori e livelli sono uguali a B0.")
r("GSE112057|d62cd9d66170|c25deea5", LM, NU,
  ["GSE112057:NA di ancestry non dichiarato mancante"],
  "La lettura nuova dichiara NA mancante per gender e age at diagnosis, non per ancestry (11 campioni, B0 lo dichiara); il livello ha nome crohns_disease invece di crohn_s_disease. Gruppi e confronti 5/5 uguali a B0: l'errore non costa qui. Dubbio: senza effetto, l'alternativa è «non errore».")
r("GSE147507|176d2a969095|0c9f8029", LM, TD,
  ["GSE147507:fattore organism inventato da cell type", "GSE147507:tempi 4 e 6 ore scritti come non applicabile", "GSE147507:time point non letta"],
  "L3 aggiunge un fattore di contesto «organism» letto da cell type con un livello ferret che la vista non ha (human 20, non applicabile 57) e legge il tempo solo da «time after treatment» con i livelli 9hrs, 12hrs, 24hrs (24hrs 27, 12hrs 14, non applicabile 36: i campioni a 4 e 6 ore cadono in non applicabile). B0 legge solo «time point» e scrive «time after treatment» uninformative. L3 non è chiuso anche per forma (source_name_ch1 ha ruolo uninformative ma due fattori lo leggono); 0/2 contro 2/2. Dubbio: causa mista con la forma.")
r("GSE147507|6e8f57fbd9a5|2060fa8c", LM, TD,
  ["GSE147507:IFNB non applicabile sull'infezione", "GSE147507:time point non letta"],
  "L4 scrive IFNB in un fattore a parte e non applicabile sull'infezione: nascono i confronti IFNB contro IAV e IFNB contro IAVdNS1. Legge il tempo solo da «time after treatment» (IAV contro mock 2/7; B0, che legge solo «time point», 2/2). Aggiunge ruxolitinib dalla description con 6 campioni (L3 ne conta 3 da source_name_ch1: non verificabile, le voci sono troncate). Confronti di Atlas 2/2 in tutte e due.")
r("GSE147507|9f155929b5d0|0c9f8029", LM, NU,
  ["GSE147507:controlli senza livello (ruxolitinib, strain)", "GSE147507:time after treatment non letta"],
  "L8 ha i fattori di B0 più un fattore Ruxolitinib dalla description senza base: 6 campioni Ruxolitinib e 71 a non applicabile, quindi i controlli non hanno un livello. Non è chiuso anche per forma (cell type ha ruolo factor e nessun fattore la legge); 0/2 contro 2/2 di B0. Resta la lettura del tempo di B0 (solo «time point»).")
r("GSE147507|b738508cf3df|d937fe8f", LM, TD,
  ["GSE147507:time point non letta"],
  "Unica differenza: il fattore tempo legge «time after treatment» (45 campioni con un valore) invece di «time point» (20 con un valore). Le due colonne sono complementari e ogni lettura ne legge una sola: B0 dichiara i livelli 4hrs, 6hrs, 12hrs senza campioni (24hrs 16, 9hrs 4, non applicabile 57) e confronta IFNB di tre tempi con 7 mock (6/7); L2 dà IAV contro mock 2/7 e IFNB contro mock 2/4. Atlas 2/2 in tutte e due. Dissento da S12r4 (nessun errore).")
r("GSE46665|9582349882d5|c3219da1", LM, B0,
  ["GSE46665:sigle dei pazienti come malattie"],
  "B0 ha un secondo fattore tempo (T0, T1, T4 dalla description) che ripete il fattore LVAD; L3 non lo ha. In tutte e due le sigle dei pazienti di source_name_ch1 sono livelli di malattia: 25 gruppi di un campione, 0/2.")
r("GSE49155|66212ce60896|84545a0e", LM, B0, [],
  "B0 ha un fattore di contesto cell_type che manda il valore vuoto al livello premalignant_lesion (10 campioni, 6 sono tumori): 0/2. L4 ha solo pathology con base normal e patient come subject/donor: 2/2, senza errori di lettura.")
r("GSE49608|5c490d073b98|0c9f8029", FO, NS, [],
  "Stessi fattori di B0, con cell_line letta da «cell line» invece che da source_name_ch1 (16/16, equivalente). Non chiuso: source_name_ch1 ha ruolo factor e nessun fattore la legge.")
r("GSE49608|5c490d073b98|2aac5829", NE, NS, [],
  "cell_line letta da «cell line» invece che da source_name_ch1: stessi 16 campioni per livello, stessi 8 gruppi, 0/0 confronti in tutte e due. Colonna equivalente; questa corsa è chiusa.")
r("GSE50499|da98547423d3|6298f733", FO, NS, [],
  "B0 non è chiuso: il livello control è usato nelle voci e come base ma manca dall'elenco dichiarato. La lettura nuova legge «mov expression» (low, high, normal), dichiara control, è chiusa e ritrova 1/1. La lettura è la stessa.")
r("GSE50499|fcba6c09e0a4|6298f733", FO, NS, [],
  "Stessa tabella dei fattori di B0, con il livello control dichiarato nell'elenco: chiusa, 1/1. In B0 il livello manca dall'elenco e la corsa non è chiusa.")
r("GSE50760|a6dd321f4dc0|29992090", LM, NU,
  ["GSE50760:tessuto come contesto senza base", "GSE50760:source_name_ch1 come donatore"],
  "La lettura nuova scrive il tessuto (normale, tumore primario, metastasi) come fattore di contesto senza base: nessun confronto del lettore. B0 lo scrive come fattore di stato con base il tessuto sano e forma 2 confronti. source_name_ch1 è subject/donor in tutte e due.")
r("GSE53280|0b6239a2e318|0c9f8029", LM, NU,
  ["GSE53280:controllo mock senza livello"],
  "L3 manda il controllo mock a un livello con nome vuoto e scrive la base vuota: non chiuso, 0/1. B0 ha il livello di controllo e la base: 1/1.")
r("GSE56235|2a0f070d3da2|4a82d6cd", NE, NS, [],
  "Il fattore è letto dalla colonna plasmid invece che da title: stessi campioni per livello (3 e 3), stessi gruppi, 1/1 in tutte e due. Colonna equivalente.")
r("GSE56691|111d229309ad|0c9f8029", LM, NU,
  ["GSE56691:controllo non trattato senza livello"],
  "La lettura nuova manda i campioni non trattati a un livello con nome vuoto nei fattori agente e tempo, con base vuota: non chiuso. B0 scrive il livello di controllo e la base.")
r("GSE56787|12ad9182f3ba|73a391bf", NE, NS, [],
  "Nel fattore cell_type le 24 biopsie hanno il livello «biopsy» invece di «not applicable»: stessi 6 gruppi e stessi confronti di B0. Gli errori che B0 ha già non cambiano e non causano la differenza.")
r("GSE57116|c37409409645|96ec7e0c", LM, NU,
  ["GSE57116:tempo ripetuto come secondo fattore"],
  "L3 scrive un livello di treatment per ogni durata (0, 4, 8 min) e in più un fattore time con gli stessi tre livelli: il tempo è scritto due volte (fattori doppi 1). Gruppi uguali a B0 e 2/2. Dubbio: senza effetto, l'alternativa è «non errore».")
r("GSE57945|6c079af72d99|0c9f8029", LM, NU,
  ["GSE57945:sesso come fattore", "GSE57945:eta' come fattore di contesto"],
  "L2 ha i fattori di B0 (il sesso è fattore di contesto in tutte e due) più due fattori di contesto vuoti, age_at_diagnosis e paris_age, senza livelli (322 campioni non dichiarati). Non chiuso per ruoli incoerenti (l2 type ha ruolo factor senza fattore; Sex, age at diagnosis e paris age hanno ruolo subject ma un fattore le legge); 0/6. Dubbio: la mancata chiusura è in parte forma.")
r("GSE60340|5ec302b13e8b|75c46680", LM, TD,
  ["GSE60340:colonna del trattamento non vista"],
  "Un solo fattore senescence_type da «sample group» come B0, e «treated with» uninformative in tutte e due. Cambia solo la base (immortal invece di young) e il nome quiescence: L3 forma induced_senescence contro immortal 9/3, con un braccio che unisce Adriamycin, 5-aza e H2O2, e quiescence contro immortal 3/3; 0/2 in tutte e due. Dubbio: il cambio di base è difendibile da solo; l'unità nuova è un effetto dell'errore che B0 ha già.")
r("GSE60340|f307254c2df8|00111868", LM, NU,
  ["GSE60340:colonna del trattamento non vista", "GSE60340:passaggio come fattore"],
  "L2 ha il fattore di B0 più un fattore «passage» (tipo time, senza base) letto da passages, che B0 scrive subject/passage; i livelli sono in ordine sbagliato (>200 → high 15, 28-30 → very_high 3). I 6 gruppi sono uguali, nessun confronto (piu_di_un_fattore 12), 0/2. «treated with» resta uninformative.")
r("GSE60340|f88c0bb58658|0c9f8029", LM, B0, [],
  "L7 scrive due fattori: senescence_type (stato, base immortal) e treatment da «treated with» (base none; none 12, adriamycin 3, 5-aza 3, h2o2 3, serum_starved 3). È la lettura giusta; B0 non vede la colonna del trattamento. L7 non è chiuso per forma: induced_senescence e induced_quiescence sono nelle voci e mancano dall'elenco dichiarato. Dubbio: S12r4 dice forma; l'alternativa è forma, in nessuna.")
r("GSE60340|f88c0bb58658|514f21a8", LM, B0, [],
  "Stessa tabella di L7 con tutti i livelli dichiarati: senescence_type (base immortal) e treatment da «treated with» (base none). 8 gruppi identici ad Atlas e 2/2. B0 non vede la colonna del trattamento: 6 gruppi, 0/2.")
r("GSE60340|f9a717c76e3d|4ffd8489", LM, TD,
  ["GSE60340:nessun trattamento diviso in tre livelli", "GSE60340:passaggio come fattore", "GSE60340:base non scritta"],
  "L5 scrive tre fattori: senescence_type (stato, base vuota), agent da «treated with» con None diviso in none (3), none_young (6) e none_replicative (3), e passage come fattore tecnico (4 livelli, senza base). 8 gruppi come Atlas ma nessun confronto (nessuno_al_base 3, piu_di_un_fattore 25), 0/2. B0 non vede la colonna del trattamento (0/2): errori diversi nelle due letture.")
r("GSE60585|fdabeb4309e2|73e24377", NE, NS, [],
  "Il fattore tecnico è letto da molecule_ch1 (polyA RNA 9, total RNA 9) invece che da «molecule subtype» (whole-cell RNA 9, ribosomal RNA depleted 9): stessa partizione, 6 gruppi e 4/4 in tutte e due. Colonna equivalente.")
r("GSE63816|17660776ac46|0c9f8029", LM, NU,
  ["GSE63816:age come donatore"],
  "Stessi tre fattori di B0 (malattia, genotipo dal titolo, shRNA dal titolo). Unica differenza: la colonna age (14 valori; «35» in 6 campioni, la linea TF-1) ha ruolo subject/donor invece di subject/age. Non chiuso in tutte e due per il nome riservato scritto not_applicable (forma, uguale a B0). Dubbio: senza effetto su gruppi e confronti, l'alternativa è «non errore».")
r("GSE63816|41564f163411|0c9f8029", NE, NS, [],
  "Come B0, ma il fattore shRNA unisce ZRSR2 shRNA1 e shRNA2 in un livello knockdown (4) contro control (2); anche Atlas ha un solo gruppo ZRSR2 shRNA di 4 campioni. Non chiuso in tutte e due per not_applicable: è lo stesso motivo di forma di B0 e non causa la differenza. Dissento da S12r4 (forma). L'elenco dichiarato ripete knockdown due volte.")
r("GSE63816|48b16d2d48cc|0c9f8029", LM, NU,
  ["GSE63816:genotipo ZRSR2 non letto", "GSE63816:shRNA letto da source_name_ch1"],
  "La lettura nuova scrive title uninformative e non ha il fattore genotipo (B0 dal titolo: mutant 8, wild_type 4). Il fattore shRNA legge source_name_ch1: midollo → not_applicable (16), linea TF-1 → control_shRNA (tutti e 6; shRNA1 e shRNA2 dichiarati senza campioni). Non chiuso per not_applicable; 0/3.")
r("GSE65335|69079952891b|d1fc7ae6", NE, NS, [],
  "growth_condition da «growth conditions» è una perturbazione con base submerged; in B0 è contesto senza base. Stessi livelli e 3 gruppi; la lettura nuova forma ALI contro submerged (2/2; B0 1/2). Dubbio: l'alternativa è lettura del modello in B0, ma ALI al giorno 14 e submerged al giorno 8 differiscono anche nel tempo e le due letture sono difendibili.")
r("GSE66573|633fc3373743|34fd6a3b", LM, B0, [],
  "B0 dà a source_name_ch1 (2 valori: healthy control 8, RRMS 6) il ruolo subject/donor; le letture nuove la scrivono uninformative. Stesso fattore disease_state, 2 gruppi, 1/1 (in B0 con avviso per i soggetti disgiunti).")
r("GSE67812|0fa6d852d97e|7f5a8b72", LM, NU,
  ["GSE67812:controlli scritti come DM1"],
  "La vista ha 3 campioni (ALS11, ALS13, ALS14) con source_name_ch1 «Control» e disease state «control» costanti. La lettura nuova li scrive dm1 (3) e lascia la base control senza campioni; B0 li scrive control. Nessun confronto di Atlas (0/0).")
r("GSE68919|77e51d4c9b22|0c9f8029", LM, NU,
  ["GSE68919:controllo PBS senza livello"],
  "La lettura nuova scrive un fattore «integrin» da treatment: PBS va a un livello con nome vuoto (3), la base è vuota, gli altri livelli sono beta5KD 2 e wild_type 3. Non chiuso, 0/1. B0 ha treatment con base control: 1/1.")
r("GSE69597|5d94015d9663|dfae353f", LM, NU,
  ["GSE69597:paese come fattore"],
  "L5 ha i tre fattori di B0 più country (Macedonia 149, Spain 17) come fattore di contesto senza base; in B0 country è subject/donor. 10 gruppi contro 7, confronti dentro il paese, 0/6 (B0 5/6).")
r("GSE69597|9e2a6d6e69a7|4db9efdf", NE, NS, [],
  "Lo stadio è letto da «subgroup» (Group 1, 2, 3 → acuto 76; 5a, 5b → cronico sotto 10 anni 24; 4a → cronico sopra 10 anni 4) invece che da «history of brucellosis»: stessa partizione per la brucellosi. La leishmaniosi (16) è un livello dello stadio invece di non applicabile. 8 gruppi e confronti uguali a B0, 5/6. Dubbio: una malattia scritta come livello dello stadio, senza effetto.")
r("GSE71289|11e3bc8e3f80|a299e5b1", NE, NS, [],
  "Il fattore genotipo ha tipo perturbation invece di state: stesse colonne, livelli, base wt, 8 gruppi, 6/6. Fattori doppi 1 in tutte e due (cell type e differentiation time hanno la stessa partizione).")
r("GSE83687|709dd1724b3e|f424c1c9", LM, NU,
  ["GSE83687:ileo come non applicabile"],
  "Il fattore tessuto da source_name_ch1 manda ileum (20), rightcolon_noninflamed (2) e rightcolon_inflamed (1) a non applicabile (23). Nascono Crohn contro sano 19/2 e colite ulcerosa contro sano 2/2 dentro «non applicabile»; 24 gruppi (B0 25), 0/2 in tutte e due.")
r("GSE83687|8b4f154a1d3d|0c9f8029", FO, NS, [],
  "Stessa tabella dei fattori e stesse voci di B0 (stessa firma 8b4f154a1d3d). Il livello ileum (20 campioni) è usato nelle voci e manca dall'elenco dichiarato: non chiuso.")

with open("schede-da-leggere.csv", newline="", encoding="utf-8") as f:
    da_leggere = list(csv.DictReader(f))
ids = [x["scheda"] for x in da_leggere]
studio = {x["scheda"]: x["studio"] for x in da_leggere}
assert len(ids) == 38 and len(set(ids)) == 38, len(ids)
assert set(ids) == set(R), (set(ids) ^ set(R))
with open("uscita/26-letture-revisore.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(["scheda", "studio", "causa", "dove", "etichette", "descrizione"])
    for i in ids:
        w.writerow([i, studio[i], *R[i]])

# Controllo: rilegge il file scritto.
with open("uscita/26-letture-revisore.csv", newline="", encoding="utf-8") as f:
    righe = list(csv.DictReader(f))
err = []
if len(righe) != 38: err.append("righe %d" % len(righe))
if [x["scheda"] for x in righe] != ids: err.append("id diversi da schede-da-leggere.csv")
for x in righe:
    s, c, d = x["scheda"], x["causa"], x["dove"]
    et = [e for e in x["etichette"].split(";") if e]
    if x["studio"] != studio[s] or not s.startswith(x["studio"] + "|"): err.append(s + ": studio")
    if c not in (LM, FO, NE): err.append(s + ": causa")
    if d not in (B0, NU, TD, NS): err.append(s + ": dove")
    if c == LM and d == NS: err.append(s + ": lettura del modello con in nessuna")
    if c in (FO, NE) and d != NS: err.append(s + ": forma o non errore con dove")
    if d in (NU, TD) and not et: err.append(s + ": manca l'etichetta")
    for e in et:
        if not e.startswith(x["studio"] + ":"): err.append(s + ": etichetta " + e)
    if not x["descrizione"].strip(): err.append(s + ": descrizione vuota")
print("righe:", len(righe))
print("causa:", dict(collections.Counter(x["causa"] for x in righe)))
print("dove:", dict(collections.Counter(x["dove"] for x in righe)))
print("schede con etichette:", sum(1 for x in righe if x["etichette"]))
vecchie = set(l.strip() for l in open("etichette-S12r4.txt", encoding="utf-8") if l.strip())
usate = sorted(set(e for x in righe for e in x["etichette"].split(";") if e))
print("etichette nuove (non in etichette-S12r4.txt):")
for e in usate:
    if e not in vecchie: print("  ", e)
print("ERRORI:", err if err else "nessuno")
sys.exit(1 if err else 0)
