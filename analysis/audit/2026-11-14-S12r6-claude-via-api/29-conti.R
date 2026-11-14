# S12r6, sola misura con i modelli Claude via API: i conti degli errori di lettura sulle 16 corse e sul file
# completato di Fable (V-fable-corsa1b). Deviazione §4 di 25-deviazioni.md: la carta (§8) chiede la lettura delle
# sole corse 1; il PI ha chiesto «chi sbaglia meno?» e una corsa sola non basta, perche' le due corse non sono uguali.
# Uso (senza --vanilla):
#   Rscript analysis/audit/2026-11-14-S12r6-claude-via-api/29-conti.R <oggetti delle 16 corse .rds> <oggetti di 24b .rds>
# Legge 27-classi.csv (74 schede delle corse 1, dopo la revisione indipendente) e 29-classi-nuove.csv (27 schede nuove
# delle corse 2 e di V-fable-corsa1b, lette dall'agente con le stesse regole, SENZA revisione indipendente).
# Scrive 29-classi-per-corsa.csv, 29-errori-per-corsa.csv, 29-due-corse.csv e 29-out.txt.
# Non cambia nessun file di 24-misura.R ne' di 27-conti.R. La previsione P13 resta giudicata sulle corse 1 (27-P13.csv).
#   largo   = studi con un errore di lettura del modello che costa gruppi o confronti del lettore
#   stretto = studi con un errore di lettura del modello che cambia la misura contro Atlas, (a) o (b)
arg <- commandArgs(trailingOnly = TRUE); stopifnot(length(arg) == 2L, all(file.exists(arg)))
S6 <- "analysis/audit/2026-11-14-S12r6-claude-via-api"
O <- readRDS(arg[1]); B <- readRDS(arg[2]); gse <- O$sv$gse
RUN <- O$RUN; stopifnot(length(gse) == 47L, length(RUN) == 16L, identical(B$sv$gse, gse))
RUN[["V-fable-corsa1b"]] <- B$RUN[["V-fable-corsa1"]]
C1 <- utils::read.csv(file.path(S6, "27-classi.csv"), stringsAsFactors = FALSE, encoding = "UTF-8"); C1$letta_in <- "corse 1, con revisione"
C2 <- utils::read.csv(file.path(S6, "29-classi-nuove.csv"), stringsAsFactors = FALSE, encoding = "UTF-8"); C2$letta_in <- "corse 2 e 1b, senza revisione"
stopifnot(nrow(C1) == 74L, nrow(C2) == 27L, !anyDuplicated(c(C1$scheda, C2$scheda)))
# costa_su_atlas e' vuoto per «non errore» e «non giudicabile» per «fermato dal limite di spesa», come in 27-classi.csv
CL <- rbind(C1, C2); stopifnot(all(CL$costa %in% c("si", "no")), all(CL$costa_su_atlas %in% c("si", "no", "", "non giudicabile")),
                               all(CL$costa_su_atlas[CL$classe == "lettura del modello"] %in% c("si", "no")))
L <- do.call(rbind, lapply(names(RUN), function(k) { r <- RUN[[k]]; t <- r$M$tab; stopifnot(identical(t$studio, gse))
  data.frame(corsa = k, studio = t$studio, scheda = r$kk$scheda, chiuso = t$chiuso, stato = t$stato, n_unita = t$n_unita,
             stop = r$inf$stop_reason, stringsAsFactors = FALSE) }))
i <- match(L$scheda, CL$scheda)
L$classe <- CL$classe[i]; L$costa <- CL$costa[i]; L$costa_su_atlas <- CL$costa_su_atlas[i]; L$letta_in <- CL$letta_in[i]
# ogni riga con un disaccordo e ogni riga di GSE147507 ha una classe; lo studio della classe e' quello della riga
da_leggere <- L$n_unita > 0 | L$studio == "GSE147507"
stopifnot(!anyNA(L$classe[da_leggere]), all(CL$scheda %in% L$scheda), identical(L$studio[!is.na(i)], CL$studio[i[!is.na(i)]]))
# una riga senza disaccordo e fuori da GSE147507 puo' avere una classe solo se la sua scheda e' uguale a una letta
L$classe[is.na(L$classe)] <- "senza disaccordo"
L$forma <- substr(L$corsa, 1L, 1L); L$modello <- sub("^[TV]-([a-z]+)-corsa.*$", "\\1", L$corsa); L$n_corsa <- sub("^.*-corsa", "", L$corsa)
ord <- c("haiku", "sonnet", "opus", "fable")
utils::write.csv(L[L$classe != "senza disaccordo", c("corsa", "forma", "modello", "n_corsa", "studio", "scheda", "chiuso", "stato", "n_unita", "classe", "costa", "costa_su_atlas", "letta_in")],
                 file.path(S6, "29-classi-per-corsa.csv"), row.names = FALSE, fileEncoding = "UTF-8")
MIS <- rbind(utils::read.csv(file.path(S6, "24-corse.csv"), stringsAsFactors = FALSE),
             transform(utils::read.csv(file.path(S6, "24b-corse.csv"), stringsAsFactors = FALSE), corsa = sub("corsa1$", "corsa1b", corsa))[0, ])
M1b <- utils::read.csv(file.path(S6, "24b-corse.csv"), stringsAsFactors = FALSE); M1b <- M1b[M1b$corsa == "V-fable-corsa1", ]; M1b$corsa <- "V-fable-corsa1b"
MIS <- rbind(MIS, M1b); stopifnot(setequal(MIS$corsa, names(RUN)))
ins <- function(d, f) sort(unique(d$studio[f]))
studi <- function(k) { d <- L[L$corsa == k, ]; lm <- d$classe == "lettura del modello"
  list(largo = ins(d, lm & d$costa == "si"), stretto = ins(d, lm & d$costa == "si" & d$costa_su_atlas == "si"),
       senza_costo = setdiff(ins(d, lm & d$costa == "no"), ins(d, lm & d$costa == "si")),
       forma = ins(d, d$classe == "forma"), rifiuto = ins(d, d$classe == "rifiuto"), fermato = ins(d, d$classe == "fermato dal limite di spesa")) }
S <- lapply(stats::setNames(names(RUN), names(RUN)), studi)
inc <- function(x) paste(x, collapse = " ")
E <- do.call(rbind, lapply(names(RUN), function(k) { s <- S[[k]]; m <- MIS[MIS$corsa == k, ]
  data.frame(corsa = k, forma = substr(k, 1L, 1L), modello = sub("^[TV]-([a-z]+)-corsa.*$", "\\1", k), n_corsa = sub("^.*-corsa", "", k),
             chiusi = m$chiusi, identici = m$identici, ritrovati = m$ritrovati, den = m$den,
             lettura_largo = length(s$largo), lettura_stretto = length(s$stretto), lettura_senza_costo = length(s$senza_costo),
             forma_studi = length(s$forma), rifiuti = length(s$rifiuto), fermati = length(s$fermato),
             studi_largo = inc(s$largo), studi_stretto = inc(s$stretto), studi_senza_costo = inc(s$senza_costo),
             studi_forma = inc(s$forma), studi_rifiuto = inc(s$rifiuto), stringsAsFactors = FALSE) }))
E <- E[order(E$forma, match(E$modello, ord), E$n_corsa), ]
utils::write.csv(E, file.path(S6, "29-errori-per-corsa.csv"), row.names = FALSE, fileEncoding = "UTF-8")
# due corse per modello e forma: per V-fable la corsa 1 e' il file completato (1b), perche' la corsa 1 ha 3 studi
# fermati dal limite di spesa; la riga con la corsa 1 depositata sta accanto
coppie <- do.call(rbind, lapply(c("T", "V"), function(f) do.call(rbind, lapply(ord, function(m) {
  a <- sprintf("%s-%s-corsa1", f, m); b <- sprintf("%s-%s-corsa2", f, m)
  r <- data.frame(forma = f, modello = m, corsa_a = a, corsa_b = b, stringsAsFactors = FALSE)
  if (f == "V" && m == "fable") r <- rbind(transform(r, corsa_a = "V-fable-corsa1b"), r)
  r }))))
D <- do.call(rbind, lapply(seq_len(nrow(coppie)), function(j) { a <- S[[coppie$corsa_a[j]]]; b <- S[[coppie$corsa_b[j]]]
  ea <- E[E$corsa == coppie$corsa_a[j], ]; eb <- E[E$corsa == coppie$corsa_b[j], ]
  data.frame(coppie[j, ], largo_a = length(a$largo), largo_b = length(b$largo), largo_media = (length(a$largo) + length(b$largo)) / 2,
             largo_almeno_una = length(union(a$largo, b$largo)), largo_tutte_e_due = length(intersect(a$largo, b$largo)),
             stretto_a = length(a$stretto), stretto_b = length(b$stretto), stretto_media = (length(a$stretto) + length(b$stretto)) / 2,
             stretto_almeno_una = length(union(a$stretto, b$stretto)), stretto_tutte_e_due = length(intersect(a$stretto, b$stretto)),
             non_chiusi_a = 47L - ea$chiusi, non_chiusi_b = 47L - eb$chiusi, rifiuti_a = ea$rifiuti, rifiuti_b = eb$rifiuti,
             ritrovati_a = ea$ritrovati, ritrovati_b = eb$ritrovati,
             studi_largo_tutte_e_due = inc(intersect(a$largo, b$largo)), studi_largo_una_sola = inc(setdiff(union(a$largo, b$largo), intersect(a$largo, b$largo))),
             studi_stretto_tutte_e_due = inc(intersect(a$stretto, b$stretto)), studi_stretto_una_sola = inc(setdiff(union(a$stretto, b$stretto), intersect(a$stretto, b$stretto))),
             stringsAsFactors = FALSE) }))
utils::write.csv(D, file.path(S6, "29-due-corse.csv"), row.names = FALSE, fileEncoding = "UTF-8")
sink(file.path(S6, "29-out.txt"), split = TRUE)
cat(sprintf("schede lette %d (corse 1: %d con revisione; nuove: %d senza revisione) in %d studi; righe studio x corsa con una classe %d su %d\n",
            nrow(CL), nrow(C1), nrow(C2), length(unique(CL$studio)), sum(L$classe != "senza disaccordo"), nrow(L)))
cat("\n== schede nuove per classe e costo (unita': scheda)\n"); print(table(C2$classe, paste("costa", C2$costa)))
cat("\n== per corsa: chiusi, gruppi identici ad Atlas, confronti ritrovati su 95; studi con un errore di lettura del modello\n")
print(E[, c("corsa", "chiusi", "identici", "ritrovati", "lettura_largo", "lettura_stretto", "lettura_senza_costo", "forma_studi", "rifiuti", "fermati")], row.names = FALSE)
cat("\n== studi con un errore di lettura che costa (largo), per corsa\n"); for (k in E$corsa) cat(sprintf("%-16s %s\n", k, E$studi_largo[E$corsa == k]))
cat("\n== studi con un errore di lettura che cambia la misura contro Atlas (stretto), per corsa\n"); for (k in E$corsa) cat(sprintf("%-16s %s\n", k, E$studi_stretto[E$corsa == k]))
cat("\n== studi con un errore di forma, per corsa\n"); for (k in E$corsa) cat(sprintf("%-16s %s\n", k, E$studi_forma[E$corsa == k]))
cat("\n== due corse per modello e forma\n")
print(D[, c("corsa_a", "corsa_b", "largo_a", "largo_b", "largo_almeno_una", "largo_tutte_e_due", "stretto_a", "stretto_b", "stretto_almeno_una", "stretto_tutte_e_due",
            "non_chiusi_a", "non_chiusi_b", "rifiuti_a", "rifiuti_b", "ritrovati_a", "ritrovati_b")], row.names = FALSE)
cat("\n== per studio: in quante delle 17 corse c'e' un errore di lettura che costa (largo)\n")
tb <- sort(table(unlist(lapply(S, `[[`, "largo"))), decreasing = TRUE); print(tb)
cat(sprintf("\nstudi con un errore di lettura che costa in almeno una corsa: %d su 47; in tutte le 17 corse: %d\n", length(tb), sum(tb == 17L)))
cat(sprintf("corse senza nessun errore di lettura che costa: %d su 17\n", sum(E$lettura_largo == 0L)))
sink()
