# Codice eseguito all'inizio di ogni test.

# Helper: crea una directory temporanea cache per il test corrente,
# pulita automaticamente da withr::defer_parent.
new_cache_dir <- function(env = parent.frame()) {
  d <- fs::path(tempfile(pattern = "cache-test-"))
  fs::dir_create(d)
  withr::defer(fs::dir_delete(d), envir = env)
  d
}
