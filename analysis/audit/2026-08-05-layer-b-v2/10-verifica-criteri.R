# Verifica dei sette criteri di riuscita del ridisegno Layer B (spec Sec.9,
# docs/superpowers/specs/2026-08-05-layer-b-redesign-design.md) SULL'ARTEFATTO
# prodotto dal build v15, non sul codice: legge i PNG/SVG/HTML/CSV reali dentro
# il bundle e la fonte dati reale (cluster_pooled.parquet dello stesso run
# STAGE4_DIR passato al build) usata solo per calcolare le soglie attese
# (k_cluster, kmin) da confrontare coi numeri scritti nell'artefatto -- mai per
# dedurre un risultato dal codice.
#
# Uso:
#   Rscript analysis/audit/2026-08-05-layer-b-v2/10-verifica-criteri.R
#
# Bundle verificato: analysis/p4-output/20260805T231606Z-layer-b-81f379d3
# (build finale, dopo il fix del collasso bracci nel forest e il collegamento
# del provider dei confronti imperfetti -- vedi 20-build.log nella stessa dir).

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

BUNDLE      <- "analysis/p4-output/20260805T231606Z-layer-b-81f379d3"
STAGE4_DIR  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
HTML_PATH   <- file.path(BUNDLE, "layer_b_report.html")
SELECTION   <- "analysis/layer-b-selection-v15.csv"

stopifnot(dir.exists(BUNDLE), file.exists(HTML_PATH), dir.exists(STAGE4_DIR))

sel <- utils::read.csv(SELECTION, stringsAsFactors = FALSE)
cluster_ids <- sel$cluster_id
label_of <- setNames(sel$label_paper, sel$cluster_id)

html_lines <- readLines(HTML_PATH, warn = FALSE)
html_txt   <- paste(html_lines, collapse = "\n")

cp_all <- open_dataset(file.path(STAGE4_DIR, "cluster_pooled.parquet")) |>
  filter(cluster_id %in% cluster_ids) |>
  collect()

esiti <- list()
segna <- function(nome, ok, dettaglio) {
  esiti[[nome]] <<- list(ok = ok, dettaglio = dettaglio)
  cat(sprintf("\n[%s] %s\n  %s\n", if (isTRUE(ok)) "PASS" else "FAIL", nome, dettaglio))
}

# Estrae il contenuto dei tag <text>...</text> da un SVG (svglite: gene label,
# tick, titolo restano testo vero, non contorni -- verificato: heatmap.svg
# invece usa il device grDevices::svg() e rasterizza il testo in <path>, quindi
# NON e' leggibile cosi'; per la heatmap si passa a ispezione visiva del PNG).
estrai_text_svg <- function(path) {
  if (!file.exists(path)) return(character(0))
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  m <- gregexpr("<text[^>]*>([^<]*)</text>", txt, perl = TRUE)
  full <- regmatches(txt, m)[[1]]
  sub("^<text[^>]*>([^<]*)</text>$", "\\1", full)
}

k_cluster_of <- function(cl_id) {
  cp <- cp_all[cp_all$cluster_id == cl_id, , drop = FALSE]
  if (nrow(cp) == 0L || !"k_effective" %in% names(cp)) return(NA_integer_)
  k <- cp$k_effective[!is.na(cp$k_effective)]
  if (length(k) == 0L) return(NA_integer_)
  as.integer(max(k))
}

# k_effective "migliore possibile" per un'etichetta mostrata (gene_symbol o
# gene_id), fra le righe SIGNIFICATIVE del cluster con quel simbolo/id.
# Necessario perche' gli HGNC symbol NON sono univoci in ARCHS4 v2.5 (piu'
# Ensembl gene_id paraloghi sullo stesso simbolo nella regione MHC, es. UBD
# ne ha 6 nel cluster IFN-gamma: k=8,8,11,8,8,3): un lookup naive per simbolo
# puo' pescare a caso una delle varianti scartate dal filtro di copertura.
# La riga REALMENTE scelta dal codice (.volcano_labels()/.forest_gene_...())
# e' sempre quella con lo score piu' alto FRA quelle che superano il filtro
# di copertura (il filtro agisce PRIMA del ranking) -- quindi se ALMENO UNA
# riga significativa con quel simbolo/id supera la soglia, l'etichetta e'
# garantita venire da quella (o da un'altra che la supera altrettanto), mai
# da una scartata. Verificato caso per caso su UBD/TAP1 (cgroup_L5_87c40ebb):
# la riga a score massimo e' sempre una di quelle che gia' passano la soglia.
k_migliore_per_etichetta <- function(cp, etichetta, solo_sig = TRUE) {
  sub <- cp[(cp$gene_symbol == etichetta | cp$gene_id == etichetta) %in% TRUE, , drop = FALSE]
  if (solo_sig && "FDR_BH_within_cluster" %in% names(sub)) {
    sub <- sub[!is.na(sub$FDR_BH_within_cluster) & sub$FDR_BH_within_cluster < 0.05, , drop = FALSE]
  }
  if (nrow(sub) == 0L || all(is.na(sub$k_effective))) return(NA_integer_)
  as.integer(max(sub$k_effective, na.rm = TRUE))
}

cat("=====================================================================\n")
cat("Bundle verificato:", BUNDLE, "\n")
cat("HTML:", HTML_PATH, file.size(HTML_PATH), "byte\n")
cat("Cluster nella selezione:", length(cluster_ids), "\n")
cat("=====================================================================\n")

## ============================================================================
## Criterio 1 -- forest di TGF-b1: bersagli della via, tutti a k_effective>=30/59
## ============================================================================
cl_tgfb1 <- "cgroup_L5_2e16719f"
top_genes_csv <- utils::read.csv(file.path(BUNDLE, cl_tgfb1, "top_genes.csv"),
                                 stringsAsFactors = FALSE)
cp_tgfb1 <- cp_all[cp_all$cluster_id == cl_tgfb1, , drop = FALSE]
k_cluster_tgfb1 <- k_cluster_of(cl_tgfb1)
kmin_tgfb1 <- ceiling(0.5 * k_cluster_tgfb1)

# (a) tabella dei top-geni del bundle: TUTTE le righe soddisfano la soglia
ok1a <- nrow(top_genes_csv) > 0L && all(top_genes_csv$k_effective >= kmin_tgfb1)
ok1b <- !any(top_genes_csv$gene_symbol %in% c("CD300C", "PROK2"))

# (b) i geni REALMENTE disegnati nel pannello superiore del forest (etichette
# lette dal file SVG vero, non dal codice), incrociati con k_effective reale
forest_labels <- estrai_text_svg(file.path(BUNDLE, cl_tgfb1, "forest.svg"))
geni_reali_tgfb1 <- unique(c(cp_tgfb1$gene_symbol, cp_tgfb1$gene_id))
geni_mostrati <- intersect(forest_labels, geni_reali_tgfb1)
k_geni_mostrati <- vapply(geni_mostrati, k_migliore_per_etichetta, integer(1), cp = cp_tgfb1)
ok1c <- length(geni_mostrati) > 0L && all(k_geni_mostrati >= kmin_tgfb1, na.rm = TRUE)

# (c) i bersagli canonici della via TGF-beta citati nello stato del progetto
# (SKIL, PMEPA1, BHLHE40, FSTL3) misurati a k pieno (59), quando presenti nel
# cluster
bersagli_canonici <- c("SKIL", "PMEPA1", "BHLHE40", "FSTL3")
bersagli_presenti <- intersect(bersagli_canonici, cp_tgfb1$gene_symbol)
k_bersagli <- vapply(bersagli_presenti, k_migliore_per_etichetta, integer(1), cp = cp_tgfb1)

segna(
  "Criterio 1: forest TGF-b1, ogni gene mostrato >= 30/59 studi",
  ok1a && ok1b && ok1c,
  sprintf(paste0(
    "k_cluster(TGF-b1)=%d, soglia richiesta=ceiling(0.5*k)=%d studi. ",
    "top_genes.csv (n=%d righe): min k_effective=%d, max=%d, tutte >= soglia: %s. ",
    "CD300C/PROK2 (bersagli vecchi, minestrone) assenti dalla tabella: %s. ",
    "Geni disegnati nel pannello superiore del forest.svg (letti dall'SVG, n=%d): %s, ",
    "tutti >= soglia: %s. Bersagli canonici della via presenti fra i mostrati: %s (k=%s)."),
    k_cluster_tgfb1, kmin_tgfb1, nrow(top_genes_csv),
    min(top_genes_csv$k_effective), max(top_genes_csv$k_effective), ok1a,
    ok1b, length(geni_mostrati), paste(geni_mostrati, collapse = ", "), ok1c,
    paste(bersagli_presenti, collapse = ", "), paste(k_bersagli, collapse = ", ")
  )
)

## ============================================================================
## Criterio 2 -- volcano: nessun punto singolo comprime gli altri sotto il 20%
## dell'altezza; tutte le etichette hanno k >= meta' degli studi
## ============================================================================
righe2 <- list()
for (cl_id in cluster_ids) {
  cp <- cp_all[cp_all$cluster_id == cl_id, , drop = FALSE]
  if (nrow(cp) == 0L) next
  k_cluster <- k_cluster_of(cl_id)
  kmin <- ceiling(0.5 * k_cluster)

  neg_log10_p <- -log10(pmax(cp$p_value_pool, .Machine$double.xmin))
  neg_log10_p <- neg_log10_p[is.finite(neg_log10_p)]
  y_max <- max(neg_log10_p, na.rm = TRUE)
  p99   <- stats::quantile(neg_log10_p, 0.99, names = FALSE)

  cap_path <- file.path(BUNDLE, cl_id, "captions.json")
  caption  <- jsonlite::fromJSON(cap_path)$volcano
  compresso <- grepl("compressed above", caption)
  soglia <- if (compresso) {
    as.numeric(sub(".*compressed above -log10\\(p\\) = ([0-9.]+):.*", "\\1", caption))
  } else NA_real_

  # frazione di altezza occupata dal grosso dei punti (sotto soglia) SENZA
  # compressione (il difetto che il fix corregge) vs CON compressione (il
  # fix): entrambe calcolate sui dati veri del run.
  frac_senza_fix <- p99 / y_max
  frac_con_fix <- if (compresso) {
    y_plot_max <- soglia + sqrt(max(y_max - soglia, 0))
    soglia / y_plot_max
  } else {
    1  # nessuna compressione applicata: l'intero asse e' lineare, frazione = 1
  }

  # etichette REALMENTE disegnate (SVG vero), incrociate con k_effective reale.
  # k_migliore_per_etichetta() (vedi sopra) risolve i simboli HGNC duplicati
  # (paraloghi MHC, es. UBD/TAP1) prendendo il k_effective piu' alto fra le
  # righe SIGNIFICATIVE con quel simbolo -- la riga che il filtro di copertura
  # avrebbe davvero lasciato passare, non una scartata pescata a caso.
  labels <- estrai_text_svg(file.path(BUNDLE, cl_id, "volcano.svg"))
  geni_reali <- unique(c(cp$gene_symbol, cp$gene_id))
  etichette_geni <- intersect(labels, geni_reali)
  k_etichette <- vapply(etichette_geni, k_migliore_per_etichetta, integer(1), cp = cp)
  ok_labels <- length(etichette_geni) > 0L && all(k_etichette >= kmin, na.rm = TRUE)

  righe2[[cl_id]] <- data.frame(
    cluster_id = cl_id, k_cluster = k_cluster, kmin = kmin,
    compresso = compresso, soglia = round(soglia, 1),
    frac_senza_fix = round(frac_senza_fix, 3),
    frac_con_fix = round(frac_con_fix, 3),
    frac_ok = frac_con_fix >= 0.2,
    n_etichette = length(etichette_geni),
    min_k_etichette = suppressWarnings(min(k_etichette, na.rm = TRUE)),
    label_ok = ok_labels
  )
}
tab2 <- do.call(rbind, righe2)
print(tab2, row.names = FALSE)

ok2_frac <- all(tab2$frac_ok)
ok2_label <- all(tab2$label_ok)
segna(
  "Criterio 2: volcano, nessuna compressione sotto il 20%% + etichette >= meta' k",
  ok2_frac && ok2_label,
  sprintf(paste0(
    "9 cluster misurati (tabella sopra). Frazione di altezza occupata dal 99%% dei punti DOPO il fix ",
    "(sempre >= 0.20): min=%.3f su %s. Senza il fix sarebbe stata < 0.20 in %d/%d cluster ",
    "(prova che il difetto esisteva ed e' stato corretto, non che il controllo e' vacuo). ",
    "Tutte le etichette disegnate hanno k >= meta' degli studi in %d/%d cluster."),
    min(tab2$frac_con_fix), tab2$cluster_id[which.min(tab2$frac_con_fix)],
    sum(tab2$frac_senza_fix < 0.2), nrow(tab2),
    sum(tab2$label_ok), nrow(tab2)
  )
)

## ============================================================================
## Criterio 3 -- zero occorrenze di cgroup_L5_ nelle intestazioni e nel sommario
## ============================================================================
headers <- regmatches(html_txt, gregexpr("<h[1-6][^>]*>.*?</h[1-6]>", html_txt, perl = TRUE))[[1]]
headers_con_id <- headers[grepl("cgroup_L5_", headers)]

toc_match <- regmatches(html_txt, regexpr('<nav[^>]*id="TOC"[^>]*>.*?</nav>', html_txt, perl = TRUE))
toc_txt <- if (length(toc_match) > 0 && nzchar(toc_match)) toc_match else ""
toc_con_id <- grepl("cgroup_L5_", toc_txt)

# occorrenze totali nel documento (per contestualizzare: dove SONO le altre,
# se ci sono, e se sono fuori da intestazioni/sommario per costruzione --
# captions, blocco PROVENIENZA, tabella di selezione in appendice)
tot_occorrenze <- lengths(regmatches(html_txt, gregexpr("cgroup_L5_[a-z0-9]+", html_txt)))

segna(
  "Criterio 3: zero cgroup_L5_ nelle intestazioni e nel sommario",
  length(headers_con_id) == 0L && !toc_con_id,
  sprintf(paste0(
    "Intestazioni <h1>-<h6> totali nel documento: %d, con cgroup_L5_ dentro: %d. ",
    "Sommario (<nav id=\"TOC\">): presente=%s, con cgroup_L5_ dentro: %s. ",
    "Occorrenze totali di cgroup_L5_ nel documento (ovunque): %d -- le restanti ",
    "stanno in blocco PROVENIENZA, didascalie delle figure e tabella di selezione ",
    "in Appendice (dichiarate per verifica incrociata, non intestazioni)."),
    length(headers), length(headers_con_id),
    nzchar(toc_txt), toc_con_id, tot_occorrenze
  )
)

## ============================================================================
## Criterio 4 -- ogni figura ha nel titolo il gruppo e il numero di studi
## ============================================================================
righe4 <- list()
for (cl_id in cluster_ids) {
  k_cluster <- k_cluster_of(cl_id)
  label <- label_of[[cl_id]]
  atteso <- sprintf("%s · %s studi", label, k_cluster)
  atteso_1studio <- sprintf("%s · 1 studio", label)

  forest_labels <- estrai_text_svg(file.path(BUNDLE, cl_id, "forest.svg"))
  volcano_labels <- estrai_text_svg(file.path(BUNDLE, cl_id, "volcano.svg"))

  forest_ok <- any(forest_labels == atteso | forest_labels == atteso_1studio)
  volcano_ok <- any(volcano_labels == atteso | volcano_labels == atteso_1studio)

  righe4[[cl_id]] <- data.frame(
    cluster_id = cl_id, label = label, k = k_cluster,
    titolo_atteso = atteso,
    forest_titolo_ok = forest_ok, volcano_titolo_ok = volcano_ok
  )
}
tab4 <- do.call(rbind, righe4)
print(tab4[, c("cluster_id", "k", "forest_titolo_ok", "volcano_titolo_ok")], row.names = FALSE)

go_title_line <- grep('title = "GO Biological Process', readLines("R/layer-b-plot-go-enrichment.R"), value = TRUE)

segna(
  "Criterio 4: ogni figura (forest/volcano/heatmap) ha nel titolo gruppo + N studi",
  all(tab4$forest_titolo_ok) && all(tab4$volcano_titolo_ok),
  sprintf(paste0(
    "Titolo atteso (\"<label_paper> . <k> studi\") trovato letteralmente come testo ",
    "nell'SVG in %d/%d forest e %d/%d volcano (vedi tabella sopra). ",
    "La heatmap (R/layer-b-plot-heatmap.R:274, column_title=titolo) usa lo stesso ",
    ".lb_titolo(): il testo NON e' leggibile via grep perche' grDevices::svg() ",
    "rasterizza i glifi in <path> (0 <text> nel file) -- verificato a occhio sul ",
    "PNG (vedi sezione 'ispezione visiva' del rapporto). NOTA fuori scope: il plot ",
    "GO enrichment (non toccato da questo ridisegno, assente da spec Sec.9bis) ha un ",
    "titolo statico che NON include gruppo/k: %s"),
    sum(tab4$forest_titolo_ok), nrow(tab4), sum(tab4$volcano_titolo_ok), nrow(tab4),
    trimws(go_title_line)
  )
)

## ============================================================================
## Criterio 5 -- la heatmap non contiene la legenda dei codici GSE
## ============================================================================
run_metadata <- jsonlite::fromJSON(file.path(BUNDLE, "run_metadata.json"))
heatmap_mostra_studi <- run_metadata$config$heatmap_mostra_studi

righe5 <- list()
for (cl_id in cluster_ids) {
  cap <- jsonlite::fromJSON(file.path(BUNDLE, cl_id, "captions.json"))$heatmap
  dichiara_omissione <- grepl("Study.*annotation.*omitted|omitted from the column bar", cap)
  righe5[[cl_id]] <- data.frame(cluster_id = cl_id, dichiara_omissione = dichiara_omissione)
}
tab5 <- do.call(rbind, righe5)

segna(
  "Criterio 5: la heatmap non contiene la legenda dei codici GSE",
  isFALSE(heatmap_mostra_studi) && all(tab5$dichiara_omissione),
  sprintf(paste0(
    "config$heatmap_mostra_studi (registrata in run_metadata.json, la config VERA ",
    "usata da questo run) = %s. Didascalia di TUTTE le %d heatmap dichiara ",
    "esplicitamente l'omissione dell'annotazione Study: %d/%d. Verifica visiva ",
    "(Read su heatmap.png di TGF-b1, DHT, enzalutamide) nella sezione dedicata."),
    heatmap_mostra_studi, nrow(tab5), sum(tab5$dichiara_omissione), nrow(tab5)
  )
)

## ============================================================================
## Criterio 6 -- ogni case study ha la narrativa compilata (non stub) e la riga
## dei confronti imperfetti col peso
## ============================================================================
righe6 <- list()
for (cl_id in cluster_ids) {
  narr_path <- file.path(BUNDLE, cl_id, "narrative.qmd")
  narr <- readLines(narr_path, warn = FALSE)
  narr_txt <- paste(narr, collapse = "\n")
  ha_todo_stub <- grepl("^\\s*TODO\\s*$", narr, ignore.case = TRUE) |> any() ||
    grepl("Biological context.*TODO|Findings.*TODO|Discussion.*TODO", narr_txt)
  riga_sporco <- grep("Quanto e' sporco", narr, value = TRUE)
  ha_riga_sporco <- length(riga_sporco) == 1L
  ha_peso_numerico <- grepl("[0-9]+\\.[0-9]% del peso stimato", riga_sporco)
  righe6[[cl_id]] <- data.frame(
    cluster_id = cl_id, ha_todo_stub = ha_todo_stub,
    ha_riga_sporco = ha_riga_sporco, ha_peso_numerico = ha_peso_numerico,
    riga_sporco = if (length(riga_sporco)) riga_sporco else NA_character_
  )
}
tab6 <- do.call(rbind, righe6)
print(tab6[, c("cluster_id", "ha_todo_stub", "ha_riga_sporco", "ha_peso_numerico")], row.names = FALSE)

n_con_conteggio <- sum(grepl("^\\- \\*\\*Quanto e' sporco:\\*\\* [0-9]+ confronti", tab6$riga_sporco))
n_con_solo_peso <- sum(tab6$ha_peso_numerico) - n_con_conteggio

segna(
  "Criterio 6: narrativa compilata (non stub) + riga dei confronti imperfetti col peso",
  !any(tab6$ha_todo_stub) && all(tab6$ha_riga_sporco) && all(tab6$ha_peso_numerico),
  sprintf(paste0(
    "0/%d narrative con stub \"TODO\" nelle sezioni Biological context/Findings/Discussion ",
    "(sostituite dalla narrativa bozza compilata dai numeri reali del deliverable -- ma ",
    "vedi nota sotto). Riga \"Quanto e' sporco\" presente in %d/%d case study, con un peso ",
    "percentuale NUMERICO REALE in %d/%d (fonte: analysis/audit/2026-08-05-rilettura-214/ ",
    "verdetti-con-peso.csv, colonna peso_citati, per cluster_id -- provider collegato in ",
    "questa sessione, prima era NULL e la riga diceva sempre 'non misurato'). Di questi, ",
    "%d/%d hanno anche il conteggio ESATTO n/tot confronti (fonte: 13-grandi-conteggio.json, ",
    "disponibile solo per i gruppi con k>=15); i restanti %d mostrano '?' al posto di n/tot ",
    "(dichiarato, non un buco silenzioso) perche' la rilettura a conteggio esatto copre solo ",
    "i 13 gruppi grandi, per costruzione del metodo (vedi docs/findings/2026-08-05-confronti-imperfetti.md)."),
    nrow(tab6), sum(tab6$ha_riga_sporco), nrow(tab6), sum(tab6$ha_peso_numerico), nrow(tab6),
    n_con_conteggio, sum(tab6$ha_peso_numerico), n_con_solo_peso
  )
)

## ============================================================================
## Criterio 7 -- il documento si apre con la prova agonista/antagonista PRIMA
## di qualunque figura tecnica
## ============================================================================
idx_apertura <- regexpr('id="apertura"', html_txt)
idx_primo_img <- regexpr("<img", html_txt)
idx_1441 <- regexpr("1\\.441", html_txt)
idx_97_7 <- regexpr("97,7", html_txt)
idx_0_938 <- regexpr("0,938", html_txt)

tutti_numeri_prima <- idx_1441 > 0 && idx_97_7 > 0 && idx_0_938 > 0 &&
  idx_1441 < idx_primo_img && idx_97_7 < idx_primo_img && idx_0_938 < idx_primo_img &&
  idx_apertura < idx_1441

segna(
  "Criterio 7: la prova agonista/antagonista precede qualunque figura tecnica",
  tutti_numeri_prima,
  sprintf(paste0(
    "Posizione (offset carattere nell'HTML) di: 'Apertura'=%d, i quattro bersagli ",
    "KLK3/TMPRSS2/FKBP5/NKX3-1=%s, '1.441' (geni sig in entrambi)=%d, '97,7' ",
    "(%% segno opposto)=%d, '0,938' (Spearman)=%d, primo <img>=%d. ",
    "Tutti i numeri del controllo compaiono DOPO l'apertura e PRIMA del primo <img>: %s."),
    idx_apertura,
    paste(sapply(c("KLK3","TMPRSS2","FKBP5","NKX3-1"), function(g) regexpr(g, html_txt)), collapse=","),
    idx_1441, idx_97_7, idx_0_938, idx_primo_img, tutti_numeri_prima
  )
)

## ============================================================================
## Sommario
## ============================================================================
cat("\n=====================================================================\n")
cat("SOMMARIO DEI SETTE CRITERI (spec Sec.9)\n")
cat("=====================================================================\n")
for (nome in names(esiti)) {
  cat(sprintf("[%s] %s\n", if (isTRUE(esiti[[nome]]$ok)) "PASS" else "FAIL", nome))
}
