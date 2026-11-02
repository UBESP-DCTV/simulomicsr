---
type: Example
title: "Esempio di riassunto «In breve»: la ricerca delle inversioni"
description: "Un riassunto nella forma del protocollo, scritto sui numeri della ricerca delle inversioni del 2026-11-02: modello di forma, approvato dal PI."
status: stable
tags: [simulomicsr, riassunto, esempio]
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-02T14:21:54+01:00'}
pi_approval: approved
sources:
- id: finding
  resource: "docs/findings/2026-11-02-inversioni-bracci-194.md"
  title: "Inversioni dei bracci sulle 194"
---

# Come si usa

- Copia la forma, non i fatti: struttura, frasi in grassetto, parole, livello di precisione.
- Il PI ha approvato questo testo il 2026-11-02.
- Questo testo non entra nel finding del 2026-11-02: il finding resta com'è.

# Il riassunto

## In breve: altri studi hanno i bracci invertiti?

**A cosa serviva.** La lettura umana ha trovato uno studio con i bracci invertiti: il «trattato» è il tessuto non tumorale, il «controllo» è il tumore. Le letture del modello non vedono questo errore, perché leggono solo le etichette. Abbiamo cercato lo stesso errore in tutte le 194 meta-analisi, perché una sola inversione può cambiare un risultato dell'articolo.

**Cosa abbiamo trovato.**

1. **La ricerca ha confermato una sola inversione, ed è quella già nota.** Lo studio è GSE144269, nella meta-analisi sul carcinoma epatocellulare.
   - Abbiamo confrontato 1.174 studi con gli altri studi della loro meta-analisi, poi abbiamo letto i metadati dei 23 studi sospetti.
2. **Quella inversione toglie quasi tutti i geni significativi alla meta-analisi sul carcinoma epatocellulare.** Oggi la meta-analisi ha 105 geni significativi, e con il segno corretto ne ha 6.590. Lo studio porta il 23% del peso.
3. **Quattro studi hanno un braccio sbagliato, e nessuna lettura del modello li ha accusati.** Due di queste meta-analisi hanno il verdetto «corretta».
   - Epatite B: il braccio «infettato» contiene solo campioni non infettati, e lo studio porta il 32% del peso.
   - Il farmaco vtp50469: il trattato ha MLL3 mutato e il controllo no, e lo studio porta il 34% del peso.
   - LPS: nel braccio «24 ore», 2 campioni su 3 sono macrofagi a 6 giorni, e lo studio porta il 3% del peso.
   - Parkinson: i 5 «controlli sani» sono pazienti, e lo studio porta meno dell'1% del peso.
4. **La ricerca non esclude altre inversioni.** Il metodo vede un'inversione in circa metà degli studi, e in 70 meta-analisi non la vede in nessuno studio. Se la frequenza trovata vale anche per gli studi non coperti, le inversioni sono fino a una decina.
5. **In 18 studi sospetti il metadato concorda con l'etichetta, e non conosciamo la causa della discordanza.** Quattro di questi studi stanno nelle 37 meta-analisi che passano tutti i controlli.

**Cosa devi decidere.**

1. **Segniamo la meta-analisi sul carcinoma epatocellulare come non citabile fino alla correzione? Consiglio di sì.** Oggi sappiamo che il suo risultato è sbagliato.
   - In alternativa la citiamo con un avviso. L'articolo userà allora un risultato che sappiamo sbagliato.
   - In alternativa correggiamo subito solo questo studio. La correzione arriverà prima, ma separata dalle altre correzioni.

**Comunque:**

- non cambiamo nessun verdetto adesso;
- correggeremo questa inversione insieme agli altri errori, quando avremo il rilevatore automatico;
- il rilevatore confronterà le etichette con i metadati, perché questi errori si leggono lì;
- quando sceglieremo le meta-analisi per l'articolo, terremo conto di questi errori: le 173 che restano valide senza gli studi difettosi contengono tutti e cinque questi studi.

Appena decidi questo punto, la sessione è chiusa.

# Da dove vengono i numeri

| Nel riassunto | Fonte | Valore letto |
|---|---|---|
| «1.174 studi» | finding, §0 | 1.174 misurabili |
| «23 studi sospetti» | finding, §2 | 23 studi distinti |
| «105 ... 6.590» | finding, §2, tabella su `GSE144269` | 105; 6.590 |
| «il 23% del peso» | finding, §2 | 22,6% |
| «32%», «34%», «3%», «meno dell'1%» | finding, §2, tabella dei quattro bracci | 31,8%; 33,5%; 3,4%; 0,6% |
| «Due ... hanno il verdetto corretta» | finding, §2 | `vtp50469`, `Parkinson Disease` |
| «circa metà degli studi» | finding, §3 | 611/1.174 = 52,0% |
| «In 70 meta-analisi» | finding, §3 | 70 gruppi senza studi coperti |
| «fino a una decina» | finding, §3 | assunzione dichiarata nel finding |
| «18 studi» | finding, §2 | 18 `nessuna_inversione` |
| «Quattro ... nelle 37» | finding, §2 | `GSE64741`, `GSE153739`, `GSE247275`, `GSE151464` |
| «contengono tutti e cinque questi studi» | finding, §2 e §5 | quattro «sì» nei 173; `Carcinoma, Hepatocellular` sta nei 173 |
