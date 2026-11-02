# Inversioni dei bracci su tutte le 194 — previsioni depositate PRIMA del calcolo (2026-11-02)

**Perché.** La lettura umana di S3 ha trovato `GSE144269` coi bracci invertiti in
`Carcinoma, Hepatocellular`: sull'etichetta il confronto è pulito, quindi nessuna delle
letture del modello poteva vederlo. Non si sa se è l'unico.

**Che cosa si misura.** Deliverable A3 v16 (194 meta-analisi,
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`),
tutti i gruppi. Per ogni studio, dopo il collasso dei bracci: Spearman fra il suo logFC e
la **mediana degli altri studi** del gruppo, su tutti i geni e sui 500 geni con |t| mediano
più alto negli altri (scelti senza guardare lo studio). Si usa la mediana, non la media
pesata, perché uno studio invertito e pesante non trascini il riferimento.

**Nullo.** Lo stesso studio contro il riferimento di 20 gruppi estratti a caso che non lo
contengono (seme 20261102). **Candidato** = sotto il 1° percentile del nullo su almeno una
delle due misure. I bracci degli studi multi-braccio si misurano a parte, col proprio nullo.

**Una correlazione negativa non è un'inversione.** Ogni candidato si classifica leggendo i
metadati grezzi dei campioni (titolo, sorgente, caratteristiche):

| classe | quando |
|---|---|
| `inversione` | nella maggioranza dei campioni di ciascun braccio il metadato dice il contrario dell'etichetta dello Stadio 2 |
| `braccio_sbagliato` | non è invertito, ma un braccio contiene materiale che l'etichetta non dice |
| `nessuna_inversione` | il metadato concorda con l'etichetta: la discordanza resta biologica o ignota |
| `non_decidibile` | il metadato non dice quale braccio sia quale |

## Le previsioni

- **P1 (controllo positivo).** `GSE144269` è candidato, sotto il 1° percentile su entrambe le misure. Se è falsa lo strumento è cieco: ci si ferma e non si legge altro.
- **P2.** I candidati a livello di studio sono fra il **2% e il 6%** delle coppie gruppo-studio.
- **P3.** Almeno il **70%** dei candidati non è un'inversione.
- **P4.** Inversioni confermate oltre a `GSE144269`: **da 0 a 5** studi.
- **P5.** Se ce ne sono, la maggioranza sta in gruppi caso-controllo di malattia, dove lo Stadio 2 deve decidere chi è il caso senza un agente nominato.

## Limiti dichiarati prima

Un'inversione in un trattamento debole non si vede: senza segnale la correlazione resta
vicina a zero. Se tutti gli studi di un gruppo fossero invertiti, nessuno sembrerebbe
discordante. A k=3 il riferimento è fatto da due soli studi. **Questa sessione misura: nessun
verdetto cambia e nessuna correzione viene applicata.**
