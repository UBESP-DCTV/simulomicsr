# =============================================================================
# LA MISURA DELLA FRAMMENTAZIONE — asse CODICE contro CODICE
# =============================================================================
# Consuma l'esito di `20-regola-risoluzione.R`. Tre blocchi:
#   A) frammentazione FUSA dalla regola (registri diversi, entrambi nel corpus)
#   B) frammentazione CANDIDATA intra-registro (contata, non fusa)
#   C) la vetrina: le 214 meta-analisi poolate di v15
# Onesta' obbligatoria: la chiave vera del deliverable e'
# `entita || verso || chiave-di-controllo`. La chiave di FUSIONE porta solo
# entita' e verso. Una fusione che attraversa due chiavi di controllo NON e'
# poolabile da sola: le due grandezze si contano separate.
# =============================================================================

suppressWarnings(suppressMessages(devtools::load_all(".", quiet = TRUE)))
OUT <- "analysis/audit/2026-08-08-deframmentazione"
say <- function(...) cat(sprintf(...), "\n", sep = "")
E <- readRDS(file.path(OUT, "21-regola-esito.rds"))
cg <- E$cg; FUS <- E$fusioni; intra <- E$intra; k_per_id <- E$k_per_id

studi <- function(idx) unique(unlist(cg$studies_in_cluster[idx]))

# --------------------------------------------------------------------------
# A) le fusioni applicate
# --------------------------------------------------------------------------
cg$chiave_fusione <- paste(cg$entita_canonica, cg$contrast_direction, sep = "||")
cg$chiave_vecchia <- paste(cg$contrast_entity, cg$contrast_direction, sep = "||")
spl <- split(seq_len(nrow(cg)), cg$chiave_fusione)
rig <- list()
for (nm in names(spl)) {
  idx <- spl[[nm]]
  scritture <- unique(cg$contrast_entity[idx])
  if (length(scritture) < 2L) next
  ck <- unique(cg$contrast_control_key[idx])
  # sotto-gruppi per chiave di controllo: dentro una stessa chiave la fusione
  # e' immediatamente poolabile, fra chiavi diverse no
  per_ck <- tapply(idx, cg$contrast_control_key[idx], function(z) z)
  poolabile <- max(vapply(per_ck, function(z) length(unique(cg$contrast_entity[z])), integer(1L)))
  rig[[length(rig) + 1L]] <- data.frame(
    entita_canonica = cg$entita_canonica[idx][1L],
    verso = cg$contrast_direction[idx][1L],
    n_scritture = length(scritture),
    scritture = paste(sprintf("%s(k=%d)", cg$contrast_entity[idx], cg$k[idx]), collapse = " + "),
    k_somma = sum(cg$k[idx]), k_max_singolo = max(cg$k[idx]),
    n_cluster = length(idx),
    n_chiavi_controllo = length(ck),
    chiavi_controllo = paste(ck, collapse = " | "),
    scritture_nella_stessa_chiave_controllo = poolabile,
    studi_slot_distinti = length(studi(idx)),
    tier = paste(sort(unique(cg$fonte_risoluzione[idx][cg$fonte_risoluzione[idx] != "GIA_CANONICO"])),
                 collapse = ","),
    stringsAsFactors = FALSE)
}
A <- if (length(rig)) do.call(rbind, rig) else data.frame()
A <- A[order(-A$k_somma), ]
say("=== A) ENTITA' SPEZZATE CHE LA REGOLA FONDE: %d ===", nrow(A))
say("cluster coinvolti: %d | studi-slot distinti coinvolti: %d",
    sum(A$n_cluster), length(studi(which(cg$chiave_fusione %in% paste(A$entita_canonica, A$verso, sep = "||")))))
say("di cui la fusione e' DENTRO la stessa chiave di controllo (poolabile subito): %d",
    sum(A$scritture_nella_stessa_chiave_controllo >= 2L))
say("di cui attraversa >1 chiave di controllo (NON poolabile senza fondere anche quella): %d",
    sum(A$scritture_nella_stessa_chiave_controllo < 2L))
print(A[, c("entita_canonica","verso","n_scritture","k_somma","k_max_singolo","n_cluster",
            "n_chiavi_controllo","scritture_nella_stessa_chiave_controllo","studi_slot_distinti","tier")])
say("--- dettaglio scritture ---")
for (i in seq_len(nrow(A))) say("  %s [%s] : %s   {controllo: %s}", A$entita_canonica[i], A$verso[i],
                               A$scritture[i], A$chiavi_controllo[i])
utils::write.csv(A, file.path(OUT, "24a-entita-spezzate-fuse.csv"), row.names = FALSE)

# --------------------------------------------------------------------------
# B) candidate INTRA-registro: contate, non fuse
# --------------------------------------------------------------------------
# Per ogni coppia intra-registro si guarda se i due ID stanno nello STESSO verso
# (altrimenti non ci sarebbe niente da fondere comunque).
B <- unique(intra[, c("registro","id_a","id_b","chiave","is_a")])
Bb <- list()
for (i in seq_len(nrow(B))) {
  ia <- B$id_a[i]; ib <- B$id_b[i]
  ca <- cg[cg$contrast_entity == ia, ]; cb <- cg[cg$contrast_entity == ib, ]
  versi <- intersect(unique(ca$contrast_direction), unique(cb$contrast_direction))
  if (!length(versi)) next
  for (v in versi) {
    ia_i <- which(cg$contrast_entity == ia & cg$contrast_direction == v)
    ib_i <- which(cg$contrast_entity == ib & cg$contrast_direction == v)
    ck_comune <- intersect(cg$contrast_control_key[ia_i], cg$contrast_control_key[ib_i])
    Bb[[length(Bb) + 1L]] <- data.frame(
      registro = B$registro[i], id_a = ia, id_b = ib, verso = v,
      k_a = sum(cg$k[ia_i]), k_b = sum(cg$k[ib_i]),
      k_se_fusi = sum(cg$k[c(ia_i, ib_i)]),
      n_cluster = length(c(ia_i, ib_i)),
      studi_slot = length(studi(c(ia_i, ib_i))),
      chiave_controllo_comune = if (length(ck_comune)) paste(ck_comune, collapse = ";") else "",
      alias_condiviso = B$chiave[i], is_a = B$is_a[i], stringsAsFactors = FALSE)
  }
}
B2 <- if (length(Bb)) unique(do.call(rbind, Bb)) else data.frame()
if (nrow(B2)) {
  B2 <- B2[order(-pmin(B2$k_a, B2$k_b)), ]
  B2 <- B2[!duplicated(paste(B2$id_a, B2$id_b, B2$verso)), ]
}
say("")
say("=== B) COPPIE INTRA-REGISTRO nello stesso verso (CONTATE, NON FUSE): %d ===", nrow(B2))
if (nrow(B2)) {
  say("cluster coinvolti: %d | k se fusi (somma): %d", sum(B2$n_cluster), sum(B2$k_se_fusi))
  say("con una chiave di controllo COMUNE (poolabili subito se si fondessero): %d",
      sum(nzchar(B2$chiave_controllo_comune)))
  print(B2[, c("registro","id_a","id_b","verso","k_a","k_b","k_se_fusi","n_cluster",
               "studi_slot","alias_condiviso","is_a")])
}
utils::write.csv(B2, file.path(OUT, "24b-intra-registro-candidate.csv"), row.names = FALSE)

# --------------------------------------------------------------------------
# C) la vetrina: le 214 poolate
# --------------------------------------------------------------------------
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/deliverable-annotato.rds"
if (file.exists(DEL)) {
  dl <- readRDS(DEL)
  say("")
  say("=== C) VETRINA: %d meta-analisi poolate ===", nrow(dl))
  # la chiave del deliverable e' l'anchor_key dei cgroup: si ri-aggancia per cluster_id
  key <- setNames(cg$contrast_entity, cg$cluster_id)
  dir_ <- setNames(cg$contrast_direction, cg$cluster_id)
  ckk <- setNames(cg$contrast_control_key, cg$cluster_id)
  canon <- setNames(cg$entita_canonica, cg$cluster_id)
  idc <- if ("cluster_id" %in% names(dl)) dl$cluster_id else dl[[1L]]
  dl$ent <- key[idc]; dl$verso <- dir_[idc]; dl$ck <- ckk[idc]; dl$canon <- canon[idc]
  say("righe agganciate ai cgroup: %d su %d", sum(!is.na(dl$ent)), nrow(dl))
  kcol <- intersect(c("k_studies","k_effective","k"), names(dl))[1L]
  say("colonna del k usata: %s", kcol)
  dl$kk <- dl[[kcol]]
  # doppioni codice<->codice DENTRO la vetrina, applicando la regola
  dl$chiave_fusione <- paste(dl$canon, dl$verso, sep = "||")
  dup <- dl[dl$chiave_fusione %in% names(which(table(dl$chiave_fusione) > 1L)), ]
  dup <- dup[order(dup$chiave_fusione, -dup$kk), ]
  say("--- doppioni FUSI dalla regola presenti nella vetrina: %d righe, %d gruppi ---",
      nrow(dup), length(unique(dup$chiave_fusione)))
  if (nrow(dup)) print(dup[, c("cluster_id","ent","canon","verso","ck","kk")])
  # doppioni CANDIDATI intra-registro presenti nella vetrina
  if (nrow(B2)) {
    hit <- B2[B2$id_a %in% dl$ent & B2$id_b %in% dl$ent, ]
    say("--- coppie intra-registro con ENTRAMBI i rami nella vetrina: %d ---", nrow(hit))
    if (nrow(hit)) {
      for (i in seq_len(nrow(hit))) {
        ra <- dl[dl$ent == hit$id_a[i] & dl$verso == hit$verso[i], ]
        rb <- dl[dl$ent == hit$id_b[i] & dl$verso == hit$verso[i], ]
        say("  %s (k=%s, ck=%s)  ~  %s (k=%s, ck=%s)  alias '%s'",
            hit$id_a[i], paste(ra$kk, collapse="/"), paste(unique(ra$ck), collapse="/"),
            hit$id_b[i], paste(rb$kk, collapse="/"), paste(unique(rb$ck), collapse="/"),
            hit$alias_condiviso[i])
      }
      utils::write.csv(hit, file.path(OUT, "24c-vetrina-intra-registro.csv"), row.names = FALSE)
    }
  }
  utils::write.csv(dl[, c("cluster_id","ent","canon","verso","ck","kk")],
                   file.path(OUT, "24c-vetrina-canonicalizzata.csv"), row.names = FALSE)
} else say("⚠️ deliverable v15 non trovato: %s", DEL)

# --------------------------------------------------------------------------
# D) quanto vale l'asse STR: (per confronto, non per fonderlo)
# --------------------------------------------------------------------------
say("")
say("=== D) l'asse STR: — non toccato, misurato per confronto ===")
nstr <- sum(startsWith(cg$contrast_entity, "STR:"))
say("cluster con entita' STR:: %d (%.1f%% degli 11.536); slug distinti: %d",
    nstr, 100 * nstr / nrow(cg), length(unique(cg$contrast_entity[startsWith(cg$contrast_entity, "STR:")])))
say("k mediano dei cluster STR:: %.1f  |  cluster STR: con k>=3: %d",
    stats::median(cg$k[startsWith(cg$contrast_entity, "STR:")]),
    sum(cg$k[startsWith(cg$contrast_entity, "STR:")] >= 3L))
say("cluster con ID ontologico e k>=3: %d",
    sum(cg$k[!startsWith(cg$contrast_entity, "STR:")] >= 3L))
