test_that("dgx_config() default usa profilo UniPD HPC u0044", {
  cfg <- dgx_config()
  expect_s3_class(cfg, "simulomicsr_dgx_config")
  expect_identical(cfg$login_user, "u0044")
  expect_identical(cfg$login_host, "logindgx.hpc.ict.unipd.it")
  expect_identical(cfg$mail_user,  "luca.vedovelli@unipd.it")
  expect_identical(cfg$partition,  "dgx12cluster")
  expect_identical(cfg$account,    "dctv_dgx")
  expect_null(cfg$nodelist)
  expect_identical(cfg$remote_root, "/mnt/home/u0044/simulomicsr-dgx")
})

test_that("dgx_config() valida nodelist opzionale", {
  expect_null(dgx_config()$nodelist)
  expect_identical(dgx_config(nodelist = "poddgx01")$nodelist, "poddgx01")
  expect_error(dgx_config(nodelist = 42), class = "simulomicsr_dgx_config_invalid")
  expect_error(dgx_config(nodelist = ""), class = "simulomicsr_dgx_config_invalid")
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
  expect_true(any(grepl("dgx12cluster", out)))
})

test_that("dgx_config() valida ssh_key_path opzionale", {
  expect_no_error(dgx_config(ssh_key_path = NULL))
  expect_no_error(dgx_config(ssh_key_path = "/home/user/.ssh/id_rsa"))
  expect_error(dgx_config(ssh_key_path = 42), class = "simulomicsr_dgx_config_invalid")
  expect_error(dgx_config(ssh_key_path = ""), class = "simulomicsr_dgx_config_invalid")
  expect_error(dgx_config(ssh_key_path = c("a", "b")), class = "simulomicsr_dgx_config_invalid")
})
