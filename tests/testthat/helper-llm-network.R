# helper-llm-network.R --- guardia per i test che chiamano DAVVERO un LLM.
#
# PERCHE' NON BASTA `nzchar(OPENAI_API_KEY)`. Misurato il 2026-07-31: la chiave
# nell'ambiente c'e' (164 caratteri, comincia per `sk-`) ma il server risponde
# **HTTP 401** — e' scaduta o revocata. La guardia vecchia la lasciava passare e
# tre test fallivano a ogni esecuzione della suite. Un test che fallisce per una
# credenziale scaduta e' rumore, e il rumore nasconde i fallimenti veri: e'
# esattamente il modo in cui due ERROR sono rimasti in giro per due mesi.
#
# Non si puo' validare una chiave senza spendere una chiamata, quindi la
# condizione giusta non e' "la chiave sembra esserci" ma **"qualcuno ha detto
# esplicitamente di volerli eseguire"**. Questi test costano denaro e dipendono
# da un servizio esterno: non devono girare per default.
#
# Per eseguirli:
#   SIMULOMICSR_LLM_SMOKE=1 Rscript -e 'devtools::test(filter = "smoke-e2e")'

skip_if_no_llm_smoke <- function() {
  testthat::skip_on_cran()
  if (!identical(Sys.getenv("SIMULOMICSR_LLM_SMOKE"), "1")) {
    testthat::skip(paste(
      "test di rete verso un LLM: servono spesa e servizio esterno.",
      "Eseguire con SIMULOMICSR_LLM_SMOKE=1."
    ))
  }
  if (!nzchar(Sys.getenv("OPENAI_API_KEY"))) {
    testthat::skip("SIMULOMICSR_LLM_SMOKE=1 ma OPENAI_API_KEY non impostata.")
  }
  invisible(TRUE)
}
