# Perche' il pacchetto da' 1.810 librerie e la misura a mano 1.717.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-12-corsie"
lk <- readRDS(file.path(SC, "94-lookup.rds"))
G  <- readRDS(file.path(SC, "92-guardie.rds"))
A  <- readRDS(file.path(SC, "90-ampiezza.rds"))
pac <- sort(unique(unname(lk)))
man <- sort(G$lib[G$G1 & G$G2 & G$G3])
solo_pac <- setdiff(pac, man); solo_man <- setdiff(man, pac)
cat("solo nel PACCHETTO:", length(solo_pac), "| solo A MANO:", length(solo_man), "\n\n")

tit <- split(A$title, A$lib)
cat("=== SOLO NEL PACCHETTO (per studio) ===\n")
print(utils::head(sort(table(sub("\r.*", "", solo_pac)), decreasing = TRUE), 12))
for (l in utils::head(solo_pac, 6))
  cat("  ", gsub("\r", " | ", l), "->", paste(utils::head(tit[[l]], 3), collapse = " ++ "), "\n")

cat("\n=== SOLO A MANO (per studio) ===\n")
print(utils::head(sort(table(sub("\r.*", "", solo_man)), decreasing = TRUE), 12))
for (l in utils::head(solo_man, 6))
  cat("  ", gsub("\r", " | ", l), "->", paste(utils::head(tit[[l]], 3), collapse = " ++ "), "\n")

cat("\n=== VERIFICA: le chiavi 'solo a mano' contengono 'run'? ===\n")
cat("  con 'run' nel titolo:",
    sum(vapply(solo_man, function(l) any(grepl("run", tolower(tit[[l]]))), logical(1))),
    "su", length(solo_man), "\n")
cat("=== VERIFICA: le chiavi 'solo pacchetto' contengono 'lane'? ===\n")
cat("  con 'lane' nel titolo:",
    sum(vapply(solo_pac, function(l) any(grepl("lane", tolower(tit[[l]]))), logical(1))),
    "su", length(solo_pac), "\n")
