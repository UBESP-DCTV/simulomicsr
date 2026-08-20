suppressPackageStartupMessages({ devtools::load_all(".", quiet=TRUE) })
H5 <- "analysis/input/human_gene_v2.5.h5"
f <- c("geo_accession","series_id","library_strategy","library_source","organism_ch1",
       "singlecellprobability","extract_protocol_ch1","title","source_name_ch1","characteristics_ch1")
d <- lapply(setNames(f,f), function(z) as.character(rhdf5::h5read(H5, paste0("meta/samples/",z))))
rhdf5::h5closeAll()
a3 <- read.table("analysis/audit/A3-libsize-scprob-bacino.tsv", sep="\t", header=TRUE, stringsAsFactors=FALSE)
lib <- setNames(a3$lib_size, a3$geo)
for (GSE in c("GSE200186","GSE172442")) {
  k <- which(vapply(strsplit(d$series_id,"[,;\\s]+",perl=TRUE), function(x) GSE %in% x, logical(1)))
  motivi <- vapply(k, function(i) {
    s <- paste0("title: ", d$title[i], ",source: ", d$source_name_ch1[i], ",", d$characteristics_ch1[i])
    r <- simulomicsr:::is_sample_classifiable(
      d$organism_ch1[i], d$library_strategy[i], d$library_source[i],
      d$extract_protocol_ch1[i], d$title[i], d$source_name_ch1[i], s,
      as.numeric(d$singlecellprobability[i]), unname(lib[d$geo_accession[i]]))
    if (isTRUE(r$keep)) "TENUTO" else r$reason
  }, character(1))
  cat("\n===", GSE, "—", length(k), "campioni nell'H5 ===\n")
  print(table(motivi))
}
