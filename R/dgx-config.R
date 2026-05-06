#' Configurazione per i run P4 sulla DGX UniPD HPC
#'
#' Restituisce un oggetto `simulomicsr_dgx_config` con i parametri di accesso
#' al cluster (login, partizione SLURM, account, nodelist) e le path remote
#' usate da `dgx_p4_submit()` / `dgx_p4_collect()`. I default sono cuciti per
#' il setup attuale dell'utente (UniPD HPC, account `dctv_dgx`, nodelist
#' `poddgx02`, login user `u0044`); ogni campo e' pero' overridable.
#'
#' @param login_user user SSH sul login node DGX. Default `"u0044"`.
#' @param login_host hostname login node. Default
#'   `"logindgx.hpc.ict.unipd.it"`.
#' @param mail_user mail per notifiche SLURM (`#SBATCH --mail-user`).
#'   Default `"luca.vedovelli@unipd.it"`.
#' @param partition partizione SLURM. Default `"dgx12cluster"`.
#' @param account account SLURM. Default `"dctv_dgx"`.
#' @param nodelist nodelist SLURM. Default `"poddgx02"`.
#' @param remote_root root remoto del workspace P4. Default
#'   `"/mnt/home/<login_user>/simulomicsr-dgx"`.
#' @param ssh_key_path path opzionale a private key SSH. `NULL` significa
#'   usa la default (id_rsa o ssh-agent).
#' @param ... interno, intercetta argomenti non riconosciuti per
#'   produrre un errore esplicito invece del default R "argument unused".
#' @return oggetto `simulomicsr_dgx_config`.
#' @export
dgx_config <- function(login_user  = "u0044",
                       login_host  = "logindgx.hpc.ict.unipd.it",
                       mail_user   = "luca.vedovelli@unipd.it",
                       partition   = "dgx12cluster",
                       account     = "dctv_dgx",
                       nodelist    = "poddgx02",
                       remote_root = NULL,
                       ssh_key_path = NULL,
                       ...) {

  known <- c("login_user", "login_host", "mail_user",
             "partition", "account", "nodelist",
             "remote_root", "ssh_key_path")

  args <- list(login_user = login_user, login_host = login_host,
               mail_user = mail_user, partition = partition,
               account = account, nodelist = nodelist,
               remote_root = remote_root, ssh_key_path = ssh_key_path)

  unknown <- setdiff(names(match.call())[-1], known)
  if (length(unknown) > 0) {
    cli::cli_abort(
      "Campi sconosciuti: {.field {unknown}}",
      class = "simulomicsr_dgx_config_unknown_field"
    )
  }

  for (nm in c("login_user", "login_host", "mail_user",
               "partition", "account", "nodelist")) {
    val <- args[[nm]]
    if (!is.character(val) || length(val) != 1L || !nzchar(val)) {
      cli::cli_abort(
        "{.field {nm}} deve essere una singola stringa non vuota.",
        class = "simulomicsr_dgx_config_invalid"
      )
    }
  }

  if (!is.null(ssh_key_path)) {
    if (!is.character(ssh_key_path) || length(ssh_key_path) != 1L || !nzchar(ssh_key_path)) {
      cli::cli_abort(
        "{.field ssh_key_path} deve essere NULL oppure una singola stringa non vuota.",
        class = "simulomicsr_dgx_config_invalid"
      )
    }
  }

  if (is.null(remote_root)) {
    remote_root <- paste0("/mnt/home/", login_user, "/simulomicsr-dgx")
  }

  cfg <- structure(
    list(
      login_user   = login_user,
      login_host   = login_host,
      mail_user    = mail_user,
      partition    = partition,
      account      = account,
      nodelist     = nodelist,
      remote_root  = remote_root,
      ssh_key_path = ssh_key_path
    ),
    class = "simulomicsr_dgx_config"
  )

  cfg
}

#' @export
print.simulomicsr_dgx_config <- function(x, ...) {
  cat("simulomicsr DGX config\n")
  cat("Login:", x$login_user, "@", x$login_host, "\n")
  cat("Mail: ", x$mail_user, "\n")
  cat("SLURM: partition=", x$partition,
      " account=", x$account,
      " nodelist=", x$nodelist, "\n", sep = "")
  cat("Remote root:", x$remote_root, "\n")
  if (!is.null(x$ssh_key_path))
    cat("SSH key:", x$ssh_key_path, "\n")
  invisible(x)
}
