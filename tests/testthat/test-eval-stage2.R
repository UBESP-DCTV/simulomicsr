test_that("design_role_to_binary mappa correttamente i 13 valori", {
  # treated
  expect_equal(design_role_to_binary("perturbed"), "treated")
  expect_equal(design_role_to_binary("case"), "treated")
  expect_equal(design_role_to_binary("secondary_arm"), "treated")
  # control
  expect_equal(design_role_to_binary("vehicle_control"), "control")
  expect_equal(design_role_to_binary("untreated_control"), "control")
  expect_equal(design_role_to_binary("negative_genetic_control"), "control")
  expect_equal(design_role_to_binary("negative_inducer_control"), "control")
  expect_equal(design_role_to_binary("baseline_t0"), "control")
  expect_equal(design_role_to_binary("comparison"), "control")
  # NA (escluso da metrica)
  expect_true(is.na(design_role_to_binary("bystander")))
  expect_true(is.na(design_role_to_binary("positive_control")))
  expect_true(is.na(design_role_to_binary("excluded")))
  expect_true(is.na(design_role_to_binary("unclear")))
})

test_that("design_role_to_binary errors on unknown role", {
  expect_error(
    design_role_to_binary("not_a_real_role"),
    class = "simulomicsr_invalid_design_role"
  )
})

test_that("design_role_to_binary vectorized: applica element-wise", {
  roles <- c("perturbed", "vehicle_control", "bystander", "case")
  expected <- c("treated", "control", NA_character_, "treated")
  expect_equal(design_role_to_binary(roles), expected)
})

test_that("eval_binary_accuracy: tutti corretti", {
  gold <- c("treated", "treated", "control", "control")
  pred <- c("treated", "treated", "control", "control")
  res <- eval_binary_accuracy(gold, pred)
  expect_equal(res$n, 4L)
  expect_equal(res$accuracy, 1.0)
  expect_equal(res$sensitivity, 1.0)
  expect_equal(res$specificity, 1.0)
  expect_equal(res$f1, 1.0)
})

test_that("eval_binary_accuracy: casi misti", {
  gold <- c("treated", "treated", "control", "control")
  pred <- c("treated", "control", "control", "treated")  # 1 FP, 1 FN
  res <- eval_binary_accuracy(gold, pred)
  expect_equal(res$n, 4L)
  expect_equal(res$accuracy, 0.5)
})

test_that("eval_binary_accuracy: NA esclusi correttamente", {
  gold <- c("treated", "treated", "control", "control", NA)
  pred <- c("treated", "treated", "control", NA, "treated")
  res <- eval_binary_accuracy(gold, pred)
  expect_equal(res$n, 3L)
  expect_equal(res$accuracy, 1.0)
})

test_that("eval_binary_accuracy: confusion matrix struttura corretta", {
  gold <- c("treated", "treated", "control", "control")
  pred <- c("treated", "control", "control", "treated")
  res <- eval_binary_accuracy(gold, pred)
  expect_true(is.matrix(res$confusion_matrix) || is.table(res$confusion_matrix))
  expect_setequal(rownames(res$confusion_matrix), c("treated", "control"))
  expect_setequal(colnames(res$confusion_matrix), c("treated", "control"))
})

test_that("eval_per_design_kind: breakdown per kind", {
  df <- tibble::tibble(
    gold_binary = c("treated", "treated", "control", "control",
                    "treated", "control"),
    predicted_binary = c("treated", "control", "control", "control",
                         "treated", "treated"),
    design_kind = c("time_course", "time_course", "time_course", "time_course",
                    "factorial", "factorial")
  )
  res <- eval_per_design_kind(df)
  expect_true(tibble::is_tibble(res))
  expect_setequal(res$design_kind, c("time_course", "factorial"))
  tc_row <- res[res$design_kind == "time_course", ]
  expect_equal(tc_row$n, 4L)
  expect_equal(tc_row$accuracy, 0.75)
  fc_row <- res[res$design_kind == "factorial", ]
  expect_equal(fc_row$n, 2L)
  expect_equal(fc_row$accuracy, 0.5)
})
