#!/usr/bin/env Rscript
# A2 delta vs OLD: confronta drop A2 vecchi (regex pre-fix) vs nuovi
# (regex underscore-aware) per quantificare il cambio sui sample che
# entrano/escono dal bacino post-A2.
#
# Riferimento: ultrathink regex audit, sessione 4 RED_ALERT.

old_drop_path <- "analysis/audit/A2-sc-by-extract-protocol.OLD.tsv"
new_drop_path <- "analysis/audit/A2-sc-by-extract-protocol.tsv"

read_drop <- function(p) {
  d <- read.delim(p, sep = "\t", header = TRUE,
                  stringsAsFactors = FALSE, quote = "",
                  fill = TRUE, comment.char = "")
  d$geo
}

old_drop <- read_drop(old_drop_path)
new_drop <- read_drop(new_drop_path)

cat(sprintf("[A2-delta] drop OLD: %d\n", length(old_drop)))
cat(sprintf("[A2-delta] drop NEW: %d\n", length(new_drop)))
cat(sprintf("[A2-delta] delta:    %+d\n", length(new_drop) - length(old_drop)))

# Sample droppati in OLD ma non in NEW = ora rescued (entrano in bacino A3)
rescued_now <- setdiff(old_drop, new_drop)
# Sample droppati in NEW ma non in OLD = nuovi catch (escono da bacino A3)
catch_now <- setdiff(new_drop, old_drop)
# Sample droppati in entrambi = invariati
invariati <- intersect(old_drop, new_drop)

cat(sprintf("\n[A2-delta] === ribaltamenti ===\n"))
cat(sprintf("  ora rescued (in OLD drop, non in NEW)  : %d\n", length(rescued_now)))
cat(sprintf("  nuovi catch (non in OLD, in NEW drop)  : %d\n", length(catch_now)))
cat(sprintf("  invariati (drop in entrambi)           : %d\n", length(invariati)))

cat(sprintf("\n[A2-delta] === bilancio bacino post-A2 ===\n"))
cat(sprintf("  bacino post-A2 OLD: 850225 - %d = %d\n",
            length(old_drop), 850225L - length(old_drop)))
cat(sprintf("  bacino post-A2 NEW: 850225 - %d = %d\n",
            length(new_drop), 850225L - length(new_drop)))

# Salva liste delta per consumo downstream (lookup lib_size sui rescued_now)
writeLines(rescued_now, "analysis/audit/A2-delta-rescued_now.txt")
writeLines(catch_now,   "analysis/audit/A2-delta-catch_now.txt")
cat("\n[A2-delta] liste delta scritte:\n")
cat("  analysis/audit/A2-delta-rescued_now.txt\n")
cat("  analysis/audit/A2-delta-catch_now.txt\n")
