#!/usr/bin/env Rscript
# 20-guadagno-poolato.R --- che cosa cambia DAVVERO nel deliverable.
#
# La misura dei membri (10-) dice quante etichette cambiano. Non basta: il gate
# dei controlli interni scarta il 43% degli studi-slot, quindi un guadagno di
# 14 slot non e' un guadagno di 14 studi poolati. Qui si usa la funzione di
# dispatch VERA — la stessa del run — su ogni fusione che la regola produce.
#
# NON c'e' una lista di casi scritta a mano: le fusioni si DERIVANO dal
# risultato della regola su tutti i membri. E' la differenza fra una regola e un
# elenco, ed e' l'errore che questo progetto ha gia' pagato per mesi.
#
# Uso: Rscript analysis/audit/2026-07-31-defrag/20-guadagno-poolato.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

OUT    <- "analysis/audit/2026-07-31-defrag"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"

d <- readRDS(file.path(OUT, Sys.getenv("IMPATTO_OUT", "impatto-membri-fix.rds")))
message("membri misurati: ", nrow(d))

key <- function(e, v, c) paste(e, v, c, sep = "||")
kept_off <- d[d$drop_off == "" & !is.na(d$ent_off), ]
kept_on  <- d[d$drop_on  == "" & !is.na(d$ent_on), ]
kept_off$grp <- key(kept_off$ent_off, kept_off$dir_off, kept_off$ck_off)
kept_on$grp  <- key(kept_on$ent_on,  kept_on$dir_on,  kept_on$ck_on)

# --------------------------------------------------------------- il bilancio --
n_stud <- function(x) length(unique(x))
g_off <- stats::aggregate(study ~ grp, kept_off, n_stud)
g_on  <- stats::aggregate(study ~ grp, kept_on,  n_stud)
names(g_off)[2] <- "k_off"; names(g_on)[2] <- "k_on"
g <- merge(g_off, g_on, by = "grp", all = TRUE)
g$k_off[is.na(g$k_off)] <- 0L; g$k_on[is.na(g$k_on)] <- 0L
g$entita <- sub("\\|\\|.*$", "", g$grp)

cat("\n================ GRUPPI (chiave entita'||verso||controllo) ================\n")
cat(sprintf("  gruppi con k>=3 PRIMA: %d\n", sum(g$k_off >= 3L)))
cat(sprintf("  gruppi con k>=3 DOPO : %d\n", sum(g$k_on  >= 3L)))
cat(sprintf("  spariti (k>=3 -> <3) : %d\n", sum(g$k_off >= 3L & g$k_on < 3L)))
cat(sprintf("  nati    (<3 -> k>=3) : %d\n", sum(g$k_off < 3L & g$k_on >= 3L)))
cat(sprintf("  cambiano k           : %d\n", sum(g$k_off != g$k_on)))

# ----------------------------------------------------- le fusioni, derivate ---
mv <- d[!is.na(d$ent_on) & !is.na(d$ent_off) & d$ent_on != d$ent_off, ]
cat("\n================ MEMBRI CHE CAMBIANO ENTITA' ================\n")
cat("  membri:", nrow(mv), "su", nrow(d),
    sprintf("(%.2f%%)\n", 100 * nrow(mv) / nrow(d)))
tab <- as.data.frame(table(da = mv$ent_off, a = mv$ent_on), stringsAsFactors = FALSE)
tab <- tab[tab$Freq > 0, ]
tab <- tab[order(-tab$Freq), ]
cat("  coppie distinte:", nrow(tab), "\n\n")
print(utils::head(tab, 40), row.names = FALSE)

# --- INVARIANTE: la regola non puo' toccare un'entita' gia' risolta ----------
# Sta nel ramo di ripiego, DOPO res$id. Se un membro cambiasse entita' partendo
# da un ID ontologico, l'innesto sarebbe nel posto sbagliato. Si prova, non si
# assume.
non_str <- mv[!is.na(mv$ent_off) & !startsWith(mv$ent_off, "STR:"), ]
cat("\n[invariante] membri che cambiano partendo da un'entita' NON STR:",
    nrow(non_str), "(atteso 0)\n")
if (nrow(non_str)) {
  print(utils::head(non_str[, c("record_id", "ent_off", "ent_on", "tl")], 20))
  stop("INVARIANTE VIOLATA: la de-frammentazione sovrascrive entita' gia' risolte")
}
cat("[invariante] sorgente dei membri cambiati:",
    paste(names(table(mv$src_on)), table(mv$src_on), sep = "=", collapse = " "), "\n")

# --- LO SPLIT: la regola crea gruppi doppi? ----------------------------------
# Il difetto trovato il 2026-08-01 leggendo l'output vero di v14: con le
# ontologie scelte PER CLASSE, lo stesso token si fondeva in alcuni record e no
# in altri, e la stessa entita' finiva in DUE gruppi (`STR:hypoxia` k=33 E
# `MeSH:D000860` k=10). Qui si controlla PRIMA del run, non dopo.
cat("\n================ CONTROLLO SPLIT (una entita', due gruppi) ================\n")
tok_fusi <- unique(sub("^STR:", "", mv$ent_off))
resta_str <- unique(sub("^STR:", "", kept_on$ent_on[startsWith(kept_on$ent_on, "STR:")]))
split_tok <- intersect(tok_fusi, resta_str)
cat("  token che si fondono in qualche record MA restano STR in altri:",
    length(split_tok), " (atteso 0)\n")
if (length(split_tok)) {
  n <- vapply(split_tok, function(x) sum(sub("^STR:", "", mv$ent_off) == x), integer(1L))
  print(utils::head(sort(n, decreasing = TRUE), 20))
  cat("\n  ⚠️ SPLIT PRESENTE: la regola frammenta invece di de-frammentare.\n")
} else {
  cat("  nessuno split: lo stesso token da' sempre lo stesso esito.\n")
}

# --- le fusioni su TAXON, da leggere UNA PER UNA -----------------------------
# La classe `drug` interroga la tassonomia come fa il resolver. Li' "cancer"
# aggancia NCBITaxon:6754, il GENERE DEL GRANCHIO: a fermarlo e' solo la guardia
# sulle parole funzionali, che e' una lista finita. Quindi ogni fusione che
# finisce su un taxon si guarda, non si somma.
tx <- tab[startsWith(tab$a, "NCBITaxon:"), ]
cat("\n================ FUSIONI SU UN TAXON (da leggere una per una) ================\n")
cat("  coppie:", nrow(tx), " membri:", sum(tx$Freq), "\n")
if (nrow(tx)) print(tx, row.names = FALSE)

ric <- d[d$drop_off != "" & d$drop_on == "", ]
cat("\n  membri RIPESCATI (scartati prima, tenuti ora):", nrow(ric), "\n")
if (nrow(ric)) print(utils::head(sort(table(ric$drop_off), decreasing = TRUE), 10))
per <- d[d$drop_off == "" & d$drop_on != "", ]
cat("  membri PERSI (tenuti prima, scartati ora):", nrow(per), "\n")
if (nrow(per)) print(utils::head(sort(table(per$drop_on), decreasing = TRUE), 10))

# --------------------------------------- il guadagno POOLATO, uno per uno -----
message("\ncarico lo Stadio 2 per il dispatch vero...")
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
n_min <- stage4_default_config()$rem_group$n_min %||% 2L

# TUTTI i gruppi in UNA sola chiamata per regime: `.build_group_rem_dispatch_from_stage3`
# indicizza lo Stadio 2 al suo interno, quindi chiamarla una volta per gruppo
# significa re-indicizzare 24.394 studi migliaia di volte. (Prima stesura: era
# cosi', e ci avrebbe messo ore. Corretta prima di usarla.)
poolati_tutti <- function(kept, grps) {
  sel <- kept[kept$grp %in% grps, ]
  if (!nrow(sel)) return(stats::setNames(integer(0), character(0)))
  cid <- paste0("sim", match(sel$grp, grps))
  meta <- data.frame(cluster_id = unique(cid), mode = "cgroup",
                     method = "rem_group", stringsAsFactors = FALSE)
  asg <- data.frame(record_id = sel$record_id, cluster_id = cid,
                    stringsAsFactors = FALSE)
  dd <- simulomicsr:::.build_group_rem_dispatch_from_stage3(meta, asg, s2, n_min = n_min)
  out <- vapply(names(dd), function(k)
    length(unique(vapply(dd[[k]], function(x) x$study_id, character(1L)))),
    integer(1L))
  stats::setNames(out, grps[as.integer(sub("^sim", "", names(dd)))])
}

cambiati <- g$grp[g$k_off != g$k_on]
cat("\n================ GUADAGNO POOLATO (dispatch vero) ================\n")
cat("  gruppi la cui composizione cambia:", length(cambiati), "\n")
p_off <- poolati_tutti(kept_off, cambiati)
p_on  <- poolati_tutti(kept_on,  cambiati)
# `m[[k]]` su un vettore con nome ASSENTE solleva "subscript out of bounds",
# non restituisce NULL: un gruppo che sparisce del tutto dal dispatch faceva
# morire l'analisi. Si passa da `match`.
gv <- function(m, k) { i <- match(k, names(m)); if (is.na(i)) 0L else unname(m[i]) }
tabg <- data.frame(
  grp = cambiati, entita = sub("\\|\\|.*$", "", cambiati),
  k_censito_off = g$k_off[match(cambiati, g$grp)],
  k_censito_on  = g$k_on[match(cambiati, g$grp)],
  k_poolato_off = vapply(cambiati, function(k) gv(p_off, k), integer(1L)),
  k_poolato_on  = vapply(cambiati, function(k) gv(p_on,  k), integer(1L)),
  stringsAsFactors = FALSE)
tabg <- tabg[order(-(tabg$k_poolato_on - tabg$k_poolato_off)), ]
print(tabg, row.names = FALSE)

cat("\n--- bilancio nel deliverable (soglia k poolato >= 3) ---\n")
cat(sprintf("  meta-analisi che ENTRANO (poolato <3 -> >=3): %d\n",
            sum(tabg$k_poolato_off < 3L & tabg$k_poolato_on >= 3L)))
cat(sprintf("  meta-analisi che ESCONO  (poolato >=3 -> <3): %d\n",
            sum(tabg$k_poolato_off >= 3L & tabg$k_poolato_on < 3L)))
cat(sprintf("  studi poolati guadagnati, in totale: %d\n",
            sum(tabg$k_poolato_on - tabg$k_poolato_off)))
cat(sprintf("  gruppi che cambiano composizione (da rileggere): %d\n",
            sum(tabg$k_poolato_off >= 3L | tabg$k_poolato_on >= 3L)))

write.csv(tabg, file.path(OUT, "guadagno-poolato.csv"), row.names = FALSE)
write.csv(tab, file.path(OUT, "coppie-entita.csv"), row.names = FALSE)

# ------------------------------------------------- i quattro numeri attesi ----
cat("\n================ I NUMERI ATTESI ================\n")
atteso <- function(nome, ent, att_off, att_on) {
  r <- tabg[tabg$entita == ent, ]
  po <- if (nrow(r)) sum(r$k_poolato_off) else NA_integer_
  pn <- if (nrow(r)) sum(r$k_poolato_on) else NA_integer_
  cat(sprintf("  %-14s %-14s poolati %s -> %s   (atteso %s -> %s)  %s\n",
              nome, ent, po, pn, att_off, att_on,
              if (!is.na(pn) && identical(as.integer(pn), as.integer(att_on))) "OK" else "DA GUARDARE"))
}
atteso("TGF-beta1", "HGNC:11766", 49, 59)
atteso("Glioblastoma", "MeSH:D005909", 2, 3)
atteso("IL17A", "HGNC:5981", 7, 8)
cat(sprintf("  %-14s %-14s membri che cambiano: %d   (atteso 0 = INVARIATO)\n",
            "IFNa", "STR:ifna", sum(mv$ent_off == "STR:ifna")))
