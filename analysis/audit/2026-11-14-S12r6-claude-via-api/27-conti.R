# S12r6, sola misura con i modelli Claude via API: i conti dopo la lettura delle schede.
# Uso (senza --vanilla): Rscript analysis/audit/2026-11-14-S12r6-claude-via-api/27-conti.R <oggetti.rds di 24-misura.R>
# Legge 27-classi.csv (una riga per scheda: classe, costa, costa_su_atlas, descrizione; scritta a mano dall'agente
# dopo la lettura di tutte le schede di 26-materiale.R) e la unisce alle 8 corse 1 con la chiave scheda -> corsa.
# Scrive 27-classi-per-corsa.csv, 27-P13.csv e 27-out.txt. Non cambia nessun file di 24-misura.R.
#   costa = si          : i gruppi del lettore sono sbagliati o i suoi confronti sono persi o sbagliati (conto largo,
#                         come 26-errori-nelle-basi.csv della sessione sulle cause, S12r4)
#   costa_su_atlas = si : la scheda cambia la misura contro Atlas, (a) o (b) (conto stretto)
# Le classi «rifiuto» e «fermato dal limite di spesa» non stanno nella carta (§8): aggiunte dopo i numeri, dichiarate.
arg <- commandArgs(trailingOnly = TRUE); stopifnot(length(arg) == 1L, file.exists(arg[1]))
S6 <- "analysis/audit/2026-11-14-S12r6-claude-via-api"
O <- readRDS(arg[1]); RUN <- O$RUN; gse <- O$sv$gse; stopifnot(length(gse) == 47L, length(RUN) == 8L)
CL <- utils::read.csv(file.path(S6, "27-classi.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
LEG <- utils::read.csv(file.path(S6, "24-da-leggere.csv"), stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(CL$scheda))
TUTTE <- do.call(rbind, lapply(names(RUN), function(k) data.frame(scheda = RUN[[k]]$kk$scheda, studio = gse, corsa = k, stringsAsFactors = FALSE)))
TUTTE$forma <- substr(TUTTE$corsa, 1L, 1L); TUTTE$modello <- sub("^[TV]-([a-z]+)-corsa1$", "\\1", TUTTE$corsa)
# ogni scheda da leggere ha una classe; ogni classe ha almeno una corsa; lo studio della classe e' quello della corsa
stopifnot(all(LEG$scheda %in% CL$scheda), all(CL$scheda %in% TUTTE$scheda))
X <- merge(TUTTE, CL[, c("scheda", "classe", "costa", "costa_su_atlas", "descrizione")], by = "scheda")
stopifnot(identical(X$studio, CL$studio[match(X$scheda, CL$scheda)]))
X$letta_per <- ifelse(paste(X$scheda, X$corsa) %in% paste(LEG$scheda, LEG$corsa), "disaccordo", "solo GSE147507")
stopifnot(sum(X$letta_per == "disaccordo") == nrow(LEG))
ord <- c("haiku", "sonnet", "opus", "fable"); X$modello <- factor(X$modello, ord)
X <- X[order(X$forma, X$modello, X$studio), ]
utils::write.csv(X[, c("corsa", "forma", "modello", "studio", "scheda", "letta_per", "classe", "costa", "costa_su_atlas", "descrizione")],
                 file.path(S6, "27-classi-per-corsa.csv"), row.names = FALSE, fileEncoding = "UTF-8")
sink(file.path(S6, "27-out.txt"), split = TRUE)
cat(sprintf("schede lette %d in %d studi; righe scheda x corsa %d (di cui %d per disaccordo, %d solo per GSE147507)\n",
            nrow(CL), length(unique(CL$studio)), nrow(X), sum(X$letta_per == "disaccordo"), sum(X$letta_per != "disaccordo")))
cat("\n== schede per classe e costo (unita': scheda)\n"); print(table(CL$classe, paste("costa", CL$costa)))
cat("\n== righe scheda x corsa per classe (unita': studio in una corsa)\n"); print(table(X$classe, X$corsa)[, names(RUN)])
lm <- X[X$classe == "lettura del modello", ]
P <- do.call(rbind, lapply(names(RUN), function(k) { d <- lm[lm$corsa == k, ]
  data.frame(corsa = k, forma = substr(k, 1L, 1L), modello = sub("^[TV]-([a-z]+)-corsa1$", "\\1", k),
             P13_largo = length(unique(d$studio[d$costa == "si"])), P13_stretto = length(unique(d$studio[d$costa == "si" & d$costa_su_atlas == "si"])),
             senza_costo = length(unique(d$studio[d$costa == "no"])),
             studi_largo = paste(sort(unique(d$studio[d$costa == "si"])), collapse = " "),
             studi_stretto = paste(sort(unique(d$studio[d$costa == "si" & d$costa_su_atlas == "si"])), collapse = " "), stringsAsFactors = FALSE) }))
attese <- c("T-haiku-corsa1" = 6, "T-sonnet-corsa1" = 3, "T-opus-corsa1" = 2, "T-fable-corsa1" = 2, "V-haiku-corsa1" = 5, "V-sonnet-corsa1" = 3, "V-opus-corsa1" = 2, "V-fable-corsa1" = 2)
P$P13_atteso <- attese[P$corsa]
utils::write.csv(P, file.path(S6, "27-P13.csv"), row.names = FALSE)
cat("\n== P13: studi con almeno un errore di lettura del modello che costa (largo: gruppi o confronti del lettore; stretto: la misura contro Atlas)\n")
print(P[, c("corsa", "P13_atteso", "P13_largo", "P13_stretto", "senza_costo")], row.names = FALSE)
for (i in seq_len(nrow(P))) cat(sprintf("  %s largo: %s\n  %s stretto: %s\n", P$corsa[i], P$studi_largo[i], P$corsa[i], P$studi_stretto[i]))
cat("\n== studi non chiusi o persi per una causa che non e' la lettura del modello\n")
print(table(X$classe[X$classe %in% c("forma", "rifiuto", "fermato dal limite di spesa")], X$corsa[X$classe %in% c("forma", "rifiuto", "fermato dal limite di spesa")]))
cat("\n== GSE147507 per corsa\n"); print(X[X$studio == "GSE147507", c("corsa", "classe", "costa", "costa_su_atlas")], row.names = FALSE)
cat("\n== studi con un errore di lettura che costa in almeno una corsa (largo):", paste(sort(unique(lm$studio[lm$costa == "si"])), collapse = " "), "\n")
sink()
