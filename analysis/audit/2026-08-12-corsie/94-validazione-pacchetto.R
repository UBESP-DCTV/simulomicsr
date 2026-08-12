# FASE 3b — Il codice di pacchetto contro la misura fatta a mano, sui DATI VERI.
# (La validazione su fixture non basta: e' la lezione del 2026-07-27, quando una
# regola passata da script a pacchetto aveva perso il vocabolario per strada.)
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"

acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
H <- data.frame(geo_accession = acc,
                title = as.character(rhdf5::h5read(h5, "meta/samples/title")),
                series_id = as.character(rhdf5::h5read(h5, "meta/samples/series_id")),
                characteristics_ch1 = as.character(rhdf5::h5read(h5, "meta/samples/characteristics_ch1")),
                source_name_ch1 = as.character(rhdf5::h5read(h5, "meta/samples/source_name_ch1")),
                stringsAsFactors = FALSE)
rhdf5::h5closeAll()
cat("H5:", nrow(H), "campioni\n")

t0 <- Sys.time()
lk <- build_lane_library_lookup(H)
cat("lookup costruita in", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
    "s | campioni mappati:", length(lk), "| librerie:", length(unique(lk)), "\n")
sc <- attr(lk, "scartate")
cat("librerie candidate scartate:", nrow(sc), "\n")
print(table(sc$motivo))

cat("\n=== ACCETTAZIONE 1: rapporto con la misura a mano (script 92) ===\n")
# La misura a mano NON e' un riferimento identico: il suo estrattore dell'indice
# di corsia conosceva solo la forma `_L00N`, quindi bloccava per G3 tutte le
# scritture `lane N` per esteso. Il pacchetto le riconosce. L'attesa corretta
# non e' quindi l'uguaglianza, ma: (a) nessuna libreria persa rispetto a mano,
# (b) le aggiunte contengono tutte la parola "lane".
G <- readRDS(file.path(SC, "92-guardie.rds"))
attese <- G$lib[G$G1 & G$G2 & G$G3]
ott <- unique(unname(lk))
A90 <- readRDS(file.path(SC, "90-ampiezza.rds")); tit <- split(A90$title, A90$lib)
solo_pac <- setdiff(ott, attese); solo_man <- setdiff(attese, ott)
cat("  a mano", length(attese), "| pacchetto", length(ott),
    "| perse:", length(solo_man), "(atteso 0) | aggiunte:", length(solo_pac), "\n")
cat("  aggiunte che contengono 'lane':",
    sum(vapply(solo_pac, function(l) any(grepl("lane", tolower(tit[[l]]))), logical(1))),
    "su", length(solo_pac), "\n")

cat("\n=== ACCETTAZIONE 2: le entry toccate sono le stesse 9? ===\n")
R <- readRDS(file.path(SC, "30-entry-annotate.rds")); R <- R[R$esito == "ammessa", ]
nb <- function(s) .n_biological(strsplit(s, ",")[[1]], lk)
R$pk_t <- vapply(R$gsm_treated, nb, integer(1))
R$pk_c <- vapply(R$gsm_control, nb, integer(1))
tocca <- (R$pk_t < R$n_treated) | (R$pk_c < R$n_control)
cade  <- (R$pk_t < 2L) | (R$pk_c < 2L)
cat("  toccate:", sum(tocca), "(a mano: ", sum(R$tocca), ") | identiche:",
    identical(tocca, R$tocca), "\n")
cat("  cadute: ", sum(cade), "(a mano: ", sum(R$cade), ") | identiche:",
    identical(cade, R$cade), "\n")
cat("  conteggi biologici identici:",
    identical(R$pk_t, R$n_bio_treated) && identical(R$pk_c, R$n_bio_control), "\n")

cat("\n=== ACCETTAZIONE 3: con lookup NULL non cambia NULLA ===\n")
n0t <- vapply(R$gsm_treated, function(s) .n_biological(strsplit(s, ",")[[1]], NULL), integer(1))
cat("  n_biological(NULL) == numero di campioni:", identical(unname(n0t), R$n_treated), "\n")

cat("\n=== ACCETTAZIONE 4: il dispatch con la lookup accesa ===\n")
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
cl  <- readRDS(file.path(S3D, "clusters.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
s2  <- readRDS(file.path(SC, "s2.rds"))
elig <- cl[cl$cluster_id %in% del$cluster_id, ]; elig$method <- "rem_group"

d_off <- simulomicsr:::.build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = 2L)
d_on  <- simulomicsr:::.build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = 2L,
                                                             lane_lookup = lk)
cat("  spento: cluster", length(d_off), "entry", sum(vapply(d_off, length, integer(1))), "\n")
cat("  acceso: cluster", length(d_on),  "entry", sum(vapply(d_on,  length, integer(1))), "\n")
cat("  entry perse:", sum(vapply(d_off, length, integer(1))) - sum(vapply(d_on, length, integer(1))),
    "(atteso 6)\n")
cat("  cluster spariti:", paste(setdiff(names(d_off), names(d_on)), collapse = ", "), "\n")
k_off <- vapply(d_off, function(z) length(unique(vapply(z, `[[`, character(1), "study_id"))), integer(1))
k_on  <- vapply(d_on,  function(z) length(unique(vapply(z, `[[`, character(1), "study_id"))), integer(1))
ch <- names(k_off)[k_off != k_on[names(k_off)] | is.na(k_on[names(k_off)])]
cat("  cluster con k cambiato:", length(ch), "(atteso 6)\n")
prev <- readRDS(file.path(SC, "50-k-prima-dopo.rds"))
att <- prev$cluster_id[prev$k_dopo != prev$k_ora]
cat("  gli stessi della misura a mano:", identical(sort(ch), sort(att)), "\n")
saveRDS(lk, file.path(SC, "94-lookup.rds"))
cat("\nscritto.\n")
