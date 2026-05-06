test_that(".dgx_run_id() ritorna stringhe distinte timestamped", {
  ids <- replicate(5, simulomicsr:::.dgx_run_id("test-slug"))
  expect_length(ids, 5)
  expect_length(unique(ids), 5)
  expect_true(all(grepl("^\\d{8}T\\d{6}Z-test-slug-[a-f0-9]{6}$", ids)))
})

test_that(".dgx_run_id() supporta slug con caratteri non-alfanumerici sanitizzati", {
  id <- simulomicsr:::.dgx_run_id("alpha xlsx (stage1)")
  expect_match(id, "^\\d{8}T\\d{6}Z-alpha-xlsx-stage1-[a-f0-9]{6}$")
})

test_that(".dgx_render_slurm_template() sostituisce tutti i placeholder", {
  tmpl <- "#SBATCH --job-name=__RUN_ID_SHORT__\nUSER=__USER__\nTIME=__TIME__\nMAIL=__MAIL_USER__\nROOT=/mnt/home/__USER__/x"
  out <- simulomicsr:::.dgx_render_slurm_template(
    tmpl,
    run_id      = "20260507T093012Z-alpha-xlsx-stage1-a3f9c1",
    run_id_short = "alpha-xlsx-stage1",
    user        = "u0044",
    time        = "12:00:00",
    mail_user   = "luca.vedovelli@unipd.it"
  )
  expect_false(grepl("__[A-Z_]+__", out))
  expect_match(out, "job-name=alpha-xlsx-stage1")
  expect_match(out, "USER=u0044")
  expect_match(out, "TIME=12:00:00")
  expect_match(out, "MAIL=luca.vedovelli@unipd.it")
  expect_match(out, "ROOT=/mnt/home/u0044/x")
})

test_that(".dgx_run_id_short() estrae lo slug dal run_id pieno", {
  short <- simulomicsr:::.dgx_run_id_short("20260507T093012Z-alpha-xlsx-stage1-a3f9c1")
  expect_identical(short, "alpha-xlsx-stage1")
})
