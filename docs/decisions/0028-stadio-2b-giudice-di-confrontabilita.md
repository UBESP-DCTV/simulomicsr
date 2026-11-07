# ADR-0028: Lo Stadio 2b — il modello legge i due bracci, una regola decide

- **Status:** Accepted (decisione del PI, 2026-11-07), con un cancello: la prova di S12p
- **Date:** 2026-11-07
- **Deciders:** Luca Vedovelli (PI); proposta di Claude dalla valutazione autonoma
- **Supersedes:** il programma «rilevatore a regole in produzione» (handout 2026-08-21, voce 10, sessioni S10 → S12)
- **Superseded by:** —

## Il problema

La pipeline decide se due bracci sono confrontabili guardando schede compresse (Stadio 1) e chiavi
(Stadio 3), mai il testo grezzo dei campioni. Dei 193 confronti difettosi nel riferimento di S11, l'88%
nasce prima della chiave: 65% bracci non appaiati (tempo zero, durata, materiale, linea, donatore,
genotipo, sesso, tecnica), 23% seconda perturbazione persa. I difetti hanno 85 categorie, 55 con un solo
caso. Il rilevatore a regole costruito in S10-S10b ne vede 81 su 193 (42%). I 50 difetti «leggibili solo
nei metadati GEO» stanno nei tre campi che il modello già riceve (`21-metadati-geo.R`): il modello li
ha avuti e non li ha portati fino al confronto. Finding:
`docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md`.

## Le opzioni

1. **Continuare con le regole** (S12 come scritto nell'handout di agosto): una regola per causa. Con 85
   categorie e una coda di casi unici non converge; recall massimo misurato 42%.
2. **Rifare Stadi 1-2 con un altro modello o schema.** Il rifacimento con lo stesso modello (S14) ha dato
   un'uscita identica al 100%; il modello è primo fra 21 sul mini-gold; la letteratura (R1) non confronta i
   modelli sul compito che qui fallisce. Il guadagno è una previsione, il costo è certo (33 h + tutto a valle).
3. **Stadio 2b.** Per ogni confronto candidato il modello (Mistral, temperatura 0, `VLLM_BATCH_INVARIANT=1`)
   riceve il **testo grezzo** dei campioni dei due bracci (titolo, sorgente, caratteristiche, più i campi
   tecnici dell'H5: `extract_protocol_ch1`, `instrument_model`, `library_selection`, `data_processing`) e
   compila una **lista di controllo strutturata**. Una **regola deterministica** decide dalla lista.

## La decisione

Opzione 3. La lista di controllo contiene, per ogni confronto:

- agenti/perturbazioni presenti nel braccio trattato e nel braccio di controllo (elenco, non uno solo);
- tempo di raccolta di ciascun braccio; se un braccio è a tempo zero;
- per materiale, linea cellulare, donatore, genotipo, sesso, età, compartimento, tecnica (strumento, kit,
  paired/single-end, RNA marcato): `uguale` / `diverso` / `non detto`, con la citazione del testo;
- l'entità isolata dal confronto, scritta per nome; mai un ID.

La regola: il confronto passa se l'unica differenza dichiarata fra i bracci è l'entità del gruppo; non
passa se un braccio è a tempo zero con il trattato più lungo, se c'è una seconda perturbazione solo in un
braccio, se materiale/linea/donatore/genotipo/sesso/tecnica sono `diverso`. `Non detto` passa ma si conta e
si scrive nei Methods. La regola è codice di pacchetto con test.

Il **cancello**: la prova cieca di S12p sui 1.903 confronti del deliverable contro i 193 difetti e i 1.710
puliti. Previsione depositata: prende ≥ 130 dei 193, accusa ≤ 40 dei 1.710. Se nessun modello passa, questo
ADR torna a `Proposed` e si decide fra regole e fine-tuning sul gold del progetto.

## Che cosa resta vero

- **Nessun Claude nella pipeline.** Lo Stadio 2b usa il modello self-hosted del progetto.
- **Deterministico.** Temperatura 0 e batch-invariant hanno dato in S14 211.484/211.484 record identici. Il
  verdetto lo dà la regola, non il modello.
- **Il rilevatore a regole di S10-S10b resta strumento di audit**; i 193 sono il banco di prova cieco di ogni
  modello e di ogni versione del prompt. Il file dei 193 non si apre prima del conto.
- **Zero errori non esiste** in nessuna strada (recall 0,84 in letteratura per il raggruppamento
  caso/controllo; 0,42 per le regole). L'errore residuo si misura con la rilettura cieca (S15) e si scrive
  nei Methods.
- **Il modello non scrive mai un ID** (S12c): sceglie fra candidati per indice.

## Conseguenze

- La chiave dello Stadio 3 riceve dallo Stadio 2b l'elenco completo degli agenti: la seconda perturbazione
  diventa parte della chiave o motivo di scarto, non più un difetto da cercare a valle.
- Le voci S12 («rilevatore in produzione») e «S14 seconda parte» dell'handout di agosto sono sostituite dal
  piano in `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md`.
- Costo: 1.903 confronti = minuti su una H100; 86.212 candidati = ore. Disegno 1 sessione, prova 1 notte.
