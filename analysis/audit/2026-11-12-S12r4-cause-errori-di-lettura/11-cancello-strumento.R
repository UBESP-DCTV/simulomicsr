# PROVA DA BUTTARE
# 11-cancello-strumento.R — S12r4, PRIMA di ogni corsa: lo strumento di misura unico (adatta_forma di 10-forme.R)
# rida' i numeri congelati delle due prove sulle uscite congelate, e i predicati vedono i 4 errori di lettura.
# Non legge uscite nuove: solo `analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl` e
# `analysis/p4-output/S12r3-lettore-v2/M-corsa1.jsonl`, e solo i 47 studi di sviluppo.
#
#   Rscript analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/11-cancello-strumento.R \
#     > analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/11-out.txt 2>&1          (SENZA --vanilla)
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/aiuti-misura-r4.R")
adatta_v1_r2 <- adatta_v1
source(file.path(R3, "22-adattatore-v2.R"))                   # adatta_v2 di S12r3, per il confronto studio per studio
passa <- function(che, ok, dett = "") { cat(sprintf("%s  %s%s\n", if (ok) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else "")); if (!ok) ESITO <<- FALSE }
ESITO <- TRUE

# ---- 1. gli schemi delle forme sui 47 studi -------------------------------------------------------------------
t0 <- Sys.time()
passa("schema di B0 = schema_studio() di S12r3, 47 studi", all(vapply(sv$gse, function(g) identical(schema_forma(viste[[g]], "B0"), schema_studio(viste[[g]])), NA)))
passa("schema di B0 scritto = schema scritto in S12r3 (JSON al carattere), 47 studi", all(vapply(sv$gse, function(g) identical(schema_json_forma(viste[[g]], "B0"), schema_json(viste[[g]])), NA)))
passa("schema di A0 = 20-schema-v1.json, 47 studi", all(vapply(sv$gse, function(g) identical(schema_forma(viste[[g]], "A0"), S1), NA)))
passa("il ponte: A0A2A3A4R e RA1PP5C hanno lo stesso schema senza descrizioni, titolo e $id, 47 studi",
      all(vapply(sv$gse, function(g) identical(spoglia(schema_forma(viste[[g]], "A0A2A3A4R")), spoglia(schema_forma(viste[[g]], "RA1PP5C"))), NA)))
passa("RC3: il blocco `factors` dello schema e' quello di B0, 47 studi",
      all(vapply(sv$gse, function(g) identical(schema_forma(viste[[g]], "RC3")$properties$factors, schema_forma(viste[[g]], "B0")$properties$factors), NA)))
grandezza <- do.call(rbind, lapply(names(FORME), function(n) {
  car <- vapply(sv$gse, function(g) nchar(schema_json_forma(viste[[g]], n), "chars"), 0L)
  comp <- vapply(sv$gse, function(g) !inherits(try(validatore_forma(viste[[g]], n), silent = TRUE), "try-error"), NA)
  data.frame(forma = n, lato = FORME[[n]]$lato, cambi = paste(FORME[[n]]$cambi, collapse = "+"), schema_car_mediana = as.integer(stats::median(car)),
             schema_car_max = max(car), studio_max = sv$gse[which.max(car)], compila_ajv = sum(comp), stringsAsFactors = FALSE)
}))
scrivi_r4(grandezza, "11-grandezza-schemi.csv")
print(grandezza, row.names = FALSE)
passa("ogni schema di ogni forma compila (ajv), 47 studi", all(grandezza$compila_ajv == 47L))
cat(sprintf("tempo degli schemi: %.0f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# ---- 2. S12r2 (schema v1): lo strumento con la forma A0 rida' 15-per-studio-v1.csv ----------------------------
stessa_tabella <- function(mio, f_congelato) {
  tmp <- tempfile(fileext = ".csv"); utils::write.csv(impila(mio), tmp, row.names = FALSE, na = "")
  a <- utils::read.csv(tmp, stringsAsFactors = FALSE); b <- utils::read.csv(f_congelato, stringsAsFactors = FALSE)
  com <- intersect(names(b), names(a))
  cat(sprintf("  colonne confrontate: %d; solo nel file congelato: %s; solo nello strumento: %s\n", length(com),
              paste(setdiff(names(b), names(a)), collapse = " "), paste(setdiff(names(a), names(b)), collapse = " ")))
  stopifnot(length(com) >= 39L, nrow(a) == 188L, nrow(b) == 188L)
  a <- a[order(a$misura_r3, a$studio), com]; b <- b[order(b$misura_r3, b$studio), com]; rownames(a) <- rownames(b) <- NULL
  isTRUE(all.equal(a, b))
}
r2 <- leggi_uscite("analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl")
mA <- misura_forma(r2, "A0")
nA <- tre_numeri(mA$tab); print(nA)
passa("S12r2 corsa 1, forma A0: 34 chiusi, 31 identiche, 50/95 e 50/97", identical(unname(nA[1:6]), c(34L, 31L, 50L, 95L, 50L, 97L)))
passa("S12r2 corsa 1, forma A0: tabella per studio uguale a 15-per-studio-v1.csv (4 misure x 47 studi)", stessa_tabella(mA$per_studio, file.path(R3, "15-per-studio-v1.csv")))
TREDICI <- c("GSE147507", "GSE46665", "GSE56787", "GSE57116", "GSE57945", "GSE59781", "GSE60340", "GSE63816",
             "GSE66207", "GSE69597", "GSE71595", "GSE83415", "GSE83687")
passa("S12r2 corsa 1, forma A0: i 13 non chiusi sono quelli di S12r2", setequal(mA$tab$studio[!mA$tab$chiuso], TREDICI))

# ---- 3. S12r3 (schema generato): lo strumento con la forma B0 rida' 24-M-per-studio.csv e adatta_v2 -----------
r3 <- leggi_uscite("analysis/p4-output/S12r3-lettore-v2/M-corsa1.jsonl")
mB <- misura_forma(r3, "B0")
nB <- tre_numeri(mB$tab); print(nB)
passa("S12r3 corsa 1, forma B0: 45 chiusi, 36 identiche, 68/95", identical(unname(nB[1:4]), c(45L, 36L, 68L, 95L)))
passa("S12r3 corsa 1, forma B0: tabella per studio uguale a 24-M-per-studio.csv (4 misure x 47 studi)", stessa_tabella(mB$per_studio, file.path(R3, "24-M-per-studio.csv")))
passa("S12r3 corsa 1, forma B0: i 2 non chiusi sono GSE50499 e GSE63816", setequal(mB$tab$studio[!mB$tab$chiuso], c("GSE50499", "GSE63816")))
chiave_conf <- function(k) if (is.null(k) || !nrow(k)) character(0) else sort(sprintf("%s|%s|%s|%s|%s", k$fattore, k$livello_trattato, k$livello_base,
  vapply(k$trattato, function(x) paste(sort(x), collapse = ","), ""), vapply(k$controllo, function(x) paste(sort(x), collapse = ","), "")))
uguale_v2 <- vapply(sv$gse, function(g) {
  a <- mB$lett[[g]]; b <- adatta_v2(viste[[g]], as.character(nullo(r3[[g]]$raw)), e_saltato(r3[[g]]), as.character(nullo(r3[[g]]$fine)))
  nb <- unique(sub(":.*$", "", sub("^(tf_tabella):.*$", "\\1", b$motivi)))
  identical(a$chiuso, b$chiuso) && setequal(nomi_motivi(a), nb) &&
    (!a$chiuso || (identical(a$partizione, b$partizione) && identical(a$n_gruppi, b$n_gruppi) && identical(chiave_conf(a$confronti), chiave_conf(b$confronti)) &&
                     identical(a$n_soggetti, b$n_soggetti)))
}, NA)
passa("S12r3 corsa 1: traduttore + adatta_v1 = adatta_v2 (chiuso, motivi, gruppi, confronti, soggetti), 47 studi", all(uguale_v2), paste(sv$gse[!uguale_v2], collapse = " "))

# ---- 4. il controllo positivo dei predicati: i 4 errori di lettura di S12r3 -----------------------------------
pr <- data.frame(studio = QUATTRO, in_B0 = mB$tab$errore_di_lettura[match(QUATTRO, mB$tab$studio)],
                 in_A0 = mA$tab$errore_di_lettura[match(QUATTRO, mA$tab$studio)], stringsAsFactors = FALSE)
print(pr, row.names = FALSE)
passa("i predicati vedono i 4 errori di lettura nelle uscite di S12r3 (B0)", all(pr$in_B0 %in% TRUE))
passa("nelle uscite di S12r2 (A0) i predicati vedono solo GSE46665 (finding S12r3: gli altri 3 non c'erano)",
      identical(pr$studio[pr$in_A0 %in% TRUE], "GSE46665") && !anyNA(pr$in_A0))

# ---- 4b. le unita' di disaccordo di S12r3: le 40 unita' e, fra quelle, le 13 di lettura del modello -------------
d3 <- utils::read.csv(file.path(R3, "26-disaccordi-M-righe.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
d3$id[is.na(d3$id)] <- ""
ch <- function(d) sort(paste(d$tipo, d$studio, d$id))
passa("S12r3 corsa 1, forma B0: le unita' di disaccordo sono le 40 di 26-disaccordi-M-righe.csv (tipo, studio, id)",
      nrow(mB$unita) == 40L && identical(ch(mB$unita), ch(d3)), sprintf("%d unita'", nrow(mB$unita)))
m13 <- d3[d3$causa == "modello", ]
passa("le 13 unita' di lettura del modello di S12r3 stanno nei 4 studi dei predicati (7, 1, 2, 3)",
      nrow(m13) == 13L && identical(as.integer(table(factor(m13$studio, levels = QUATTRO))), c(7L, 1L, 2L, 3L)) &&
        all(paste(m13$tipo, m13$studio, m13$id) %in% paste(mB$unita$tipo, mB$unita$studio, mB$unita$id)))
fuori13 <- d3[d3$causa != "modello" & d3$lettura_modello %in% TRUE, ]
cat(sprintf("unita' con una lettura del modello fuori dalle 13: %d (%s)\n", nrow(fuori13),
            paste(sprintf("%s %d", names(table(fuori13$studio)), as.integer(table(fuori13$studio))), collapse = ", ")))
scrivi_r4(rbind(mA$unita, mB$unita), "11-unita-A0-B0.csv")

# ---- 4c. il conto generico dei soggetti costanti nei gruppi: controllo positivo sulle 5 unita' di S12r3 ----------
sc <- function(m) m$tab[!is.na(m$tab$soggetto_costante_nei_gruppi) & nzchar(m$tab$soggetto_costante_nei_gruppi), c("forma", "studio", "soggetto_costante_nei_gruppi")]
print(rbind(sc(mA), sc(mB)), row.names = FALSE)
passa("il conto dei soggetti costanti nei gruppi vede `source_name_ch1` in GSE50760 e GSE71595 nelle uscite di S12r3 (B0)",
      all(c("GSE50760", "GSE71595") %in% sc(mB)$studio) && all(sc(mB)$soggetto_costante_nei_gruppi[sc(mB)$studio %in% c("GSE50760", "GSE71595")] == "source_name_ch1"))

# ---- 5. le firme: in quanti studi la tabella dei fattori di S12r2 e quella di S12r3 sono diverse --------------
d <- merge(mA$tab[c("studio", "valida", "stato", "n_b_uguale", "firma", "fonti")], mB$tab[c("studio", "valida", "stato", "n_b_uguale", "firma", "fonti")],
           by = "studio", suffixes = c("_A0", "_B0"))
d$firma_uguale <- d$firma_A0 == d$firma_B0
scrivi_r4(d, "11-firme-A0-B0.csv")
cat(sprintf("firma della tabella dei fattori: uguale fra S12r2 e S12r3 in %d studi su %d con le due uscite valide; diversa in %d; non valutabile in %d\n",
            sum(d$firma_uguale, na.rm = TRUE), sum(!is.na(d$firma_uguale)), sum(!d$firma_uguale, na.rm = TRUE), sum(is.na(d$firma_uguale))))
print(table(S12r2 = d$stato_A0, S12r3 = d$stato_B0))
scrivi_r4(rbind(mA$tab, mB$tab), "11-per-studio-A0-B0.csv")
cat(if (ESITO) "\nCANCELLO DELLO STRUMENTO: PASSA\n" else "\nCANCELLO DELLO STRUMENTO: FALLISCE\n")
if (!ESITO) quit(status = 1L)
