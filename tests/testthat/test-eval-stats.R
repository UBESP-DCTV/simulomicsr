test_that("wilson_ci ritorna intervalli noti per casi standard", {
  ci <- wilson_ci(50L, 100L, conf = 0.95)
  expect_equal(ci$estimate, 0.5)
  expect_equal(ci$lower, 0.4038, tolerance = 0.001)
  expect_equal(ci$upper, 0.5962, tolerance = 0.001)
})

test_that("wilson_ci gestisce p=0 e p=1 senza esplodere", {
  ci_zero <- wilson_ci(0L, 100L, conf = 0.95)
  expect_equal(ci_zero$estimate, 0)
  expect_true(ci_zero$lower >= 0)
  expect_true(ci_zero$upper > 0 && ci_zero$upper < 0.05)

  ci_one <- wilson_ci(100L, 100L, conf = 0.95)
  expect_equal(ci_one$estimate, 1)
  expect_true(ci_one$lower > 0.95 && ci_one$lower < 1)
  expect_equal(ci_one$upper, 1)
})

test_that("wilson_ci gestisce n=0", {
  ci <- wilson_ci(0L, 0L, conf = 0.95)
  expect_true(is.na(ci$estimate))
  expect_true(is.na(ci$lower))
  expect_true(is.na(ci$upper))
})

test_that("mcnemar_paired matcha mcnemar.test base R su esempio noto", {
  pred_a <- c(rep("correct", 30), rep("correct", 20), rep("wrong", 10), rep("wrong", 40))
  pred_b <- c(rep("correct", 30), rep("wrong", 20),   rep("correct", 10), rep("wrong", 40))
  result <- mcnemar_paired(pred_a, pred_b, continuity = FALSE)
  expect_equal(result$statistic, 3.333, tolerance = 0.01)
  expect_equal(result$b, 20L)
  expect_equal(result$c, 10L)
  tab <- table(pred_a, pred_b)
  base_result <- mcnemar.test(tab, correct = FALSE)
  expect_equal(result$statistic, as.numeric(base_result$statistic),
               tolerance = 0.01)
  expect_equal(result$p_value, base_result$p.value, tolerance = 0.001)
})

test_that("mcnemar_paired ritorna p_value alto quando b=c (no disagreement direzionale)", {
  pred_a <- c("correct", "wrong", "correct", "wrong")
  pred_b <- c("wrong", "correct", "wrong", "correct")
  result <- mcnemar_paired(pred_a, pred_b, continuity = FALSE)
  expect_equal(result$b, 2L)
  expect_equal(result$c, 2L)
  expect_true(result$p_value > 0.5)
})

test_that("bootstrap_delta_ci e' deterministico con seed", {
  set.seed(NULL)
  pred_a <- c(rep("correct", 80), rep("wrong", 20))
  pred_b <- c(rep("correct", 70), rep("wrong", 30))
  ci_1 <- bootstrap_delta_ci(pred_a, pred_b, n_iter = 500L, seed = 42L)
  ci_2 <- bootstrap_delta_ci(pred_a, pred_b, n_iter = 500L, seed = 42L)
  expect_equal(ci_1$lower, ci_2$lower)
  expect_equal(ci_1$upper, ci_2$upper)
  expect_equal(ci_1$delta, 0.1, tolerance = 0.001)
})

test_that("bootstrap_delta_ci CI contiene il delta vero", {
  pred_a <- c(rep("correct", 80), rep("wrong", 20))
  pred_b <- c(rep("correct", 70), rep("wrong", 30))
  ci <- bootstrap_delta_ci(pred_a, pred_b, n_iter = 1000L, seed = 1812L,
                           conf = 0.95)
  expect_true(ci$lower < 0.1 && 0.1 < ci$upper)
})

test_that("holm_adjust matcha p.adjust(method='holm') base R", {
  p_values <- c(0.01, 0.02, 0.03, 0.04)
  result <- holm_adjust(p_values)
  expected <- p.adjust(p_values, method = "holm")
  expect_equal(result, expected)
})
