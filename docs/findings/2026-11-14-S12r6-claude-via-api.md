---
type: Finding
title: "I modelli Claude via API come lettori dello studio: quale sbaglia meno, e uno legge senza errori? Haiku, Sonnet, Opus e Fable, due forme dell'uscita, due corse, gli stessi 47 studi (prova di sola misura, progetto chiuso)"
description: "Opus sbaglia meno: con lo schema v1 vincolato ha un errore di lettura che costa gruppi o confronti in 2 e 3 studi su 47 nelle due corse (1 e 2 col conto delle sessioni di prima, contro i 5 di Mistral-Small 3.2), chiude 47 studi su 47 e ritrova 72 confronti di Atlas su 95. Nessuna delle 17 corse è senza un errore di lettura che costa e nessun modello dà la stessa uscita in due corse. Le quattro risposte della carta: nessuna configurazione ha quattro sì."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-14T21:30:00+01:00}
sources:
- {id: carta, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/00-previsioni.md", title: "La carta: forme T e V, impostazioni, regole della chiamata, cancelli K1-K5, previsioni P1-P15, le quattro risposte, depositati prima delle corse (commit ed52296)"}
- {id: adr30, resource: "docs/decisions/0030-chiusura-del-progetto-non-si-puo-fare.md", title: "ADR-0030 e aggiornamento del 2026-11-14: prova di sola misura ordinata dal PI (commit 3ba8d2d)"}
- {id: esplorazione, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/05-esplorazione/", title: "Le prove di esplorazione prima del deposito: l'API non accetta lo schema B0 come vincolo"}
- {id: lancio, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/23-lancia.py", title: "Il programma di lancio (e 23b-completa.py per i tre studi fermati)"}
- {id: sha, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/23-uscite-sha256.txt", title: "SHA-256 delle uscite congelate (e 23b-uscita-sha256.txt)"}
- {id: misura, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/24-out.txt", title: "La misura delle 16 corse col programma depositato: cancelli, numeri per corsa, appaiati, ripetibilità, previsioni"}
- {id: corse, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/24-corse.csv", title: "Una riga per corsa: chiusi, identici, ritrovati, rifiuti, token, dollari"}
- {id: appaiati, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/24-appaiati.csv", title: "Differenze appaiate contro Mistral nella stessa forma e contro il metodo di oggi"}
- {id: ripetibilita, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/24-ripetibilita.csv", title: "Ripetibilità fra le due corse"}
- {id: previsionicsv, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/24-previsioni.csv", title: "Esito delle previsioni P1-P12, P14, P15 sulla corsa 1"}
- {id: accanto, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/24b-out.txt", title: "La misura accanto con i tre studi di Fable completati (24b-misura-1b.R)"}
- {id: deviazioni, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/25-deviazioni.md", title: "Le deviazioni dalla carta, §1-§4"}
- {id: classi, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/27-classi.csv", title: "La lettura delle 74 schede delle corse 1, dopo la revisione indipendente (audit interno)"}
- {id: p13, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/27-P13.csv", title: "La previsione P13 per modello e forma, conto largo e stretto"}
- {id: revisione, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/28-confronto.csv", title: "La revisione indipendente (due subagenti Claude, audit interno): 26 schede diverse, chi ha ragione e perché; regole R1-R4 in 28-revisione.py"}
- {id: nuove, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/29-classi-nuove.csv", title: "La lettura delle 27 schede nuove delle corse 2 e della corsa completata, senza revisione indipendente"}
- {id: conti, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/29-out.txt", title: "I conti degli errori di lettura sulle 17 corse (29-conti.R), con 29-errori-per-corsa.csv, 29-due-corse.csv, 29-largo-col-precedente.csv"}
- {id: tabelle, resource: "analysis/audit/2026-11-14-S12r6-claude-via-api/30-tabelle.md", title: "Le tabelle di questo finding, generate dai CSV (30-tabelle.py)"}
- {id: s12r4, resource: "docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md", title: "La sessione sulle cause (S12r4): i 9 errori di lettura di B0, il precedente «base non scritta senza costo»"}
- {id: s12r5, resource: "docs/findings/2026-11-12-S12r5-piu-letture-dello-stesso-studio.md", title: "La sessione con più letture (S12r5): l'errore di GSE147507"}
---

# In breve

## In breve: quale modello Claude sbaglia meno quando legge gli studi, e uno di loro legge senza errori?

**A cosa serviva.** Il progetto è chiuso, e questa è una prova di sola misura che hai ordinato tu. Quattro modelli Claude (Haiku, Sonnet, Opus, Fable) hanno letto gli stessi 47 studi già letti da Mistral-Small 3.2, il modello di produzione. Ogni modello ha letto ogni studio due volte, in due forme della risposta. Nella prima forma il modello riceve lo schema della risposta come testo, nella seconda il servizio obbliga la risposta a uno schema fisso. Poi ho letto tutte le risposte in disaccordo con i curatori di Expression Atlas e ho contato gli errori di lettura.

**Cosa abbiamo trovato.**

1. **Opus sbaglia meno, ma nessun modello legge senza errori.** Con lo schema fisso Opus ha un errore di lettura che cambia i gruppi o i confronti in 2 studi su 47 nella prima corsa. Nella seconda corsa gli studi sono 3. Un solo studio (GSE69597) cambia la misura contro i curatori. Opus chiude 47 studi su 47 e ritrova 72 confronti dei curatori su 95 in tutte e due le corse. Mistral ha un errore che cambia i gruppi o i confronti in 5 studi, con il conto meno severo delle sessioni di prima. Con quel conto Opus ne ha 1 e 2.
2. **Gli altri tre modelli sbagliano di più, o rifiutano studi.** Sonnet ha un errore in 4 o 5 studi, e in ogni corsa un solo studio cambia la misura contro i curatori. Haiku ha un errore in un numero di studi fra 4 e 7. Fable ha un errore in 2 o 3 studi, ma rifiuta di leggere uno studio (GSE71421) in ogni corsa. Con lo schema come testo rifiuta anche un secondo studio. Fable costa circa 32 dei 51,5 dollari spesi.
3. **Nessuna delle 17 corse è senza un errore di lettura che cambia i gruppi o i confronti.** Gli errori cadono in 11 studi su 47, e alcuni studi sono difficili per tutti i modelli. Nello studio GSE69597 il modello scrive il paese dei pazienti come un fattore, in 14 corse su 17. Lo studio GSE57945 ha un errore in 11 corse.
4. **Nessun modello dà la stessa risposta in due corse uguali.** Il servizio non permette di fissare la temperatura. Fra le due corse la risposta dà gli stessi fattori, gruppi e confronti in un numero di studi fra 25 e 41 su 47. Mistral dà due risposte uguali al carattere in 47 studi su 47. Anche gli studi con errore cambiano. Opus con lo schema fisso ha l'errore in 2 studi in tutte e due le corse, e in 1 studio in una sola.
5. **Con lo schema fisso i modelli Claude ritrovano più confronti di Mistral. Con lo schema come testo la prova non mostra una differenza.** Con lo schema fisso ritrovano fra 68 e 72 confronti su 95, contro 50 di Mistral nella stessa forma. Con lo schema come testo ritrovano fra 60 e 72, contro 68 di Mistral. La forma migliore di Mistral e la forma migliore di Claude sono vicine: 68 contro 72.

**Cosa devi decidere.**

1. **Che cosa facciamo di questo risultato? Raccomando di fermarci: il risultato resta come misura e il progetto resta chiuso.** La tua regola dice che nessun errore si accetta. Il modello migliore ha ancora un errore in 2 o 3 studi su 47 e non ripete la stessa risposta. Inoltre una regola del progetto vieta un modello Claude nella pipeline e nella validazione pubblicata.
   - In alternativa riapri il progetto con Opus come lettore. Serve una tua decisione che supera la chiusura e la regola su Claude. Con lo stesso conto gli studi con errore scendono da 5 a 1 o 2 su 47, ma non vanno a zero. Ogni corsa dà risposte diverse, quindi un risultato pubblicato non è riproducibile al carattere. Una lettura dei 47 studi costa circa 2,70 dollari.
   - In alternativa faccio un'altra prova con la chiave, che vale fino a domani alle 18:20. Esempio: Opus legge ogni studio più volte e un programma tiene la risposta più frequente. La prova può togliere gli errori presenti in una sola corsa. Non toglie gli errori presenti in tutte le corse, come GSE69597 e GSE57945, quindi non porta a zero errori. Non la raccomando.

**Comunque:**

- gli 82 studi chiusi per il giudizio finale restano chiusi, e la pipeline non cambia;
- la mia lettura degli errori non è cieca, e un modello Claude ha giudicato le risposte dei modelli Claude;
- due revisori indipendenti hanno riletto le 74 schede delle prime corse. Nessuno ha riletto le 27 schede nuove delle seconde corse;
- la chiave è ancora nel file locale del progetto. Quando decidi di fermarci tolgo la riga, e tu cancelli la chiave.

Appena decidi questo punto, la sessione è chiusa.

---

# 1. Che cosa è stato fatto

Prova di sola misura ordinata dal PI il 2026-11-14 a progetto chiuso (ADR-0030, aggiornamento[^adr30]). Gli stessi 47
studi di sviluppo, la stessa vista v0, lo stesso costruttore dei confronti e le stesse misure contro Expression Atlas
delle prove S12r-S12r5. Niente entra nel pacchetto. Gli 82 studi di giudizio non sono stati letti (cancello K5).

- **Modelli:** `claude-haiku-5-5`, `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-fable-5-1`, via API con la chiave
  a tempo del PI. `output_config.effort = "high"`, ragionamento di default, `max_tokens` 64000, flusso, nessuna
  `temperature` (l'API la rifiuta), 8 chiamate in parallelo.[^carta]
- **Due forme**, perché l'API non accetta lo schema `B0` come vincolo («the compiled grammar is too large» per 45
  studi su 47)[^esplorazione] e il PI ha scelto di fare tutte e due le strade:
  - **forma T, «schema `B0` come testo»**: prompt v2, lo schema `B0` dello studio scritto nel messaggio, uscita non
    vincolata, validata da un programma contro lo schema `B0` (adattatore `B0`). Non è la stessa forma di Mistral:
    Mistral subiva lo schema come vincolo, qui il modello lo legge;
  - **forma V, «schema v1 vincolato»**: prompt v1, l'API vincola l'uscita allo schema v1 (adattatore `A0`). È la
    forma della prova ripetuta (S12r2).
- **Corse:** 4 modelli × 2 forme × 2 corse = 16 corse da 47 studi, più 3 chiamate per completare la corsa 1 di
  Fable nella forma V, fermata dal limite di spesa (`V-fable-corsa1b`). Uscite congelate con SHA-256 prima di ogni misura.[^sha]
- **Misura:** programma depositato `24-misura.R`, senza cambi; la misura accanto con i tre studi completati sta in
  `24b-misura-1b.R`. **I cancelli K1-K5 passano**[^misura] (K1: il programma ridà i numeri congelati di Mistral e
  del metodo di oggi).
- **Lettura:** tutte le schede di disaccordo delle 8 corse 1 (74 schede, 19 studi), con revisione indipendente di
  due subagenti; poi le 27 schede nuove delle corse 2 e della corsa completata, senza revisione (deviazione §4).
  In tutto 101 schede in 22 studi.[^conti]

# 2. I numeri delle corse

**Tabella 1. Le 17 corse: chiusura e misure contro Atlas**

`V-fable corsa 1` è la corsa fermata dal limite di spesa (3 studi senza chiamata); `V-fable corsa 1b` è la stessa corsa con i tre studi completati.

| corsa | chiusi su 47 | (a) gruppi identici su 47 | (b) ritrovati | (b) su 97 | (c) errori / giudicabili | non valide | valide non chiuse | rifiuti | dollari |
|---|---|---|---|---|---|---|---|---|---|
| T-haiku corsa 1 | 47 | 38 | 71/95 | 71/97 | 3/18 | 0 | 0 | 0 | 0,21 |
| T-haiku corsa 2 | 46 | 38 | 68/95 | 68/97 | 1/22 | 1 | 0 | 0 | 0,22 |
| T-sonnet corsa 1 | 46 | 39 | 72/95 | 72/97 | 1/21 | 0 | 1 | 0 | 1,79 |
| T-sonnet corsa 2 | 46 | 38 | 70/95 | 70/97 | 1/24 | 1 | 0 | 0 | 1,82 |
| T-opus corsa 1 | 45 | 37 | 69/95 | 69/97 | 2/22 | 1 | 1 | 0 | 3,72 |
| T-opus corsa 2 | 47 | 38 | 67/95 | 67/97 | 2/33 | 0 | 0 | 0 | 3,63 |
| T-fable corsa 1 | 44 | 35 | 60/95 | 62/97 | 2/34 | 0 | 1 | 2 | 8,65 |
| T-fable corsa 2 | 45 | 36 | 65/95 | 67/97 | 2/31 | 0 | 0 | 2 | 8,68 |
| V-haiku corsa 1 | 46 | 37 | 72/95 | 72/97 | 1/19 | 0 | 1 | 0 | 0,14 |
| V-haiku corsa 2 | 47 | 39 | 68/95 | 68/97 | 3/20 | 0 | 0 | 0 | 0,14 |
| V-sonnet corsa 1 | 47 | 39 | 72/95 | 72/97 | 2/25 | 0 | 0 | 0 | 1,36 |
| V-sonnet corsa 2 | 47 | 38 | 70/95 | 70/97 | 2/23 | 0 | 0 | 0 | 1,32 |
| V-opus corsa 1 | 47 | 38 | 72/95 | 72/97 | 2/32 | 0 | 0 | 0 | 2,70 |
| V-opus corsa 2 | 47 | 38 | 72/95 | 72/97 | 2/30 | 0 | 0 | 0 | 2,67 |
| V-fable corsa 1 | 43 | 36 | 69/95 | 71/97 | 2/26 | 0 | 0 | 1 | 6,48 |
| V-fable corsa 1b | 46 | 37 | 69/95 | 71/97 | 2/31 | 0 | 0 | 1 | 7,23 |
| V-fable corsa 2 | 46 | 37 | 69/95 | 71/97 | 2/38 | 0 | 0 | 1 | 7,18 |

Termini di paragone: metodo di oggi 14/47 e 13/95; Mistral-Small 3.2 forma `B0` 45 chiusi, 36/47, 68/95, 2/33; Mistral-Small 3.2 schema v1 34 chiusi, 31/47, 50/95, 0/4.

**Tabella 2. Differenza appaiata nei confronti ritrovati (b), punti percentuali, IC95 per studio**

| corsa | Claude % | Mistral stessa forma % | Claude meno Mistral | esito | Claude meno oggi |
|---|---|---|---|---|---|
| T-haiku corsa 1 | 74,7 | 71,6 | +3,2 (-6,5, +12,5) | a cavallo di 0 | +61,1 (+44,9, +74,7) |
| T-haiku corsa 2 | 71,6 | 71,6 | +0,0 (-17,9, +18,0) | a cavallo di 0 | +57,9 (+39,8, +73,3) |
| T-sonnet corsa 1 | 75,8 | 71,6 | +4,2 (-11,8, +20,0) | a cavallo di 0 | +62,1 (+45,5, +75,3) |
| T-sonnet corsa 2 | 73,7 | 71,6 | +2,1 (-17,6, +20,4) | a cavallo di 0 | +60,0 (+42,7, +74,0) |
| T-opus corsa 1 | 72,6 | 71,6 | +1,1 (-16,9, +17,7) | a cavallo di 0 | +58,9 (+41,7, +73,3) |
| T-opus corsa 2 | 70,5 | 71,6 | -1,1 (-19,0, +16,0) | a cavallo di 0 | +56,8 (+39,3, +72,3) |
| T-fable corsa 1 | 63,2 | 71,6 | -8,4 (-29,6, +12,3) | a cavallo di 0 | +49,5 (+29,5, +67,3) |
| T-fable corsa 2 | 68,4 | 71,6 | -3,2 (-21,1, +14,7) | a cavallo di 0 | +54,7 (+35,5, +71,4) |
| V-haiku corsa 1 | 75,8 | 52,6 | +23,2 (+6,1, +41,0) | sopra 0 | +62,1 (+46,8, +74,0) |
| V-haiku corsa 2 | 71,6 | 52,6 | +18,9 (+2,6, +35,4) | sopra 0 | +57,9 (+40,3, +72,6) |
| V-sonnet corsa 1 | 75,8 | 52,6 | +23,2 (+8,5, +37,4) | sopra 0 | +62,1 (+45,5, +75,3) |
| V-sonnet corsa 2 | 73,7 | 52,6 | +21,1 (+4,2, +36,6) | sopra 0 | +60,0 (+42,9, +74,1) |
| V-opus corsa 1 | 75,8 | 52,6 | +23,2 (+6,6, +38,6) | sopra 0 | +62,1 (+45,3, +75,6) |
| V-opus corsa 2 | 75,8 | 52,6 | +23,2 (+6,6, +38,6) | sopra 0 | +62,1 (+45,3, +75,6) |
| V-fable corsa 1 | 72,6 | 52,6 | +20,0 (+3,1, +35,8) | sopra 0 | +58,9 (+41,7, +73,1) |
| V-fable corsa 1b | 72,6 | 52,6 | +20,0 (+3,1, +35,8) | sopra 0 | +58,9 (+41,7, +73,1) |
| V-fable corsa 2 | 72,6 | 52,6 | +20,0 (+3,1, +35,8) | sopra 0 | +58,9 (+41,7, +73,1) |

Lettura: nella forma V tutti e quattro i modelli ritrovano più confronti di Mistral nella stessa forma (schema v1:
50/95), in tutte e due le corse. Nella forma T nessun intervallo sta sopra lo zero: i modelli Claude stanno fra 60 e
72 su 95, Mistral `B0` a 68. Contro il metodo di oggi (13/95) ogni corsa sta sopra lo zero.

# 3. Gli errori di lettura

Classi della carta: non errore (scelta dei curatori), forma, vista, lettura del modello, e per la lettura del modello
se costa gruppi o confronti. Aggiunte dopo i numeri: le classi «rifiuto» e «fermato dal limite di spesa»; il conto
«stretto» (l'errore cambia la misura contro Atlas) accanto al conto «largo» (l'errore costa gruppi o confronti del
lettore); quattro regole uniformi scritte dopo la revisione indipendente[^revisione]:

- **R1.** Una colonna con un valore per campione letta come soggetto o donatore, senza effetto sui gruppi: lettura
  del modello senza costo.
- **R2.** Base non scritta dove la tabella ha un livello di riferimento, e un confronto del lettore si perde:
  lettura del modello che costa (largo); costa contro Atlas solo se si perde un confronto di Atlas. **Si scosta dal
  precedente della sessione sulle cause (S12r4), dove la base non scritta in `GSE93624` era senza costo.** Per questo
  la tabella porta la colonna «col precedente».
- **R3.** Forma T: un fattore che nessuna colonna dichiara per tutti i campioni e che il modello scrive in
  `not_understood` è un errore di forma, non di lettura (`GSE147507`, il tempo).
- **R4.** Due fattori dalla stessa colonna con la stessa partizione: fattore doppio, lettura del modello che costa.

**Tabella 3. Errori di lettura del modello per corsa (studi su 47)**

«Largo»: l'errore costa gruppi o confronti del lettore (regole R1-R4 scritte dopo la revisione). «Col precedente»: lo stesso conto se la base non scritta resta senza costo, come nella sessione sulle cause (S12r4). «Stretto»: l'errore cambia la misura contro Atlas.

| corsa | largo | col precedente | stretto | solo senza costo | errori di forma | rifiuti | fermati | studi (largo) | studi (stretto) | studi (forma) | studi (rifiuto) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T-haiku corsa 1 | 4 | 3 | 1 | 3 | 1 | 0 | 0 | GSE50760 GSE57945 GSE60340 GSE93624 | GSE57945 | GSE147507 |  |
| T-haiku corsa 2 | 6 | 5 | 3 | 3 | 2 | 0 | 0 | GSE50760 GSE57945 GSE58365 GSE60340 GSE69597 GSE71595 | GSE58365 GSE69597 GSE71595 | GSE147507 GSE67812 |  |
| T-sonnet corsa 1 | 4 | 3 | 1 | 0 | 2 | 0 | 0 | GSE50760 GSE57945 GSE60340 GSE69597 | GSE69597 | GSE147507 GSE93624 |  |
| T-sonnet corsa 2 | 4 | 3 | 1 | 0 | 2 | 0 | 0 | GSE50760 GSE57945 GSE60340 GSE69597 | GSE69597 | GSE147507 GSE66207 |  |
| T-opus corsa 1 | 2 | 1 | 1 | 3 | 3 | 0 | 0 | GSE57945 GSE69597 | GSE69597 | GSE147507 GSE83687 GSE93624 |  |
| T-opus corsa 2 | 3 | 3 | 3 | 2 | 1 | 0 | 0 | GSE65335 GSE69597 GSE71595 | GSE65335 GSE69597 GSE71595 | GSE147507 |  |
| T-fable corsa 1 | 3 | 3 | 3 | 4 | 1 | 2 | 0 | GSE46665 GSE69597 GSE71595 | GSE46665 GSE69597 GSE71595 | GSE112057 | GSE147507 GSE71421 |
| T-fable corsa 2 | 3 | 3 | 3 | 3 | 0 | 2 | 0 | GSE46665 GSE69597 GSE71595 | GSE46665 GSE69597 GSE71595 |  | GSE147507 GSE71421 |
| V-haiku corsa 1 | 4 | 3 | 2 | 3 | 1 | 0 | 0 | GSE50760 GSE57945 GSE65335 GSE93624 | GSE57945 GSE65335 | GSE68919 |  |
| V-haiku corsa 2 | 7 | 5 | 4 | 3 | 0 | 0 | 0 | GSE50760 GSE57945 GSE58365 GSE60340 GSE65335 GSE71595 GSE93624 | GSE57945 GSE58365 GSE65335 GSE71595 |  |  |
| V-sonnet corsa 1 | 4 | 2 | 1 | 0 | 0 | 0 | 0 | GSE57945 GSE60340 GSE69597 GSE93624 | GSE69597 |  |  |
| V-sonnet corsa 2 | 5 | 3 | 1 | 1 | 0 | 0 | 0 | GSE52778 GSE57945 GSE60340 GSE69597 GSE93624 | GSE69597 |  |  |
| V-opus corsa 1 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | GSE57945 GSE69597 | GSE69597 |  |  |
| V-opus corsa 2 | 3 | 2 | 1 | 2 | 0 | 0 | 0 | GSE57945 GSE60340 GSE69597 | GSE69597 |  |  |
| V-fable corsa 1 | 2 | 2 | 2 | 2 | 0 | 1 | 3 | GSE46665 GSE69597 | GSE46665 GSE69597 |  | GSE71421 |
| V-fable corsa 1b | 3 | 3 | 2 | 3 | 0 | 1 | 0 | GSE46665 GSE69597 GSE83687 | GSE46665 GSE69597 |  | GSE71421 |
| V-fable corsa 2 | 3 | 3 | 2 | 2 | 0 | 1 | 0 | GSE46665 GSE69597 GSE93624 | GSE46665 GSE69597 |  | GSE71421 |

**Tabella 5. Per studio: in quante delle 17 corse c'è un errore di lettura che costa (largo)**

| studio | corse con l'errore (largo), su 17 | corse con l'errore (stretto), su 17 |
|---|---|---|
| GSE69597 | 14 | 14 |
| GSE57945 | 11 | 3 |
| GSE60340 | 8 | 0 |
| GSE50760 | 6 | 0 |
| GSE93624 | 6 | 0 |
| GSE46665 | 5 | 5 |
| GSE71595 | 5 | 5 |
| GSE65335 | 3 | 3 |
| GSE58365 | 2 | 2 |
| GSE52778 | 1 | 0 |
| GSE83687 | 1 | 0 |

Studi con un errore che costa in almeno una corsa: 11 su 47. Corse senza un errore di lettura che costa: 0 su 17.

**Il confronto con Mistral-Small 3.2 nella forma `B0`.** Le sessioni di prima contano per Mistral 5 studi con un
errore di lettura che costa: i 4 della sessione sulle cause (`GSE46665`, `GSE57945`, `GSE60340`, `GSE49155`) più
`GSE147507`.[^carta] Quel conto usa il precedente «base non scritta senza costo»: il confronto corretto è con la
colonna «col precedente». Opus: 1 e 2 (forma V), 1 e 3 (forma T). Sonnet: 2 e 3 (V), 3 e 3 (T). Fable: 2-3 (V), 3 e 3
(T). Haiku: 3 e 5 (V), 3 e 5 (T). Un limite di questo confronto: per Mistral `GSE147507` è un errore di lettura (legge
una sola delle due colonne del tempo), per i modelli Claude nella forma T è un errore di forma (regola R3: il modello
dichiara di non poter scrivere il tempo). Se si conta come lettura anche nella forma T, Haiku, Sonnet e Opus hanno uno
studio in più per corsa nella forma T. Nella forma V `GSE147507` non ha un errore che costa in nessuna corsa.

**Dei 9 errori di lettura noti di `B0`** (predicati deterministici, forma T, corsa 1): dei 4 che costano nessuno è
presente in nessun modello (P11 confermata); dei 5 che non costano uno è presente in Haiku (P12 smentita per Haiku).
Gli errori dei modelli Claude sono quindi in gran parte altri: `GSE69597` (il paese come fattore tecnico: 10 gruppi
contro 7, 0 confronti su 6), `GSE71595`, `GSE65335` (fattore doppio), `GSE58365`, e in `GSE46665` e `GSE57945` errori
diversi da quelli di Mistral (fattore doppio dal tempo; basi non scritte).

# 4. Le due corse

**Tabella 4. Le due corse dello stesso modello e della stessa forma**

| coppia | largo | largo, almeno una | largo, tutte e due | stretto | stretto, almeno una | stretto, tutte e due | ritrovati su 95 | uscita identica al carattere (P14) | stessa tabella, gruppi e confronti (P15) | stessi gruppi | stessi confronti |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T-haiku corsa 1 e 2 | 4 e 6 | 7 | 3 | 1 e 3 | 4 | 0 | 71 e 68 | 1 | 29 | 43 | 39 |
| T-sonnet corsa 1 e 2 | 4 e 4 | 4 | 4 | 1 e 1 | 1 | 1 | 72 e 70 | 18 | 39 | 44 | 41 |
| T-opus corsa 1 e 2 | 2 e 3 | 4 | 1 | 1 e 3 | 3 | 1 | 69 e 67 | 8 | 35 | 44 | 39 |
| T-fable corsa 1 e 2 | 3 e 3 | 3 | 3 | 3 e 3 | 3 | 3 | 60 e 65 | 9 | 40 | 46 | 45 |
| V-haiku corsa 1 e 2 | 4 e 7 | 7 | 4 | 2 e 4 | 4 | 2 | 72 e 68 | 0 | 25 | 43 | 39 |
| V-sonnet corsa 1 e 2 | 4 e 5 | 5 | 4 | 1 e 1 | 1 | 1 | 72 e 70 | 15 | 41 | 46 | 46 |
| V-opus corsa 1 e 2 | 2 e 3 | 3 | 2 | 1 e 1 | 1 | 1 | 72 e 72 | 11 | 36 | 47 | 45 |
| V-fable corsa 1b e 2 | 3 e 3 | 4 | 2 | 2 e 2 | 2 | 2 | 69 e 69 | - | - | - | - |
| V-fable corsa 1 e 2 | 2 e 3 | 3 | 2 | 2 e 2 | 2 | 2 | 69 e 69 | 7 | 38 | 44 | 43 |

La ripetibilità (ultime quattro colonne) è misurata dal programma depositato sulle 16 corse: per Fable con lo schema v1 confronta la corsa 1 fermata e la corsa 2.

Nessun modello passa P14 (uscita identica al carattere in 47 studi) né P15 (stessa tabella, gruppi e confronti in
almeno 43 studi). Mistral-Small 3.2 con `temperature = 0` e `VLLM_BATCH_INVARIANT=1` dà 47 su 47 identici al
carattere. Sonnet è il più stabile nella forma V (41), Fable nella forma T (40); Haiku il meno stabile (25 e 29).
I confronti ritrovati cambiano di 0-5 su 95 fra le due corse.

# 5. Le quattro risposte della carta (§7), per modello e forma

| modello, forma | 1. ritrova più confronti di Mistral nella stessa forma | 2. chiude gli studi (non chiusi ≤ 7) | 3. legge senza errori che costano | 4. due corse danno lo stesso risultato |
|---|---|---|---|---|
| Haiku, T | no | sì (0 e 1) | no | no |
| Sonnet, T | no | sì (1 e 1) | no | no |
| Opus, T | no | sì (2 e 0) | no | no |
| Fable, T | no | sì (3 e 2) | no | no |
| Haiku, V | sì | sì (1 e 0) | no | no |
| Sonnet, V | sì | sì (0 e 0) | no | no |
| Opus, V | sì | sì (0 e 0) | no | no |
| Fable, V | sì | sì (4 con i 3 fermati, 1 completata, 1) | no | no |

Nessuna configurazione ha quattro sì: la frase «un modello Claude legge gli studi senza errori» non vale. L'agente
aveva scritto prima di aspettarsi il no ai punti 3 e 4.

# 6. Le previsioni

**Tabella 6. Previsioni depositate, corsa 1 (ordine: Haiku / Sonnet / Opus / Fable)**

|  | forma | quantità | atteso | misurato | esito |
|---|---|---|---|---|---|
| P1 | T | studi non chiusi | 9 / 5 / 4 / 3 | 0 / 1 / 2 / 3 | confermata |
| P1 | V | studi non chiusi | 6 / 3 / 2 / 2 | 1 / 0 / 0 / 4 | confermata |
| P2 | T | uscite non valide contro lo schema | 6 / 2 / 2 / 1 | 0 / 0 / 1 / 0 | confermata |
| P2 | V | uscite non valide contro lo schema | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P3 | T | rifiuti | 0 / 0 / 0 / 1 | 0 / 0 / 0 / 2 | confermata / confermata / confermata / smentita |
| P3 | V | rifiuti | 0 / 0 / 0 / 1 | 0 / 0 / 0 / 1 | confermata / confermata / confermata / smentita |
| P4 | T | uscite troncate | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P4 | V | uscite troncate | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P5 | T | uscite con un recinto di codice | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P6 | T | (a) quota di studi con partizione identica | 31/47 / 36/47 / 38/47 / 39/47 | 38 / 39 / 37 / 35 | confermata |
| P6 | V | (a) quota di studi con partizione identica | 33/47 / 37/47 / 39/47 / 39/47 | 37 / 39 / 38 / 36 | confermata |
| P7 | T | (b) confronti ritrovati su 95 | 56 / 68 / 72 / 74 | 71 / 72 / 69 / 60 | - |
| P7 | V | (b) confronti ritrovati su 95 | 58 / 68 / 72 / 74 | 72 / 72 / 72 / 69 | - |
| P8 | T | Claude meno Mistral nella stessa forma, (b) | -13 punti / +0 punti / +4 punti / +6 punti | +3,2 / +4,2 / +1,1 / -8,4 | a cavallo di 0 |
| P8 | V | Claude meno Mistral nella stessa forma, (b) | +8 punti / +19 punti / +23 punti / +25 punti | +23,2 / +23,2 / +23,2 / +20,0 | sopra 0 |
| P9 | T | Claude meno oggi, (b) | sopra 0 / sopra 0 / sopra 0 / sopra 0 | +61,1 / +62,1 / +58,9 / +49,5 | sopra 0 |
| P9 | V | Claude meno oggi, (b) | sopra 0 / sopra 0 / sopra 0 / sopra 0 | +62,1 / +62,1 / +62,1 / +58,9 | sopra 0 |
| P10 | T | (c) errori fra i non elencati | 3% / 3% / 3% / 3% | 16,7% / 4,8% / 9,1% / 5,9% | indeterminata |
| P10 | V | (c) errori fra i non elencati | 3% / 3% / 3% / 3% | 5,3% / 8,0% / 6,2% / 7,7% | indeterminata |
| P11 | T | dei 4 errori di B0 che costano, presenti | 2 / 1 / 1 / 1 | 0 / 0 / 0 / 0 | confermata |
| P12 | T | dei 5 errori di B0 che non costano, presenti | 2 / 1 / 0 / 0 | 1 / 0 / 0 / 0 | smentita / confermata / confermata / confermata |
| P13 | T | studi con un errore di lettura che costa (largo; stretto) | 6 / 3 / 2 / 2 | 4; 1 / 4; 1 / 2; 1 / 3; 3 | smentita per i quattro (intervallo: 0) |
| P13 | V | studi con un errore di lettura che costa (largo; stretto) | 5 / 3 / 2 / 2 | 4; 2 / 4; 1 / 2; 1 / 2; 2 | smentita per i quattro (intervallo: 0) |
| P14 | T | studi con l'uscita identica al carattere fra le due corse | 15 / 15 / 15 / 15 | 1 / 18 / 8 / 9 | smentita |
| P14 | V | studi con l'uscita identica al carattere fra le due corse | 15 / 15 / 15 / 15 | 0 / 15 / 11 / 7 | smentita |
| P15 | T | studi con la stessa tabella, gli stessi gruppi e gli stessi confronti fra le due corse | 38 / 41 / 42 / 42 | 29 / 39 / 35 / 40 | smentita |
| P15 | V | studi con la stessa tabella, gli stessi gruppi e gli stessi confronti fra le due corse | 38 / 41 / 42 / 42 | 25 / 41 / 36 / 38 | smentita |

- **Confermate:** P1, P2, P4, P5, P6, P9, P11 per tutti; P8 nella forma T («nessun intervallo sopra 0»).
- **Smentite:** P3 per Fable (2 rifiuti nella forma T, 1 nella forma V; attesi 1 e 1, intervallo 0); P12 per Haiku;
  P13 per tutti (attesa dell'agente: smentita); P14 e P15 per tutti (attesa dell'agente: no). P8 nella forma V: Haiku
  era atteso a cavallo dello zero e sta sopra.
- **Indeterminata:** P10, gli errori fra i confronti non elencati (da 4,8% a 16,7%, intervalli larghi su 18-34
  confronti giudicabili). Non tocca una conclusione: le conclusioni poggiano sulla lettura delle schede.
- **I valori attesi dell'agente erano sbagliati in due direzioni.** Haiku fa meglio dell'atteso (71 e 72 contro 56 e
  58; 0 e 1 non chiusi contro 9 e 6). Fable fa peggio dell'atteso (60 e 69 contro 74). L'ordine atteso Haiku <
  Sonnet < Opus < Fable non c'è nei confronti ritrovati.
- **Attese per studio** (forma T, corsa 1): 11 giuste su 16, senza `GSE147507`.[^misura]

**I rifiuti di Fable.** `GSE71421` ha `stop_reason = refusal` in tutte le 5 corse di Fable; `GSE147507` (infezione
da SARS-CoV-2) nelle 2 corse della forma T. Nessun altro modello rifiuta. Lo studio rifiutato è non chiuso e conta
zero.

# 7. Deviazioni dalla carta[^deviazioni]

1. **Il limite di spesa della chiave ha fermato le chiamate** il 2026-11-14 alle 18:45:10Z, durante la corsa 1 di
   Fable nella forma V: 3 studi senza chiamata. Il PI ha alzato il limite a 150 dollari; i tre studi sono stati
   chiamati una volta (`V-fable-corsa1b`). La misura principale di quella corsa resta la corsa fermata (43 chiusi,
   69/95); la misura accanto con i tre studi dà 46 chiusi e 69/95.
2. Una riga di stampa del programma di misura non funziona (non cambia nessun numero).
3. Le 8 corse 2 sono partite insieme, non nell'ordine della carta.
4. **La lettura delle 27 schede nuove delle corse 2 e della corsa completata** è oltre la carta (§8 chiedeva la sola
   corsa 1), è scritta come deviazione prima di leggerle e **non ha una revisione indipendente**. P13 resta sulle
   corse 1.

**Spesa** (a listino, dai token): 16 corse 50,72 dollari (corse 1: 25,06; corse 2: 25,66), più 0,75 per i tre studi
completati: 51,47 dollari. Per modello, 16 corse: Fable 30,99, Opus 12,72, Sonnet 6,30, Haiku 0,71. Le chiamate di
esplorazione e di prova del percorso non sono in queste tabelle.

# 8. La revisione indipendente e i limiti

**Revisione** (audit interno, due subagenti Claude, materiale in cartella congelata): revisore A 20 schede, 7
diverse, il revisore ha ragione in 7 su 7; revisore B 54 schede, 19 diverse (agente 6, revisore 7, convenzione 3, in
parte 3). 17 classi cambiate dopo la revisione; la lettura di prima sta in `28-classi-prima-della-revisione.csv`.

**Limiti.**

- **La lettura non è cieca e un modello Claude giudica uscite di modelli Claude** (l'agente è Claude Fable 5, i
  revisori sono subagenti Claude). I conti per modello dipendono da questa lettura.
- Due classi, il conto stretto e le regole R1-R4 sono nati dopo i numeri. R2 si scosta dal precedente: i due conti
  stanno accanto.
- Le 27 schede nuove non hanno revisione. Nel materiale delle corse 1 alcuni campi erano tagliati a 70 caratteri
  (400 nel materiale nuovo). I revisori potevano tecnicamente leggere i file dell'agente.
- **Punti di giudizio aperti**, dichiarati: `GSE69597` il paese come fattore tecnico è contato come errore che costa
  (un revisore ha un dubbio: è l'errore che decide il conto stretto di Opus e Sonnet); `GSE52778` la linea cellulare
  (4 donatori) come fattore di contesto; `GSE83415` il verso del confronto; `GSE83687` il fattore di infiammazione
  dedotto dal testo; `GSE93624` l'ascendenza come fattore; `GSE67812` uno studio non chiuso senza confronti da
  perdere; `GSE50760` il tessuto come fattore di contesto senza base. Differenze tenute contro il revisore: 6 schede
  (`28-confronto.csv`, colonna `chi_ha_ragione = agente`) e una parte di una settima (`in parte`).
- 47 studi, gli stessi di sei prove: le differenze fra modelli di 1-2 studi non si distinguono dal caso, e fra due
  corse dello stesso modello gli studi con errore cambiano di 0-3.
- La forma T non è la forma di Mistral, e la forma V usa lo schema v1, con cui Mistral faceva 50/95. Nessuna forma
  mette Claude e Mistral nella stessa condizione esatta.
- `effort = "high"` e ragionamento di default: altre impostazioni non sono misurate.

# 9. Che cosa resta

Il progetto resta chiuso (ADR-0030). La regola «nessun Claude nella pipeline né nella validazione pubblicata» resta
scritta: questa prova misura soltanto. La chiave del PI sta solo in `.Renviron.local` (non tracciato) e vale fino al
2026-11-15T17:20:48Z: alla fine della prova la riga si toglie e il PI cancella la chiave.

# Da dove vengono i numeri del riassunto

| frase del riassunto | file e riga | valore letto |
|---|---|---|
| Opus, schema fisso: errore in 2 e 3 studi | `29-errori-per-corsa.csv`, `V-opus-corsa1` e `V-opus-corsa2`, `lettura_largo` | 2; 3 |
| un solo studio (GSE69597) cambia la misura contro i curatori | stesse righe, `lettura_stretto`, `studi_stretto` | 1 e 1; GSE69597 |
| Opus chiude 47 su 47 e ritrova 72 su 95 nelle due corse | `24-corse.csv`, `V-opus-corsa1`, `V-opus-corsa2` | 47, 72/95; 47, 72/95 |
| Mistral: 5 studi | `00-previsioni.md` §6, riga P13 | «Mistral `B0`: 5 studi (4 più `GSE147507`)» |
| con quel conto Opus ne ha 1 e 2 | `29-largo-col-precedente.csv`, `V-opus-corsa1`, `V-opus-corsa2` | 1; 2 |
| Sonnet 4 o 5 studi, uno solo contro i curatori in ogni corsa | `29-errori-per-corsa.csv`, 4 righe di Sonnet | largo 4, 4, 4, 5; stretto 1, 1, 1, 1 |
| Haiku fra 4 e 7 | `29-errori-per-corsa.csv`, 4 righe di Haiku | 4, 6, 4, 7 |
| Fable 2 o 3 studi | `29-errori-per-corsa.csv`, 5 righe di Fable | 3, 3, 2, 3, 3 |
| Fable rifiuta GSE71421 in ogni corsa e un secondo studio con lo schema come testo | `24-per-studio.csv` e `24b-per-studio.csv`, `stop_reason = refusal` | GSE71421 in 5 corse; GSE147507 in `T-fable-corsa1` e `-corsa2` |
| Fable circa 32 dei 51,5 dollari | `24-corse.csv` e `24b-corse.csv`, `dollari` | Fable 30,99 + 0,75 = 31,74; totale 50,72 + 0,75 = 51,47 |
| nessuna delle 17 corse senza errore; 11 studi su 47 | `29-errori-per-corsa.csv`, `lettura_largo`, minimo sulle 17 righe; `29-out.txt` riga 144 | minimo 2; 11 su 47 |
| GSE69597 in 14 corse su 17 (sempre il paese come fattore), GSE57945 in 11 | `29-classi-per-corsa.csv`, `costa = si` (6 schede di GSE69597, tutte sul paese); `30-tabelle.md` T5 | 14; 11 |
| uguali in 25-41 studi su 47 fra le due corse | `24-ripetibilita.csv`, `stessa_chiave` | 29, 39, 35, 40, 25, 41, 36, 38 |
| Mistral: 47 su 47 uguali al carattere | finding S12r3 e S12r4 (`B0` due volte identica al carattere 47/47) | 47/47 |
| Opus, schema fisso: errore in 2 studi in tutte e due le corse, 1 in una sola | `29-due-corse.csv`, V opus | tutte e due 2; almeno una 3 |
| schema fisso: 68-72 su 95 contro 50 | `24-corse.csv` e `24b-corse.csv`, corse V; `00-previsioni.md` K1 | 72, 68, 72, 70, 72, 72, 69, 69, 69; 50/95 |
| schema come testo: 60-72 contro 68 | `24-corse.csv`, corse T; `00-previsioni.md` K1 | 71, 68, 72, 70, 69, 67, 60, 65; 68/95 |
| la prova non mostra una differenza (schema come testo) | `24-appaiati.csv`, `mistral_stessa_forma`, corse T | 8 intervalli su 8 a cavallo di 0 |
| una lettura dei 47 studi con Opus costa circa 2,70 dollari | `24-corse.csv`, `V-opus-corsa1`, `V-opus-corsa2` | 2,70; 2,67 |
| la chiave vale fino a domani alle 18:20 | messaggio del PI del 2026-11-14T17:20:48Z, 24 ore | 2026-11-15T17:20:48Z (18:20 ora locale) |
| 74 schede riviste, 27 no | `27-classi.csv`, `29-classi-nuove.csv` | 74 righe; 27 righe |

[^carta]: `analysis/audit/2026-11-14-S12r6-claude-via-api/00-previsioni.md`.
[^adr30]: `docs/decisions/0030-chiusura-del-progetto-non-si-puo-fare.md`, aggiornamento del 2026-11-14.
[^esplorazione]: `analysis/audit/2026-11-14-S12r6-claude-via-api/05-esplorazione/`.
[^sha]: `23-uscite-sha256.txt`, `23b-uscita-sha256.txt`.
[^misura]: `24-out.txt` («CANCELLI: PASSANO»; «attese giuste: 11 su 16»).
[^conti]: `29-out.txt`.
[^revisione]: `28-revisione.py`, `28-confronto.csv`.
[^deviazioni]: `25-deviazioni.md`.
