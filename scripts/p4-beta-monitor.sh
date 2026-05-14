#!/bin/bash
# P4 β cron monitor — wrapper sottile, logica in scripts/p4-beta-monitor.R.
# Setup crontab:
#   0 */2 * * * /home/user/simulomicsr/scripts/p4-beta-monitor.sh >> /home/user/simulomicsr/analysis/p4-beta-monitor.log 2>&1
# Log file (gitignored) accresce con un blocco ogni 2h.
#
# Nota SSH: la chiave ~/.ssh/id_ed25519 e' passphrase-protected, cron non ha
# accesso allo ssh-agent della sessione utente. Workaround: punta a
# /run/user/1000/keyring/ssh (socket di gnome-keyring) che persiste finche'
# l'utente e' loggato graficamente. Se l'utente fa logout / reboot, il monitor
# fallisce su `Permission denied (publickey)` finche' non si rilogga.
# Alternativa permanente: `loginctl enable-linger user` (richiede sudo).

set -uo pipefail
PROJECT_DIR="/home/user/simulomicsr"
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-/run/user/1000/keyring/ssh}"

cd "$PROJECT_DIR" || exit 1
Rscript scripts/p4-beta-monitor.R
