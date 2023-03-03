test_that("pull_pxd_listfile works", {
  # setup
  two_pdxs <- compose_pxds(c(1, 4))
  missing_pdxs <- compose_pxds(2)

  # eval
  res <- pull_pxd_listfile(two_pdxs)

  # test
  expect_length(res, 2L)
  expect_list(res)
  expect_warning(
    pull_pxd_listfile(missing_pdxs),
    regexp = "400 Bad Request"
  )
})
