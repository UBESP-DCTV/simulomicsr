# AUDIT DEL RESOLVER — passo 5: una REGOLA GENERALE al posto della lista.
#
# Ipotesi: una sigla corta (<=4 caratteri) identifica davvero l'entita' solo se
# in quel corpus l'entita' e' anche NOMINATA PER ESTESO da qualche parte
# ("LPS" e' credibile perche' "lipopolysaccharide" compare nei metadati;
# "ML"->THPO non lo e' perche' "thrombopoietin" non compare mai).
#
# Si valuta la regola contro l'adjudicazione manuale: se separa i casi giusti
# dai casi sbagliati, e' una regola pubblicabile e sostituisce la curatela.
suppressPackageStartupMessages({library(dplyr)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
A <- readRDS(file.path(OUT, "alias-catalog.rds"))
freq <- readRDS(file.path(OUT, "corpus-token-freq.rds"))
fire <- readRDS(file.path(OUT, "production-firing.rds"))

## token del corpus (etichette Stadio 2 + testi H5 dei campioni recuperati)
corpus_tok <- unique(c(freq$tok,
  unlist(strsplit(gsub("[^a-z0-9]+", " ", tolower(fire$txt)), " +"))))
corpus_tok <- corpus_tok[nzchar(corpus_tok)]

## alias lunghi (>=5 char) per entita'
long_alias <- A |> mutate(a = gsub("[^a-z0-9]", "", alias)) |>
  filter(nchar(a) >= 5) |> select(id, alias) |> distinct()
long_by_id <- split(long_alias$alias, long_alias$id)

attested <- function(id) {
  al <- long_by_id[[id]]
  if (is.null(al) || !length(al)) return(FALSE)
  # attestato se ALMENO UN alias lungo dell'entita' compare nel corpus come
  # token (o come sequenza di token per gli alias multi-parola)
  for (a in al) {
    w <- strsplit(gsub("[^a-z0-9]+", " ", tolower(a)), " +")[[1]]
    w <- w[nchar(w) >= 5]
    if (length(w) && all(w %in% corpus_tok)) return(TRUE)
  }
  FALSE
}

S <- fire |> filter(!is.na(alias_innesco)) |>
  group_by(alias = alias_innesco, agent_id, name) |> summarise(n_gsm = n(), .groups = "drop")
S$len <- nchar(gsub("[^a-z0-9]", "", S$alias))
S$corta <- S$len <= 4
ids <- unique(S$agent_id)
att <- vapply(ids, attested, logical(1)); names(att) <- ids
S$attestata <- att[S$agent_id]
S$regola_rifiuta <- S$corta & !S$attestata &
  gsub("[^a-z0-9]", "", tolower(S$alias)) != gsub("[^a-z0-9]", "", tolower(S$name %||% ""))

## ---- valutazione contro l'adjudicazione manuale (audit interno) ----
SBAGLIATE <- c("ml","in","ifn","ifna","lead","iaa","dha","ser","hgf","apg","il1","tpa","5fu","tpo",
  "pal","pvp","hgi","csf","egf","igm","il27","sel","amo","mc","chop","pd1","ph","c6","donor","bap",
  "ampk","activin","cancer","tumor","mit","c","nrg1","dec","male","pdx","tac","tmp","can","tad","acf",
  "akm","aps","dpn","eto","ffa","ilt","lp","mek","mrna","oxa","shh","tnt","tsa","doc","ifna8","iso",
  "ky","l3","mk","nmda","palb","a20","ach","act","bg","c10","c5a","vitamin")
GIUSTE <- c("lps","dht","tnfa","r1881","imatinib","tgfb","il4","pma","erlotinib","il21","bpa","saha",
  "il15","copd","actinomycin","h2o2","forskolin","etanercept","pfbs","ifnb","vpa","actd","qnz","tcdd",
  "il13","dncb","vegf","fgf2","il11","tmz","il6","baff","gentamicin","tdf","dmog","pufa","3tc","cpg",
  "il10","palmitate","sildenafil","aid","dhea","mehp","c16","dioxin","nicotinamide","s4u","sr1","3ap",
  "ammonium","tnfalpha","cortisol","formoterol","il2","mcsf","mms","aea","aflatoxin","ar","camp","cccp",
  "cddp","ciclosporin","lcfa","zinc","dfmo","il23","mpa","tmao","aha","bitc","bpf","scf","brdu","atp",
  "mtx","oct4","raloxifene","menadione","s1p","bfgf","pfoa","pfos","plab","mda5")
ev <- S |> mutate(alias_n = gsub("[^a-z0-9]", "", tolower(alias))) |>
  mutate(verita = case_when(alias_n %in% SBAGLIATE ~ "sbagliata",
                            alias_n %in% GIUSTE ~ "giusta", TRUE ~ NA_character_)) |>
  filter(!is.na(verita))
cat("=== VALUTAZIONE DELLA REGOLA DI CO-ATTESTAZIONE ===\n")
cat(sprintf("coppie adjudicate: %d (sbagliate %d, giuste %d)\n", nrow(ev),
            sum(ev$verita == "sbagliata"), sum(ev$verita == "giusta")))
tb <- table(regola = ifelse(ev$regola_rifiuta, "rifiuta", "accetta"), verita = ev$verita)
print(tb)
vp <- sum(ev$regola_rifiuta & ev$verita == "sbagliata"); fp <- sum(ev$regola_rifiuta & ev$verita == "giusta")
fn <- sum(!ev$regola_rifiuta & ev$verita == "sbagliata"); vn <- sum(!ev$regola_rifiuta & ev$verita == "giusta")
cat(sprintf("\nprecisione del rifiuto (rifiutate davvero sbagliate): %.1f%% (%d/%d)\n",
            100 * vp / max(1, vp + fp), vp, vp + fp))
cat(sprintf("copertura (sbagliate intercettate)                 : %.1f%% (%d/%d)\n",
            100 * vp / max(1, vp + fn), vp, vp + fn))
cat(sprintf("danno (giuste rifiutate)                           : %.1f%% (%d/%d)\n",
            100 * fp / max(1, fp + vn), fp, fp + vn))
cat("\n-- GIUSTE che la regola rifiuterebbe (danno) --\n")
print(as.data.frame(ev |> filter(regola_rifiuta, verita == "giusta") |>
                      select(alias, name, n_gsm) |> arrange(desc(n_gsm))), row.names = FALSE)
cat("\n-- SBAGLIATE che la regola NON intercetta (residuo) --\n")
print(head(as.data.frame(ev |> filter(!regola_rifiuta, verita == "sbagliata") |>
                           select(alias, name, n_gsm) |> arrange(desc(n_gsm))), 25), row.names = FALSE)
saveRDS(S, file.path(OUT, "coattestazione.rds"))
