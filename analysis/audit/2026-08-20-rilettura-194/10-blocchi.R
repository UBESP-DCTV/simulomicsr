#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/10-blocchi.R
#
# Scrive i blocchi da leggere, a partire dai dispatch validati da 00-materiale.R.
#
# Ogni gruppo porta con se':
#   - i confronti EFFETTIVAMENTE POOLATI, con le etichette INTERE dei due bracci;
#   - per ogni studio, la COLONNA COMPARATIVA: dov'era nel run di riferimento.
#     Se lo studio nel riferimento stava sotto un'altra chiave di contrasto, si
#     stampano ANCHE le etichette che aveva li' — lette dal master Stadio 2 del
#     riferimento, non da quello di A3.
#   - gli studi USCITI: c'erano sotto questa chiave nel riferimento, ora non piu'.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/10-blocchi.R

suppressPackageStartupMessages({ library(cli) })
OUT    <- "analysis/audit/2026-08-20-rilettura-194"
A3_POOL  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
RIF_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d"
BLOCCO <- as.integer(Sys.getenv("PER_BLOCCO", "13"))
`%||%` <- function(a, b) if (is.null(a) || !length(a) || !nzchar(a)) b else a

dA3  <- readRDS(file.path(A3_POOL,  "deliverable-annotato.rds"))
dRIF <- readRDS(file.path(RIF_POOL, "deliverable-annotato.rds"))
RA3  <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
RRIF <- readRDS(file.path(OUT, "dispatch-RIF.rds"))$tenuti

# L'identita' di una meta-analisi e' la CHIAVE DEL CONTRASTO, non il cluster_id:
# il cluster_id e' un hash della composizione, confrontarlo direbbe «sono tutte
# diverse» senza informare su nulla.
kchiave <- function(d) paste(d$contrast_entity, d$contrast_direction, d$contrast_control_key, sep = "||")
dA3$ckey_cmp  <- kchiave(dA3);  dRIF$ckey_cmp <- kchiave(dRIF)
RA3$ckey  <- dA3$ckey_cmp[match(RA3$cluster_id,  dA3$cluster_id)]
RRIF$ckey <- dRIF$ckey_cmp[match(RRIF$cluster_id, dRIF$cluster_id)]

# dove stava ogni studio nel riferimento (puo' stare in piu' gruppi)
rif_per_studio <- split(seq_len(nrow(RRIF)), RRIF$study_id)

etichetta_rif <- function(sid, ck) {
  i <- rif_per_studio[[sid]]; if (is.null(i)) return(NULL)
  j <- i[RRIF$ckey[i] == ck]; if (!length(j)) return(NULL)
  RRIF[j, , drop = FALSE]
}

# BLOCCHI BILANCIATI. Ordinando per k e tagliando a fette consecutive, il primo
# blocco si prende i 13 gruppi piu' grandi e diventa dieci volte gli altri (183
# KB contro 20). I gruppi si distribuiscono a giro, come fa il partitore dei
# pezzi del re-pool: cosi' ogni lettore riceve un carico simile e un mix di k.
dA3 <- dA3[order(-dA3$k_effective, dA3$contrast_entity), ]
N_BLOCCHI <- as.integer(ceiling(nrow(dA3) / BLOCCO))
tutte_lab <- character(0); righe_div <- list()
blocchi <- split(seq_len(nrow(dA3)), (seq_len(nrow(dA3)) - 1L) %% N_BLOCCHI + 1L)
cli_alert_info("{nrow(dA3)} gruppi -> {length(blocchi)} blocchi bilanciati")

for (b in seq_along(blocchi)) {
  idx <- blocchi[[b]]
  L <- c(sprintf("# BLOCCO %02d — %d meta-analisi", b, length(idx)), "",
    "Ogni gruppo qui sotto e' una META-ANALISI del deliverable. I confronti elencati",
    "sono quelli EFFETTIVAMENTE POOLATI (replica del dispatch di produzione, validata",
    "contro il registro degli scarti e contro per_study_de). Le etichette sono INTERE.",
    "",
    "La riga [CONFRONTO] e' cio' che il gruppo mette insieme. La riga [RIFERIMENTO]",
    "dice dov'era quello studio nell'altra esecuzione della stessa catena, che",
    "differisce SOLO per gli stadi LLM.", "")
  for (i in idx) {
    r <- dA3[i, ]
    e <- RA3[RA3$cluster_id == r$cluster_id, , drop = FALSE]
    e <- e[order(e$study_id), ]
    studi_ora <- unique(e$study_id)
    # chi c'era nel riferimento sotto questa stessa chiave di contrasto
    j <- which(RRIF$ckey == r$ckey_cmp)
    studi_prima <- unique(RRIF$study_id[j])
    usciti <- setdiff(studi_prima, studi_ora)
    entrati <- setdiff(studi_ora, studi_prima)
    gruppo_esisteva <- r$ckey_cmp %in% dRIF$ckey_cmp

    L <- c(L,
      sprintf("## GRUPPO %s", r$cluster_id),
      sprintf("- entita dichiarata : %s  (%s)", r$contrast_entity, r$contrast_entity_label %||% "-"),
      sprintf("- verso / controllo : %s / %s", r$contrast_direction, r$contrast_control_key),
      sprintf("- studi poolati     : %d   studi efficaci (Kish): %.1f   piu pesante: %.0f%%",
              r$k_effective, r$k_kish, 100 * r$quota_top1),
      sprintf("- geni significativi: %d   I2 mediano: %.1f", r$n_sig, r$I2_med),
      sprintf("- verdetto attuale  : %s%s", r$coherence_verdict,
              if (!is.na(r$coherence_reason)) paste0(" — ", r$coherence_reason) else ""),
      sprintf("- nel riferimento   : %s", if (!gruppo_esisteva) "QUESTO GRUPPO NON ESISTEVA (meta-analisi nuova)"
              else sprintf("esisteva con %d studi; entrati ora: %d, usciti: %d",
                           length(studi_prima), length(entrati), length(usciti))),
      "- CONFRONTI POOLATI (etichette intere):")
    for (q in seq_len(nrow(e))) {
      x <- e[q, ]
      L <- c(L,
        sprintf("    [%s] n_trattati=%d vs n_controlli=%d", x$study_id, x$n_t, x$n_c),
        sprintf("        TRATTATO : %s", x$etichetta_trattato),
        sprintf("        CONTROLLO: %s", x$etichetta_controllo))
      tutte_lab <- c(tutte_lab, x$etichetta_trattato, x$etichetta_controllo)
    }
    # LA COLONNA COMPARATIVA, UNA VOLTA PER STUDIO (non per confronto).
    # Ripeterla a ogni confronto moltiplicava le stesse tre righe del riferimento
    # sotto ognuno dei tre confronti dello stesso studio: rumore, e per giunta
    # invitava a contare per destinazione invece che per studio.
    L <- c(L, "- CONFRONTO CON L'ALTRA ESECUZIONE, studio per studio:")
    for (sid in studi_ora) {
      ora <- e[e$study_id == sid, , drop = FALSE]
      rr  <- etichetta_rif(sid, r$ckey_cmp)
      set_ora <- sort(paste(ora$etichetta_trattato, "\u2192", ora$etichetta_controllo))
      if (!is.null(rr)) {
        set_rif <- sort(paste(rr$etichetta_trattato, "\u2192", rr$etichetta_controllo))
        if (identical(set_ora, set_rif)) {
          L <- c(L, sprintf("    [%s] STABILE: stesso gruppo, stessi confronti, stesse etichette.", sid))
        } else {
          L <- c(L, sprintf("    [%s] stesso gruppo ma i CONFRONTI CAMBIANO (%d ora, %d nel riferimento) >>> DIVERGENZA",
                            sid, length(set_ora), length(set_rif)),
                    "        nel riferimento erano:")
          for (z in set_rif) L <- c(L, sprintf("            %s", z))
          righe_div[[length(righe_div)+1L]] <- data.frame(cluster_id=r$cluster_id,
            ckey=r$ckey_cmp, study_id=sid, tipo="etichette_cambiate", stringsAsFactors=FALSE)
        }
      } else {
        alt <- rif_per_studio[[sid]]
        if (is.null(alt)) {
          L <- c(L, sprintf("    [%s] ENTRATO: nel riferimento questo studio non era poolato in NESSUNA meta-analisi >>> DIVERGENZA", sid))
        } else {
          L <- c(L, sprintf("    [%s] SPOSTATO: nel riferimento lo stesso studio stava sotto un'ALTRA chiave >>> DIVERGENZA", sid))
          for (z in alt) L <- c(L,
            sprintf("        era in %s", RRIF$ckey[z]),
            sprintf("            %s \u2192 %s", RRIF$etichetta_trattato[z], RRIF$etichetta_controllo[z]))
        }
        righe_div[[length(righe_div)+1L]] <- data.frame(cluster_id=r$cluster_id,
          ckey=r$ckey_cmp, study_id=sid, tipo="entrato", stringsAsFactors=FALSE)
      }
    }
    if (length(usciti)) {
      L <- c(L, sprintf("- STUDI USCITI rispetto al riferimento (%d) >>> DIVERGENZA:", length(usciti)))
      for (s in usciti) {
        rr <- etichetta_rif(s, r$ckey_cmp)
        dove <- unique(RA3$ckey[RA3$study_id == s])
        L <- c(L, sprintf("    [%s] nel riferimento era in QUESTO gruppo; ora %s", s,
                          if (!length(dove)) "NON e' poolato in nessuna meta-analisi"
                          else paste0("sta in: ", paste(dove, collapse = " ; "))))
        if (!is.null(rr)) for (z in seq_len(nrow(rr)))
          L <- c(L, sprintf("        era TRATTATO : %s", rr$etichetta_trattato[z]),
                    sprintf("        era CONTROLLO: %s", rr$etichetta_controllo[z]))
        righe_div[[length(righe_div)+1L]] <- data.frame(cluster_id=r$cluster_id,
          ckey=r$ckey_cmp, study_id=s, tipo="uscito", stringsAsFactors=FALSE)
      }
    }
    L <- c(L, "")
  }
  writeLines(L, file.path(OUT, sprintf("blocco-%02d.txt", b)))
}

if (length(righe_div)) utils::write.csv(do.call(rbind, righe_div),
  file.path(OUT, "divergenze.csv"), row.names = FALSE)

# --- IL CONTROLLO CHE LO STRUMENTO VEDA IL DATO PER INTERO --------------------
n <- nchar(tutte_lab)
cli_h2("Le etichette sono intere?")
cli_alert_info("etichette totali: {length(n)} | max: {max(n)} | mediana: {stats::median(n)}")
tb <- sort(table(n), decreasing = TRUE)
cli_alert_info("Le dieci lunghezze piu' frequenti (una lunghezza molto popolare = sospetto troncamento):")
for (k in seq_len(min(10, length(tb))))
  cat(sprintf("    %4s caratteri : %d etichette\n", names(tb)[k], tb[k]))
for (s in c(40, 58, 64, 80, 100, 128)) {
  cnt <- sum(n == s)
  if (cnt > 0) cat(sprintf("    soglia %3d : %d etichette%s\n", s, cnt,
                           if (cnt > 5) "   <-- DA ISPEZIONARE" else ""))
}
writeLines(unique(tutte_lab), file.path(OUT, "tutte-le-etichette.txt"))
cli_alert_success("Scritti {length(blocchi)} blocchi. Divergenze registrate: {length(righe_div)}")
