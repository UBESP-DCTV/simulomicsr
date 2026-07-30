# test-stage4-coherence-annotation.R --- TDD per R/stage4-coherence-annotation.R
#
# I gruppi giudicati incoerenti dal censimento (lettura dei bundle, uno per uno)
# NON vengono scartati dalla pipeline: sarebbe una lista scritta a mano, non una
# regola, e chi rifacesse la pipeline otterrebbe un numero diverso senza sapere
# perche'. Vengono POOLATI e MARCATI, cosi' la selezione resta visibile.
#
# La cosa che questi test difendono davvero: se la marcatura non trova il gruppo
# a cui si riferisce un verdetto, deve FERMARSI. Un verdetto che non attacca
# lascerebbe un gruppo incoerente marcato "coerente" — cioe' il fallimento
# peggiore possibile, silenzioso e a favore della conclusione che ci piace.

.clusters_fixture <- function() {
  data.frame(
    cluster_id = c("cgroup_L5_aaa", "cgroup_L5_bbb", "cgroup_L5_ccc"),
    contrast_entity = c("HGNC:5991", "CHEBI:16412", "STR:ptsd"),
    contrast_direction = c("gain", "gain", "gain"),
    contrast_control_key = c("vehicle_untreated", "vehicle_untreated", "vehicle_untreated"),
    stringsAsFactors = FALSE
  )
}

.verdicts_fixture <- function() {
  data.frame(
    ckey = c("HGNC:5991||gain||vehicle_untreated",
             "STR:ptsd||gain||vehicle_untreated"),
    motivo = c("mescola IL-1alfa e IL-1beta",
               "due studi caso-controllo, il terzo una perturbazione dentro i malati"),
    stringsAsFactors = FALSE
  )
}

test_that("i gruppi elencati fra i verdetti sono marcati incoerenti col motivo", {
  out <- .annotate_coherence(.clusters_fixture(), .verdicts_fixture(),
                             source = "censimento-2026-07-28")
  expect_equal(out$coherence_verdict,
               c("incoherent", "coherent", "incoherent"))
  expect_equal(out$coherence_reason[1], "mescola IL-1alfa e IL-1beta")
})

test_that("i gruppi non elencati sono marcati coerenti, senza motivo", {
  out <- .annotate_coherence(.clusters_fixture(), .verdicts_fixture(),
                             source = "censimento-2026-07-28")
  expect_equal(out$coherence_verdict[2], "coherent")
  expect_true(is.na(out$coherence_reason[2]))
})

test_that("la provenienza del giudizio e' registrata su ogni riga", {
  # Il verdetto e' una lettura umana, non l'output di una regola: chi lo trova
  # nel deliverable deve poter risalire a quando e da dove viene.
  out <- .annotate_coherence(.clusters_fixture(), .verdicts_fixture(),
                             source = "censimento-2026-07-28")
  expect_equal(unique(out$coherence_source), "censimento-2026-07-28")
})

test_that("un verdetto che non trova il suo gruppo FERMA la marcatura", {
  v <- .verdicts_fixture()
  v$ckey[1] <- "HGNC:9999||gain||vehicle_untreated"   # gruppo inesistente
  expect_error(
    .annotate_coherence(.clusters_fixture(), v, source = "x"),
    "HGNC:9999"
  )
})

test_that("righe e ordine dell'input restano invariati", {
  cl  <- .clusters_fixture()
  out <- .annotate_coherence(cl, .verdicts_fixture(), source = "x")
  expect_equal(nrow(out), nrow(cl))
  expect_equal(out$cluster_id, cl$cluster_id)
})

test_that("nessun verdetto: tutti coerenti, nessun errore", {
  vuoto <- data.frame(ckey = character(0), motivo = character(0),
                      stringsAsFactors = FALSE)
  out <- .annotate_coherence(.clusters_fixture(), vuoto, source = "x")
  expect_equal(unique(out$coherence_verdict), "coherent")
})

test_that("la chiave del contrasto puo' arrivare gia' pronta nella colonna ckey", {
  cl <- .clusters_fixture()
  cl$ckey <- paste0(cl$contrast_entity, "||", cl$contrast_direction, "||",
                    cl$contrast_control_key)
  cl$contrast_entity <- NULL   # solo ckey, niente colonne sorgente
  cl$contrast_direction <- NULL
  cl$contrast_control_key <- NULL
  out <- .annotate_coherence(cl, .verdicts_fixture(), source = "x")
  expect_equal(out$coherence_verdict, c("incoherent", "coherent", "incoherent"))
})

test_that("una tabella senza chiave del contrasto e senza colonne per costruirla e' un errore", {
  cl <- data.frame(cluster_id = "cgroup_L5_aaa", stringsAsFactors = FALSE)
  expect_error(.annotate_coherence(cl, .verdicts_fixture(), source = "x"),
               "ckey")
})

test_that("due gruppi con la stessa chiave sono entrambi marcati", {
  # La chiave del contrasto non e' garantita unica: se due gruppi la
  # condividono, il verdetto vale per entrambi e nessuno dei due va perso.
  cl <- .clusters_fixture()
  cl <- rbind(cl, cl[1, ])
  cl$cluster_id[4] <- "cgroup_L5_ddd"
  out <- .annotate_coherence(cl, .verdicts_fixture(), source = "x")
  expect_equal(out$coherence_verdict[c(1, 4)], c("incoherent", "incoherent"))
})
