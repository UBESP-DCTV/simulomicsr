# Variabili d'ambiente aggiuntive per il container (VLLM_BATCH_INVARIANT & c.)
#
# Contesto: il template SLURM passava tre `--env` fissi e non c'era modo di
# aggiungerne. La misura della riproducibilita' del 2026-08-09 era stata fatta
# con uno script mai committato: `grep -r VLLM_BATCH_INVARIANT` sul repo dava
# ZERO. Qui la flag diventa codice, e -- soprattutto -- il job registra
# l'ambiente che ha ricevuto DAVVERO, perche' una variabile scritta nello script
# e non arrivata al processo e' lo stesso modo di fallire del collasso delle
# corsie (spento per un intero re-pool con un warning sepolto).

test_that(".dgx_format_env_lines rende una riga --env per variabile", {
  out <- .dgx_format_env_lines(c(VLLM_BATCH_INVARIANT = "1"))
  expect_match(out, '--env "VLLM_BATCH_INVARIANT=1"', fixed = TRUE)
  expect_match(out, "\\\\$")  # continuazione di riga per il comando singularity
})

test_that(".dgx_format_env_lines rende piu' variabili, una per riga", {
  out <- .dgx_format_env_lines(c(A = "1", B = "due"))
  righe <- strsplit(out, "\n", fixed = TRUE)[[1]]
  expect_length(righe, 2L)
  expect_match(righe[[1]], '--env "A=1"', fixed = TRUE)
  expect_match(righe[[2]], '--env "B=due"', fixed = TRUE)
})

test_that(".dgx_format_env_lines senza variabili non aggiunge alcuna --env", {
  expect_false(grepl("--env", .dgx_format_env_lines(NULL), fixed = TRUE))
  expect_false(grepl("--env", .dgx_format_env_lines(character(0)), fixed = TRUE))
})

test_that(".dgx_format_env_lines senza variabili NON restituisce una riga vuota", {
  # Il segnaposto sta dentro un comando continuato con `\`: una riga vuota lo
  # chiude e singularity riceve zero argomenti (job 35590/35591 FAILED il
  # 2026-08-16). Deve restare una continuazione valida.
  for (v in list(NULL, character(0))) {
    out <- .dgx_format_env_lines(v)
    expect_false(grepl("^[[:space:]]*$", out))
    expect_match(out, "\\\\$")
  }
})

# --- casi NEGATIVI: la direzione in cui lo strumento sbaglia senza dare segno --

test_that(".dgx_format_env_lines rifiuta un vettore senza nomi", {
  expect_error(.dgx_format_env_lines("1"),
               class = "simulomicsr_dgx_env_invalid")
  expect_error(.dgx_format_env_lines(c(A = "1", "2")),
               class = "simulomicsr_dgx_env_invalid")
})

test_that(".dgx_format_env_lines rifiuta nomi non validi per una shell", {
  expect_error(.dgx_format_env_lines(c("A B" = "1")),
               class = "simulomicsr_dgx_env_invalid")
  expect_error(.dgx_format_env_lines(c("A=B" = "1")),
               class = "simulomicsr_dgx_env_invalid")
  expect_error(.dgx_format_env_lines(c("1A" = "1")),
               class = "simulomicsr_dgx_env_invalid")
})

test_that(".dgx_format_env_lines rifiuta valori che romperebbero le virgolette", {
  # Un valore con `"` o `$` o backtick uscirebbe dalle virgolette del template
  # e finirebbe interpretato dalla shell del nodo.
  expect_error(.dgx_format_env_lines(c(A = 'x"y')),
               class = "simulomicsr_dgx_env_invalid")
  expect_error(.dgx_format_env_lines(c(A = "x`id`")),
               class = "simulomicsr_dgx_env_invalid")
  expect_error(.dgx_format_env_lines(c(A = "x$y")),
               class = "simulomicsr_dgx_env_invalid")
  expect_error(.dgx_format_env_lines(c(A = "x\ny")),
               class = "simulomicsr_dgx_env_invalid")
})

test_that(".dgx_format_env_lines rifiuta NA", {
  expect_error(.dgx_format_env_lines(c(A = NA_character_)),
               class = "simulomicsr_dgx_env_invalid")
})

# --- il template ------------------------------------------------------------

test_that("il template SLURM espone il segnaposto delle env aggiuntive", {
  tmpl_path <- system.file("dgx", "slurm", "run_p4.sh", package = "simulomicsr")
  skip_if(!nzchar(tmpl_path), "template non trovato")
  tmpl <- paste(readLines(tmpl_path, warn = FALSE), collapse = "\n")
  expect_match(tmpl, "__EXTRA_ENV__", fixed = TRUE)
})

test_that("il template registra l'ambiente ricevuto DAVVERO dal container", {
  # Non basta scrivere la variabile: il job deve lasciare la prova che e'
  # arrivata al processo. Senza questo, una env persa non da' alcun segno.
  tmpl_path <- system.file("dgx", "slurm", "run_p4.sh", package = "simulomicsr")
  skip_if(!nzchar(tmpl_path), "template non trovato")
  tmpl <- paste(readLines(tmpl_path, warn = FALSE), collapse = "\n")
  expect_match(tmpl, "container-env.txt", fixed = TRUE)
})

test_that("il render risolve il segnaposto e non ne lascia altri", {
  tmpl <- "riga1 __EXTRA_ENV__\nriga2 __RUN_ID__"
  out <- .dgx_render_slurm_template(tmpl, extra_env = "", run_id = "abc")
  expect_false(grepl("__", out, fixed = TRUE))
})

# --- integrazione: dgx_p4_submit(env=) --------------------------------------

.mk_bundle_finto <- function(dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  structure(
    list(run_id = "20260101T000000Z-test-abc123",
         stage = "stage1",
         bundle_dir = dir,
         config = dgx_config(login_user = "u0044", mail_user = "x@y.z")),
    class = "simulomicsr_dgx_bundle")
}

test_that("dgx_p4_submit(env=) scrive la riga --env nello script renderizzato", {
  d <- withr::local_tempdir()
  b <- .mk_bundle_finto(file.path(d, "b"))
  job <- dgx_p4_submit(b, dry_run = TRUE,
                       env = c(VLLM_BATCH_INVARIANT = "1"))
  sh <- paste(readLines(job$rendered_slurm, warn = FALSE), collapse = "\n")
  expect_match(sh, '--env "VLLM_BATCH_INVARIANT=1"', fixed = TRUE)
})

test_that("dgx_p4_submit senza env NON scrive alcuna riga aggiuntiva", {
  # Caso negativo del precedente: se lo script contenesse la flag anche quando
  # non la si chiede, il test positivo passerebbe per costruzione.
  d <- withr::local_tempdir()
  b <- .mk_bundle_finto(file.path(d, "b"))
  job <- dgx_p4_submit(b, dry_run = TRUE)
  sh <- paste(readLines(job$rendered_slurm, warn = FALSE), collapse = "\n")
  expect_false(grepl("VLLM_BATCH_INVARIANT", sh, fixed = TRUE))
})

test_that("lo script renderizzato e' shell VALIDA, con e senza env", {
  # ⚠️ Questo e' il test che mancava. Quello sopra guarda l'ETICHETTA (la
  # stringa c'e' / non c'e'); questo guarda l'ULTIMO ANELLO: che cosa la shell
  # fara' davvero. Senza di lui, il 2026-08-16 due job sono partiti con uno
  # script in cui una riga vuota chiudeva la continuazione di `singularity
  # exec`, che e' finito senza argomenti.
  skip_if(Sys.which("bash") == "", "bash non disponibile")
  d <- withr::local_tempdir()
  for (env in list(NULL, c(VLLM_BATCH_INVARIANT = "1"))) {
    b <- .mk_bundle_finto(file.path(d, paste0("b", length(env))))
    job <- dgx_p4_submit(b, dry_run = TRUE, env = env)
    res <- system2("bash", c("-n", shQuote(job$rendered_slurm)),
                   stdout = TRUE, stderr = TRUE)
    expect_identical(attr(res, "status"), NULL)   # bash -n senza errori

    # ⚠️ `bash -n` NON vede il difetto del 2026-08-16: lo script rotto era
    # sintatticamente VALIDO -- una riga vuota chiude una continuazione, non e'
    # un errore di sintassi. Verificato: con extra_env="" `bash -n` passa lo
    # stesso. L'asserzione che porta il peso e' quella qui sotto. `bash -n`
    # resta perche' costa nulla e prende altre classi di errore.
    #
    # Il comando singularity deve restare UNO: nessuna riga vuota fra
    # `singularity exec` e l'immagine .sif.
    righe <- readLines(job$rendered_slurm, warn = FALSE)
    i_exec <- grep("SINGULARITY_BIN\" exec", righe, fixed = TRUE)
    i_sif  <- grep("simulomicsr-vllm.sif", righe, fixed = TRUE)
    expect_gt(length(i_exec), 0L)
    for (k in seq_along(i_exec)) {
      blocco <- righe[i_exec[[k]]:i_sif[[k]]]
      expect_false(any(grepl("^[[:space:]]*$", blocco)))
    }
  }
})

test_that("dgx_p4_submit propaga l'errore su env non valide", {
  d <- withr::local_tempdir()
  b <- .mk_bundle_finto(file.path(d, "b"))
  expect_error(dgx_p4_submit(b, dry_run = TRUE, env = c(A = 'x"y')),
               class = "simulomicsr_dgx_env_invalid")
})
