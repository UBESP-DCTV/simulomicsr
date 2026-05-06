test_that("dgx_config() default usa profilo UniPD HPC u0044", {
  cfg <- dgx_config()
  expect_s3_class(cfg, "simulomicsr_dgx_config")
  expect_identical(cfg$login_user, "u0044")
  expect_identical(cfg$login_host, "logindgx.hpc.ict.unipd.it")
  expect_identical(cfg$mail_user,  "luca.vedovelli@unipd.it")
  expect_identical(cfg$partition,  "dgx12cluster")
  expect_identical(cfg$account,    "dctv_dgx")
  expect_identical(cfg$nodelist,   "poddgx02")
  expect_identical(cfg$remote_root, "/mnt/home/u0044/simulomicsr-dgx")
})

test_that("dgx_config() override singolo campo lascia altri intatti", {
  cfg <- dgx_config(login_user = "altro")
  expect_identical(cfg$login_user, "altro")
  expect_identical(cfg$mail_user,  "luca.vedovelli@unipd.it")
  expect_identical(cfg$remote_root, "/mnt/home/altro/simulomicsr-dgx")
})

test_that("dgx_config() rifiuta campi non noti", {
  expect_error(
    dgx_config(unknown_field = "x"),
    class = "simulomicsr_dgx_config_unknown_field"
  )
})

test_that("dgx_config() rifiuta tipi non-character", {
  expect_error(dgx_config(login_user = 42), class = "simulomicsr_dgx_config_invalid")
  expect_error(dgx_config(login_user = c("a", "b")), class = "simulomicsr_dgx_config_invalid")
})

test_that("dgx_config() print method mostra campi chiave", {
  cfg <- dgx_config()
  out <- capture.output(print(cfg))
  expect_true(any(grepl("u0044", out)))
  expect_true(any(grepl("poddgx02", out)))
})
