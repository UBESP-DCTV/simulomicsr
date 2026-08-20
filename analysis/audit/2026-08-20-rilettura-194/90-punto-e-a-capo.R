OUT <- "analysis/audit/2026-08-20-rilettura-194"
q <- read.csv(file.path(OUT,"quadro-194.csv"), stringsAsFactors=FALSE)
d <- read.csv(file.path(OUT,"difetti.csv"), stringsAsFactors=FALSE)

# tasso di difetto PER STUDIO, non per gruppo
n_coppie <- 1178
cat("difetti / coppie gruppo-studio:", nrow(d), "/", n_coppie,
    sprintf(" = %.1f%%\n", 100*nrow(d)/n_coppie))
p <- nrow(d)/n_coppie

# se il difetto fosse indipendente e con questo tasso, quanti gruppi
# risulterebbero difettosi per la sola dimensione?
q$attesa <- 1 - (1-p)^q$k_effective
fasce <- cut(q$k_effective, c(2,4,9,14,Inf), labels=c("k=3-4","k=5-9","k=10-14","k>=15"))
oss <- tapply(q$verdetto_finale %in% c("difettosa"), fasce, mean)
att <- tapply(q$attesa, fasce, mean)
cat("\n  fascia      osservato   atteso-se-solo-dimensione\n")
for (i in seq_along(oss))
  cat(sprintf("  %-10s  %6.1f%%      %6.1f%%\n", names(oss)[i], 100*oss[i], 100*att[i]))

# e se si tolgono gli studi accusati, cosa resta?
acc <- table(d$cluster_id)
q$n_acc <- as.integer(acc[q$cluster_id]); q$n_acc[is.na(q$n_acc)] <- 0L
q$k_dopo <- q$k_effective - q$n_acc
cat("\n=== SE SI TOLGONO GLI STUDI ACCUSATI ===\n")
cat("meta-analisi che restano con k>=3 :", sum(q$k_dopo>=3), "su 194\n")
cat("meta-analisi che scendono sotto 3 :", sum(q$k_dopo<3), "\n")
g <- q[q$k_effective>=15,]
cat("\n  i 14 gruppi piu' grandi, k prima -> dopo:\n")
for (i in order(-g$k_effective)) cat(sprintf("    %-22s %2d -> %2d   (%s)\n",
   substr(g$contrast_entity_label[i],1,22), g$k_effective[i], g$k_dopo[i], g$verdetto_finale[i]))
