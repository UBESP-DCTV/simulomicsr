test_that("compose_pxds works", {
  # setup
  one <- 1
  ten <- 10
  eleven <- 11
  hundredone <- 101
  onetwo <- 1:2

  # test
  expect_equal(compose_pxds(one), "PXD000001")
  expect_equal(compose_pxds(ten), "PXD000010")
  expect_equal(compose_pxds(eleven), "PXD000011")
  expect_equal(compose_pxds(hundredone), "PXD000101")
  expect_equal(compose_pxds(onetwo), c("PXD000001", "PXD000002"))
})
