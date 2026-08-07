#!/usr/bin/env Rscript
# Tabella finale per entita' + note delle ispezioni manuali + provenienza.

suppressMessages({library(data.table)})
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
LIN <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
log <- function(...) cat(sprintf(...), "\n", sep = "")

c1 <- as.data.table(readRDS(file.path(OUT, "20-entita-con-firme.rds")))

# --- esiti delle ispezioni manuali (ogni riga qui e' stata letta a mano) -----
c1[, nota_ispezione := NA_character_]
c1[contrast_entity == "CHEBI:29073", nota_ispezione :=
   "match per nome normalizzato RIFIUTATO: i due pert_id LINCS 'ascorbic-acid' sono ascorbil-palmitato (CYJPUZLKFAUFHF) e acido deidroascorbico (KRGQEOSDQHTZMX), non L-ascorbico (CIWBSHSKHKDKBQ)"]
c1[contrast_entity == "CHEBI:3139", nota_ispezione :=
   "BORDERLINE non contato: LINCS ha 'bleomycin-sulfate' (BRD-M82067008) senza InChIKey; miscela/sale, non la bleomicina A2"]
c1[contrast_entity == "CHEBI:46741", nota_ispezione :=
   "BORDERLINE non contato: LINCS ha 'nutlin-3' (BRD-A12230535, BRD-K73255294) ma la nostra entita' e' il termine di CLASSE 'Nutlin', senza struttura"]
c1[contrast_entity == "CHEBI:39421", nota_ispezione :=
   "verificata assenza: LINCS ha 'ammonium-perfluorocaprylate' (PFOA), la nostra e' PFOS (sulfonato) - composto diverso"]
c1[contrast_entity == "CHEBI:17347", nota_ispezione :=
   "match per blocco: dei 4 pert_id, 2 hanno nome 'testosterone', 2 sono stereoisomeri senza nome"]
c1[metodo_match == "struttura_blocco_connettivita" & is.na(nota_ispezione),
   nota_ispezione := "match per blocco: stesso scheletro, LINCS non annota la stereochimica"]
c1[metodo_match == "nome_sinonimo_esatto", nota_ispezione :=
   "match per nome: la via strutturale non e' percorribile (composto di Pt o miscela, oppure LINCS senza InChIKey); verificato a mano su SMILES/nome"]
c1[contrast_entity %in% c("CHEBI:16412", "CHEBI:84491"), nota_ispezione :=
   "assenza attesa: non e' una singola struttura (LPS / poly(I:C)) - LINCS li ha semmai come trt_lig, non trt_cp"]
c1[contrast_entity %in% c("CHEMBL:CHEMBL265582", "CHEMBL:CHEMBL1201576",
                          "CHEBI:231601", "CHEMBL:CHEMBL4297771"),
   nota_ispezione := "assenza attesa: biologico (proteina/anticorpo), fuori dal perimetro trt_cp"]

cols <- c("contrast_entity", "nome_risolto", "contrast_entity_label", "canonical_name",
          "kind_effective_resolved", "metodo_match", "n_inchikey", "pert_id", "nome_lincs",
          "n_pert_id", "n_firme_lincs", "n_firme_exemplar", "n_linee_lincs", "n_dosi_lincs",
          "k_effective", "k_kish", "n_sig", "n_studi_poolati", "coherence_verdict",
          "nota_ispezione")
out <- c1[order(-agganciata, -n_firme_lincs, -k_effective), ..cols]
fwrite(out, file.path(OUT, "copertura-lincs-per-entita.csv"))

log("=== TABELLA FINALE: %s ===", file.path(OUT, "copertura-lincs-per-entita.csv"))
log("righe: %d (= i 111 candidati CHEBI+CHEMBL)", nrow(out))
log("")
log("AGGANCIATE: %d   NON AGGANCIATE: %d", sum(c1$agganciata), sum(!c1$agganciata))
log("")
log("metodo:"); print(table(c1$metodo_match))
log("")
log("=== distribuzione per k_effective ===")
tab <- c1[, .(agganciate = sum(agganciata), non_agganciate = sum(!agganciata)),
          by = .(fascia = fifelse(k_effective >= 10, "k>=10",
                          fifelse(k_effective >= 5, "k 5-9", "k 3-4")))]
print(tab[order(fascia)])
log("")
log("=== le agganciate con k_effective >= 10 ===")
print(c1[agganciata & k_effective >= 10][order(-k_effective),
     .(contrast_entity, nome_risolto, k_effective, n_firme_lincs, n_linee_lincs,
       n_dosi_lincs, metodo_match)])
log("")
log("=== firme LINCS: totali sulle agganciate ===")
log("somma firme trt_cp    : %d", sum(c1$n_firme_lincs))
log("mediana firme         : %.1f", median(c1$n_firme_lincs[c1$agganciata]))
log("min / max             : %d / %d", min(c1$n_firme_lincs[c1$agganciata]),
    max(c1$n_firme_lincs[c1$agganciata]))
log("agganciate con < 10 firme : %d", sum(c1$agganciata & c1$n_firme_lincs < 10))
log("agganciate con >= 100 firme: %d", sum(c1$agganciata & c1$n_firme_lincs >= 100))
log("mediana linee cellulari    : %.1f", median(c1$n_linee_lincs[c1$agganciata]))
log("mediana dosi               : %.1f", median(c1$n_dosi_lincs[c1$agganciata]))

# ------------------------------------------------------------------ provenienza
f <- c("compoundinfo_beta.txt", "siginfo_beta.txt", "geneinfo_beta.txt",
       "cellinfo_beta.txt", "src1src7.txt.gz")
prov <- rbindlist(lapply(f, function(x) {
  p <- file.path(LIN, x)
  data.table(file = x, bytes = file.size(p),
             sha256 = strsplit(system(paste("sha256sum", shQuote(p)), intern = TRUE), " ")[[1]][1])
}))
prov[, fonte := c(rep("https://s3.amazonaws.com/macchiato.clue.io/builds/LINCS2020/", 4),
                  "https://ftp.ebi.ac.uk/pub/databases/chembl/UniChem/data/wholeSourceMapping/src_id1/")]
fwrite(prov, file.path(OUT, "provenienza-file-scaricati.csv"))
log("")
log("=== PROVENIENZA ==="); print(prov[, .(file, bytes, sha256 = substr(sha256, 1, 16))])
