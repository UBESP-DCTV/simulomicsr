#!/usr/bin/env Rscript
# 40-analisi.R — S9: cancelli 2-3, previsioni P1-P4, tabelle di fusioni e rotture.
#
# Legge 30-due-regimi.rds (le chiavi di tutti gli 86.745 confronti, OFF e ON) e lo
# confronta con lo Stadio 3 del deliverable e con il deliverable stesso. Scrive
# 40-out.txt e i CSV con TUTTE le righe che cambiano: niente campioni.
#
# Uso: Rscript analysis/audit/2026-11-07-S9-greche-e-corsie/40-analisi.R
suppressPackageStartupMessages({ library(cli); library(arrow) })
OUT <- "analysis/audit/2026-11-07-S9-greche-e-corsie"
S3  <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
log_ <- character(0)
say <- function(...) { s <- sprintf(...); log_ <<- c(log_, s); cat(s, "\n") }

r   <- readRDS(file.path(OUT, "30-due-regimi.rds"))
ing <- readRDS(file.path(OUT, "20-ingressi.rds"))
stopifnot(identical(r$record_id, ing$record_id))
asg <- read_parquet(file.path(S3, "assignments.parquet"))
asg <- as.data.frame(asg[asg$mode == "cgroup", ])
nc  <- readRDS(file.path(S3, "non_clusterable.rds"))
nc  <- as.data.frame(nc[nc$mode == "cgroup", ])
d   <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
psd <- as.data.frame(read_parquet(file.path(DEL, "per_study_de.parquet"),
                                  col_select = c("cluster_id", "study_id")))
psd <- unique(psd)
q40 <- read.csv("analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv",
                stringsAsFactors = FALSE)
stopifnot(nrow(d) == 194L, nrow(q40) == 40L, all(q40$cluster_id %in% d$cluster_id))

key <- function(e, dr, ck) paste(e, dr, ck, sep = "||")
r$tenuto_off <- r$scarto_off == ""
r$tenuto_on  <- r$scarto_on  == ""
r$key_off <- ifelse(r$tenuto_off, key(r$entity_off, r$direction_off, r$control_key_off), NA)
r$key_on  <- ifelse(r$tenuto_on,  key(r$entity_on,  r$direction_on,  r$control_key_on),  NA)
# stato = dove finisce il confronto nello Stadio 3: un gruppo (la chiave) o fuori
stato <- function(tenuto, k, scarto) ifelse(tenuto & r$eleggibile, k,
                                     ifelse(tenuto, "FUORI:tier_s_incompleto", paste0("FUORI:", scarto)))
r$stato_off <- stato(r$tenuto_off, r$key_off, r$scarto_off)
r$stato_on  <- stato(r$tenuto_on,  r$key_on,  r$scarto_on)
in_gruppo <- function(s) !startsWith(s, "FUORI:")

# ------------------------------------------------------------------ cancello 2 --
say("== CANCELLO 2: il regime OFF riproduce lo Stadio 3 ==")
say("record cgroup costruiti (tenuti dal contrasto): %d (atteso 53.915)", sum(r$tenuto_off))
el <- r[r$tenuto_off & r$eleggibile, ]
say("eleggibili tenuti: %d; in assignments: %d", nrow(el), nrow(asg))
m <- match(asg$record_id, el$record_id)
say("record di assignments ritrovati: %d su %d", sum(!is.na(m)), nrow(asg))
ok_key <- !is.na(m) & el$key_off[m] == asg$anchor_key
say("chiave uguale ad anchor_key: %d su %d", sum(ok_key), nrow(asg))
ts <- nc[nc$reason == "tier_s_incomplete", ]
ne <- r[r$tenuto_off & !r$eleggibile, ]
say("non eleggibili: %d ricostruiti, %d in non_clusterable (tier_s_incomplete); insiemi uguali: %s",
    nrow(ne), nrow(ts), setequal(ne$record_id, ts$record_id))
cg <- nc[nc$reason == "contrast_gate", ]
sc <- r[!r$tenuto_off, ]
mm <- match(cg$record_id, sc$record_id)
say("scarti: %d ricostruiti, %d in non_clusterable (contrast_gate); ritrovati %d; ragione uguale %d",
    nrow(sc), nrow(cg), sum(!is.na(mm)), sum(!is.na(mm) & sc$scarto_off[mm] == cg$details))
altre <- setdiff(unique(nc$reason), c("tier_s_incomplete", "contrast_gate"))
say("altre ragioni cgroup in non_clusterable: %s", if (length(altre)) paste(altre, collapse = ", ") else "nessuna")
c2 <- sum(r$tenuto_off) == 53915L && nrow(el) == nrow(asg) && all(ok_key) &&
      setequal(ne$record_id, ts$record_id) && nrow(sc) == nrow(cg) &&
      all(!is.na(mm)) && all(sc$scarto_off[mm] == cg$details) && !length(altre)
say("CANCELLO 2: %s", if (c2) "PASSATO" else "FALLITO")

# ------------------------------------------------------------------ cancello 3 --
say("")
say("== CANCELLO 3: copertura e controllo negativo ==")
campi <- c("entity", "direction", "control_key", "classe", "fonte", "scarto")
uguale <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
tutto_uguale <- Reduce(`&`, lapply(campi, function(f) uguale(r[[paste0(f, "_off")]], r[[paste0(f, "_on")]])))
say("confronti calcolati in entrambi i regimi: %d su %d (scarto NA: OFF %d, ON %d)",
    sum(!is.na(r$scarto_off) & !is.na(r$scarto_on)), nrow(r), sum(is.na(r$scarto_off)), sum(is.na(r$scarto_on)))
say("confronti senza caratteri di G: %d; con esito ON uguale a OFF in tutti i campi: %d",
    sum(!r$G_in), sum(!r$G_in & tutto_uguale))
c3 <- !anyNA(r$scarto_off) && !anyNA(r$scarto_on) && all(tutto_uguale[!r$G_in])
say("CANCELLO 3: %s", if (c3) "PASSATO" else "FALLITO")

# ---------------------------------------------------------------- P1 e conteggi --
say("")
say("== P1 e punto 2: i confronti con caratteri di G ==")
set.seed(20261107)
per_st <- tapply(r$G_in, r$study, function(x) c(sum(x), length(x)))
gS <- vapply(per_st, `[`, 0, 1); nS <- vapply(per_st, `[`, 0, 2)
bt <- replicate(2000L, { i <- sample.int(length(nS), replace = TRUE); sum(gS[i]) / sum(nS[i]) })
p1 <- sum(r$G_in) / nrow(r); ic1 <- stats::quantile(bt, c(0.025, 0.975))
say("P1: %d confronti su %d con almeno un carattere di G = %.3f%% [%.3f; %.3f] (B = 2000, seme 20261107, %d studi)",
    sum(r$G_in), nrow(r), 100 * p1, 100 * ic1[1], 100 * ic1[2], length(nS))
say("per categoria (tutti i confronti con G):")
log_ <- c(log_, capture.output(print(table(r$cat_G[r$G_in]))))
say("studi con almeno un confronto con G: %d", sum(gS > 0))
say("confronti con G che OFF mette in un gruppo: %d; per categoria:", sum(r$G_in & in_gruppo(r$stato_off)))
log_ <- c(log_, capture.output(print(table(r$cat_G[r$G_in & in_gruppo(r$stato_off)]))))
cl_of_key <- unique(asg[, c("cluster_id", "anchor_key")])
gG <- r[r$G_in & in_gruppo(r$stato_off), ]
gG$cluster_id <- cl_of_key$cluster_id[match(gG$stato_off, cl_of_key$anchor_key)]
gG$nel_deliverable <- gG$cluster_id %in% d$cluster_id
say("di questi, in gruppi che sono meta-analisi del deliverable: %d confronti in %d meta-analisi",
    sum(gG$nel_deliverable), length(unique(gG$cluster_id[gG$nel_deliverable])))
tabG <- as.data.frame(table(cluster_id = gG$cluster_id[gG$nel_deliverable],
                            cat_G = gG$cat_G[gG$nel_deliverable]), stringsAsFactors = FALSE)
tabG <- tabG[tabG$Freq > 0L, ]; names(tabG)[names(tabG) == "Freq"] <- "confronti"
tabG$entita <- d$contrast_entity_label[match(tabG$cluster_id, d$cluster_id)]
tabG$in40 <- tabG$cluster_id %in% q40$cluster_id
write.csv(tabG[order(-tabG$confronti), ], file.path(OUT, "40-G-nelle-194.csv"), row.names = FALSE)

# ------------------------------------------------------------- che cosa cambia --
say("")
say("== Che cosa cambia con la traduzione ==")
cambia <- r$stato_off != r$stato_on
say("confronti il cui stato nello Stadio 3 cambia: %d (tutti con G: %s)", sum(cambia), all(r$G_in[cambia]))
tipo <- ifelse(!cambia, "uguale",
        ifelse(in_gruppo(r$stato_off) & in_gruppo(r$stato_on), "cambia gruppo",
        ifelse(in_gruppo(r$stato_off), "esce dal gruppo",
        ifelse(in_gruppo(r$stato_on), "entra in un gruppo", "cambia ragione di scarto"))))
log_ <- c(log_, capture.output(print(table(tipo[cambia], r$cat_G[cambia]))))
r$tipo <- tipo
ch <- r[cambia, ]
ch <- merge(ch, ing[, c("record_id", "tl", "cl", "tfl", "cfl", "anchor_name", "anchor_id")], by = "record_id")
ch$cluster_off <- cl_of_key$cluster_id[match(ch$stato_off, cl_of_key$anchor_key)]
ch$meta_off <- d$contrast_entity_label[match(ch$cluster_off, d$cluster_id)]
write.csv(ch[order(ch$tipo, ch$stato_off), c("record_id", "study", "tipo", "cat_G", "stato_off", "stato_on",
          "cluster_off", "meta_off", "fonte_off", "fonte_on", "tl", "cl", "tfl", "cfl", "anchor_name", "anchor_id")],
          file.path(OUT, "40-confronti-che-cambiano.csv"), row.names = FALSE)

# -------------------------------------------------- gruppi: fusioni e rotture --
gr <- r[in_gruppo(r$stato_off) | in_gruppo(r$stato_on), c("record_id", "study", "stato_off", "stato_on")]
chiavi_off <- unique(gr$stato_off[in_gruppo(gr$stato_off)])
chiavi_on  <- unique(gr$stato_on[in_gruppo(gr$stato_on)])
kk <- function(col) { x <- gr[in_gruppo(gr[[col]]), ]; tapply(x$study, x[[col]], function(s) length(unique(s))) }
k_off <- kk("stato_off"); k_on <- kk("stato_on")
toccate <- unique(c(ch$stato_off[in_gruppo(ch$stato_off)], ch$stato_on[in_gruppo(ch$stato_on)]))
# rottura: un gruppo OFF i cui confronti finiscono in >= 2 destinazioni ON (FUORI conta come destinazione)
rot <- vapply(intersect(toccate, chiavi_off), function(k) length(unique(r$stato_on[r$stato_off == k])), 0L)
# fusione: un gruppo ON i cui confronti vengono da >= 2 origini OFF (FUORI conta come origine)
fus <- vapply(intersect(toccate, chiavi_on), function(k) length(unique(r$stato_off[r$stato_on == k])), 0L)
say("")
say("== Gruppi dello Stadio 3 ==")
say("gruppi OFF: %d; gruppi ON: %d", length(chiavi_off), length(chiavi_on))
say("chiavi di gruppo toccate (OFF o ON): %d", length(toccate))
say("entita' OFF dei confronti che cambiano: %d distinte", length(unique(ch$entity_off[!is.na(ch$entity_off)])))
say("gruppi OFF che si spezzano (>= 2 destinazioni): %d", sum(rot >= 2L))
say("gruppi ON che nascono da una fusione (>= 2 origini): %d", sum(fus >= 2L))
nuovi <- chiavi_on[!(chiavi_on %in% chiavi_off)]
spariti <- chiavi_off[!(chiavi_off %in% chiavi_on)]
say("chiavi nuove in ON: %d; chiavi che spariscono: %d", length(nuovi), length(spariti))
gk <- data.frame(chiave = toccate,
                 k_off = as.integer(ifelse(toccate %in% names(k_off), k_off[toccate], 0L)),
                 k_on  = as.integer(ifelse(toccate %in% names(k_on),  k_on[toccate],  0L)),
                 stringsAsFactors = FALSE)
gk$origini_on <- ifelse(gk$chiave %in% names(fus), fus[gk$chiave], NA)
gk$destinazioni_off <- ifelse(gk$chiave %in% names(rot), rot[gk$chiave], NA)
gk$cluster_id <- cl_of_key$cluster_id[match(gk$chiave, cl_of_key$anchor_key)]
gk$meta_analisi <- d$contrast_entity_label[match(gk$cluster_id, d$cluster_id)]
gk$in40 <- gk$cluster_id %in% q40$cluster_id
write.csv(gk[order(-pmax(gk$k_off, gk$k_on)), ], file.path(OUT, "40-gruppi-toccati.csv"), row.names = FALSE)
p4 <- gk[gk$k_on >= 3L & gk$k_off < 3L, ]
say("P4: gruppi con almeno 3 studi in ON e meno di 3 in OFF: %d", nrow(p4))
for (i in seq_len(nrow(p4))) say("   %s  k %d -> %d", p4$chiave[i], p4$k_off[i], p4$k_on[i])
giu <- gk[gk$k_off >= 3L & gk$k_on < 3L, ]
say("gruppi con almeno 3 studi in OFF e meno di 3 in ON: %d", nrow(giu))
for (i in seq_len(nrow(giu))) say("   %s  k %d -> %d", giu$chiave[i], giu$k_off[i], giu$k_on[i])

# ------------------------------------------------------- le 194 e le 40: P2 e P3 --
say("")
say("== Le meta-analisi del deliverable ==")
del_key <- d$anchor_key
stopifnot(all(del_key %in% chiavi_off))
# controllo: gli studi del gruppo ricostruito = n_studies del deliverable
k_ric <- as.integer(k_off[del_key])
say("controllo: studi del gruppo ricostruito uguali a n_studies del deliverable: %d su 194",
    sum(k_ric == d$n_studies))
riga <- lapply(seq_len(nrow(d)), function(i) {
  k <- del_key[i]
  esce <- r[r$stato_off == k & r$stato_on != k, ]
  entra <- r[r$stato_on == k & r$stato_off != k, ]
  poolati <- psd$study_id[psd$cluster_id == d$cluster_id[i]]
  st_off <- unique(r$study[r$stato_off == k]); st_on <- unique(r$study[r$stato_on == k])
  data.frame(cluster_id = d$cluster_id[i], meta_analisi = d$contrast_entity_label[i],
             in40 = d$cluster_id[i] %in% q40$cluster_id,
             confronti_escono = nrow(esce), confronti_entrano = nrow(entra),
             studi_persi = length(setdiff(st_off, st_on)), studi_nuovi = length(setdiff(st_on, st_off)),
             studi_persi_poolati = length(intersect(setdiff(st_off, st_on), poolati)),
             k_off = length(st_off), k_on = length(st_on),
             dove_escono = paste(unique(esce$stato_on), collapse = " ; "),
             da_dove_entrano = paste(unique(entra$stato_off), collapse = " ; "),
             stringsAsFactors = FALSE)
})
mt <- do.call(rbind, riga)
mt$cambia <- mt$confronti_escono > 0L | mt$confronti_entrano > 0L
write.csv(mt[mt$cambia | mt$cluster_id %in% tabG$cluster_id, ], file.path(OUT, "40-meta-analisi.csv"), row.names = FALSE)
say("P2: meta-analisi delle 194 il cui gruppo cambia (entra o esce almeno un confronto): %d", sum(mt$cambia))
say("    con almeno uno studio in piu' o in meno: %d", sum(mt$studi_persi + mt$studi_nuovi > 0L))
say("P3: meta-analisi delle 40 il cui gruppo cambia: %d", sum(mt$cambia & mt$in40))
for (i in which(mt$cambia)) say("   %-40s in40=%-5s escono %d (studi persi %d, di cui poolati %d), entrano %d (studi nuovi %d), k %d -> %d",
    mt$meta_analisi[i], mt$in40[i], mt$confronti_escono[i], mt$studi_persi[i], mt$studi_persi_poolati[i],
    mt$confronti_entrano[i], mt$studi_nuovi[i], mt$k_off[i], mt$k_on[i])
estr <- grepl("estradiol", d$contrast_entity_label, ignore.case = TRUE)
say("17beta-estradiolo (rinvio dalla validazione esterna): %s",
    paste(sprintf("%s [%s] in40=%s cambia=%s", d$contrast_entity_label[estr], d$contrast_entity[estr],
                  d$cluster_id[estr] %in% q40$cluster_id, mt$cambia[estr]), collapse = "; "))

# ------------------------------------------------------ che cosa non si vede --
say("")
say("== Che cosa lo strumento non vede (anchor non ricalcolato) ==")
ing_g <- r$record_id %in% ing$record_id[!is.na(ing$anchor_name) & vapply(ing$anchor_name, function(s) grepl("[µßͰ-Ͽἀ-῿]", s, perl = TRUE), NA)]
cieco <- in_gruppo(r$stato_off) & (r$fatti_G | ing_g)
say("confronti in un gruppo il cui anchor o i cui fatti dello Stadio 1 hanno un carattere di G: %d", sum(cieco))
say("   di cui con l'entita' presa dall'anchor (fonte = anchor): %d", sum(cieco & r$fonte_off == "anchor"))
say("   di cui in meta-analisi del deliverable: %d in %d meta-analisi", sum(cieco & r$stato_off %in% del_key),
    length(unique(r$stato_off[cieco & r$stato_off %in% del_key])))
say("confronti eleggibili per il tier S su tutti: %d; non eleggibili con fatti con G: %d",
    sum(r$eleggibile), sum(!r$eleggibile & r$fatti_G))

writeLines(log_, file.path(OUT, "40-out.txt"))
cli_alert_success("Scritto 40-out.txt")
