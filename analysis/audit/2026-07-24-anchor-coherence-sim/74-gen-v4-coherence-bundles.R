suppressPackageStartupMessages({library(dplyr); library(jsonlite)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC,"fase1-v4-results.rds")); pm <- r$pm
elig <- pm[pm$elig,]
# poolabili k>=3
agg <- elig |> group_by(ckey) |> summarise(k=n_distinct(study_id), n=n(),
  src=ifelse(startsWith(entity[1],"NAME:"),"NAME",ifelse(startsWith(entity[1],"STR:"),"STR","onto")),
  cls=dom_cls[1], .groups="drop") |> filter(k>=3)
cat("poolabili k>=3:", nrow(agg), " per fonte:\n"); print(table(agg$src)); print(table(agg$cls))

# campione STRATIFICATO: prendi da ogni (src x cls) fino a copertura, priorità ai rischiosi (STR/NAME) e k alto
set_seed_order <- function(x) x[order(-x$k),]  # deterministico per k
pick <- function(df, m){ df <- df[order(-df$k),]; head(df$ckey, m) }
sel <- c(
  pick(agg[agg$src=="STR",], 16),      # i più a rischio (etichetta non ontologica)
  pick(agg[agg$src=="NAME",], 14),     # nome ereditato (rischio merge grezzo)
  pick(agg[agg$src=="onto",], 10)      # ontologia (dovrebbero essere puliti)
)
sel <- unique(sel)
cat("campione selezionato:", length(sel), "\n")

con <- file(file.path(SC,"v4_bundles.jsonl"),"w")
for(kk in sel){
  m <- elig[elig$ckey==kk,]
  m$tuple <- sprintf("%s  =>  %s   [%s]", substr(m$treated_label,1,70), substr(m$control_label,1,70), m$design_kind)
  tab <- sort(table(m$tuple), decreasing=TRUE)
  b <- list(ckey=kk, entity=m$entity[1], control_type=sub("^[^|]*\\|\\|","",kk),
            k_studies=length(unique(m$study_id)), n_members=nrow(m),
            contrasts_dedup=unname(sprintf("%dx  %s", as.integer(tab), names(tab)))[seq_len(min(22,length(tab)))])
  writeLines(toJSON(b, auto_unbox=TRUE, null="null"), con)
}
close(con)
cat("scritto v4_bundles.jsonl\n")
