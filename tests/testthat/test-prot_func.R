test_that("pull_pxd_listfile works", {
  # setup
  two_pdxs <- compose_pxds(c(1, 4))
  missing_pdxs <- compose_pxds(2)

  # eval
  res <- pull_pxd_listfile(two_pdxs) |>
    suppressMessages()

  # test
  expect_length(res, 2L)
  expect_list(res)
  expect_warning(
    pull_pxd_listfile(missing_pdxs),
    regexp = "400 Bad Request"
  )
})

test_that("extract_with_proteins works", {
  # setup
  with_prot <- compose_pxds(22)
  no_prot <- compose_pxds(c(1, 4))
  some_pdxs <- c(with_prot, no_prot)

  pxd_NA <- compose_pxds(c(2, 22))

  # eval
  res <- pull_pxd_listfile(some_pdxs) |>
    extract_with_proteins() |>
    suppressMessages()

  res_NA <- pull_pxd_listfile(pxd_NA) |> # PXD2 returns NA
    extract_with_proteins() |>
    suppressMessages()

  # test
  expect_character(res, len = 1L)
  expect_character(res_NA, len = 1L)
  expect_equal(res, with_prot)
})

test_that("get_proteingroups_filepath works", {
  # setup
  prot_22 <- compose_pxds(c(1, 4, 22, 44))

  # eval
  res <- pull_pxd_listfile(prot_22) |>
    extract_with_proteins() |>
    get_proteingroups_filepath() |>
    suppressMessages()

  # test
  expect_character(res, pattern = "proteinGroups\\.txt$", len = 2)
  purrr::walk(res, expect_file_exists)
})

test_that("get_proteingroups_filepath works", {
  # setup
  prot_22 <- compose_pxds(22)

  # eval
  res <- pull_pxd_listfile(prot_22) |>
    extract_with_proteins() |>
    get_proteingroups_filepath() |>
    read_proteingroups()

  # test
  expect_tibble(res)
})



