# =============================================================================
# 1. CECITA' DEL MIO STRUMENTO, misurata (obbligatorio)
# 2. Tre guardie IN PIU', tutte generali e tutte prese dai dati, con il loro
#    effetto misurato sulle fusioni e sul campione giudicato
# 3. Cose che NON sono entita': quantificate con una regola, non con un elenco
# =============================================================================
#
# DIFETTO TROVATO NEL MIO STESSO STRUMENTO. La regola applica
# `.cg_is_umbrella_name()` alla CHIAVE NORMALIZZATA (senza spazi). Misurato:
# quella funzione riconosce "mek inhibitor" e "kinase inhibitor" ma NON
# "mekinhibitor" e "kinaseinhibitor" — le sue regex hanno confini di parola, e
# in una stringa concatenata non possono agganciare. La guardia piu' importante
# della regola era quindi SPENTA. E' la stessa classe di errore che il progetto
# ha pagato tre volte (alias corti, lettere greche, testo troncato): lo
# strumento vedeva meno del dato.
# =============================================================================

suppressWarnings(suppressMessages(devtools::load_all(".", quiet = TRUE)))
OUT  <- "analysis/audit/2026-08-08-deframmentazione"
DICT <- "/home/user/.cache/R/simulomicsr"
say <- function(...) cat(sprintf(...), "\n", sep = "")
E <- readRDS(file.path(OUT, "21-regola-esito.rds"))
cg <- E$cg; k_per_id <- E$k_per_id
ponti <- utils::read.csv(file.path(OUT, "22-ponti-fra-registri.csv"), stringsAsFactors = FALSE)
.strip_markup <- function(x) gsub("<[^>]*>", "", x)

CH <- readRDS(file.path(DICT, "chebi", "chebi-lookup.rds"))
MS <- readRDS(file.path(DICT, "mesh-lookup.rds"))
TX <- readRDS(file.path(DICT, "taxonomy", "taxonomy-lookup.rds"))

# --------------------------------------------------------------------------
# 1. La cecita', misurata
# --------------------------------------------------------------------------
say("=== 1a. GUARDIA OMBRELLO: forma con spazi contro forma normalizzata ===")
prove <- c("mek inhibitor", "kinase inhibitor", "steroid hormone", "protein kinase inhibitor",
           "adp ribose transferases", "albumins", "viruses", "interleukin 27")
for (p in prove) say("  %-26s spaziata=%-5s  concatenata=%-5s", p,
                     .cg_is_umbrella_name(p), .cg_is_umbrella_name(gsub("[^a-z0-9]", "", p)))

# Ricostruzione del NOME SPAZIATO dietro ogni chiave-ponte: si riprende dal
# registro il nome che ha prodotto quella chiave.
nome_spaziato <- local({
  tab <- rbind(
    data.frame(key = gsub("[^a-z0-9]", "", tolower(.strip_markup(CH$by_id$primary_name))),
               nome = tolower(.strip_markup(CH$by_id$primary_name)), stringsAsFactors = FALSE),
    data.frame(key = gsub("[^a-z0-9]", "", tolower(CH$aliases$alias_lower)),
               nome = tolower(CH$aliases$alias_lower), stringsAsFactors = FALSE),
    data.frame(key = gsub("[^a-z0-9]", "", tolower(MS$by_ui$mh)),
               nome = tolower(MS$by_ui$mh), stringsAsFactors = FALSE),
    data.frame(key = gsub("[^a-z0-9]", "", tolower(MS$by_entry_lower$entry_lower)),
               nome = tolower(MS$by_entry_lower$entry_lower), stringsAsFactors = FALSE))
  tab <- tab[nzchar(tab$key) & grepl("[ /(),-]", tab$nome), ]
  tapply(tab$nome, tab$key, function(z) z[which.max(nchar(z))])
})
ponti$nome_spaziato <- unname(nome_spaziato[ponti$chiave])
ponti$ombrello_spaziata <- !is.na(ponti$nome_spaziato) & vapply(
  ifelse(is.na(ponti$nome_spaziato), "", ponti$nome_spaziato), .cg_is_umbrella_name, logical(1L))
say("")
say("=== 1b. COSTO DELLA CECITA' ===")
say("equivalenze totali: %d", nrow(ponti))
say("bloccate se la guardia ombrello gira sulla forma SPAZIATA: %d (%.1f%%)",
    sum(ponti$ombrello_spaziata), 100 * mean(ponti$ombrello_spaziata))
say("di quelle con entrambi i lati nel corpus (le 15 applicate): %d",
    sum(ponti$ombrello_spaziata & ponti$entrambi_nel_corpus))
if (any(ponti$ombrello_spaziata))
  say("  esempi: %s", paste(head(unique(ponti$nome_spaziato[ponti$ombrello_spaziata]), 8), collapse = " ; "))

# limiti di lunghezza nel MIO percorso
say("")
say("=== 1c. LIMITI DI LUNGHEZZA nel mio percorso ===")
nk <- nchar(ponti$chiave)
say("chiave-ponte: min %d, mediana %d, max %d caratteri", min(nk), stats::median(nk), max(nk))
say("soglia .CA_DEFRAG_MIN_CHARS = %d: chiavi a ESATTAMENTE 4 caratteri fra i ponti: %d",
    .CA_DEFRAG_MIN_CHARS, sum(nk == 4L))
say("  (sono le piu' rischiose: %s)", paste(head(unique(ponti$chiave[nk == 4L]), 12), collapse = " "))
ent <- unique(cg$contrast_entity)
say("entita' del corpus: nchar min %d mediana %d max %d (nessun picco = nessun troncamento)",
    min(nchar(ent)), stats::median(nchar(ent)), max(nchar(ent)))
tb <- table(nchar(ent)); pk <- as.integer(names(tb))
say("le 5 lunghezze piu' frequenti: %s",
    paste(sprintf("%d char x%d", pk[order(-tb)][1:5], sort(tb, decreasing = TRUE)[1:5]), collapse = ", "))

# lettere greche: quante slug portano il segno di una greca cancellata
say("")
say("=== 1d. LETTERE GRECHE PERSE NELLA SLUGIFICAZIONE A MONTE ===")
str_ent <- unique(cg$contrast_entity[startsWith(cg$contrast_entity, "STR:")])
slug <- sub("^STR:", "", str_ent)
# regola generale: un token di UNA sola lettera fra quelle che traducono una
# greca (a=alpha, b=beta, g=gamma, d=delta, k=kappa, l=lambda, s=sigma, w=omega),
# preceduto da un token piu' lungo -> quasi certamente una greca cancellata
tok <- strsplit(slug, "_", fixed = TRUE)
GRECHE <- c(a = "alpha", b = "beta", g = "gamma", d = "delta", k = "kappa",
            l = "lambda", s = "sigma", w = "omega")
sospetta_greca <- vapply(tok, function(z)
  length(z) >= 2L && any(z[-1L] %in% names(GRECHE)), logical(1L))
say("slug STR: distinti: %d | con un token di una sola lettera greca-compatibile: %d (%.1f%%)",
    length(slug), sum(sospetta_greca), 100 * mean(sospetta_greca))
say("  esempi: %s", paste(head(slug[sospetta_greca], 12), collapse = " ; "))
# quanti di quelli risolverebbero se si ri-mettesse la greca per esteso
oe <- NULL
ric <- vapply(slug[sospetta_greca], function(s) {
  z <- strsplit(s, "_", fixed = TRUE)[[1L]]
  i <- which(z[-1L] %in% names(GRECHE))[1L] + 1L
  paste0(paste(z[1:(i - 1L)], collapse = ""), GRECHE[[z[i]]],
         if (i < length(z)) paste(z[(i + 1L):length(z)], collapse = "") else "")
}, character(1L))
# aggancio sull'indice ChEBI/HGNC/MeSH via chiave normalizzata
idx_all <- unique(c(gsub("[^a-z0-9]", "", tolower(CH$aliases$alias_lower)),
                    gsub("[^a-z0-9]", "", tolower(MS$by_entry_lower$entry_lower))))
hgnc <- readRDS(file.path(DICT, "hgnc-lookup.rds"))
idx_all <- unique(c(idx_all, gsub("[^a-z0-9]", "", tolower(hgnc$aliases_long$alias_lower)),
                    gsub("[^a-z0-9]", "", tolower(hgnc$by_hgnc_int$symbol))))
ok <- ric %in% idx_all
say("di quelli, ri-mettendo la greca per esteso agganciano un alias reale: %d su %d",
    sum(ok), length(ric))
say("  esempi che agganciano: %s", paste(head(paste0(names(ric)[ok], " -> ", ric[ok]), 10), collapse = " ; "))
kk <- vapply(paste0("STR:", names(ric)[ok]),
             function(e) sum(cg$k[cg$contrast_entity == e]), integer(1L))
say("k totale nei cluster di quegli slug: %d (di cui k>=3: %d cluster)", sum(kk),
    sum(cg$k[cg$contrast_entity %in% paste0("STR:", names(ric)[ok])] >= 3L))
utils::write.csv(data.frame(slug = names(ric), ricostruito = unname(ric), aggancia = ok),
                 file.path(OUT, "26-greche-perse.csv"), row.names = FALSE)

say("")
say("=== 1e. MAIUSCOLE/MINUSCOLE ===")
say("tutte le chiavi passano da tolower(): il confronto e' case-INSENSITIVE per")
say("costruzione. Verifica che non serva il contrario: prefissi con grafia diversa")
say("nello stesso corpus: %d (0 = nessuna frammentazione da casing)",
    length(unique(sub(":.*$", "", ent))) - length(unique(tolower(sub(":.*$", "", ent)))))
say("ID che differiscono SOLO per il caso: %d",
    length(unique(tolower(ent))) - length(unique(ent)) + 0L)

# --------------------------------------------------------------------------
# 2. Tre guardie in piu', generali, prese dai dati
# --------------------------------------------------------------------------
say("")
say("=== 2. GUARDIE AGGIUNTIVE, effetto misurato ===")
# (a) ChEBI stars: 3 = curata a mano. CHEBI:202717 ("PAX5", un peptide) ha 2.
stars <- setNames(CH$by_id$stars, paste0("CHEBI:", CH$by_id$chebi_id))
g_stars <- function(id) { if (!startsWith(id, "CHEBI:")) return(TRUE)
                          s <- stars[id]; !is.na(s) && s >= 3L }
# (b) profondita' MeSH: un descrittore alto nell'albero e' una CLASSE
depth_mesh <- local({
  br <- MS$by_ui$tree_branches
  d <- vapply(strsplit(ifelse(is.na(br), "", br), "[^A-Z0-9.]+"), function(z) {
    z <- z[nzchar(z)]; if (!length(z)) return(NA_integer_)
    min(vapply(strsplit(z, ".", fixed = TRUE), length, integer(1L)))
  }, integer(1L))
  setNames(d, paste0("MeSH:", MS$by_ui$ui))
})
SOGLIA_MESH <- 3L
g_mesh <- function(id) { if (!startsWith(id, "MeSH:")) return(TRUE)
                         d <- depth_mesh[id]; is.na(d) || d > SOGLIA_MESH }
# (c) rango tassonomico: sopra la specie non e' un organismo specifico
rank_tx <- setNames(TX$nodes$rank, paste0("NCBITaxon:", TX$nodes$taxid))
g_tax <- function(id) { if (!startsWith(id, "NCBITaxon:")) return(TRUE)
                        r <- rank_tx[id]
                        is.na(r) || r %in% c("species", "subspecies", "strain", "serotype",
                                             "no rank", "isolate", "serogroup", "genotype") }
appl <- ponti[ponti$entrambi_nel_corpus == TRUE, ]
for (nm in c("g_stars", "g_mesh", "g_tax")) {
  f <- get(nm)
  blocca <- !vapply(appl$id_a, f, logical(1L)) | !vapply(appl$id_b, f, logical(1L))
  say("  %-8s blocca %d delle %d fusioni applicate: %s", nm, sum(blocca), nrow(appl),
      paste(sprintf("%s==%s", appl$id_a[blocca], appl$id_b[blocca]), collapse = " ; "))
}
blocca_omb <- appl$chiave %in% ponti$chiave[ponti$ombrello_spaziata]
say("  ombrello  blocca %d delle %d fusioni applicate", sum(blocca_omb), nrow(appl))
tutte <- ponti[, c("id_a","id_b","chiave","tier","entrambi_nel_corpus")]
tutte$blocco <- ifelse(!vapply(tutte$id_a, g_stars, logical(1L)) |
                       !vapply(tutte$id_b, g_stars, logical(1L)), "chebi_stars<3",
                ifelse(!vapply(tutte$id_a, g_mesh, logical(1L)) |
                       !vapply(tutte$id_b, g_mesh, logical(1L)), "mesh_troppo_alto",
                ifelse(!vapply(tutte$id_a, g_tax, logical(1L)) |
                       !vapply(tutte$id_b, g_tax, logical(1L)), "taxon_sopra_specie",
                ifelse(tutte$chiave %in% ponti$chiave[ponti$ombrello_spaziata], "nome_ombrello", ""))))
say("  effetto sulle %d equivalenze: %s", nrow(tutte),
    paste(sprintf("%s=%d", names(table(tutte$blocco)), as.integer(table(tutte$blocco))), collapse = " "))
utils::write.csv(tutte, file.path(OUT, "26-guardie-effetto.csv"), row.names = FALSE)

# --------------------------------------------------------------------------
# 3. Cose che NON sono entita' — quantificate con una regola
# --------------------------------------------------------------------------
say("")
say("=== 3. COSE CHE NON SONO ENTITA' (regole, non elenchi) ===")
ne <- data.frame(cluster_id = cg$cluster_id, entita = cg$contrast_entity, k = cg$k,
                 stringsAsFactors = FALSE)
# (i) ID ontologico che e' una CLASSE per il suo stesso registro
ne$classe_registro <- ifelse(!vapply(ne$entita, g_mesh, logical(1L)), "mesh_alto_nell_albero",
                      ifelse(!vapply(ne$entita, g_tax, logical(1L)), "taxon_sopra_specie",
                      ifelse(!vapply(ne$entita, g_stars, logical(1L)), "chebi_non_curata", "")))
# (ii) ChEBI che e' ANTENATO is_a di un'altra entita' del corpus -> e' la classe
#      che contiene qualcosa che misuriamo a parte (il caso Nutlin)
isa <- CH$is_a
ent_ch <- unique(ne$entita[startsWith(ne$entita, "CHEBI:")])
ant <- unique(paste0("CHEBI:", isa$parent_id[paste0("CHEBI:", isa$chebi_id) %in% ent_ch]))
ne$antenato_di_membro <- ne$entita %in% intersect(ant, ent_ch)
# (iii) slug STR: che il vocabolario del progetto riconosce come stato/ombrello,
#       misurato sulla forma DE-slugificata (dove le guardie possono accendersi)
de <- gsub("_", " ", sub("^STR:", "", ne$entita))
ne$str_stato_o_ombrello <- startsWith(ne$entita, "STR:") &
  (vapply(de, .cg_is_generic_token, logical(1L)) | vapply(de, .cg_is_umbrella_name, logical(1L)))
say("cluster con entita' che il REGISTRO stesso dichiara classe: %d", sum(nzchar(ne$classe_registro)))
print(table(ne$classe_registro[nzchar(ne$classe_registro)]))
say("cluster la cui entita' ChEBI e' ANTENATO is_a di un'altra entita' del corpus: %d (%s)",
    sum(ne$antenato_di_membro), paste(unique(ne$entita[ne$antenato_di_membro]), collapse = " "))
say("cluster con slug STR: riconosciuto stato/ombrello dal vocabolario del progetto: %d",
    sum(ne$str_stato_o_ombrello))
say("  esempi: %s", paste(head(unique(ne$entita[ne$str_stato_o_ombrello]), 15), collapse = " ; "))
ne$non_entita <- nzchar(ne$classe_registro) | ne$antenato_di_membro | ne$str_stato_o_ombrello
say("TOTALE cluster con entita' che NON e' un'entita' specifica: %d (%.1f%% degli 11.536), k somma %d",
    sum(ne$non_entita), 100 * mean(ne$non_entita), sum(ne$k[ne$non_entita]))
say("di questi, con k>=3 (cioe' candidabili al deliverable): %d", sum(ne$non_entita & ne$k >= 3L))
say("⚠️ NON scartati: non e' una decisione mia. Tenuti FUORI dalle fusioni: %d",
    sum(ne$non_entita & cg$entita_canonica != cg$contrast_entity))
utils::write.csv(ne[ne$non_entita, ], file.path(OUT, "26-non-entita.csv"), row.names = FALSE)
