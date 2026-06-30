# HUMANE — Recupero-nome biologici (citochine + patogeni) → Stadio 3 v6

*Versione leggibile della spec `2026-06-29-stage3-biologics-name-recovery-design.md`. Per la
review umana: cosa facciamo, perché, cosa NON facciamo, quanto costa.*

## In due frasi
Le citochine (IFN-β, IL-6, TNF) e i patogeni (LPS, SARS-CoV-2, M. tuberculosis) sono ancora
minestrone nel clustering perché non hanno un dizionario nome→ID come ce l'hanno farmaci (ChEMBL/
ChEBI) e malattie (MeSH). Diamo loro quel dizionario — citochine via **HGNC** (+ ImmPort/UniProt/GO
per i sinonimi), patogeni via **NCBI Taxonomy** — e ri-tipizziamo i biologici che l'LLM aveva
scambiato per "small molecule".

## Perché così
- È lo **stesso pattern** che ha già funzionato per malattie (MeSH) e farmaci (ChEMBL): dizionario
  offline + estrazione tollerante + gating di precisione (meglio "ignoto" che un merge sbagliato).
- **HGNC ce l'abbiamo già in cache**: per le citochine il pezzo grosso è fatto, mancano i sinonimi.
- **Precisione prima della copertura**: in meta-analisi unire due cose diverse è peggio che
  lasciarne una non risolta.

## Cosa NON fa (di proposito)
- Non usa l'**LLM** per indovinare i nomi: l'LLM-fallback è un passo separato e successivo, e sarà
  comunque "propone ma deve passare l'ontologia".
- Non ri-tipizza nel verso opposto (un biologico che diventa farmaco): un fronte solo, per precisione.
- Non separa "LPS from E. coli" in due entità (PAMP + batterio): per ora risolve solo il PAMP.
- Non blocca nulla del v5 già fatto: malattie e farmaci restano come sono.

## Le scelte che hai fatto nel brainstorming
1. **Entrambe** le famiglie in un colpo (un re-cluster, non due).
2. Citochine da **HGNC + UniProt + GO + ImmPort** (ImmPort lo scarichi tu con una API key gratuita).
3. Il **fix-tipo** (LPS/TNF/IL4 mal-etichettati) **in questo giro**.
4. I **PAMP** (LPS, poly(I:C)…) restano identificati come molecole ChEBI ma analizzati insieme ai
   patogeni, decisi da una lista bianca corta e leggibile.

## L'unica cosa che serve da te
Una **API key ImmPort** (registrazione gratuita, 1 minuto, scope "browse") quando arriviamo al build
dei dizionari. Tutto il resto si scarica in anonimo.

## Il punto di non ritorno
Prima dei run pesanti (~6-7h + ~10h) c'è uno **smoke**: misuriamo su dati veri quanti biologici
"ignoti" riusciamo davvero a nominare e controlliamo di non aver introdotto match falsi. **Se il
guadagno non c'è, ci fermiamo lì** — niente run da 17 ore a vuoto. È lo stesso gate che ci ha fatto
risparmiare un re-cluster inutile nella sessione 19.

## Rischi noti
- **UniProt** potrebbe non aggiungere quasi nulla (HGNC ha già molti alias): lo teniamo solo se lo
  smoke dimostra che serve.
- **I virus** sono notoriamente i più difficili da riconoscere da testo: verifica manuale del
  sottoinsieme.
- **ImmPort** ha una licenza "data-use agreement" (non CC): redistribuiamo il derivato con le dovute
  attribuzioni.

## Stima
- **Codice** (TDD, subagent-driven): una sessione di lavoro, niente run pesanti — come la FASE 1 del
  Plan B farmaci.
- **Run gated**: build (minuti) → smoke (minuti, gate decisionale) → re-cluster (~6-7h) → re-pool
  (~10h) → re-gate (minuti). Spalmati su sessioni separate con il tuo via libera a ogni step.

## Cosa ti darà
Se va come per le malattie e i farmaci: `cytokine_stim` giù dal 61% e `pathogen` giù dal 33%, senza
toccare i risultati già buoni (disease 7,7%, small_molecule ~8%). Dopo, resta solo l'LLM-fallback
finale sui residui più ostici.
