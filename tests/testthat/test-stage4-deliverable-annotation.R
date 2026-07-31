# test-stage4-deliverable-annotation.R --- TDD: il deliverable annotato deve
# nascere da UNA funzione di pacchetto, non da una sequenza di script di audit.
#
# PERCHE' ESISTE. Le misure di efficacia del pooling e di materiale sono state
# calcolate a mano in `analysis/audit/2026-07-31-layer-b-v13/`. Nessuna e'
# richiamata da un file della pipeline (verificato con grep il 2026-07-31):
# **un re-pool futuro rifarebbe un deliverable senza `k_kish`**, cioe' senza la
# cosa che l'utente ha chiesto di mettere dentro. Un numero che vive solo in uno
# script di audit non e' nel deliverable: e' un'altra cosa che gli somiglia.
#
# LE COSE CHE QUESTI TEST DIFENDONO:
#  1. tutte le colonne escono da una chiamata sola — nessuna cucitura a mano;
#  2. un verdetto di coerenza che non trova il suo gruppo FERMA la funzione
#     (stessa difesa gia' in `.annotate_coherence`): un verdetto orfano
#     lascerebbe un gruppo incoerente marcato "coerente", cioe' il fallimento
#     silenzioso e per giunta a favore della conclusione che fa comodo;
#  3. l'ordine delle righe e' deterministico — due esecuzioni sullo stesso
#     input devono dare lo stesso file, altrimenti ogni diff e' rumore.

.ann_cluster_meta <- function() {
  data.frame(
    cluster_id = c("cg_a", "cg_b"),
    contrast_entity = c("CHEBI:16412", "HGNC:5991"),
    contrast_direction = c("gain", "gain"),
    contrast_control_key = c("vehicle_untreated", "vehicle_untreated"),
    canonical_name = c("lipopolysaccharide", "IL1A"),
    stringsAsFactors = FALSE
  )
}

.ann_pooled <- function() {
  data.frame(
    cluster_id = rep(c("cg_a", "cg_b"), each = 3L),
    gene_id = rep(c("G1", "G2", "G3"), 2L),
    method = "rem_group",
    logFC_pool = 1, SE_pool = 0.1, tau2 = 0, I2 = c(80, 80, 80, 40, 40, 40),
    k_effective = c(3L, 3L, 2L, 2L, 2L, 2L),
    FDR_BH_within_cluster = c(0.01, 0.01, 0.9, 0.01, 0.9, 0.9),
    stringsAsFactors = FALSE
  )
}

.ann_per_arm <- function() {
  rbind(
    data.frame(cluster_id = "cg_a", gene_id = rep(c("G1", "G2"), each = 3L),
               study_id = rep(c("GSE1", "GSE2", "GSE3"), 2L), SE = 0.2,
               stringsAsFactors = FALSE),
    data.frame(cluster_id = "cg_b", gene_id = "G1",
               study_id = c("GSE9", "GSE9", "GSE8"), SE = c(0.01, 0.01, 2),
               stringsAsFactors = FALSE)
  )
}

.ann_labels <- function() {
  rbind(
    data.frame(cluster_id = "cg_a", study_id = c("GSE1", "GSE2", "GSE3"),
               label = c("LPS-treated tissue", "LPS-treated organoid",
                         "LPS-treated biopsy"), stringsAsFactors = FALSE),
    data.frame(cluster_id = "cg_b", study_id = c("GSE9", "GSE8"),
               label = c("IL-1 alpha", "IL-1 beta"), stringsAsFactors = FALSE)
  )
}

test_that("una sola chiamata produce tutte le colonne del deliverable", {
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())

  attese <- c("cluster_id", "k_effective", "n_sig", "I2_med",
              "k_kish", "frazione_efficace", "quota_top1", "dominato",
              "studio_dominante", "materiale_misto", "n_studi_model",
              "n_studi_primary", "n_studi_unknown", "classe_studio_dominante",
              "dominato_da_modello")
  expect_true(all(attese %in% names(out)))
  expect_equal(nrow(out), 2L)
})

test_that("k_effective e' il MASSIMO per cluster, non un valore per gene", {
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())
  expect_equal(out$k_effective[out$cluster_id == "cg_a"], 3L)
})

test_that("n_sig conta i geni sotto la soglia, non tutte le righe", {
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())
  expect_equal(out$n_sig[out$cluster_id == "cg_a"], 2L)
  expect_equal(out$n_sig[out$cluster_id == "cg_b"], 1L)
})

test_that("l'efficacia del pooling coincide con la funzione dedicata", {
  # Non deve esserci una seconda implementazione: l'annotazione compone, non
  # ricalcola. Se i due numeri divergono, uno dei due e' morto.
  tau2 <- .ann_pooled()[.ann_pooled()$FDR_BH_within_cluster < 0.05,
                        c("cluster_id", "gene_id", "tau2")]
  atteso <- compute_pooling_effectiveness(.ann_per_arm(), tau2)
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())

  for (cid in atteso$cluster_id) {
    expect_equal(out$k_kish[out$cluster_id == cid],
                 atteso$k_kish[atteso$cluster_id == cid], tolerance = 1e-12)
  }
})

test_that("dominato_da_modello richiede DOMINANZA, non solo un modello in cima", {
  # Senza la congiunzione con `dominato` la colonna si accendeva su gruppi in cui
  # lo studio "dominante" pesa il 2,5%: errore vero, corretto il 2026-07-31
  # guardando l'output prima di pubblicarlo.
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())

  a <- out[out$cluster_id == "cg_a", ]
  expect_false(a$dominato)            # tre studi con lo stesso SE
  expect_false(a$dominato_da_modello) # quindi non puo' essere dominato da un modello
})

test_that("un verdetto di coerenza senza gruppo FERMA la funzione", {
  v <- data.frame(ckey = "NON:esiste||gain||vehicle_untreated",
                  motivo = "verdetto orfano", stringsAsFactors = FALSE)
  expect_error(
    annotate_stage4_deliverable(
      cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
      cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels(),
      coherence_verdicts = v),
    "non trovano nessun gruppo"
  )
})

test_that("i verdetti che attaccano marcano i gruppi giusti", {
  v <- data.frame(ckey = "HGNC:5991||gain||vehicle_untreated",
                  motivo = "mescola IL-1alfa e IL-1beta", stringsAsFactors = FALSE)
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels(),
    coherence_verdicts = v)

  expect_equal(out$coherence_verdict[out$cluster_id == "cg_b"], "incoherent")
  expect_equal(out$coherence_verdict[out$cluster_id == "cg_a"], "coherent")
})

test_that("l'ordine delle righe e' deterministico", {
  a <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())
  b <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled()[rev(seq_len(nrow(.ann_pooled()))), ],
    per_study_de = .ann_per_arm(), cluster_meta = .ann_cluster_meta(),
    member_labels = .ann_labels())
  expect_equal(a$cluster_id, b$cluster_id)
})

test_that("senza etichette dei membri le colonne di materiale restano NA dichiarate", {
  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = NULL)

  expect_true("materiale_misto" %in% names(out))
  expect_true(all(is.na(out$materiale_misto)))
  # ma l'efficacia del pooling c'e' comunque: non dipende dalle etichette
  expect_false(any(is.na(out$k_kish)))
})

test_that("un cluster poolato assente dai metadati FERMA la funzione", {
  # Un gruppo senza identita' del contrasto uscirebbe con entita' NA e nessuno
  # se ne accorgerebbe leggendo il CSV.
  meta <- .ann_cluster_meta()[1L, ]
  expect_error(
    annotate_stage4_deliverable(
      cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
      cluster_meta = meta, member_labels = .ann_labels()),
    class = "rlang_error"
  )
})

test_that("il materiale si misura sui soli studi POOLATI, non su tutti gli assegnati", {
  # Un gruppo puo' avere studi assegnati che il gate del pooling ha scartato:
  # contarli falserebbe l'asse del materiale. Sui dati v13 la differenza e' fra
  # 1.758 studi-slot assegnati e 1.234 poolati.
  lab_extra <- rbind(
    .ann_labels(),
    data.frame(cluster_id = "cg_a", study_id = "GSE_SCARTATO",
               label = "iPSC-derived organoid", stringsAsFactors = FALSE))

  out_tutti  <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = lab_extra)
  out_poolati <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = .ann_labels())

  # GSE_SCARTATO non e' in per_study_de: non deve contare
  expect_equal(out_tutti$n_studi_model[out_tutti$cluster_id == "cg_a"],
               out_poolati$n_studi_model[out_poolati$cluster_id == "cg_a"])
})

test_that("dice quanti studi sono stati censiti e quanti ne sono entrati nel pool", {
  # Il gate dei controlli interni scarta studi: sui dati v13 il 76% dei gruppi
  # entra nel pool con MENO studi di quelli assegnati (524 persi in totale).
  # Senza queste colonne il lettore non sa che l'insieme e' cambiato.
  lab_extra <- rbind(
    .ann_labels(),
    data.frame(cluster_id = "cg_a", study_id = "GSE_FUORI",
               label = "LPS-treated tissue", stringsAsFactors = FALSE))

  out <- annotate_stage4_deliverable(
    cluster_pooled = .ann_pooled(), per_study_de = .ann_per_arm(),
    cluster_meta = .ann_cluster_meta(), member_labels = lab_extra)

  a <- out[out$cluster_id == "cg_a", ]
  expect_equal(a$n_studi_censiti, 4L)   # 3 nel pool + GSE_FUORI
  expect_equal(a$n_studi_poolati, 3L)
  expect_false(a$stessi_membri)
  expect_equal(a$studi_caduti, "GSE_FUORI")

  b <- out[out$cluster_id == "cg_b", ]
  expect_true(b$stessi_membri)
  expect_equal(b$studi_caduti, "")
})
