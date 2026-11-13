# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Fonte canonica del contesto del progetto per ogni sessione Claude Code, su
> qualunque macchina. Sostituisce la memoria locale (`~/.claude/projects/<path>/memory/`).
> **Leggi questo file per intero prima di agire.** È corto apposta: la cronologia
> (preambolo RED ALERT + 44 blocchi di «Stato», maggio–agosto 2026) sta in
> **`docs/STORIA.md`**, con l'indice delle ritrattazioni in testa. Qui sta lo
> STATO, non la storia: non riportare qui blocchi di cronologia.
>
> **Protocollo di sessione:** all'inizio di ogni sessione carica la skill
> `simulomicsr-session` (`.claude/skills/simulomicsr-session/`). Rispondi al PI in stile
> ASD-STE100 all'80%, in italiano: le regole stanno nella skill. Vale dalla prima sessione
> dopo il 2026-11-02 e non è retroattivo.

---

## 1. Dove siamo (2026-11-13): PROGETTO CHIUSO

> **Il PI ha chiuso tutto il progetto il 2026-11-13 con l'esito «non si può fare» (ADR-0030,
> `docs/decisions/0030-chiusura-del-progetto-non-si-puo-fare.md`).** Nessuna sessione si apre: niente Piano 2, niente
> ricalcolo, niente deliverable v17, niente articolo. Il deliverable A3 v16 resta su disco e **non è un risultato
> finale**. Niente è cancellato e gli 82 studi di giudizio restano chiusi. Tutto quello che segue in questo file è lo
> stato al momento della chiusura: non è un piano di lavoro. Se una sessione nuova chiede di riprendere, serve prima
> una decisione esplicita del PI che supera ADR-0030.

**Branch** `p6-tabella-dei-fattori` (dal 2026-11-09, nato da `review-scientific-consistency-2026-06-10`) · **master invariato** ·
**mai `git push`** (lo fa l'utente; il 2026-11-13 il PI ha ordinato il push di questo branch, una volta).

**Deliverable corrente — A3 v16, 194 meta-analisi:**
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
(Stadio 3 `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159`; Stadio 1 e 2
**rigenerati** su un sottoinsieme congelato di 2.566 studi con `VLLM_BATCH_INVARIANT=1`).
**Riferimento per i confronti — 211 meta-analisi, master LLM vecchi:**
`.../simulomicsr-stage4-v16/archivio/20260815T193851Z-stage4-v16-3e31e59d` su Stadio 3
`analysis/p4-output/20260815T231154Z-stage3-v16-7f986159` (byte-identico a
`20260814T025911Z-…`, che è quello scritto nel suo `run_metadata.json`).
Le altre due directory omonime (`20260815T121010Z`, v16 senza collasso delle corsie;
`20260819T184204Z`, duplicato byte-identico del deliverable) stanno con il riferimento
in **`archivio/`** dal 2026-08-21 — il `README.md` nella cartella dice che cosa sono;
nella radice resta solo il deliverable. I documenti anteriori le citano senza `archivio/`.
**Copia verificata** (S2, 2026-08-21) in `/mnt/micron/simulomicsr-salvataggio/`
(deliverable, riferimento, Stadio 3, master, dizionari; 9,4 GB) col manifesto
`analysis/audit/2026-08-21-S2-deliverable-in-salvo/SHA256SUMS.txt` — verifica:
`10-manifesto-e-copia.sh verifica [DEST]`. Nei prompt scrivi il percorso per esteso:
il difetto tipico di questo progetto è lavorare sull'oggetto sbagliato.

**Il quadro (S3-S11 chiuse fra il 2026-08-22 e il 2026-11-07; i blocchi di Stato verbatim stanno in
`docs/STORIA.md` Parte V; fa fede il finding):**

| che cosa sappiamo | numero | finding |
|---|---|---|
| Le 194 lette tutte, due volte | 116 corrette / 62 difettose / 16 incerte; test-retest **kappa 0,78**; umano 18/19 | `2026-08-20-rilettura-194-correttezza`, `2026-08-21-S3-il-metro-concorda` |
| Confronti difettosi di riferimento | **193 / 1.903 (10,1%)**, 85 categorie, 55 con un solo caso; origine: 65% bracci non appaiati (tempo zero 48), 23% seconda perturbazione persa, 8% chiave, 4% indecidibili | `2026-11-07-S11-lettura-falsi-allarmi`, `2026-11-07-valutazione-autonoma-del-progetto` |
| Rilevatore a regole | vede **81/193**; non va in produzione (ADR-0028) | `2026-11-07-S10-rilevatore`, `-S10b-rilevatore-metadati` |
| Controllo condiviso | 492/1.118 bracci; errore standard ×1,20; taglio 113 → 41; tre bracci con ruoli sbagliati (`GSE222992`, `GSE208347`, `GSE135485`) | `2026-11-02-S4-controllo-condiviso` |
| Gate e insiemi | gate a **3 studi**; «40 principali + 132 supplementari» **decaduta** in S11: si rifà in S15 | `2026-11-03-S5-gate-e-insiemi` |
| Studi doppi | 13 gruppi (`sirna pool against igf2bp1` = uno studio); si tolgono in S13 con una regola sulle conte | S5 §6 |
| Validazione esterna (senza nullo) | 14/19 LINCS, 11/32 Tahoe-100M; tumori 6/6 su TCGA; il numero dell'articolo è della seconda esecuzione (S7c) | `2026-11-04-S6-…`, `-S7-validazione-esecuzione` |
| Greche, sinonimi, ID | 7/194 cambiano; **il modello scrive il nome giusto con l'ID ChEBI sbagliato** e il codice si fida dell'ID; 61/194 `canonical_name` sbagliati o NA (l'etichetta di contrasto è giusta) | `2026-11-07-S9-greche-e-corsie`, valutazione |
| Inversioni di braccio | `GSE144269` in HCC confermata (gruppo non citabile finché non è corretto) + 4 bracci; lo strumento vede il 52% | `2026-11-02-inversioni-bracci-194` |
| Re-run Stadi 1-2 (S14, prima parte) | 24.393 studi da zero in 33 h; 211.484/211.484 record identici; master `analysis/p4-output/S14-stage{1,2}-master.jsonl` (copia su micron); outlier con `max_model_len` 32768 | `2026-11-07-S14-due-passi-col-modello`, `-S8b-prova-re-run` |
| Soffitto e biologia | **455 entità** con ≥3 studi nello Stadio 3 (deliverable = 43%); controllo biologico **30/31**, DHT contro enzalutamide −0,944 | valutazione |
| Stadio 2b, il disegno (S12) | schema, regola (segnali → tabella errore/avviso), ingresso senza tagli, prompt v1, test verdi; 1.902/1.903 ingressi nel limite (mediana 3.603 token); **codifica UTF-8 doppia e tripla nell'H5**, riparata nell'ingresso; parte 2 (2026-11-08): 4 decisioni del PI come raccomandato; `description` e protocolli **da GEO congelati** (993 studi) nell'ingresso `28-ingressi-1903.jsonl.gz`; la descrizione cambia fra i campioni in 419/993 studi; **2 campioni dei bracci cancellati da GEO** (GSE226005), marcati; S13 toglie i cancellati | `2026-11-07-S12-stadio2b-disegno` §10 |
| Stadio 2b, la prova (S12p) | **nessun modello passa** il cancello: presi su 193 / puliti accusati su 1.710 = Mistral 186/965, Magistral 177/887, Gemma-4-31B 155/364; lettura cieca dei falsi allarmi di Gemma e Mistral (42 agenti, L2 84%) e seconda lettura senza affermazioni (kappa 0,94): **280 confronti «puliti» non confrontabili** (soprattutto bracci di composizione diversa; regole del PI sui donatori applicate), quindi il riferimento dei 193 è incompleto (473 = 24,9%); Mistral scrive la malattia del donatore come agente (301/315); Gemma ha bisogno di 2 GPU e non è ripetibile al carattere (verdetti 1.903/1.903 uguali); `_preprocess_chat_one` di vLLM si blocca su prompt oltre il contesto; prompt v2 (puliti accusati 713/1.430) e codice da solo non bastano; **diagnosi (§14): 240/473 difetti hanno la differenza nei fatti che lo Stadio 2 riceve** (il prompt dello Stadio 2 non chiede bracci uguali, la RULE 2 fa del tempo zero un controllo; un braccio unisce condizioni diverse in 12/473 difetti e 45/1.430 puliti), **139/473 nascono nello Stadio 1** (letta nel titolo, non scritta), 36 firma, 35 campi non letti, 21 nome; master S14 = A3 in 993/993 studi | `2026-11-08-S12p-prova-cieca-stadio2b` |
| Il lettore dello studio, la prova piccola (S12r) | 47 studi di sviluppo, Mistral, prompt e schema v0, due corse identiche al carattere; cancelli K1-K5 passati; **il lettore v0 non fa meglio della pipeline di oggi**: gruppi identici ad Atlas 14/47 contro 14/47, confronti ritrovati 10/93 contro 19/93 (−9,7 punti, IC95 −25,3, +4,3); **24 studi non chiusi, 18 per la forma delle voci di `assignment`** (sensibilità dichiarata dopo i numeri: 33 chiusi, 20/47, 15/93); 145 disaccordi letti tutti: forma 68, fattore letto dal titolo in 13 studi, fattore annidato in 4 studi, scelte dei curatori 22 (**Atlas usa il tempo zero come controllo**: 10; oggi ne ritrova 6, contati fra i suoi 19); oggi forma 411 gruppi contro i 172 di Atlas e ritrova 16/19 confronti dove i gruppi sono identici, 3/74 altrove; costruttore: Atlas contro Atlas 47/47 e 93/93; Gemma (UBC) non risponde; i due concorrenti del 2026 non formano confronti | `2026-11-09-S12r-prova-lettore-studio` |
| Il lettore dello studio, la prova ripetuta (S12r2) | stessi 47 studi di sviluppo, vista v0, schema e prompt v1, riferimento senza il tempo zero come controllo (97 confronti; intero 93, stretto 86); **Mistral-Small 3.2 con lo schema v1: gruppi identici ad Atlas 31/47 contro 14/47 di oggi, confronti ritrovati 50/97 contro 13/97 (+38,1 punti, IC95 +19,0, +58,2), errori fra i non elencati 0/4**, due corse identiche al carattere; **13 studi non chiusi** (soglia depositata 7): 8 per un valore della colonna senza voce, 3 per la forma, 2 per colonna o valore non letterale; senza `repetition_penalty` 50/97 uguale; **Mistral-Small-4-119B fa peggio (32/97 e 25/97 nelle due corse) e non è ripetibile (4/47 identici) anche con `VLLM_BATCH_INVARIANT=1`, su 4 GPU con `tensor_parallel_size` 4**; Qwen3.5-122B non parte in due tentativi (vLLM 0.20.2 non ammette la batch invariance per gli strati GDN; cache KV insufficiente su 4 GPU con `max_model_len` 65536): non misurato, pesi cancellati dal DGX il 2026-11-10 per decisione del PI; 63 disaccordi letti tutti (audit interno): forma 16, schema o vista con rimedio non misurato 30, lettura del modello 5 (in 2 studi; il modello più grande ne toglie 1), curatori 12; sensibilità dichiarata dopo i numeri: 64/97; **regola di esito: no per i tre modelli** (per Mistral-Small 3.2 valgono tre condizioni su quattro; la quarta è no con la lettura severa, sì alla lettera); proposta non misurata: schema generato per ogni studio, con colonne e valori a elenco chiuso e una voce per valore | `2026-11-10-S12r2-prova-ripetuta-lettore-studio` |
| Il lettore dello studio, la terza prova (S12r3) | stessi 47 studi, vista v0, solo Mistral-Small 3.2, **schema delle uscite generato per ogni studio a elenco chiuso** (massimo 222.556 caratteri, nessun taglio), prompt v2; riferimento a **95 confronti**: i confronti di Atlas di solo contesto (`cell type`, `cell line`, `organism part`) escono per decisione del PI (2026-11-11), la misura su 97 accanto; due corse identiche al carattere 47/47; **45 studi chiusi su 47** (v1 34), **gruppi identici ad Atlas 36/47** (v1 31, oggi 14), **confronti ritrovati 68/95** (v1 50, oggi 13; +57,9 punti, IC95 +40,0, +73,2), errori fra i non elencati 2/33, nessuno del lettore; i 2 non chiusi (`GSE50499`, `GSE63816`) scrivono il nome di un livello in una forma che lo schema non lega (sensibilità dichiarata dopo i numeri: 47/47 chiusi, 71/95); 40 disaccordi letti tutti (audit interno): non errore 21, vista o schema 6, **lettura del modello 13 in 4 studi, gruppi sbagliati in 3** (`GSE57945` sesso come fattore, `GSE46665` sigle dei pazienti come malattie, `GSE60340` colonna del trattamento non vista; `GSE49155` fattore doppio); **3 dei 4 errori non c'erano con lo schema v1 e le 5 unità di lettura di S12r2 sono sparite: l'errore di lettura si sposta con la forma dell'uscita, origine non diagnosticata**; la misura (c) non vede un fattore di troppo (`GSE57945`: 18 confronti «coerenti»); **regola di esito: no per il solo punto 4** (1, 2, 3 e 5 sì), come depositato | `2026-11-11-S12r3-terza-prova-lettore-studio` |
| Il lettore dello studio, dove nasce ogni errore di lettura (S12r4) | stessi 47 studi, vista v0, solo Mistral-Small 3.2, **31 forme dell'uscita** con un cambio per volta fra schema e prompt v1 e la forma di S12r3 (`B0`), più le due correzioni di forma dello schema e 4 placebo (una frase del prompt riscritta senza cambiare il senso); 32 corse su `poddgx02`, 222 minuti; i 5 cancelli passano, `B0` due volte identica al carattere 47/47; **58 errori di lettura letti in 32 studi su 47; regola di diagnosi depositata: della forma 14, del modello 2, non deciso 42** (lettura severa dichiarata dopo i numeri: 5, 2, 51); **un solo errore dei 4 di S12r3 resta in 31 forme su 31** (`GSE46665`, sigle dei pazienti come malattie: del modello); `GSE57945` in 13 forme, `GSE60340` in 8, `GSE49155` in 14; **col placebo la tabella dei fattori cambia in 5-9 studi su 47**, 2 dei 4 errori spariscono e nascono errori in 0-3 studi per corsa; 24 forme su 29 tolgono almeno un errore e tutte e 24 ne fanno nascere almeno uno in un altro studio; `B0` ha 9 errori in 8 studi (4 che costano gruppi o confronti) e nessuna delle 13 forme a un cambio da `B0` ne ha meno; **forma finale secondo la regola: `B0` senza cambi**; le due correzioni di forma non entrano (`F1` fa nascere errori in 14 studi, `F2` in 5; conto per etichetta); `RPa` (47 chiusi, 74/95) e `F2` (76/95) ritrovano più confronti ma non entrano per la regola; due conti degli errori nuovi (depositato e per etichetta, il secondo dichiarato dopo i numeri); revisione indipendente: 6 rilievi, un mio errore di lettura corretto (`GSE69597`), esiti 58/58 uguali dopo la correzione; **la vista non è stata variata**; chiusa con due decisioni del PI | `2026-11-12-S12r4-cause-errori-di-lettura` |
| Il lettore dello studio, più letture dello stesso studio (S12r5) | stessi 47 studi, vista v0, solo Mistral-Small 3.2, forma `B0`; **9 letture per studio**: `B0` e 8 letture con una frase del prompt riscritta senza cambiare il senso (frasi estratte da un programma, giudicate uguali da due agenti, 3 esche viste); 9 corse su `poddgx02`; i 5 cancelli passano, `B0` identica al carattere alla corsa congelata; **la discordanza segnala 24 studi su 47: 6 degli 8 con un errore di `B0`, 18 degli altri 39** (+0,288, IC95 −0,091, +0,610); **regola di esito depositata: no** (4 su 4 studi con un errore che costa sono segnalati, la condizione sull'intervallo no); **5 dei 9 errori di `B0` sono uguali in 9 letture su 9**, fra cui 2 dei 4 che costano (`GSE46665`, `GSE57945`); per lettura: chiusi 41-45, gruppi identici 34-36, ritrovati 58-71 su 95 (`B0` 68), chiave diversa da `B0` in 6-12 studi; lette tutte le 38 schede di disaccordo (24 studi): **le 8 letture nuove portano 22 errori di lettura nuovi in 13 studi** (2-8 studi per lettura, mediana 4,5); nei 24 segnalati la discordanza tocca un errore di lettura in 16, forma in 2, non errore in 6; previsioni smentite 1, 10 e 11 (la 11 col criterio severo, confermata col criterio di prima); revisione indipendente: 29 schede su 38 uguali, il revisore ha ragione in 8 delle 9 diverse e in parte in 1; **trovato in `B0` un errore fuori dai 9, uguale in tutte le letture, in uno studio contato senza errori** (`GSE147507`: il tempo in due colonne complementari, il modello ne legge una); un errore di assegnazione (ruxolitinib, `L4` e `L8`) era passato a tutti e due i lettori perché le schede erano tagliate (19 file su 24); regola di esito accanto con l'errore aggiunto: 7/9 contro 17/38, ancora no; **la vista non è stata variata; i 23 studi non segnalati non sono stati riletti; chiusa il 2026-11-13 con la chiusura del progetto (ADR-0030)** | `2026-11-12-S12r5-piu-letture-dello-stesso-studio` |

**Decisione del PI (2026-11-07):** strada «tenere e sostituire un pezzo» (ADR-0028). Si tengono ETL,
master S14, Stadio 4, gold, verdetti e strumenti di audit; **si sostituisce il giudice di confrontabilità**
con lo **Stadio 2b**: il modello legge il testo grezzo dei due bracci e compila una lista di controllo, una
regola deterministica decide. Cancello: la prova cieca di S12p (≥130/193 presi, ≤40/1.710 accusati). Il
modello non cambia finché S12p non lo misura. Finding: `docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md`.
**S12p (2026-11-08): il cancello non è passato; non si va a S13.**

**Decisione del PI (2026-11-09), ADR-0029: il lettore dello studio.** Un solo passo del modello per studio sostituisce
gli Stadi 1 e 2: legge il testo dello studio e la tabella dei campioni e scrive la **tabella dei fattori** (ruoli delle
colonne, fattori, livelli, livello di base, assegnazione). Un costruttore deterministico forma i confronti da una
definizione sola: due gruppi uguali in tutti i fattori tranne uno, con uno dei due al livello di base; i soggetti
(donatore, sesso, età, passaggio) si confrontano come insiemi. Lo Stadio 2b (ADR-0028) esce dal piano; le due
decisioni aperte di S12p sono superate. **Cancello:** la curazione di Expression Atlas su 129 studi del bacino
(47 sviluppo, 42 giudizio A, 40 giudizio B; **gli 82 studi di giudizio sono chiusi**: niente fattori, confronti o
uscite del modello fino all'apertura), con le stesse misure sul master S14 come termine di paragone. Spec
`docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`; piano in quattro parti
`docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md` (+ `-HUMANE.md`).

**Decisioni del PI (2026-11-10), dopo la prova S12r («ok a tutto»):** (1) ADR-0029 resta: si corregge lo schema e si
ripete la prova sugli stessi 47 studi di sviluppo, con Mistral e con uno o due modelli più grandi, previsioni nuove
prima (**S12r2**); il lettore non entra nel pacchetto prima di quella prova. (2) I confronti di Atlas col tempo zero
come controllo **escono dal riferimento** del cancello, con una regola scritta prima e per costruzione; la misura sul
riferimento intero si riporta accanto. ADR-0029 §Aggiornamento; decisioni tecniche dell'agente in S12r:
`analysis/audit/2026-11-09-lettore-studio/68-decisioni-e-minori.md`.

**Dopo la prova ripetuta S12r2 (2026-11-10). Decise dal PI:** il modello del lettore è Mistral-Small 3.2; Qwen3.5-122B
non si riprova e i suoi pesi sono cancellati dal DGX. **Decisa il 2026-11-11:** prima del Piano 2 si fa una **terza
prova piccola (S12r3)** sugli stessi 47 studi, solo con Mistral-Small 3.2, con lo schema delle uscite a elenco
chiuso. «Schema» qui è la forma JSON dell'uscita, non il disegno dello studio: un programma la genera per ogni
studio dalla tabella dei campioni (solo colonne e valori che esistono, una voce per ogni valore); il modello decide
ancora fattori, livelli e base. Il rimedio non è misurato e non toglie gli errori di lettura. Il Piano 2 non si
scrive e il lettore non entra nel pacchetto prima di quella prova.

**Decisione del PI (2026-11-12), dopo la terza prova S12r3:** il Piano 2 non si scrive adesso. Prima una sessione
breve (**S12r4**) cerca dove nasce ogni errore di lettura del modello: stessi 47 studi, solo Mistral-Small 3.2, un
cambio per volta fra le due forme dell'uscita (schema e prompt), più le due correzioni di forma dello schema. Niente
correzioni al prompt per coprire uno studio, niente regole che fanno il lavoro del modello. Gli 82 studi di giudizio
restano chiusi. ADR-0029 §Aggiornamento 2026-11-12.

**Decisioni del PI (2026-11-12), dopo la sessione sulle cause S12r4, come raccomandato:** (1) la forma dell'uscita del
lettore è `B0` (schema generato per ogni studio a elenco chiuso, prompt v2), senza cambi: è l'esito della regola
depositata; `RPa` e `F2` ritrovano più confronti ma non entrano. (2) Il Piano 2 non si scrive adesso. Prima una sessione
breve (**S12r5**) legge ogni studio più volte, con frasi del prompt riscritte senza cambiare il senso, sugli stessi 47
studi e solo con Mistral-Small 3.2, e misura se la discordanza fra le letture segnala gli errori di lettura. La regola
sulla discordanza si scrive prima e segnala soltanto: non sceglie fra le letture. Limiti noti (calcolo dopo i numeri, tre
letture): segnala 12 studi su 47, 7 con gruppi giusti; 3 dei 4 studi con un errore che costa, non `GSE57945`; non porta a
zero errori. Gli 82 studi di giudizio restano chiusi. ADR-0029 §Aggiornamento 2026-11-12 (S12r4).

**Decisione del PI (2026-11-13), ADR-0030: il progetto è chiuso, «non si può fare».** Il PI ha giudicato la sessione
raccomandata qui sotto senza senso o con un effetto microscopico («non siamo pronti per fare uno studio del genere») e
ha scelto «Tutto il progetto». Il lettore dello studio si ferma prima del cancello; S12r5 è chiusa.

**Dopo la sessione con più letture S12r5 (2026-11-12): erano aperte, superate da ADR-0030.** (1) Che cosa si fa degli studi che
la discordanza segnala: raccomandata «non entra come filtro, resta uno strumento di misura»; le altre: togliere i
segnalati, o tenerli con una nota. (2) Se si scrive il Piano 2 adesso: raccomandata «no, prima una sessione sugli errori
uguali in tutte le letture, che varia la vista»; le altre sei stanno nel finding §8. Non si apre
nessuna sessione e il Piano 2 non si scrive.

**Decisioni del PI che restano valide, una riga ciascuna:** gate a 3 studi · S13 corregge la varianza del
controllo condiviso (T1) e assegna i ruoli per nome · studi doppi tolti con una regola sulle conte · LINCS dà
il verdetto, Tahoe-100M si riporta senza verdetto, soglia 17% · nessuna correzione guarda l'esito di una
singola meta-analisi · tempo zero e differenza tecnica fra i bracci sono **sempre** errori · **nessuna
soglia di errore accettata**: ogni causa si corregge · i campioni cancellati da GEO si tolgono nel ricalcolo (S13) · solo `poddgx02`.

**Che cosa fare adesso: niente, il progetto è chiuso (ADR-0030).** L'ordine qui sotto è quello che era in piedi alla
chiusura; le sessioni da S12s in poi **non si fanno**. **`docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md`** comandava
l'ordine: **S12** (Stadio 2b, il disegno: **chiusa** il 2026-11-08) → **S12p** (la prova: fatta il 2026-11-08,
nessun modello passa) → **S12q** (il lettore dello studio: disegno approvato il 2026-11-09, piano approvato il 2026-11-10, **chiusa**;
esecuzione scelta dal PI: un solo agente per sessione e una revisione indipendente alla fine; lo stato si tiene in `docs/superpowers/plans/2026-11-09-lettore-studio-mappa/`, aggiornato a ogni Task) → **S12r** (Piano 1: costruttore dei confronti, misure contro Atlas, misura di oggi, prova
da buttare sui 47 studi di sviluppo; **fatta il 2026-11-10, la regola di esito non è soddisfatta; chiusa** con le due decisioni del PI qui sopra; il Piano 2 non è scritto) → **S12r2** (la prova ripetuta sui 47 studi: carta e previsioni prima, schema e prompt v1, Mistral e modelli più grandi, una corsa senza `repetition_penalty`; **fatta il 2026-11-10, la regola di esito dà no per i tre modelli; **chiusa il 2026-11-11** con le tre decisioni del PI qui sopra) → **S12r3** (la terza prova piccola sui 47 studi: schema delle uscite a elenco chiuso, solo Mistral-Small 3.2, carta e previsioni prima; **fatta il 2026-11-11: la regola di esito dà no per il solo punto 4, errori di lettura del modello in 4 studi; chiusa il 2026-11-12** con la decisione del PI qui sopra) → **S12r4** (dove nasce ogni errore di lettura: carta e previsioni prima, un cambio per volta sui 47 studi; **fatta il 2026-11-12: 58 errori di lettura in 32 studi, la regola dà una causa nella forma per 14 e nessuna causa per 42, forma finale `B0` senza cambi; chiusa il 2026-11-12** con le due decisioni del PI qui sopra) → **S12r5** (più letture dello stesso studio con frasi riscritte: carta, previsioni e regola sulla discordanza prima, forma `B0`; **fatta il 2026-11-12: la discordanza segnala 24 studi su 47, la regola di esito dà no, 5 dei 9 errori di `B0` sono uguali in tutte le letture, 22 errori nuovi nelle 8 letture nuove; chiusa il 2026-11-13 con la chiusura del progetto**) → **S12s** (Piano 2: il lettore nel pacchetto e il cancello; STOP) →
S12c+S12b, S12d → **S13** (corsa intera, deliverable v17) → S15 (rilettura cieca) → S7c, S7b → S16, S17. L'handout del 2026-08-21 resta per le sessioni chiuse e per i prompt di S12b, S12c, S12d, S16, S17.
Il deliverable su disco resta A3 v16 fino a S13.

**La regola che governa tutto (RED ALERT 2026-07-24, `docs/RED_ALERT.md`):** per
mesi si sono ottimizzati i NOMI dei cluster dichiarando «finale» senza verificare
la **coerenza di contrasto**; verificata, l'85% del deliverable era minestrone.
Da allora **la coerenza è il gate, non i nomi**; niente si dichiara «finale /
publication-grade» senza il gate; le verifiche si fanno su **tutti** i gruppi,
mai a campione; i numeri si misurano sull'oggetto vero, non su un proxy.

---

## 2. La pipeline in breve

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio
design-aware** basata su classificazione LLM dei metadati GEO (il nome è legacy:
non simula nulla). Positioning ADR-0006: non un annotatore di GEO ma la catena
end-to-end metadato → comparison appaiate → anchor canonico → pooling REM;
competitor più vicino RummaGEO (gene-set per studio, senza anchor né effect size).

| stadio | che cosa fa | dove |
|---|---|---|
| 0 · ETL | ARCHS4 v2.5 human bulk (H5) → bacino 508.037 campioni; filtro mouse-mislabeled H2; resolver series | `R/etl-*.R`, `analysis/p4-fase-f-etl-build.R` |
| 1 · sample | Mistral classifica ogni campione (`sample_facts.stage1.v3`); guard deterministico `is_zero_timepoint` a valle | `R/stage1-*.R`, `p4-fase-f2-*` |
| 2 · study | Mistral interpreta il disegno: replicate groups, `design_role`, comparison; **un record per studio** (`.assert_stage2_one_record_per_series`) | `R/stage2-*.R`, `p4-fase-f4-stage2-*-v3.R` |
| 3 · cluster | `build_stage3_clusters()`: record `cgroup` **dal contrasto** (ADR-0025), chiave `entità-delta ‖ verso ‖ tipo-di-controllo`; regole di gate (`stage3-contrast-gate.R`) e di riga (`stage3-row-pairing.R`); recupero-nome deterministico + overlay; coerenza `stage3-coherence.R` | `R/stage3-*.R`, `analysis/p4-fase-f13-stage3-v16-tre-cambi.R` |
| 4 · pooling | solo ramo **`rem_group`** (ADR-0022/0026): limma-voom per studio + collasso bracci intra-studio + REM `metafor`; gate `k_eff≥3`, `n_min=2`; corsie di sequenziamento collassate (`stage4-technical-lanes.R`); dedup una meta-analisi per entità; annotazione `k_kish`/dominanza (`stage4-deliverable-annotation.R`); LOO (`stage4-loo-influence.R`) | `R/stage4-*.R`, `analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R` + `-f5b-stage4-ricomponi-pezzi.R` |
| Layer B | case study per l'articolo (ADR-0017, selezione ADR-0027): 9 bundle, figure, narrative in bozza | `R/layer-b-*.R`, `analysis/p5-stage4-layer-b-build-v*.R` |

Rami `mega`, `mega_aug`, `rem` restano nel codice ma **fuori dal deliverable**
(`stage4_default_config()$deliverable_methods = "rem_group"`).

---

## 3. Comandi che funzionano (verificati)

- **R sul laptop: `Rscript` SENZA `--vanilla`.** Con `--vanilla` mancano `arrow`
  e `devtools` (verificato 2026-08-21). Gli script di audit lo dicono in testata.
  Sul DGX (R 4.6.0) idem: `Rscript -e ...` senza `--vanilla`.
- **Suite di test:** `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="stage4", reporter="summary")'`
  — **senza `head` in pipe** (chiude la pipe e tronca la suite: è già successo).
  Ultima misura: 4.317 asserzioni, 0 fallimenti (2026-08-13).
- **Run multi-ora: `setsid nohup ... < /dev/null &`**, poi verifica `SID == PID`
  (`ps -eo pid,sid,args | grep "[f]13-stage3"`). `run_in_background=true` ha
  **ucciso** un run di ore (stage4 v6 a cluster 76/533, senza OOM né errore).
  Monitorare con `pgrep` sul nome dello script, non col PID. **Dentro un comando che contiene il nome,
  `pgrep -f nome` trova se stesso** e il ciclo non finisce mai (S12, 2026-11-08: 30 min persi): usa `pgrep -f "[n]ome"`.
- **Aggiornamento ORARIO durante i run pesanti**: «fatto + ETA» ogni ora, non
  solo a fine run. Niente poller `until … sleep` in background: check attivi.
- **Re-cluster Stadio 3**: ~2 h 30 m con 32 worker (misurato; a 64 peggiora).
  **Re-pool Stadio 4**: ~75 min in 16 pezzi (`PEZZO`/`N_PEZZI`/`PEZZI_DIR`/
  `STAGE3_DIR`/`VERDETTI_PATH`) + `p4-fase-f5b-stage4-ricomponi-pezzi.R`; in un
  pezzo solo 32 h. Comandi e default: `docs/superpowers/specs/2026-08-16-HANDOUT-PROSSIMA-SESSIONE.md` §6.
  Verdetti da passare: gli **APPLICABILI** (11), non 24 — la guardia è fatale **a fine corsa**.
- **Controllo biologico** (minuti, bersagli fissati dalla letteratura prima di
  guardare): `POOL_DIR=<dir> Rscript analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R`;
  **annotazione a freddo** dai parquet: `…/80-annotazione-a-freddo-v15.R`.
- Quarto **c'è** (`/usr/local/bin/quarto`): se la dashboard non renderizza non è il binario.

---

## 4. Regole di metodo già pagate (una riga ciascuna, con il prezzo)

- **Nessun errore è accettabile, e le domande al PI devono essere semplici**: in S11 ho chiesto al PI quale precisione accettare per il rilevatore, e ho proposto un'opzione che i numeri decidevano già. Il PI: «La pipeline non deve sbagliare. Sono dati fissi, non ci sono dati nuovi.» Il database è fisso: ogni errore ha una causa che si corregge. Prima di portare una scelta al PI, verifica che ogni opzione possa cambiare l'esito, e scrivila senza sigle.
- **Il costo non vale contro il mandato**: in S8b ho consigliato di non fare il re-run, per il costo e su un campione. Il PI: «Si rifa tutto, siamo scienziati». Un limite si dichiara nei Methods quando il lavoro non si può fare, non quando costa ore.
- **validate-before-fullrun**: smoke + validazione scalata, poi STOP e sessione
  nuova per il run massivo. **Previsioni depositate PRIMA del run**, per iscritto.
- **Lo strumento deve vedere il dato intero**: tre strumenti ciechi in due giorni
  (alias corti, lettere greche cancellate, etichette troncate). Prima di
  giudicare, misura «quante stringhe toccano il limite».
- **Misura l'oggetto giusto**: il censito ≠ il poolato (47 accusati su 85 non
  erano nel deliverable); `k_effective` è **per-gene**, non del cluster; i pesi
  si calcolano sugli studi dopo il collasso dei bracci, non sui bracci; il
  dispatch va **misurato**, non simulato a mano (il k_eff del 13/08).
- **Scalari-come-array**: nei JSON `value_hours` è un array di un elemento;
  `is.numeric(list(0))` è FALSE. `\b` non vede il confine dopo `_` né dopo una
  cifra. I regex con `ignore.case=TRUE` annullano i vincoli `sh[A-Z]`.
- **No whack-a-mole**: dopo 2+ crash dello stesso job, STOP; isola ogni causa con
  una riproduzione minima, poi ri-lancia una volta.
- **Audit-before-patch**: con N≥2 bug dallo stesso audit, cerca il pattern nella
  decision table prima di patchare uno per uno.
- **Bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`** (`R/stage3-name-recovery-lookup.R`)
  a ogni cambio di `recover_identity`: senza bump il re-cluster riusa il lookup
  stale (8 h buttate, output identico al precedente). Verifica: build ~1 min, file
  cache nuovo. I percorsi di input del re-cluster vanno passati, non scritti nel codice.
- **Le variabili d'ambiente vanno verificate sul processo**, non nello script
  (`tr '\0' '\n' < /proc/<pid>/environ | grep VLLM`): una flag scritta e non
  passata è come il collasso delle corsie che non si accendeva.
- **Congela l'ambiente, non solo il prompt**: il primo retest di S3 aveva prompt
  byte-identici e 11 agenti su 60 hanno letto file scritti *dopo* il run originale
  (stringhe grezze, verdetti). Gli agenti hanno strumenti: materiale in cartella
  congelata fuori dal repo, e conta le fonti sui transcript **dopo** (`25-cosa-hanno-letto.py`).
- **Una lista scritta a mano non è una regola**: scarta per costruzione, non per
  elenco di chiavi; i verdetti umani si marcano, non si sovrascrivono
  (`canonical_name` non è mai sovrascritto).
- **Domanda ≠ critica**: «perché X?» chiede il razionale, non un cambio. Decisioni
  non banali: spiega, elenca TUTTE le opzioni coi trade-off, dichiara la
  preferenza, aspetta. Paper-grade: nessuna fretta, nessun «v1 accettabile».
- **Nessun Claude nella pipeline né nella validazione pubblicata** (evaluator =
  Mistral self-hosted); pipeline e gate **deterministici**; i subagent Claude
  sono solo audit interno.

---

## 5. Convenzioni

**Tracciabilità — ogni decisione documentata prima del codice che la riflette.**
ADR → `docs/decisions/NNNN-<slug>.md` (template `template.md`) · spec →
`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` · plan →
`docs/superpowers/plans/…-plan.md` + companion HUMANE · finding →
`docs/findings/YYYY-MM-DD-<topic>.md` · evidenza → `analysis/audit/<data>-<topic>/`
· ledger → `.superpowers/sdd/progress.md`.

**Git.** Branch per fase (`p<N>-<slug>`); merge **fast-forward only** su master
con tag `p<N>-<slug>-complete`. **MAI `git push`** — lo fa l'utente. **MAI
`--no-verify` / `--no-gpg-sign`.** Commit atomici, messaggi in italiano. Prima
di ogni commit: `git checkout -- renv/settings.json` (è tracciato: mai `rm`) e ripristinare
`analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` — **mai** durante
un `tar_make` in corso.

**Codice.** Italiano in commenti, docstring, errori e commit; ASCII per gli
accenti nei `.Rd`. Interne `@keywords internal`, `@export` solo i veri entry
point. **TDD bite-sized** (test → fail → impl → pass → commit). Rigenerare
`NAMESPACE`/`man` dopo ogni cambio (è rimasto indietro due volte). «Codice robusto,
non bello»: errori diagnostici, warning su ogni drop silenzioso, tracce in
`run_metadata`. **Mai tagli silenziosi** nelle figure: ogni filtro in caption.

---

## 6. Configurazione LLM di produzione (invariata da α, ADR-0008/0010/0011/0013)

Container `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` · modello
`mistralai/Mistral-Small-3.2-24B-Instruct-2506` FP16 su DGX H100, costo $0 ·
`temperature=0.0`, `repetition_penalty=1.1` · Stadio 2 `chunk_size=50`,
`max_num_seqs=6`, `microbatch=50`, tier max_tokens S/M/L/XL → 4K/8K/16K/32K ·
structured outputs · **`VLLM_BATCH_INVARIANT=1`** (rende riproducibile il run
nuovo, **non** lo fa coincidere col vecchio: senza flag due run identici davano lo
stesso record nel 40% dei casi). Rescue a cascata: `rep_pen` 1.2→1.3→1.4,
cs50→cs25, `max_tokens` 32768 (`docs/findings/2026-05-17-p4-beta-rescue-strategies.md`,
`-2026-06-11-f4-stage2-v3-rescue-and-generalization.md`). Config identica su
tutti gli stadi, anche a costo di efficienza.

---

## 7. DGX UniPD (P4 cluster)

- **Usa solo `poddgx02`. Non usare `poddgx01`: lo ha vietato il PI.** Non usare `nodelist = NULL`, perché lo scheduler può scegliere `poddgx01`. Il 2026-11-04 la sessione S8b ha lanciato 4 job su `poddgx01` senza cercare il divieto, e il nodo è caduto con 2 di quei job in corsa (causa non nota). I testi `R/dgx-config.R` e `analysis/p5-name-cleanup-run.R` suggeriscono ancora gli altri nodi: non seguirli. «Tutto il pod» (PI, 2026-11-05) vuol dire le 8 GPU di `poddgx02`, due job da 4 GPU: `poddgx05` sta su `shared-dgx`, con altri utenti, e serve una risposta esplicita del PI.
- Path **`/home/u0044/`**, NON `/mnt/home/u0044/` (i compute node non lo montano;
  sintomo: `ExitCode 0:53` in 2 s senza log).
- **Prima di sottomettere**: `sinfo` = `idle` non basta, verifica il mount con un
  `srun` breve (`/home` non montato → `0:53` e zero log; diagnostica in
  `docs/STORIA.md` Parte IV).
- Dati pesanti su **`/mnt/projects/dctv/dgx/u0044/`** (NFS di gruppo, no cap),
  non in `/home` (quota 500 G). TODO: migrare il workspace `simulomicsr-dgx`.
- ssh non-interattivo non sourca `/etc/profile.d` → `R/dgx-utils.R::.dgx_ssh()`
  wrappa con `bash -lc`. `singularity exec --nv` diretto, **no `srun singularity`**.
- `dgx_p4_submit(time=)`: default 72 h, rispetta il plan; su TIMEOUT resume
  (collect parziale + split residuo), non alert+stop. Partition `dgx12cluster`
  `infinite`; 2 TB RAM / 100 core. Vignette: `vignettes/p4-dgx-setup.Rmd`.

---

## 8. Trappole tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs 1.1.4 (installato)**: il libpath del progetto è
  quello giusto; `--vanilla` lo bypassa ed è il motivo per cui mancano i pacchetti.
- `tar_make`: `callr_function = NULL` se i target chiamano OpenAI (callr non
  eredita la API key); `format = "rds"`; `sample_facts_validator` storizza un
  PATH allo schema (V8 non serializzabile), `compile_schema()` inline.
- **Non re-introdurre `temperature = 0` di default** in `R/llm-client-openai.R`
  (i reasoning model rispondono 400); esplicito dal chiamante. Hang HTTP iniziale
  dopo un glitch di rete: kill + retry.
- `write_parquet` perde gli attributi: i registri vanno in `qc_report`, non come
  `attr()`. La cache delle conte scrive su temporaneo + rename. `h5_metadata`
  senza i cinque campi delle corsie è **fatale** (prima: warning sepolto).
- **La cache delle conte non conserva l'ordine dei campioni** (chiave ordinata) e `.run_per_study_de_all()` assegna
  i ruoli per posizione: se la stessa matrice è stata chiesta con un'altra divisione, i ruoli cadono sui campioni
  sbagliati. **Prima di ogni re-pool** va corretto (S13). Misurato: 3 bracci su 1.903 nel deliverable.
- **`non_processable.rds` non conta tutti gli esclusi dal gate**: `k_eff_min` taglia anche il `k` censito in
  `.identify_layer_a_clusters()`. A k_min=2 i candidati sono 700, non 316. Il registro ne vede 88 su 282.
- **Il deliverable conta studi GEO, non dati distinti**: due numeri GEO possono avere le stesse conte (a meno del
  riallineamento). `k_eff` e `quota_top1` ne risentono (finding S5 §6). Non usare l'impronta esatta: serve la distanza.
- **`data.table`: dentro `dt[...]` un nome di colonna vince sulla variabile esterna**, anche dentro una funzione anonima: `g[cluster_id == cluster_id[i]]` confronta `g` con se stessa. Ha dato 32 su 32 e 3 su 16 falsi in S7. Salva il valore in una variabile con un altro nome. Lo stesso vale per i parametri degli aiutanti (`k`).
- **I testi GEO nell'H5 sono in parte codificati due o tre volte** («Î²» per «β», «Â°C» per «°C»): li hanno letti
  anche gli Stadi 1 e 2. Riparazione: `.s2b_norm_testo()` (`R/stage2b-input.R`). **`rhdf5::h5read(..., index=)`
  sulle stringhe di `meta/samples` va in segfault**: leggi il campo intero (13 s per 13 campi).
- ARCHS4 v2.5: 4.638/67.186 simboli HGNC duplicati → asse dei geni `gene_id`
  Ensembl (`gene_symbol` è etichetta); tabelle per simbolo deduplicate
  (`.rank_and_dedup_genes()`); merge fra gruppi su `gene_id`.

---

## 9. Dove stanno i dati che il repo NON contiene

| asset | dove | come si ottiene |
|---|---|---|
| Deliverable Stadio 4 corrente (194) e riferimento (211) | §1 | re-pool (§3); copia verificata in `/mnt/micron/simulomicsr-salvataggio/` (S2) |
| Stadio 3 A3 / riferimento | `analysis/p4-output/20260818T110906Z-…` / `20260815T231154Z-…` (gitignored) | re-cluster (§3) |
| Master Stadio 1 v2 (508.037) / Stadio 2 v3 (24.394 studi) | `analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl`, `p4-fase-f4-stage2-master-v3.jsonl`; versioni A3 innestate `analysis/p4-output/A3-stage{1,2}-master-innestato.jsonl` (script in `analysis/audit/2026-08-16-A3/`) | run DGX (§6, §7) |
| Master S14, da zero e ripetibili: Stadio 1 (508.037) / Stadio 2 (24.393 studi) | `analysis/p4-output/S14-stage1-master.jsonl`, `S14-stage2-master.jsonl` (SHA-256 in `analysis/audit/2026-11-05-S14-re-run-modello/90-master-sha256.txt`); copia in `/mnt/micron/simulomicsr-salvataggio/S14-master-2026-11-07/` | `analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R` |
| Input Stadio 1 v2 | `analysis/input/archs4-human-stage1-input-v2.jsonl` | `analysis/p4-fase-f-etl-build.R` |
| ARCHS4 H5 human v2.5 (47,86 GB) | `analysis/input/human_gene_v2.5.h5` | `wget -c https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5`; MD5 in `analysis/p4-output/p4-beta-archs4-source.json` |
| `lib_size` precalcolato | `analysis/audit/A3-libsize-scprob-bacino.tsv` | riusabile senza ri-scansionare l'H5 |
| Dizionari ontologici | `~/.cache/R/simulomicsr/` (ChEBI, HGNC, MeSH, ChEMBL `cache/chembl/chembl-lookup.rds`, taxonomy, ImmPort, UniProt, GO) | `analysis/p5-audit-chembl-build-dict.R` e script di build; HGNC da genenames.org |
| Cache conte Stadio 4 · recupero-nome · Entrez | `stage4-counts/` (chiave method-independent, riusabile fra re-pool) · lookup **v7** (`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`, §4) · `tools::R_user_dir("simulomicsr","cache")/geo-series-resolver-cache.rds` (~5-6 h con `NCBI_API_KEY`) | auto |
| `OPENAI_API_KEY` · bundle DGX | `.Renviron.local` (gitignored; oggi risponde 401 → smoke E2E solo con `SIMULOMICSR_LLM_SMOKE=1`) · `analysis/p4-bundles/` | utente · `dgx_p4_build_bundle()` |

**Dal 2026-10-27 i dati stanno fisicamente su `/mnt/micron/simulomicsr-dati/`**:
`analysis/input`, `analysis/p4-bundles`, le 416 voci di `analysis/p4-output` e
`~/.cache/R/simulomicsr` sono link (i 17 file tracciati di `p4-output` restano veri). I
percorsi di sempre funzionano; i run **nuovi** in `analysis/p4-output/` cadono ancora
sulla radice. Mai cancellare lì: non è una copia. `analysis/audit/2026-10-27-dati-su-micron/`.

---

## 10. Gold standard

- `data-raw/relevant_sample_classified.xlsx` (committato, ~10 MB): 130.784 righe,
  `trtctr_EP` = gold manuale («qualunque intervento esplicito», diverge da
  `design_role`).
- Gold design-aware: `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 campioni);
  gold LLM-assisted 756 campioni / 72 studi (accuratezza binaria 94,1–96,0%).
- Bersagli biologici fissati dalla letteratura per il controllo di §3 (DHT vs
  enzalutamide di segno opposto, TGF-β1, IFN-γ, LPS, SARS-CoV-2).

---

## 11. Limiti misurati, da scrivere nei Methods (S17)

Puntatori, non numeri nuovi: **L7** controlli prestati bocciati, trattati-solo
irrecuperabili (`docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`);
**dominanza** (`k_kish` nel deliverable); **bias concorde** invisibile a ogni
leave-one-out; **16,5%** di verdetti che l'etichetta non chiude (32/194, insieme
diverso dalle 16 incerte); **1.993 campioni** persi dallo Stadio 2 (potenza, non
errori); il gate seleziona per controllo interno e **può concentrare l'errore**;
l'FDR premia i consistenti, non i grandi; la correlazione da controllo condiviso
non è modellata nel deliverable (misurata in S4, si corregge in S13), e il batch fra bracci con campioni diversi resta non modellato comunque; il verdetto sulle etichette **non vede i bracci invertiti**
(`GSE144269`, finding S3 §5); sotto i dieci studi l'I² è poco leggibile e la significatività dipende dal test z; il segno concorde non è una prova, e gli studi doppi non si vedono dalle etichette (finding S5). La validazione esterna riconosce soprattutto i composti forti e molto studiati, e contro Tahoe il valore è molto più basso (finding S7). Il paper è per bioinformatici: niente frizioni
d'infrastruttura salvo impatto biologico diretto.

---

## 12. Riferimenti

- **Storia e ritrattazioni**: `docs/STORIA.md` · **RED ALERT**: `docs/RED_ALERT.md`
  (§«Come Claude si deve comportare con me in questo audit»).
- **Handout corrente**: `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md` (ordine delle sessioni); quello del 2026-08-21 per le sessioni chiuse e i prompt di S12b-S12d, S16, S17;
  comandi dei run: `-2026-08-16-HANDOUT-PROSSIMA-SESSIONE.md` §6-§8.
- **Findings recenti**: `2026-11-12-S12r5-piu-letture-dello-stesso-studio` · `2026-11-12-S12r4-cause-errori-di-lettura` · `2026-11-11-S12r3-terza-prova-lettore-studio` · `2026-11-10-S12r2-prova-ripetuta-lettore-studio` · `2026-11-09-S12r-prova-lettore-studio` · `2026-11-08-S12p-prova-cieca-stadio2b` · `2026-11-07-S12-stadio2b-disegno` · `2026-11-07-valutazione-autonoma-del-progetto` · `2026-11-07-S11-lettura-falsi-allarmi` · `2026-11-07-S10b-rilevatore-metadati` · `2026-11-07-S10-rilevatore` · `2026-11-07-S9-greche-e-corsie` · `2026-11-07-S14-due-passi-col-modello` · `2026-11-05-S8b-prova-re-run` · `2026-11-04-S8-re-run-decisione` · `2026-11-04-S7-validazione-esecuzione` · `2026-11-04-S6-validazione-disegno` · `2026-11-03-S5-gate-e-insiemi` · `2026-11-02-S4-controllo-condiviso` · `2026-11-02-inversioni-bracci-194` · `2026-08-21-S3-il-metro-concorda` · `2026-08-21-S2-deliverable-in-salvo` · `2026-08-20-rilettura-194-correttezza` · `2026-08-19-a3-movimento-stadio3`
  · `2026-08-16-batch-invarianza-a-shard-diverso` · `2026-08-13-tre-cambi-implementati`
  · `2026-08-13-passo2-il-nome-sbagliato-non-costa` · `2026-08-12-corsie-non-repliche`
  · `2026-08-10-sensitivity-confronti-spuri` · `2026-08-05-confronti-imperfetti`
  · `2026-07-23-stage3-cluster-coherence` (tutti in `docs/findings/`).
- **ADR chiave** (`docs/decisions/`): 0006 positioning · 0008 sampling · 0016
  dream/gene-symbol · 0017 Layer B · 0019 metadati ARCHS4 v2 · 0020 Stadio 2 per
  condizioni · 0021 metrica di consistenza · 0022 ramo `rem_group` · 0023/0024
  overlay e fallback nomi · 0025 record di gruppo dal contrasto · 0028 Stadio 2b (superato da 0029) · 0029 il lettore dello studio e la tabella dei fattori (superato da 0030) · **0030** chiusura del progetto, «non si può fare» · **0026** ramo
  mega fuori dal deliverable — ⚠️ il file sta solo sul branch
  `mega-recovery-2026-07-27` (worktree `/home/user/simulomicsr-mega`), non in
  questo branch: da annotare · 0027 selezione dei case study.
- Valutazione modelli: `docs/model-evaluation-history.md`; report P3.5:
  `analysis/eval/p35a-benchmark.html`. **Decisioni rinviate** (rename ADR-0003,
  `ellmer`, vocabolari extra, gold scalato, MetaHQ, cache cross-modello, server
  ADR-0005) e la vecchia **Roadmap**: `docs/STORIA.md` Parte III, verbatim.
