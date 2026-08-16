# La batch-invarianza tiene anche quando cambia la composizione dello shard

**2026-08-16** · branch `review-scientific-consistency-2026-06-10` · master invariato
Evidenza: `analysis/audit/2026-08-16-A3/invarianza/` · script `20-` e `21-`

---

## Il buco che questa misura chiude

La misura del 2026-08-09 aveva stabilito che `VLLM_BATCH_INVARIANT=1` porta al
100% l'identità fra giri ripetuti. Ma dichiarava lei stessa il proprio limite:

> in tutti i run, i cinque giri di ogni record sono stati serviti dallo **stesso
> worker** […] Il test quindi non ha mai variato la composizione del batch fra i
> giri. […] Chi volesse quella garanzia deve misurarla, e non l'ha fatto nessuno.

Non è una nota a margine, ed è il motivo per cui questa misura viene prima di
tutto il resto. Il runtime assegna il record *i* al worker *i* mod *n*
(`shard_round_robin`) e per lo Stadio 1 manda l'**intero shard in una sola
chiamata** (`MICROBATCH = None`). Lo shard dipende quindi da quanti record ha il
job. A3 ne rigenera 86.898; il re-run completo ne fa 508.037 in blocchi da
10.000. Sono job di dimensione diversa: se la flag non tenesse fra job diversi,
il movimento misurato da A3 mescolerebbe il rumore del modello con l'effetto
della dimensione del job.

## Il disegno

Gli stessi **1.000 record** dello Stadio 1, due volte: da soli in un job da
1.000 (**A**), e mescolati con altri 4.000 in un job da 5.000 (**B**), con
rimescolamento a seme fisso. Misurato sul disegno vero: **il 75,8% dei record
condivisi finisce su un worker diverso**. Tutto il resto identico.

⚠️ Il primo disegno interlacciava in modo uniforme (1 condiviso ogni 4). Con
passo 5 e 4 worker, 5 mod 4 = 1 = il passo del job A: **ogni** record restava
sullo stesso worker. Sarebbe sembrato un test serio senza provare nulla — lo
stesso difetto che va a cercare. L'ha bocciato la guardia, prima di sottomettere.

## Risultato

| caso di accettazione | esito |
|---|---|
| **negativo, controllato per primo** — senza flag A e B devono differire | **445/997 diversi (44,6%)** |
| **negativo** — una differenza piantata a mano viene vista | 1 vista |
| **positivo** — con flag A e B byte-identici | **997/997 (100,00%)** |
| **P5** — la flag è arrivata al **processo** (`container-env.txt`, non lo script) | presente nei 2 job con flag, assente nei 2 senza |

Il caso negativo si controlla per primo per costruzione: se senza flag i due job
non differissero, il confronto non sarebbe in grado di vedere nulla e il caso
positivo passerebbe **per costruzione**.

**Omissione dichiarata:** il confronto è su **997** record, non 1.000. Tre
record falliscono lo schema in tutti e quattro i job e sono esclusi da tutti e
quattro allo stesso modo.

## Costo, misurato di nuovo e per caso

| job | record | wall |
|---|---:|---:|
| senza flag | 1.000 | 2m 40s |
| **con flag** | 1.000 | **3m 38s** |
| senza flag | 5.000 | 6m 51s |
| **con flag** | 5.000 | **9m 49s** |

Sui 5.000 record — la stessa dimensione del test del 9 agosto — il rapporto è
**1,43×**, contro il **+44%** dichiarato allora. Corroborazione indipendente.
I tempi includono l'avvio e il caricamento del modello, quindi non si scompone
il costo per record: sarebbe un modello, non una misura.

## Che cosa questo NON dice

- Non dice che due run su **nodi diversi** coincidano: qui il nodo è sempre
  poddgx02.
- Non dice nulla sullo **Stadio 2**, che usa `microbatch = 50` invece dello
  shard intero. La proprietà è plausibile ma qui non è misurata.
- Non dice nulla sulla **correttezza**: un run riproducibile può essere
  riproducibilmente sbagliato.

## Un difetto mio, chiuso in corsa

I primi due job senza flag sono `FAILED`. Con `env = NULL` il segnaposto
`__EXTRA_ENV__` diventava una **riga vuota** dentro il comando `singularity
exec … \` continuato su più righe: la continuazione si chiude, e singularity
riceve zero argomenti.

Il test che avevo scritto controllava **l'assenza della stringa**
`VLLM_BATCH_INVARIANT`, non che lo script fosse ancora un comando solo: ho
guardato l'etichetta, non l'ultimo anello — la stessa forma di errore già pagata
con le fusioni.

⚠️ E `bash -n` **non** prende questo difetto: lo script rotto è sintatticamente
**valido**, perché una riga vuota che chiude una continuazione non è un errore di
sintassi. Verificato. Il controllo che lo prende è quello sull'assenza di righe
vuote dentro il comando, e ho verificato che **fallisce** sul codice vecchio
prima di accettarlo come test.
