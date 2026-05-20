# Annotation manuale del mini-gold p5-mega-aug-anchor-matching-gold.csv
#
# Annotated 2026-05-20 da Claude Opus 4.7 in delegation di lucavd
# (utente confermato "annotalo tu il minigold, io intervengo se hai dubbi").
#
# Approccio: valutazione biologica caso-per-caso, ignorando la classificazione
# automatica strict/relaxed (per evitare circolarità nella validation della
# policy). I criteri biologici applicati:
#
# - Tier S (kind_effective, agent_id, tissue): match obbligatorio (gia'
#   garantito dal pre-filtering del generator).
# - cell_id: stesso cell type / cell line. Case-insensitive su nomi tessuti
#   generici (Plasma vs plasma OK), case-sensitive su cell line IDs.
# - perturbation context (variant_label, disease_status, phase_canonical):
#   biological compatibility (es. wt vs wt OK; case vs none acceptable per
#   disease_normal pairs).
# - dose/duration: tolerate sui vehicle/baseline pools dove dose=0 o nodose
#   sono equivalenti a "no treatment".
# - has_engineered: TRUE vs FALSE = different biology (engineered cells hanno
#   baseline transcriptome distinto). DUBBIO.
# - cell_id mismatch tra biologically equivalent entities (es. "Plasma" vs
#   "plasma") = match con note paper-grade (suggerisce normalization fix
#   upstream).

suppressPackageStartupMessages({
  library(simulomicsr)
})

IN_CSV  <- "inst/extdata/p5-mega-aug-anchor-matching-gold.csv"
OUT_CSV <- IN_CSV

d <- read.csv(IN_CSV, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 29L)

# Annotation per-riga. Ordine identico al CSV generato (strict_ok 1-10,
# relaxed_only 11-19, mismatch 20-29).
annotations <- list(
  # === STRICT_OK (1-10) ===
  list(label = "match", note = ""),  # 1: prostate primary culture vehicle baseline
  list(label = "match", note = ""),  # 2: blood vehicle CHEBI:36941 (37 studi)
  list(label = "match", note = ""),  # 3: macrophage Listeria vs untreated baseline
  list(label = "match", note = ""),  # 4: Thrombocytes disease_normal, 7 studi baseline
  list(label = "match", note = ""),  # 5: PBMC vehicle (12 studi)
  list(label = "match", note = ""),  # 6: MCF-7 vehicle (60 studi — pool enorme)
  list(label = "match", note = ""),  # 7: prostate primary culture vehicle
  list(label = "match", note = ""),  # 8: blood vehicle (4 studi)
  list(label = "match", note = ""),  # 9: CVCL_0023 lung vehicle (97 studi — pool gigantesco)
  list(label = "match", note = "pair treated context_kind=iPSC_derived vs control e baseline=organoid; MEGA-AUG augmenta solo il control quindi internal pair inconsistency non e' impattante qui"),  # 10: HSC organoid

  # === RELAXED_ONLY (11-19) ===
  list(label = "dubbio",
        note = "pair MCF-7 ha has_engineered=true (modifiche genetiche), baseline MCF-7 ha has_engineered=false (wt). Engineered cells possono avere baseline transcriptome distinto da wt (es. ER overexpression cambia geni a valle). Da escludere se la modifica e' un knockdown/knockout di target gene; OK se solo reporter fluorescente. Senza accesso al sample_facts originale per discriminare, vado conservative."),  # 11
  list(label = "match",
        note = "pair_control dose=0 (placebo) e' biologically equivalente a baseline nodose (untreated). Tier C tolerated correttamente."),  # 12: White Bean vs vehicle PBMC
  list(label = "match", note = ""),  # 13
  list(label = "match", note = ""),  # 14: Glycine max vs vehicle PBMC
  list(label = "match", note = ""),  # 15
  list(label = "match", note = ""),  # 16: L1 Glycine
  list(label = "match", note = ""),  # 17
  list(label = "match", note = ""),  # 18: L1 White Bean
  list(label = "match", note = ""),  # 19

  # === MISMATCH (20-29) ===
  list(label = "no_match",
        note = "Thrombocytes (platelets) vs PBMCs (mixed lymphocytes/monocytes): popolazioni cellulari distinte, transcriptome completamente diverso."),  # 20
  list(label = "no_match",
        note = "Normal human prostate primary stromal cells vs VCaP (prostate cancer cell line): primary vs cancer line, biologicamente incompatibili."),  # 21
  list(label = "no_match",
        note = "CVCL_0023 vs CVCL_0016: due cell line diverse, baseline transcriptome differente."),  # 22
  list(label = "match",
        note = "Pair cell_id='Plasma', baseline cell_id='plasma' — case-sensitive mismatch su entita' biologically identica. Policy automatica li scarta erroneamente. Paper-grade implication: normalizzazione cell_id upstream (Stadio 1/2) o case-insensitive match nel matcher policy."),  # 23
  list(label = "no_match",
        note = "Thrombocytes vs CD19 (B-cells): cell types distinti."),  # 24
  list(label = "no_match",
        note = "Macrophage primary_culture vs Peripheral Blood primary_tissue: cell type specifico vs mix + hard_filter context_kind diverso."),  # 25
  list(label = "dubbio",
        note = "Plasma cell-free RNA vs Plasma generico: cf-RNA e' un molecular fraction (extracellular vesicles/apoptotic bodies) con read distribution diversa dal whole-plasma RNA. Borderline biologicamente; sconsiglierei augmentation senza ulteriore controllo."),  # 26
  list(label = "no_match",
        note = "MCF10A (cell line) vs Adult Human Breast Epithelium (primary tissue): cell line vs primary, transcriptome differente."),  # 27
  list(label = "no_match",
        note = "CVCL_0023 vs H1299: due lung cancer cell line diverse."),  # 28
  list(label = "no_match",
        note = "Thrombocytes vs CD4 T cells: cell types distinti.")  # 29
)

stopifnot(length(annotations) == nrow(d))

d$human_label <- vapply(annotations, function(a) a$label, character(1L))
d$human_note  <- vapply(annotations, function(a) a$note, character(1L))

cat("Distribution of human_label:\n")
print(table(d$human_label))

cat("\nDistribution by stratum + human_label:\n")
print(table(d$stratum, d$human_label))

# === Confusion matrix: policy automatica vs gold ===
# Solo righe con human_label != "dubbio" (per ora) per due 2x2 matrices.
d_clear <- d[d$human_label %in% c("match", "no_match"), ]
d_clear$bio_match <- d_clear$human_label == "match"

cat("\n=== Confusion matrix STRICT policy (n =", nrow(d_clear), "righe non-dubbio) ===\n")
print(table(policy_strict = d_clear$strict_match, biology = d_clear$bio_match))

cat("\n=== Confusion matrix RELAXED policy (default) ===\n")
print(table(policy_relaxed = d_clear$relaxed_match, biology = d_clear$bio_match))

# Metriche
tp_s <- sum(d_clear$strict_match & d_clear$bio_match)
fp_s <- sum(d_clear$strict_match & !d_clear$bio_match)
fn_s <- sum(!d_clear$strict_match & d_clear$bio_match)
tn_s <- sum(!d_clear$strict_match & !d_clear$bio_match)
cat(sprintf("\nSTRICT  sensitivity = %d/%d = %.1f%%   specificity = %d/%d = %.1f%%\n",
             tp_s, tp_s + fn_s, 100 * tp_s / (tp_s + fn_s),
             tn_s, tn_s + fp_s, 100 * tn_s / (tn_s + fp_s)))

tp_r <- sum(d_clear$relaxed_match & d_clear$bio_match)
fp_r <- sum(d_clear$relaxed_match & !d_clear$bio_match)
fn_r <- sum(!d_clear$relaxed_match & d_clear$bio_match)
tn_r <- sum(!d_clear$relaxed_match & !d_clear$bio_match)
cat(sprintf("RELAXED sensitivity = %d/%d = %.1f%%   specificity = %d/%d = %.1f%%\n",
             tp_r, tp_r + fn_r, 100 * tp_r / (tp_r + fn_r),
             tn_r, tn_r + fp_r, 100 * tn_r / (tn_r + fp_r)))

write.csv(d, OUT_CSV, row.names = FALSE)
cat("\n[OK] CSV annotato e sovrascritto a:", OUT_CSV, "\n")
