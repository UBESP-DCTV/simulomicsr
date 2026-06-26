# Rework Stadio 3 — versione leggibile (HUMANE)

Companion di `2026-06-25-stage3-name-recovery-reclustering-plan.md`. Qui in parole,
senza codice.

## Cosa stiamo costruendo (in una riga)

Un pezzo di codice che legge i metadati grezzi di GEO, capisce **di che malattia o
composto parla** ogni studio, e lo usa per raggruppare gli studi nello Stadio 3 — così
non finiscono più insieme leucemia, HIV e Alzheimer solo perché sono tutti "sangue".

## Come funziona, a blocchi

1. **Modulo che legge i metadati** (puro, testato pezzo per pezzo): estrae il nome
   della malattia (dalle voci "disease", "diagnosis"…) o del composto (da "treatment",
   "drug"…), e si accorge se uno studio etichettato "farmaco" è in realtà **genetico**
   (degron/CRISPR/siRNA) — quello lo corregge (decisione K2).
2. **Normalizzazione su ontologia**: "breast cancer", "breast tumor", "breast
   carcinoma" devono diventare lo **stesso** identificatore (MeSH per le malattie,
   ChEBI per i composti), altrimenti la stessa malattia si spezza in tanti gruppi. Gli
   indici nome→codice esistono già nel codice, li riusiamo.
3. **Tabella `campione → identità`**: una passata sull'H5 costruisce, per ogni
   campione, l'identità recuperata.
4. **Innesto nell'anchor**: dove oggi lo Stadio 3 scrive `UNK` (sconosciuto), ci mette
   l'identità recuperata. Niente lookup → resta `UNK`.
5. **Ri-raggruppamento** (Stadio 3) → **ri-calcolo del DE** (Stadio 4, solo sui gruppi
   che cambiano) → **collaudo**.
6. **Banco di prova dell'LLM** (a parte): giriamo l'LLM sugli stessi casi e misuriamo
   quanto è bravo. Se è bravo, lo usiamo come rete solo dove il deterministico non
   arriva.

## Cosa NON fa (per scelta)

- Non ri-gira l'LLM in produzione (di quello non ci fidiamo qui). L'LLM entra solo come
  banco di prova, e diventa rete solo se passa una soglia che fissiamo insieme.
- Non rivede **tutti** i tipi della pipeline (K3 scartata): corregge solo i tipi
  **palesemente** sbagliati con segnali inequivocabili.
- Non inventa un nome dove i metadati non lo danno: quei casi restano senza
  raggruppamento cross-studio (li contiamo e li dichiariamo).

## Decisioni già prese (con te)

- Sorgente nome: **deterministico** dai metadati + ontologia (A), con benchmark LLM → eventuale ibrido (C).
- Scope: **tutti** i cluster con agente sconosciuto, non solo le malattie (S3).
- Granularità: **livello-malattia** (sottotipi dello stesso tumore insieme; malattie diverse separate) (G2).
- Senza nome → **niente pooling** (U1).
- Correzione tipi palesemente sbagliati: **sì**, deterministica (K2).

## Cosa serve da te durante l'esecuzione

- **Gate prima delle run pesanti**: re-cluster Stadio 3 e ri-pooling Stadio 4 sono ore
  di calcolo, partono solo col tuo ok.
- **Soglia del benchmark LLM**: la fissiamo guardando i numeri.
- **Collaudo finale**: il criterio è "~0 minestroni provati" nei gruppi nuovi. Se non
  ci arriviamo, iteriamo prima di accettare.

## Stima onesta

- Modulo + lookup + innesto + collaudo: lavoro di codice TDD, gestibile in una/due
  sessioni.
- Le run a cascata (Stadio 3 + Stadio 4): ore di calcolo, separate e gated.
- Il rischio vero non è il codice (i punti di innesto sono verificati): è **empirico** —
  quanti casi restano senza nome o si frammentano. Lo misura il collaudo, e da lì
  decidiamo se basta o serve un secondo giro.
