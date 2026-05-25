test_that("Stage 3 v3.1 perf budget: 90 min wall-time, 8 GB memory peak", {
  # Budget v3.1 (ADR-0018, validato 2026-05-25 sessione S2):
  #   - wall: 76.6 min su 879k stage1 + 39k stage2 record (laptop 251 GB)
  #   - peak memory delta Vcells*8: 6.75 GB
  # Overhead vs v3 baseline (15 min / 4 GB):
  #   ~60 min aggiuntivi su Phase 6 summarize_clusters per resolve_agent_canonical
  #   + infer_kind_from_ontology lookup su 390k cluster.
  # Budget v3.1 setting: 90 min wall + 8 GB memory (cushion ~15% sui valori 2026-05-25).
  skip_on_ci()
  skip_on_cran()

  # Path relativi a tests/testthat/ (working dir di testthat durante il run)
  s2_path <- testthat::test_path(
    "..", "..",
    "analysis", "p4-output", "p4-beta-stage2-master-rescued-collect.rds"
  )
  s1_path <- testthat::test_path(
    "..", "..",
    "analysis", "p4-output", "p4-beta-stage1-master-predictions-rescued.jsonl"
  )

  skip_if_not(file.exists(s2_path), "beta stage2 master output not present")
  skip_if_not(file.exists(s1_path), "beta stage1 master output not present")

  # Reset GC stats e misura baseline memoria (Vcells * 8 bytes proxy su 64-bit)
  gc(reset = TRUE)
  gc_before <- gc()
  mem_before_vcells <- gc_before["Vcells", "used"]

  start_time <- Sys.time()

  s3 <- simulomicsr::build_stage3_clusters(
    stage1_master   = s1_path,
    stage2_master   = s2_path,
    archs4_metadata = NULL  # skip h5 load per isolamento perf
  )

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Peak memory: max used Vcells durante il run (gc reset = TRUE sopra)
  gc_after <- gc()
  peak_vcells <- gc_after["Vcells", "max used"]
  peak_mem_gb <- (peak_vcells - mem_before_vcells) * 8 / 1e9

  cli::cli_inform("Stage 3 wall-time: {round(elapsed, 1)}s ({round(elapsed/60, 1)} min)")
  cli::cli_inform("Stage 3 peak memory delta (Vcells*8): {round(peak_mem_gb, 2)} GB")
  cli::cli_inform("Stage 3 output: {nrow(s3$clusters)} cluster, {nrow(s3$assignments)} assignments")

  expect_lt(elapsed, 90 * 60)  # budget v3.1: 90 minuti (~15% cushion su 76.6 min)
  expect_lt(peak_mem_gb, 8)    # budget v3.1: 8 GB delta (~18% cushion su 6.75 GB)
})
