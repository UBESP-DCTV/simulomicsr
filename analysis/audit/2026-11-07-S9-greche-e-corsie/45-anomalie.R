#!/usr/bin/env Rscript
# 45-anomalie.R — S9: le misure che spiegano i risultati di 40-analisi.R e le
# anomalie viste durante il lavoro. Ogni numero del finding fuori da 40-out.txt
# viene da qui (45-out.txt).
#
#  A. P1 scomposto: micro delle unita', nome dell'anchor, lettere greche vere.
#  B. I confronti che cambiano nelle 194, contro difetti.csv della rilettura di agosto.
#  C. TNF-alpha scritto in ASCII: oggi dove finisce (difetto della forma ASCII).
#  D. Interferon gamma scritto per esteso: il gruppo nuovo di P4.
#  E. La regola dell'entita' tenuta costante su un controllo che NEGA l'entita'.
#  F. Greche rovinate dalla codifica (UTF-8 letto come Latin-1): dove stanno.
#  G. IL1A: i membri del gruppo del deliverable.
#
# Uso: Rscript analysis/audit/2026-11-07-S9-greche-e-corsie/45-anomalie.R
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S9-greche-e-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
r   <- readRDS(file.path(OUT, "30-due-regimi.rds"))
ing <- readRDS(file.path(OUT, "20-ingressi.rds"))
stopifnot(identical(r$record_id, ing$record_id))
d   <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
dif <- read.csv("analysis/audit/2026-08-20-rilettura-194/difetti.csv", stringsAsFactors = FALSE)
onto <- simulomicsr:::.load_ontology_dicts()
L <- character(0); say <- function(...) { s <- sprintf(...); L <<- c(L, s); cat(s, "\n") }
key_off <- paste(r$entity_off, r$direction_off, r$control_key_off, sep = "||")
in_grp  <- r$eleggibile & r$scarto_off == ""
GX <- "[µßͰ-Ͽἀ-῿]"

say("== A. P1 scomposto (su %d confronti) ==", nrow(r))
s4 <- paste(ing$tl, ing$cl, ing$tfl, ing$cfl)
G4 <- grepl(GX, s4, perl = TRUE)
Ga <- !is.na(ing$anchor_name) & grepl(GX, ing$anchor_name, perl = TRUE)
gl <- grepl("[ßͰ-λν-Ͽἀ-῿]", s4, perl = TRUE)
say("G nelle quattro stringhe del confronto: %d", sum(G4))
say("   di cui lettere greche diverse da mu (o ss): %d = %.2f%%", sum(gl), 100 * mean(gl))
say("   di cui solo micro (mu o segno di micro): %d", sum(G4 & !gl))
say("G solo nel nome dell'anchor: %d", sum(Ga & !G4))

say("")
say("== B. I confronti che cambiano nelle 194, contro difetti.csv ==")
ch <- read.csv(file.path(OUT, "40-confronti-che-cambiano.csv"), stringsAsFactors = FALSE)
ch <- ch[!is.na(ch$cluster_off) & ch$cluster_off %in% d$cluster_id, ]
ch$in_difetti <- paste(ch$cluster_off, ch$study) %in% paste(dif$cluster_id, dif$study_id)
tb <- aggregate(cbind(confronti = 1, gia_difetto = in_difetti) ~ meta_off + study + stato_on,
                data = transform(ch, in_difetti = as.integer(in_difetti)), FUN = sum)
tb$gia_difetto <- tb$gia_difetto > 0
L <- c(L, capture.output(print(tb[order(tb$meta_off, tb$study), ], row.names = FALSE)))
print(tb[order(tb$meta_off, tb$study), ], row.names = FALSE)
st <- unique(ch[, c("meta_off", "study", "in_difetti")])
say("studi (meta-analisi, studio) che cambiano: %d; gia' in difetti.csv per la stessa meta-analisi: %d",
    nrow(st), sum(st$in_difetti))
write.csv(tb, file.path(OUT, "45-cambi-contro-difetti.csv"), row.names = FALSE)

say("")
say("== C. TNF-alpha scritto in ASCII ==")
for (s in c("tnf-alpha", "tnfalpha", "tnf alpha", "tnfa", "tnf-α", "tnfα")) {
  a <- simulomicsr:::.normalize_compound_to_chebi(s, onto)
  b <- simulomicsr:::.normalize_cytokine_to_hgnc(s, onto)
  say("   %-10s -> ChEBI/ChEMBL %s (%s) | citochine %s", s, a$id, a$name, b$id)
}
say("CHEBI:197439 nella lista nera dell'ancora del contrasto: %s",
    "CHEBI:197439" %in% simulomicsr:::.CA_BLACKLIST_ID)
tnf_key <- "HGNC:11892||gain||vehicle_untreated"
inT <- unique(r$study[in_grp & key_off == tnf_key])
tlfl <- paste(ing$tl, ing$tfl)
asc <- grepl("tnf[- ]?(alpha|a\\b)", tlfl, ignore.case = TRUE, perl = TRUE) & !r$G_in & r$eleggibile
c_chembl <- asc & r$scarto_off == "" & r$entity_off == "CHEMBL:CHEMBL265582"
c_black  <- asc & r$scarto_off == "id_blacklist"
say("studi nel gruppo TNF del deliverable: %d", length(inT))
say("confronti eleggibili con TNF-alpha in ASCII nel trattato: %d; nel gruppo TNF: %d (studi %d)",
    sum(asc), sum(asc & in_grp & key_off == tnf_key), length(unique(r$study[asc & in_grp & key_off == tnf_key])))
say("   nel gruppo CHEMBL:CHEMBL265582: %d confronti, %d studi", sum(c_chembl), length(unique(r$study[c_chembl])))
say("   scartati come id_blacklist: %d confronti, %d studi", sum(c_black), length(unique(r$study[c_black])))
fu <- unique(r$study[c_chembl | c_black])
say("   studi fuori dal gruppo TNF per la forma ASCII: %d; non gia' nel gruppo: %d", length(fu), length(setdiff(fu, inT)))
say("CHEMBL:CHEMBL265582 e' una meta-analisi del deliverable: %s", any(d$contrast_entity == "CHEMBL:CHEMBL265582"))

say("")
say("== D. Interferon gamma scritto per esteso (gruppo nuovo di P4) ==")
for (s in c("interferon gamma", "interferon γ", "interferon", "ifn-gamma")) {
  a <- simulomicsr:::.normalize_compound_to_chebi(s, onto)
  b <- simulomicsr:::.normalize_cytokine_to_hgnc(s, onto)
  say("   %-17s -> ChEBI/ChEMBL %s (%s) | citochine %s", s, a$id, a$name, b$id)
}

say("")
say("== E. Entita' tenuta costante con un controllo che nega l'entita' ==")
ec  <- r$scarto_off == "entita_costante"
neg <- grepl("(^|[^a-z])(no|non|without|w/o|minus|absence)([^a-z]|$)", tolower(ing$cl), perl = TRUE)
say("scarti entita_costante (OFF): %d; eleggibili: %d", sum(ec), sum(ec & r$eleggibile))
say("   con no/non/without/w/o/minus/absence nel controllo: %d eleggibili in %d studi",
    sum(ec & neg & r$eleggibile), length(unique(r$study[ec & neg & r$eleggibile])))
e <- ing[ec & neg & r$eleggibile, c("record_id", "study", "tl", "cl")]
write.csv(e, file.path(OUT, "45-entita-costante-negata.csv"), row.names = FALSE)

say("")
say("== F. Greche rovinate dalla codifica ==")
moj <- "[Îî][\u0080-¿]|[Ïï][\u0080-\u0089]|[Ââ]µ"
f <- function(x) !is.na(x) & grepl(moj, x, perl = TRUE)
m4 <- f(ing$tl) | f(ing$cl) | f(ing$tfl) | f(ing$cfl); ma <- f(ing$anchor_name)
say("nelle quattro stringhe del confronto: %d; nel nome dell'anchor: %d", sum(m4), sum(ma))
say("   in un gruppo: %d; in un gruppo con l'entita' presa dall'anchor: %d",
    sum((m4 | ma) & in_grp), sum((m4 | ma) & in_grp & r$fonte_off == "anchor"))

say("")
say("== G. IL1A nel deliverable ==")
il_key <- d$anchor_key[d$contrast_entity_label == "IL1A"]
g <- ing[in_grp & key_off == il_key, c("study", "tl", "cl")]
L <- c(L, capture.output(print(g, row.names = FALSE))); print(g, row.names = FALSE)

writeLines(L, file.path(OUT, "45-out.txt"))
