#!/usr/bin/env Rscript
# S12p, quinta parte: dove nascono i 473 difetti. Per ogni confronto, l'ultimo passo della pipeline che aveva
# l'informazione che rende i bracci non confrontabili (classi A-E). Regole, cancelli e previsioni:
# 00-previsioni-diagnosi.md (depositate prima del calcolo, commit a5897aa). Non cambia niente della pipeline.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/130-diagnosi.R > analysis/audit/2026-11-08-S12p-prova/130-out.txt 2>&1
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(jsonlite))
DIR <- "analysis/audit/2026-11-08-S12p-prova"
A3_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
S1 <- "analysis/p4-output/A3-stage1-master-innestato.jsonl"
S2 <- "analysis/p4-output/A3-stage2-master-innestato.jsonl"
S2_IN <- c("analysis/input/A3-stage2-subset.jsonl", "analysis/input/A3-stage2-rescue.jsonl")
S14_S2 <- "analysis/p4-output/S14-stage2-master.jsonl"
SEME <- 20261108L; B <- 2000L
ferma <- function(...) stop(sprintf(...), call. = FALSE)
wilson <- function(x, n) { z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
`%||%` <- function(a, b) if (is.null(a)) b else a
cat(sprintf("impronte: %s\n", paste(sprintf("%s %s", substr(vapply(c(S2_IN, S14_S2), function(f) digest::digest(file = f, algo = "sha256"), ""), 1, 16), c(S2_IN, S14_S2)), collapse = " | ")))

# --- G0: il manifesto del deliverable e dei master (130-manifesto-out.txt, eseguito prima di questo script) ---
m <- readLines(file.path(DIR, "130-manifesto-out.txt"))
if (!any(grepl("^VERIFICA OK", m)) || !any(m == "EXIT 0")) ferma("G0: manifesto non verificato")
cat("G0 manifesto: OK\n")

# --- oggetti ---
ten <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)
nuovi <- read.csv(file.path(DIR, "94-difetti-finali.csv"), stringsAsFactors = FALSE)
ten$difettoso <- ten$record_id %in% union(rif$record_id, nuovi$record_id)
if (sum(ten$difettoso) != 473L) ferma("attesi 473 difettosi, trovati %d", sum(ten$difettoso))
dl <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
ten$kind <- dl$kind_effective_resolved[match(ten$cluster_id, dl$cluster_id)]
studi <- unique(ten$study_id)
sid_di <- function(x) sub('^.*?"series_id": ?"([^"]+)".*$', "\\1", x, perl = TRUE)

# --- tipo del difetto (regole di 00-previsioni-diagnosi.md) ---
tipi_s11 <- function(cat) {
  c0 <- tolower(cat); t <- character()
  if (grepl("tempo zero|controllo a tempo zero", c0)) t <- c(t, "tempo_zero")
  if (grepl("tempo|durata|fase", c0)) t <- c(t, "tempo_diverso")
  if (grepl("secondo agente|secondo intervento|secondo fattore|combinazione|due agenti|esposizione farmacologica", c0)) t <- c(t, "secondo_agente")
  if (grepl("entita' nel controllo", c0, fixed = TRUE)) t <- c(t, "agente_nel_controllo")
  if (grepl("entita'", gsub("entita' nel controllo", "", c0, fixed = TRUE), fixed = TRUE)) t <- c(t, "entita_diversa")
  if (grepl("sede|materiale|compartimento|comparto|tessuto|frazione|vescicole|sferoidi|linea|clone|pdx|xenotrapianto|modello", c0)) t <- c(t, "materiale_o_sede")
  if (grepl("donatore|sesso|etnia|eta'", c0)) t <- c(t, "soggetti")
  if (grepl("genotipo|genetic|stato genetico", c0)) t <- c(t, "genotipo")
  if (grepl("stato cellulare|differenziamento|coltura|passaggio", c0)) t <- c(t, "coltura")
  if (grepl("tecnica", c0)) t <- c(t, "tecnica")
  if (grepl("braccio misto", c0)) t <- c(t, "braccio_misto")
  if (!length(t)) t <- "altro"
  unique(t)
}
TIPI <- c(setNames(lapply(rif$categoria, tipi_s11), rif$record_id),
          setNames(lapply(nuovi$tipi2, function(x) unique(strsplit(x, " ")[[1]])), nuovi$record_id))
FAM_TIPO <- list(materiale_o_sede = "materiale", coltura = "coltura", genotipo = "genotipo", soggetti = "soggetti",
                 tempo_zero = "tempo", tempo_diverso = "tempo", secondo_agente = "agente", agente_nel_controllo = "agente",
                 tecnica = "tecnica")
FAMIGLIE <- c("materiale", "coltura", "genotipo", "soggetti", "tempo", "agente", "tecnica")

# --- Stadio 2: master A3 (gruppi) e ingresso (condizioni) ---
l2 <- readLines(S2); l2 <- l2[sid_di(l2) %in% studi]
M2 <- lapply(l2, fromJSON, simplifyVector = FALSE); names(M2) <- vapply(M2, function(x) as.character(x$series_id), "")
if (!all(studi %in% names(M2))) ferma("studi assenti dal master dello Stadio 2: %d", sum(!studi %in% names(M2)))
COND <- list()   # studio -> list(membro -> condition_id, rapp -> condition_id -> GSM rappresentante, membri)
for (f in S2_IN) for (l in readLines(f)) {
  if (!sid_di(l) %in% studi) next
  r <- fromJSON(l, simplifyVector = FALSE); s <- as.character(unlist(r$series_id))
  for (c0 in r$samples) {
    cid <- as.character(unlist(c0$condition_id)); mem <- sort(as.character(unlist(c0$member_sample_ids))); rep <- as.character(unlist(c0$geo_accession))
    old <- COND[[s]][[cid]]
    if (!is.null(old) && (!identical(old$membri, mem) || !identical(old$rapp, rep))) ferma("condizione %s/%s diversa fra gli ingressi", s, cid)
    COND[[s]][[cid]] <- list(membri = mem, rapp = rep)
  }
}
cat(sprintf("condizioni lette per %d studi su %d\n", sum(studi %in% names(COND)), length(studi)))

gruppo <- function(s, gid) { for (g in M2[[s]]$replicate_groups) if (identical(as.character(g$group_id), gid)) return(g); NULL }
spl <- function(x) sort(strsplit(x, ",")[[1]])

# --- G1: i bracci del dispatch sono i gruppi del master A3 ---
g1 <- vapply(seq_len(nrow(ten)), function(i) {
  gt <- gruppo(ten$study_id[i], ten$treated_group[i]); gc <- gruppo(ten$study_id[i], ten$control_group[i])
  !is.null(gt) && !is.null(gc) && identical(sort(as.character(unlist(gt$sample_ids))), spl(ten$gsm_t[i])) &&
    identical(sort(as.character(unlist(gc$sample_ids))), spl(ten$gsm_c[i]))
}, TRUE)
cat(sprintf("G1 bracci del dispatch = gruppi del master A3: %d su %d\n", sum(g1), length(g1)))
if (!all(g1)) { print(head(ten$record_id[!g1], 20)); ferma("G1 fallito") }

# --- fatti dello Stadio 1 di tutti i campioni dei bracci ---
serve <- unique(unlist(lapply(c(ten$gsm_t, ten$gsm_c), spl)))
l1 <- readLines(S1); rid1 <- sub('^\\{"record_id": ?"([^"]+)".*$', "\\1", substr(l1, 1, 60), perl = TRUE)
l1 <- l1[rid1 %in% serve]; rm(rid1); gc()
# I fatti dopo la correzione deterministica del tempo zero (P1b), cioe' quelli che lo Stadio 2 ha letto (00-previsioni-diagnosi.md, correzione dopo G3)
F1 <- lapply(l1, function(x) { r <- fromJSON(x, simplifyVector = FALSE); normalize_stage1_facts_zt(fromJSON(r$raw_output, simplifyVector = FALSE))$facts })
names(F1) <- vapply(l1, function(x) sub('^\\{"record_id": ?"([^"]+)".*$', "\\1", substr(x, 1, 60), perl = TRUE), "", USE.NAMES = FALSE)
rm(l1); gc()

# --- G2: ogni campione ha fatti e condizione; ogni braccio e' un'unione di condizioni intere ---
MAPPA <- lapply(COND, function(cc) { v <- unlist(lapply(names(cc), function(k) setNames(rep(k, length(cc[[k]]$membri)), cc[[k]]$membri)))
  if (anyDuplicated(names(v))) ferma("un campione in due condizioni"); v })
cond_di <- function(s, gsm) { v <- MAPPA[[s]][gsm]; if (is.null(v)) NA_character_ else unname(v) }
g2 <- vapply(seq_len(nrow(ten)), function(i) {
  s <- ten$study_id[i]; ok <- TRUE
  for (b in c(ten$gsm_t[i], ten$gsm_c[i])) {
    g <- spl(b); if (!all(g %in% names(F1))) return(FALSE)
    cid <- vapply(g, function(x) cond_di(s, x), ""); if (anyNA(cid)) return(FALSE)
    for (k in unique(cid)) if (!all(COND[[s]][[k]]$membri %in% g)) ok <- FALSE
  }
  ok
}, TRUE)
cat(sprintf("G2 fatti, condizioni e bracci fatti di condizioni intere: %d su %d\n", sum(g2), length(g2)))
if (!all(g2)) { print(head(ten$record_id[!g2], 20)); ferma("G2 fallito") }

# --- G3: la firma ricalcolata e' uguale dentro ogni condizione toccata ---
tocca <- unique(unlist(lapply(seq_len(nrow(ten)), function(i) paste(ten$study_id[i], vapply(spl(paste(ten$gsm_t[i], ten$gsm_c[i], sep = ",")), function(x) cond_di(ten$study_id[i], x), ""), sep = "|"))))
g3 <- vapply(tocca, function(k) { p <- strsplit(k, "|", fixed = TRUE)[[1]]; mem <- COND[[p[1]]][[p[2]]]$membri
  length(unique(vapply(mem, function(g) design_signature(F1[[g]]), ""))) == 1L }, TRUE)
cat(sprintf("G3 firma uguale dentro la condizione: %d condizioni su %d\n", sum(g3), length(g3)))
if (!all(g3)) { print(head(names(g3)[!g3], 20)); ferma("G3 fallito") }

# --- i valori per famiglia di un campione ---
ns <- function(x) .norm_scalar(x)
lista <- function(x, f) .canon_json(lapply(x %||% list(), f))
attivi <- function(f) {
  a <- character()
  for (p in f$perturbations) {
    k <- ns(p$kind); if (k %in% c("none", "vehicle_only", "unclear", "")) next
    if (identical(ns(p$is_negative_control), "true")) next
    ag <- ns(p$agent_raw); if (nzchar(ag)) a <- c(a, ag)
  }
  sort(unique(a))
}
valori <- function(f) {
  cc <- f$cell_context; ds <- f$disease_state; pm <- f$patient_metadata
  per <- f$perturbations %||% list()
  dur <- sort(unique(Filter(nzchar, vapply(per, function(p) .norm_duration(p$duration), ""))))
  list(
    materiale = list(F = list(tissue = ns(cc$tissue), tissue_segment = ns(cc$tissue_segment), cell_type_or_line_raw = ns(cc$cell_type_or_line_raw),
                              context_kind = ns(cc$context_kind), subcellular_fraction = ns(cc$subcellular_fraction$kind)),
                     L = list(sort_markers = .canon_json(.norm_set(cc$sort_markers))),
                     X = list(cellosaurus = ns(cc$cell_line_cellosaurus_candidate), host_organism = ns(f$host_organism)),
                     XL = list(cell_composition = .canon_json(lapply(cc$cell_composition_estimates %||% list(), function(z) .canon_json(lapply(z, ns)))))),
    coltura = list(F = list(cell_state = ns(cc$cell_state), developmental_stage = ns(cc$developmental_stage), context_kind = ns(cc$context_kind)),
                   L = list(co_culture = lista(cc$co_culture_partners, .norm_ccp)),
                   X = list(passage_or_state = ns(cc$passage_or_state)), XL = list()),
    genotipo = list(F = list(), L = list(engineered_modifications = lista(cc$engineered_modifications, .norm_engmod)),
                    X = list(cellosaurus = ns(cc$cell_line_cellosaurus_candidate)), XL = list()),
    soggetti = list(F = list(ds_status = ns(ds$status), ds_term = ns(ds$term_raw), ds_mesh = ns(ds$mesh_id_candidate),
                             condition = ns(pm$condition), clinical_response = ns(pm$clinical_response), stage = ns(pm$stage), survival_group = ns(pm$survival_group)),
                    L = list(), X = list(donor_id = ns(pm$donor_id), age = ns(pm$age), sex = ns(pm$sex), ancestry = ns(pm$ancestry_or_population),
                                          admixture = ns(pm$ancestry_admixture)), XL = list()),
    tempo = list(dur = paste(dur, collapse = ";"), zero = any(vapply(per, function(p) identical(ns(p$duration$is_zero_timepoint), "true"), TRUE)),
                 phase = paste(sort(unique(Filter(nzchar, vapply(per, function(p) ns(p$phase), "")))), collapse = ";"),
                 visit = ns(pm$visit_or_timepoint),
                 ordine = paste(sort(unique(Filter(nzchar, vapply(per, function(p) ns(p$temporal_order), "")))), collapse = ";")),
    agente = list(attivi = attivi(f), tecnici = .canon_json(lapply(f$technical_treatments %||% list(), function(z) .canon_json(lapply(z, ns))))),
    tecnica = list(tecnici = .canon_json(lapply(f$technical_treatments %||% list(), function(z) .canon_json(lapply(z, ns)))))
  )
}
# I campi del contrasto stesso, ignorati solo fra i bracci (00-previsioni-diagnosi.md)
ignora <- function(kind) {
  k <- if (is.null(kind) || is.na(kind)) "" else kind
  if (identical(k, "disease_vs_normal")) return(c("ds_status", "ds_term", "ds_mesh", "condition", "clinical_response", "stage", "survival_group"))
  if (identical(k, "pathogen_or_aggregate_exposure")) return(c("ds_status", "ds_term", "ds_mesh"))
  if (startsWith(k, "genetic_")) return("engineered_modifications")
  if (identical(k, "differentiation")) return(c("cell_state", "developmental_stage"))
  character()
}

# Confronto di una famiglia fra due insiemi di campioni (VT, VC: liste di valori()) e dentro ciascuno.
# escl: se TRUE usa anche i campi esclusi dalla firma. Restituisce i campi diversi fra i bracci e dentro i bracci.
confronta <- function(fam, VT, VC, ign, escl = TRUE) {
  fra <- character(); dentro <- character()
  sc <- function(V, nm, sez) vapply(V, function(v) v[[fam]][[sez]][[nm]], "")
  if (fam %in% c("materiale", "coltura", "genotipo", "soggetti")) {
    sez <- c("F", "L", if (escl) c("X", "XL"))
    for (z in sez) for (nm in names(VT[[1]][[fam]][[z]])) {
      vt <- sc(VT, nm, z); vc <- sc(VC, nm, z)
      if (z %in% c("F", "X")) { vt <- unique(vt[nzchar(vt)]); vc <- unique(vc[nzchar(vc)]) } else { vt <- unique(vt); vc <- unique(vc) }
      if (length(vt) && length(vc) && !setequal(vt, vc) && !nm %in% ign) fra <- c(fra, nm)
      if (length(vt) >= 2 || length(vc) >= 2) dentro <- c(dentro, nm)
    }
  } else if (fam == "tempo") {
    g <- function(V, k) vapply(V, function(v) as.character(v$tempo[[k]]), "")
    zt <- g(VT, "zero") == "TRUE"; zc <- g(VC, "zero") == "TRUE"
    if (any(zc) && !any(zt)) fra <- c(fra, "is_zero_timepoint")
    for (k in c("dur", "phase", "visit", if (escl) "ordine")) {
      vt <- unique(Filter(nzchar, g(VT, k))); vc <- unique(Filter(nzchar, g(VC, k)))
      if (length(vt) && length(vc) && !setequal(vt, vc)) fra <- c(fra, k)
      if (length(vt) >= 2 || length(vc) >= 2) dentro <- c(dentro, k)
    }
    if (length(unique(zt)) > 1 || length(unique(zc)) > 1) dentro <- c(dentro, "is_zero_timepoint")
  } else if (fam == "agente") {
    at <- unique(unlist(lapply(VT, function(v) v$agente$attivi))); ac <- unique(unlist(lapply(VC, function(v) v$agente$attivi)))
    if (length(setdiff(at, ac)) >= 2) fra <- c(fra, "agenti_solo_trattato")
    if (length(setdiff(ac, at)) >= 1) fra <- c(fra, "agenti_nel_controllo")
    st <- unique(vapply(VT, function(v) paste(v$agente$attivi, collapse = ";"), "")); sc2 <- unique(vapply(VC, function(v) paste(v$agente$attivi, collapse = ";"), ""))
    if (length(st) >= 2 || length(sc2) >= 2) dentro <- c(dentro, "agenti")
    if (escl) { tt <- unique(vapply(VT, function(v) v$agente$tecnici, "")); tc <- unique(vapply(VC, function(v) v$agente$tecnici, ""))
      if (!setequal(tt, tc)) fra <- c(fra, "technical_treatments"); if (length(tt) >= 2 || length(tc) >= 2) dentro <- c(dentro, "technical_treatments") }
  } else if (fam == "tecnica") {
    if (escl) { tt <- unique(vapply(VT, function(v) v$tecnica$tecnici, "")); tc <- unique(vapply(VC, function(v) v$tecnica$tecnici, ""))
      if (!setequal(tt, tc)) fra <- c(fra, "technical_treatments"); if (length(tt) >= 2 || length(tc) >= 2) dentro <- c(dentro, "technical_treatments") }
  }
  list(fra = unique(fra), dentro = unique(dentro))
}

# Chiavi dell'ingresso dello Stadio 1 per famiglia (classe C)
RE_CHIAVE <- c(materiale = "tissue|organ|site|source_name|cell type|cell line|cell_type|material|fraction|compartment|region",
               coltura = "culture|differentiat|passage|medium|state|stage", genotipo = "genotype|mutation|clone|knock|crispr|variant|allele",
               soggetti = "donor|patient|subject|individual|sex|gender|age|ethnic|race|disease|status|diagnosis",
               tempo = "time|day|hour|hr|week|duration|visit", agente = "treatment|agent|compound|drug|dose|concentration|stimul|infect",
               tecnica = "batch|lane|run|library|instrument|rin|rna|well|plate|investigative|center|kit")
SM <- read.csv(file.path(DIR, "100-senza-modello.csv"), stringsAsFactors = FALSE, na.strings = c("NA"))
SM$accuse[is.na(SM$accuse)] <- ""; SM$chiavi_mescolate[is.na(SM$chiavi_mescolate)] <- ""
chiavi_c <- function(rid) { r <- SM[SM$record_id == rid, ]; k <- unique(c(strsplit(r$accuse, "\\|")[[1]], strsplit(r$chiavi_mescolate, "\\|")[[1]])); k[nzchar(k)] }
fam_chiavi <- function(k) FAMIGLIE[vapply(FAMIGLIE, function(f) any(grepl(RE_CHIAVE[[f]], k)), TRUE)]

# La classe di un confronto per un insieme di famiglie. Ingresso: rappresentanti e campioni dei bracci (liste di
# valori()), condizioni per braccio, tipo di entita', famiglie delle chiavi d'ingresso diverse.
classe_di <- function(x, fams) {
  ign <- ignora(x$kind)
  au <- character(); as <- character(); bb <- character()
  for (fam in fams) {
    # A-unione: dentro un braccio fatto di 2+ condizioni, fra i rappresentanti
    for (b in c("t", "c")) if (length(x$rapp[[b]]) >= 2L) {
      d <- confronta(fam, x$rapp[[b]], x$rapp[[b]], ign)$dentro; if (length(d)) au <- c(au, paste0(fam, ":", d))
    }
    f <- confronta(fam, x$rapp$t, x$rapp$c, ign)$fra; if (length(f)) as <- c(as, paste0(fam, ":", f))
    a <- confronta(fam, x$tutti$t, x$tutti$c, ign); if (length(c(a$fra, a$dentro))) bb <- c(bb, paste0(fam, ":", unique(c(a$fra, a$dentro))))
  }
  cl <- if (length(au) || length(as)) "A" else if (length(bb)) "B" else if (any(fams %in% x$fam_chiavi)) "C" else "D"
  list(classe = cl, sotto = if (length(au)) "A-unione" else if (length(as)) "A-scelta" else cl,
       campi_au = paste(unique(au), collapse = "|"), campi_as = paste(unique(as), collapse = "|"), campi_b = paste(unique(bb), collapse = "|"))
}
ORDINE <- c(A = 1, B = 2, C = 3, D = 4)
classe_tipi <- function(x, tipi) {
  t <- setdiff(tipi, "entita_diversa")
  if (!length(t)) return(list(classe = "E", sotto = "E", campi_au = "", campi_as = "", campi_b = ""))
  rs <- lapply(t, function(z) classe_di(x, if (z %in% names(FAM_TIPO)) FAM_TIPO[[z]] else FAMIGLIE))
  rs[[which.min(vapply(rs, function(r) ORDINE[[r$classe]], 1))]]
}

# --- G4: controllo positivo dello strumento, confronti finti ---
finto <- function(tissue = "liver", donor = NA, agenti = "drugx", dur = "24") {
  list(cell_context = list(tissue = tissue, cell_type_or_line_raw = "hepatocyte", context_kind = "primary"),
       disease_state = list(status = "none"), patient_metadata = list(donor_id = donor),
       perturbations = lapply(agenti, function(a) list(kind = if (a == "dmso") "vehicle_only" else "chemical", agent_raw = a,
                                                       duration = list(value_hours = dur, is_zero_timepoint = FALSE), is_negative_control = a == "dmso")))
}
caso <- function(rt, rc, tt = rt, tc = rc, ch = character()) list(rapp = list(t = lapply(rt, valori), c = lapply(rc, valori)),
                                                                 tutti = list(t = lapply(tt, valori), c = lapply(tc, valori)), kind = "small_molecule", fam_chiavi = ch)
prove <- list(
  "A-unione" = classe_di(caso(list(finto(), finto(tissue = "lung")), list(finto(agenti = "dmso"))), FAMIGLIE)$sotto,
  "A-scelta" = classe_di(caso(list(finto()), list(finto(tissue = "lung", agenti = "dmso"))), FAMIGLIE)$sotto,
  "B" = classe_di(caso(list(finto(donor = "d1")), list(finto(donor = "d1", agenti = "dmso")),
                       tt = list(finto(donor = "d1"), finto(donor = "d2")), tc = list(finto(donor = "d1", agenti = "dmso"), finto(donor = "d1", agenti = "dmso"))), FAMIGLIE)$sotto,
  "C" = classe_di(caso(list(finto()), list(finto(agenti = "dmso")), ch = "materiale"), FAMIGLIE)$sotto,
  "D" = classe_di(caso(list(finto()), list(finto(agenti = "dmso"))), FAMIGLIE)$sotto)
g4 <- identical(unname(unlist(prove)), names(prove))
cat(sprintf("G4 controllo positivo dello strumento: %s (%s)\n", if (g4) "OK" else "FALLITO", paste(names(prove), unlist(prove), sep = "->", collapse = ", ")))
if (!g4) ferma("G4 fallito")

# --- calcolo su tutti i 1.903 ---
V1 <- lapply(F1, valori)
righe <- lapply(seq_len(nrow(ten)), function(i) {
  s <- ten$study_id[i]; gt <- spl(ten$gsm_t[i]); gc <- spl(ten$gsm_c[i])
  ct <- unique(vapply(gt, function(g) cond_di(s, g), "")); cc <- unique(vapply(gc, function(g) cond_di(s, g), ""))
  rt <- vapply(ct, function(k) COND[[s]][[k]]$rapp, ""); rc <- vapply(cc, function(k) COND[[s]][[k]]$rapp, "")
  x <- list(rapp = list(t = V1[rt], c = V1[rc]), tutti = list(t = V1[gt], c = V1[gc]), kind = ten$kind[i],
            fam_chiavi = fam_chiavi(chiavi_c(ten$record_id[i])))
  tutte <- classe_di(x, FAMIGLIE)
  pt <- if (ten$difettoso[i]) classe_tipi(x, TIPI[[ten$record_id[i]]]) else list(classe = NA, sotto = NA, campi_au = NA, campi_as = NA, campi_b = NA)
  data.frame(record_id = ten$record_id[i], study_id = s, difettoso = ten$difettoso[i], kind = ten$kind[i],
             tipi = if (ten$difettoso[i]) paste(TIPI[[ten$record_id[i]]], collapse = " ") else "",
             n_cond_t = length(ct), n_cond_c = length(cc), classe = pt$classe, sotto = pt$sotto,
             campi_au = pt$campi_au, campi_as = pt$campi_as, campi_b = pt$campi_b,
             classe_tutte = tutte$classe, sotto_tutte = tutte$sotto, tutte_au = tutte$campi_au, tutte_as = tutte$campi_as, tutte_b = tutte$campi_b,
             chiavi_ingresso = paste(x$fam_chiavi, collapse = " "), stringsAsFactors = FALSE)
})
R <- do.call(rbind, righe)

# --- G5: controllo positivo sui dati ---
et <- rif$record_id[rif$fonte == "etichetta" & !vapply(rif$record_id, function(r) identical(TIPI[[r]], "entita_diversa"), TRUE)]
g5 <- R$classe_tutte[match(et, R$record_id)] == "A"
cat(sprintf("G5 difetti visibili nelle etichette dello Stadio 2 in classe A (tutte le famiglie): %s (soglia 80%%)\n", fmt(sum(g5), length(g5))))
if (sum(g5) / length(g5) < 0.80) { write.csv(R, file.path(DIR, "130-diagnosi.csv"), row.names = FALSE); ferma("G5 fallito: lo strumento e' cieco") }

# --- S14: gli stessi bracci tornano nel master S14 dello Stadio 2? ---
l14 <- readLines(S14_S2); l14 <- l14[sid_di(l14) %in% studi]
COPPIE14 <- list()
for (l in l14) { r <- fromJSON(l, simplifyVector = FALSE); s <- as.character(r$series_id)
  gg <- setNames(lapply(r$replicate_groups, function(g) paste(sort(as.character(unlist(g$sample_ids))), collapse = ",")), vapply(r$replicate_groups, function(g) as.character(g$group_id), ""))
  COPPIE14[[s]] <- unique(c(COPPIE14[[s]], vapply(r$comparisons, function(cp) paste(gg[[as.character(cp$treated_group)]] %||% "?", gg[[as.character(cp$control_group)]] %||% "?", sep = "||"), ""))) }
R$s14_uguale <- vapply(seq_len(nrow(ten)), function(i) paste(paste(spl(ten$gsm_t[i]), collapse = ","), paste(spl(ten$gsm_c[i]), collapse = ","), sep = "||") %in% COPPIE14[[ten$study_id[i]]], TRUE)
write.csv(R, file.path(DIR, "130-diagnosi.csv"), row.names = FALSE)

# --- previsioni ---
d <- R[R$difettoso, ]; p <- R[!R$difettoso, ]
cat("\n== classi dei 473 difetti (per tipo) ==\n")
for (k in c("A", "B", "C", "D", "E")) cat(sprintf("  %s: %s\n", k, fmt(sum(d$classe == k), nrow(d))))
cat(sprintf("  di cui A-unione: %s; A-scelta: %s\n", fmt(sum(d$sotto == "A-unione"), nrow(d)), fmt(sum(d$sotto == "A-scelta"), nrow(d))))
cat("\n== classi con tutte le famiglie: difettosi e puliti ==\n")
for (k in c("A", "B", "C", "D")) cat(sprintf("  %s: difettosi %s | puliti %s\n", k, fmt(sum(d$classe_tutte == k), nrow(d)), fmt(sum(p$classe_tutte == k), nrow(p))))
cat(sprintf("  A-unione: difettosi %s | puliti %s\n", fmt(sum(d$sotto_tutte == "A-unione"), nrow(d)), fmt(sum(p$sotto_tutte == "A-unione"), nrow(p))))
multi <- R$n_cond_t >= 2 | R$n_cond_c >= 2
cat(sprintf("\nbraccio di 2+ condizioni: difettosi %s | puliti %s\n", fmt(sum(multi[R$difettoso]), nrow(d)), fmt(sum(multi[!R$difettoso]), nrow(p))))
cat(sprintf("  trattato di 2+ condizioni: difettosi %d, puliti %d; controllo di 2+ condizioni: difettosi %d, puliti %d\n",
            sum(d$n_cond_t >= 2), sum(p$n_cond_t >= 2), sum(d$n_cond_c >= 2), sum(p$n_cond_c >= 2)))
boot <- function(stat) {
  set.seed(SEME); st <- unique(R$study_id); idx <- split(seq_len(nrow(R)), R$study_id)
  v <- replicate(B, { s <- sample(st, length(st), replace = TRUE); j <- unlist(idx[s], use.names = FALSE); stat(R[j, ]) })
  quantile(v, c(0.025, 0.975))
}
dA <- function(X) 100 * (mean(X$classe_tutte[X$difettoso] == "A") - mean(X$classe_tutte[!X$difettoso] == "A"))
dM <- function(X) { m <- X$n_cond_t >= 2 | X$n_cond_c >= 2; 100 * (mean(m[X$difettoso]) - mean(m[!X$difettoso])) }
ci <- boot(dA); cat(sprintf("D7 classe A, difettosi meno puliti: %+.1f punti [%+.1f; %+.1f] (bootstrap per studio, B=%d)\n", dA(R), ci[1], ci[2], B))
ci <- boot(dM); cat(sprintf("D8 braccio di 2+ condizioni, difettosi meno puliti: %+.1f punti [%+.1f; %+.1f]\n", dM(R), ci[1], ci[2]))
cat(sprintf("D9 stessi bracci nel master S14: difettosi %s | puliti %s\n", fmt(sum(d$s14_uguale), nrow(d)), fmt(sum(p$s14_uguale), nrow(p))))

cat("\n== tipo per classe (difetti; un difetto con piu' tipi conta in ogni tipo) ==\n")
tt <- do.call(rbind, lapply(seq_len(nrow(d)), function(i) data.frame(tipo = strsplit(d$tipi[i], " ")[[1]], classe = d$classe[i])))
print(table(tt$tipo, tt$classe))
cat("\n== i 193 e i 280 separati (per tipo) ==\n")
d$origine <- ifelse(d$record_id %in% rif$record_id, "193", "280"); print(table(d$origine, d$sotto))
cat("\n== campi che fanno la classe A (per tipo): quante volte, fra i difetti ==\n")
k <- table(sub(":.*", "", unlist(strsplit(paste(d$campi_au, d$campi_as, sep = "|"), "\\|")))); print(sort(k[nzchar(names(k))], decreasing = TRUE))
cat("\n== campi fra i bracci (A-scelta, tutte le famiglie): difettosi contro puliti, quota dei confronti ==\n")
campi <- function(X) { z <- lapply(X$tutte_as, function(s) unique(strsplit(s, "\\|")[[1]])); table(unlist(z)) }
kd <- campi(d); kp <- campi(p); nm <- union(names(kd), names(kp)); nm <- nm[nzchar(nm)]
tab <- data.frame(campo = nm, difettosi = as.integer(kd[nm]), puliti = as.integer(kp[nm])); tab[is.na(tab)] <- 0L
tab$q_dif <- round(100 * tab$difettosi / nrow(d), 1); tab$q_pul <- round(100 * tab$puliti / nrow(p), 1); tab$scarto <- tab$q_dif - tab$q_pul
print(head(tab[order(-tab$scarto), ], 25), row.names = FALSE)
cat("\n== campi dentro un braccio (A-unione, tutte le famiglie): difettosi contro puliti ==\n")
campi2 <- function(X) table(unlist(lapply(X$tutte_au, function(s) unique(strsplit(s, "\\|")[[1]]))))
kd <- campi2(d); kp <- campi2(p); nm <- union(names(kd), names(kp)); nm <- nm[nzchar(nm)]
tab2 <- data.frame(campo = nm, difettosi = as.integer(kd[nm]), puliti = as.integer(kp[nm])); tab2[is.na(tab2)] <- 0L
tab2$q_dif <- round(100 * tab2$difettosi / nrow(d), 1); tab2$q_pul <- round(100 * tab2$puliti / nrow(p), 1); tab2$scarto <- tab2$q_dif - tab2$q_pul
print(head(tab2[order(-tab2$scarto), ], 20), row.names = FALSE)
cat("DIAGNOSI FINITA\n")
