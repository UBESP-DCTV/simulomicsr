#!/usr/bin/env Rscript
# Quali meta-analisi misurabili hanno una lettera greca nel nome o la parola alpha/beta/gamma: la fragilita' dichiarata dall'handout.
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
x <- fread(file.path(OUT6, "50-copertura-con-tahoe.csv"))[misurabile == TRUE]
g <- x[grepl("[α-ωΑ-Ω]|alpha|beta|gamma|delta", nome, ignore.case = TRUE)]
print(as.data.frame(g[, .(nome, classe, insieme, metodo_match)]), right = FALSE)
cat("composti misurabili con la marca:", g[classe == "piccola molecola", .N], "su", x[classe == "piccola molecola", .N], "; nelle 19:", g[classe == "piccola molecola" & insieme == "40", .N], "\n")
cat("nomi dei ligandi misurabili:", x[classe == "ligando", nome], "\n")
