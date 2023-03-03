compose_pxds <- function(n) {
  checkmate::check_integerish(n)
  sprintf("PXD%06d", n)
}
