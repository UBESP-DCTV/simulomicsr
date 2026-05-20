# Test per R/stage4-franchini-correction.R
#
# Coprono:
# - .has_shared_baseline()
# - .build_franchini_V_matrix() diagonale quando nessun pool e' condiviso
# - .build_franchini_V_matrix() blocco correlation per shared pool
# - Edge case: NA pool_id (cluster non augmented) restano indipendenti

test_that(".has_shared_baseline FALSE quando tutti i pool_id NA o unici", {
  expect_false(.has_shared_baseline(c(NA_character_, NA_character_, NA_character_)))
  expect_false(.has_shared_baseline(c("pool_a", "pool_b", "pool_c")))
  expect_false(.has_shared_baseline(c("pool_a", NA_character_, "pool_b")))
})

test_that(".has_shared_baseline TRUE quando >= 1 pool_id duplicato", {
  expect_true(.has_shared_baseline(c("pool_a", "pool_a", "pool_b")))
  expect_true(.has_shared_baseline(c("pool_a", "pool_b", "pool_a")))
  expect_true(.has_shared_baseline(c("pool_a", NA_character_, "pool_a")))
})

test_that(".build_franchini_V_matrix produce matrice diagonale senza shared baseline", {
  yi <- c(0.5, -0.3, 1.2)
  vi <- c(0.04, 0.02, 0.08)
  pool_ids <- c("pool_a", "pool_b", NA_character_)
  V <- .build_franchini_V_matrix(yi, vi, pool_ids, rho = 0.5)
  expect_equal(dim(V), c(3L, 3L))
  expect_equal(diag(V), vi)
  # Off-diagonal: tutti zero
  expect_true(all(V[lower.tri(V)] == 0))
  expect_true(all(V[upper.tri(V)] == 0))
})

test_that(".build_franchini_V_matrix popola off-diagonal per pool condiviso", {
  yi <- c(0.5, -0.3, 1.2)
  vi <- c(0.04, 0.02, 0.08)
  pool_ids <- c("pool_a", "pool_a", "pool_b")  # 1+2 condividono pool_a
  V <- .build_franchini_V_matrix(yi, vi, pool_ids, rho = 0.5)
  expect_equal(diag(V), vi)
  # V[1,2] = rho * sqrt(vi[1] * vi[2]) = 0.5 * sqrt(0.04 * 0.02)
  expect_equal(V[1L, 2L], 0.5 * sqrt(0.04 * 0.02))
  expect_equal(V[2L, 1L], 0.5 * sqrt(0.04 * 0.02))
  # V[1,3] e V[2,3] = 0 (pool diversi)
  expect_equal(V[1L, 3L], 0)
  expect_equal(V[2L, 3L], 0)
})

test_that(".build_franchini_V_matrix simmetrica e positiva-definita per casi semplici", {
  yi <- c(0.5, -0.3, 1.2, 0.1)
  vi <- c(0.04, 0.02, 0.08, 0.05)
  pool_ids <- c("pool_a", "pool_a", "pool_b", "pool_b")
  V <- .build_franchini_V_matrix(yi, vi, pool_ids, rho = 0.5)
  # Simmetria
  expect_equal(V, t(V))
  # Positive definite check: tutti eigenvalues > 0
  eig <- eigen(V, only.values = TRUE)$values
  expect_true(all(eig > 0))
})

test_that(".build_franchini_V_matrix NA pool_id non si correla con se' stesso", {
  yi <- c(0.5, -0.3, 1.2)
  vi <- c(0.04, 0.02, 0.08)
  pool_ids <- c(NA_character_, NA_character_, "pool_b")
  # Due NA non devono essere considerati "shared"
  V <- .build_franchini_V_matrix(yi, vi, pool_ids, rho = 0.5)
  expect_equal(V[1L, 2L], 0)
})

test_that(".build_franchini_V_matrix rho=0 produce sempre diagonale", {
  yi <- c(0.5, -0.3, 1.2)
  vi <- c(0.04, 0.02, 0.08)
  pool_ids <- c("pool_a", "pool_a", "pool_b")
  V <- .build_franchini_V_matrix(yi, vi, pool_ids, rho = 0)
  expect_equal(V, diag(vi))
})

test_that(".build_franchini_V_matrix solleva errore se input non paralleli", {
  expect_error(
    .build_franchini_V_matrix(c(0.5, 0.3), c(0.04, 0.02, 0.01),
                                c("pool_a", "pool_a", "pool_b")),
    "stesso numero di elementi"
  )
})
