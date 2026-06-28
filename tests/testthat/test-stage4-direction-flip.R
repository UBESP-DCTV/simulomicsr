# Integration test: direction_flip end-to-end via .run_per_study_de_all
#
# Verifica che cluster con direction_check="swapped" produca logFC negato
# rispetto a un cluster canonical con stesso dispatch e stesse counts.
# Aspettativa: canon$logFC == -swap$logFC e direction_applied "none"/"flipped".

test_that("cluster con direction_check=swapped applica logFC flip in per_study_de", {
  skip_if_not_installed("limma")

  # Build eligible con 1 cluster swapped + 1 canonical
  eligible <- tibble::tibble(
    cluster_id = c("canon_c", "swap_c"),
    method = c("rem", "rem"),
    direction_check = factor(c("canonical", "swapped"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na"))
  )

  # Stesso dispatch per entrambi (so the only difference is direction)
  same_dispatch <- list(
    list(study_id = "GSE_test", treated = c("GSM001","GSM002","GSM003"),
         control = c("GSM004","GSM005","GSM006"))
  )
  attr(eligible, "study_dispatch") <- list(
    canon_c = same_dispatch,
    swap_c  = same_dispatch
  )

  mock_fetch <- function(gse, sample_ids) {
    set.seed(42)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    # Induci diff su primi 5 geni
    m[1:5, 1:3] <- m[1:5, 1:3] * 5
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  result <- .run_per_study_de_all(eligible, fetch_fn = mock_fetch)

  canon <- result[result$cluster_id == "canon_c", ]
  swap  <- result[result$cluster_id == "swap_c", ]

  expect_equal(canon$logFC[order(canon$gene_id)], -swap$logFC[order(swap$gene_id)])
  expect_equal(unique(canon$direction_applied), "none")
  expect_equal(unique(swap$direction_applied), "flipped")
})
