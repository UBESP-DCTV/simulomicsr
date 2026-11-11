# PROVA DA BUTTARE
# 27-sensibilita.R — S12r3: SENSIBILITA' DICHIARATA DOPO I NUMERI. Non e' la misura della prova e non cambia
# l'esito di nessuna previsione ne' della regola di esito: la misura resta quella di 24-misura.R (adattatore
# senza tolleranze di forma, committato prima del primo invio).
#
# La lettura dei disaccordi (25-materiale-M.txt) ha trovato due studi non chiusi per la forma dei NOMI dei
# livelli, che lo schema JSON a elenco chiuso non lega:
#   T1  un livello riservato scritto in un'altra forma (`not_applicable` per «not applicable»): GSE63816;
#   T2  un livello scritto in una voce (e come base) ma non nell'elenco `levels` del fattore: GSE50499.
# Qui si misura che cosa succede se l'adattatore tollera le due forme, per sapere che cosa RESTA tolta la
# prima causa (colonna `resto` di 26-cause-M.txt) e quanto vale il rimedio nominato. Le tolleranze sono scritte
# DOPO aver letto le uscite: il numero che esce e' ottimista per costruzione (rischio di adattamento ai 47 studi).
#   T1: nelle voci, un livello non dichiarato che, in minuscolo e con «_» e «-» letti come spazio, e' uguale
#       a «not applicable» o «not stated» diventa il nome riservato;
#   T2: un livello scritto in una voce e non dichiarato entra nell'elenco `levels` del fattore, senza descrizione.
# Uso (SENZA --vanilla): Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/27-sensibilita.R > .../27-out.txt 2>&1
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-11-S12r3-elenco-chiuso/aiuti-misura-r3.R")
source(file.path(R3, "22-adattatore-v2.R"))
nullo <- function(x) if (is.null(x)) NA else x
sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv); viste <- leggi_viste(sv)
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)
f1 <- "analysis/p4-output/S12r3-lettore-v2/M-corsa1.jsonl"
imp <- readLines(file.path(R3, "23-uscite-sha256.txt"))
stopifnot(any(imp == paste0(unname(digest::digest(file = f1, algo = "sha256")), "  ", f1)))
cx <- leggi_jsonl(f1); names(cx) <- vapply(cx, `[[`, "", "record_id"); cx <- cx[sv$gse]

norma <- function(x) trimws(gsub("[_-]+", " ", tolower(x)))
tollera <- function(raw) {
  cambi <- character(0)
  if (is.na(raw) || !nzchar(raw)) return(list(raw = raw, cambi = cambi))
  u <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(u)) return(list(raw = raw, cambi = cambi))
  for (i in seq_along(u$factors)) {
    f <- u$factors[[i]]; liv <- vapply(f$levels, function(l) l$level, "")
    for (j in seq_along(f$assignment$values)) {
      l <- f$assignment$values[[j]]$level
      if (l %in% c(liv, NON_STATED_V2, NON_APPLICABLE_V2)) next
      if (norma(l) %in% c(NON_STATED_V2, NON_APPLICABLE_V2)) {
        u$factors[[i]]$assignment$values[[j]]$level <- norma(l); cambi <- c(cambi, sprintf("T1 %s: %s", f$name, l))
      } else {
        u$factors[[i]]$levels[[length(u$factors[[i]]$levels) + 1L]] <- list(level = l, text_as_written = "", entity = "", dose = "", duration = "")
        liv <- c(liv, l); cambi <- c(cambi, sprintf("T2 %s: %s", f$name, l))
      }
    }
  }
  list(raw = if (length(cambi)) as.character(jsonlite::toJSON(u, auto_unbox = TRUE)) else raw, cambi = unique(cambi))
}
tl <- lapply(cx, function(x) tollera(as.character(nullo(x$raw))))
toccati <- names(tl)[lengths(lapply(tl, `[[`, "cambi")) > 0L]
cat("uscite toccate dalle due tolleranze:", length(toccati), "su 47\n")
for (g in toccati) cat(sprintf("  %s: %s\n", g, paste(tl[[g]]$cambi, collapse = " | ")))
e_saltato <- function(x) { s <- x$saltato; !is.null(s) && !is.na(s) && nzchar(as.character(s)) }
adatta <- function(g, raw) adatta_v2(viste[[g]], raw, e_saltato(cx[[g]]), as.character(nullo(cx[[g]]$fine)))
lett0 <- stats::setNames(lapply(sv$gse, function(g) adatta(g, as.character(nullo(cx[[g]]$raw)))), sv$gse)
lett <- stats::setNames(lapply(sv$gse, function(g) adatta(g, tl[[g]]$raw)), sv$gse)
ch0 <- vapply(lett0, `[[`, TRUE, "chiuso"); ch <- vapply(lett, `[[`, TRUE, "chiuso")
cat(sprintf("studi chiusi: misura %d su 47; con le tolleranze %d su 47\n", sum(ch0), sum(ch)))
for (g in names(ch)[!ch]) cat("  resta non chiuso", g, ":", paste(lett[[g]]$motivi, collapse = " || "), "\n")
mis <- function(L) {
  mm <- lapply(sv$gse, function(g) {
    r <- L[[g]]; x <- rif[[g]]
    t <- if (r$chiuso) misura_r3(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
      misura_r3(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
    for (m in NOMI_R3) { if (!r$chiuso) t[[m]]$riga$classe_gruppi <- "non_chiuso"; t[[m]]$riga$chiuso <- r$chiuso }
    t
  }); names(mm) <- sv$gse; mm
}
m0 <- mis(lett0); m1 <- mis(lett)
per <- function(mm, m) do.call(rbind, lapply(mm, function(x) x[[m]]$riga))
for (m in NOMI_R3) {
  p0 <- per(m0, m); p1 <- per(m1, m)
  # controllo positivo: senza tolleranze la sensibilita' rida' la misura di 24-misura.R
  rifm <- utils::read.csv(file.path(R3, "24-M-per-studio.csv"), stringsAsFactors = FALSE); rifm <- rifm[rifm$misura_r3 == m, ]
  stopifnot(identical(p0$classe_gruppi, rifm$classe_gruppi), identical(as.integer(p0$n_b_uguale), as.integer(rifm$n_b_uguale)),
            identical(as.integer(p0$n_errori), as.integer(rifm$n_errori)))
  r0 <- tf_riassumi_misure(p0, B = B, seme = SEME); r1 <- tf_riassumi_misure(p1, B = B, seme = SEME)
  cat(sprintf("\n-- misura %s --  (controllo positivo: senza tolleranze ridà 24-M-per-studio.csv)\n", m))
  cat("misura della prova:\n"); print(r0[1:3, ], row.names = FALSE, digits = 4)
  cat("con le due tolleranze (sensibilita' dichiarata dopo i numeri):\n"); print(r1[1:3, ], row.names = FALSE, digits = 4)
}
p1 <- per(m1, "principale")
cat("\nstudi toccati, misura principale con le tolleranze:\n")
print(p1[p1$studio %in% toccati, c("studio", "chiuso", "classe_gruppi", "n_b_uguale", "n_b_den", "n_giudicabili", "n_errori")], row.names = FALSE)
for (g in toccati) {
  r <- lett[[g]]; if (!r$chiuso) next
  cat(sprintf("\n=== %s: gruppi del lettore × gruppi di Atlas nell'universo ===\n", g))
  u <- rif[[g]]$universo; pa <- rif[[g]]$atlas$partizione
  print(table(lettore = r$partizione[u], atlas = pa[u]))
  gr <- tf_gruppi(r$tabella); print(gr[, setdiff(names(gr), "campioni")], row.names = FALSE)
  k <- r$confronti
  if (nrow(k)) print(data.frame(id = k$id, fattore = k$fattore, trattato = k$livello_trattato, base = k$livello_base,
                                n_t = lengths(k$trattato), n_c = lengths(k$controllo), esito = k$esito), row.names = FALSE)
  cat("registro coppie:\n"); print(table(r$registro$motivo))
  a <- m1[[g]]$principale$atlas; print(data.frame(id = a$id, nome = a$nome, in_b = a$in_b, ritrovato = a$ritrovato), row.names = FALSE)
  ne <- m1[[g]]$principale$non_elencati; if (nrow(ne)) print(data.frame(id = ne$id, giudizio = ne$giudizio), row.names = FALSE)
}
