# 26-cause-tabella.R — S12r3: le sottoclassi di causa della lettura dei disaccordi, chi le puo' togliere e, per le cause
# di vista o di schema, il rimedio nominato (00-previsioni.md, regola di esito, punto 4). Letto da 26-disaccordi.R.
# Le sottoclassi di lettura del modello e dei curatori sono quelle di S12r2 (stesso nome, stesso significato). Le
# sottoclassi di forma di S12r2 (forma delle voci, valore senza voce, valore o colonna non letterale, condizione sulla
# colonna padre) non esistono piu': lo schema a elenco chiuso non le ammette.
RIMEDIO <- c(
  "schema/una_colonna_per_fattore" = "schema", "schema/colonna_fattore_e_soggetto" = "schema",
  "schema/context_senza_base" = "schema", "vista/sotto_serie" = "vista", "vista/mancante_non_dichiarato" = "vista",
  "modello/fattore_per_campione" = "modello", "modello/fattore_doppio" = "modello", "modello/fattori_uniti" = "modello",
  "modello/fattore_non_visto" = "modello", "modello/fattore_inventato" = "modello", "modello/ruolo_soggetto" = "modello",
  "modello/tipo_fattore" = "modello", "modello/base" = "modello", "modello/livello" = "modello",
  "modello/colonna_sbagliata" = "modello", "modello/ruolo_incoerente" = "modello",
  "curatore/tempo_zero" = "non_serve", "curatore/riferimento" = "non_serve", "curatore/repliche" = "non_serve",
  "curatore/errore_campione" = "non_serve", "curatore/fattore_ignorato" = "non_serve",
  "curatore/fattori_combinati" = "non_serve", "curatore/livelli_uniti" = "non_serve",
  "strumento/fattori_ridondanti" = "strumento")
SPIEGA <- c(
  "schema/una_colonna_per_fattore" = "lo schema v2 dà a un fattore una sola colonna: la variabile è scritta in due o più colonne, ognuna valida per una parte dei campioni, e nessuna colonna la scrive per tutti",
  "schema/colonna_fattore_e_soggetto" = "per lo schema v2 una colonna letta da un fattore non può essere anche soggetto",
  "schema/context_senza_base" = "per schema un fattore di contesto non ha livello di base: il lettore non può scrivere il confronto fra due tipi cellulari, due tessuti o due condizioni di coltura",
  "vista/sotto_serie" = "la vista porta i campioni di più sotto-serie con colonne diverse e molte celle vuote",
  "vista/mancante_non_dichiarato" = "la stringa «NA» di una colonna di soggetto non è dichiarata in `missing_values`: il costruttore la legge come un valore scritto",
  "modello/fattore_per_campione" = "un fattore letto dal titolo o da un identificativo, con un livello per campione",
  "modello/fattore_doppio" = "due fattori scritti dalla stessa informazione (una colonna ripete l'altra)",
  "modello/fattori_uniti" = "due variabili del disegno scritte come un fattore solo, o una colonna che non distingue i livelli scritti",
  "modello/fattore_non_visto" = "una colonna che distingue le condizioni è giudicata non informativa, replica o soggetto",
  "modello/fattore_inventato" = "un fattore che i metadati non scrivono, o una colonna di soggetto o di replica scritta come fattore",
  "modello/ruolo_soggetto" = "ruolo di soggetto sbagliato: il donatore o il sesso scritti come fattore, o una colonna di condizione letta come donatore",
  "modello/tipo_fattore" = "tipo del fattore sbagliato (una malattia scritta come contesto, un contesto come stato)",
  "modello/base" = "livello di base non scritto dove c'è, o scritto dove non c'è",
  "modello/livello" = "livello sbagliato per un valore della colonna (anche «not stated» o «not applicable» dove il valore è scritto)",
  "modello/colonna_sbagliata" = "il fattore legge una colonna che non lo scrive per tutti i campioni, dove un'altra colonna lo scrive",
  "modello/ruolo_incoerente" = "il ruolo di una colonna in `columns` contraddice i fattori: `factor` senza un fattore che la legge, o un fattore su una colonna con un altro ruolo",
  "curatore/tempo_zero" = "Atlas usa il tempo zero come controllo",
  "curatore/riferimento" = "Atlas usa come riferimento un gruppo che non è un controllo",
  "curatore/repliche" = "Atlas tratta come repliche campioni che differiscono in una variabile sperimentale",
  "curatore/errore_campione" = "Atlas mette un campione nel gruppo sbagliato",
  "curatore/fattore_ignorato" = "Atlas ignora una colonna di GEO che distingue i campioni",
  "curatore/fattori_combinati" = "Atlas confronta due gruppi che differiscono in due fattori veri",
  "curatore/livelli_uniti" = "Atlas unisce in un livello due valori che GEO distingue",
  "strumento/fattori_ridondanti" = "la misura (c) conta come due fattori la stessa differenza scritta due volte da Atlas")
NOMINATO <- c(
  "schema/una_colonna_per_fattore" = "la vista aggiunge una colonna unita per le variabili scritte in più colonne a celle complementari, oppure lo schema ammette più colonne per fattore con una voce per ogni combinazione che esiste",
  "schema/colonna_fattore_e_soggetto" = "lo schema ammette per una colonna il doppio ruolo fattore e soggetto",
  "schema/context_senza_base" = "nessuno: è la regola del costruttore decisa dal PI (2026-11-11); i confronti di solo contesto sono fuori dal riferimento",
  "vista/sotto_serie" = "la vista porta una sotto-serie per volta, con le sole colonne di quella sotto-serie",
  "vista/mancante_non_dichiarato" = "la vista scrive come cella vuota le stringhe che vogliono dire dato mancante")
