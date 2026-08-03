#!/usr/bin/env Rscript
# 30-verdetti-v15.R --- produce `verdetti-poolato-v15.csv`.
#
# Unisce i SEI verdetti di incoerenza del censimento 2026-07-29 (che restano
# validi: nessuna delle loro chiavi e' toccata dalla de-frammentazione a due
# entita') con i DICIOTTO nuovi, dalla rilettura dei 49 gruppi che la dedup
# sbagliata cancellava (FASE D0ter estesa, decisione utente 2026-08-03).
#
# I 49 gruppi sono stati letti con le etichette INTERE, quattro lettori in
# parallelo, con la rubrica del progetto: coerente = i membri isolano lo stesso
# contrasto. Esito della lettura: 31 coerenti, 17 incoerenti, 1 dubbio — e il
# dubbio e' poi stato ESCLUSO dall'utente, quindi i verdetti nuovi sono 18.
#
# IL DUBBIO E' STATO CHIUSO DALL'UTENTE (2026-08-03): si esclude.
# `cgroup_L5_855ca642` (perossido di idrogeno) ha 6 membri puliti su 7; il
# settimo (GSE235768) usa come riferimento un «vehicle (bortezomib)» invece del
# veicolo del confronto gemello nello stesso studio. Per decidere servirebbe il
# testo dello studio; l'utente ha scelto di escluderlo invece di tenerlo per
# buono. E' la scelta conservativa, ed e' l'unica azione che la pipeline
# consente a questo livello: i verdetti marcano un GRUPPO, non un singolo
# membro. Costo dichiarato: si perdono anche i 6 confronti puliti.
#
# Uso: Rscript analysis/audit/2026-08-02-fix/30-verdetti-v15.R
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-08-02-fix/verdetti-poolato-v15.csv"
VECCHI <- "analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv"

# --- i 18 nuovi (17 giudicati incoerenti + 1 escluso), col motivo di chi ha letto --------------------
nuovi <- rbind(
  data.frame(cluster_id = "cgroup_L5_3b91a21d", motivo = "entita' che e' una classe: 'Neoplasm Metastasis' mescola tumori primari diversi (colon->fegato, ovaio->omento) e un membro che confronta stadi (M1 vs M0), non malattia vs sano; due membri isolano solo cellule endoteliali"),
  data.frame(cluster_id = "cgroup_L5_165b7913", motivo = "entita' che e' una classe: l'ID ChEMBL e' 'INTERFERON' generico e il gruppo mescola IFN-gamma e IFN-alfa, che hanno recettori e vie diverse (tipo II contro tipo I)"),
  data.frame(cluster_id = "cgroup_L5_3668c2c2", motivo = "due membri su quattro sono difettosi: uno e' etichettato 'attivate IN ASSENZA di IL-10' ma classificato come braccio trattato; l'altro confronta una cellula differenziata trattata contro una non differenziata (due cose insieme)"),
  data.frame(cluster_id = "cgroup_L5_545a48c6", motivo = "clinico contro sperimentale: due studi su tessuto di paziente, uno su linee immortalizzate; e un membro usa la stessa linea tumorale come proprio 'controllo normale'"),
  data.frame(cluster_id = "cgroup_L5_e25d67cf", motivo = "clinico contro sperimentale: pazienti RSV a visita acuta contro convalescente, insieme a infezioni in vitro su colture (A549, H292, HBEC, NHBE)"),
  data.frame(cluster_id = "cgroup_L5_f51ff620", motivo = "materiali incompatibili: lo stesso studio contribuisce sia epitelio nasale sia sangue periferico allo stesso gruppo asma-vs-normale"),
  data.frame(cluster_id = "cgroup_L5_304e1195", motivo = "l'entita' e' il NOME DELLA CATEGORIA, non una cosa: sotto finiscono tessuto mammario esposto, tumore testa-collo HPV+, S. epidermidis su CD34+, neuroblastoma con RNA virale"),
  data.frame(cluster_id = "cgroup_L5_6d58c751", motivo = "il controllo non e' un controllo: un membro confronta tessuto di epatocarcinoma contro HepG2, che e' una linea cellulare di epatocarcinoma, non tessuto sano"),
  data.frame(cluster_id = "cgroup_L5_bfeacf75", motivo = "tre materiali biologici diversi sotto la stessa entita': monociti circolanti, macrofagi infiltranti il tumore, e tessuto in blocco"),
  data.frame(cluster_id = "cgroup_L5_38c9104c", motivo = "l'entita' e' il segnaposto 'unidentified' (NCBITaxon:32644) e i membri lo confermano: tre interventi scollegati, etichette degeneri"),
  data.frame(cluster_id = "cgroup_L5_d5e79c9e", motivo = "'diseased' e' una classe, non una malattia: tessuto malato non specificato, fibrosi polmonare, valvola aortica"),
  data.frame(cluster_id = "cgroup_L5_4def5638", motivo = "clinico contro sperimentale: biopsie muscolari di pazienti FSHD1 insieme a mioblasti coltivati e fibre da hIPS, dove il gene causale DUX4 e' notoriamente meno stabile"),
  data.frame(cluster_id = "cgroup_L5_d6fad784", motivo = "il controllo non e' un controllo: 'DM1 digitorum/bicipite/deltoide/diaframma' confrontati tutti contro 'quadricipite di controllo' — cambiano insieme malattia e sede anatomica"),
  data.frame(cluster_id = "cgroup_L5_67e7722b", motivo = "tre disegni diversi: un vero prima/dopo, un confronto fra due tipi cellulari distinti, e uno che cambia insieme origine cellulare e stato di differenziazione"),
  data.frame(cluster_id = "cgroup_L5_6e9f3913", motivo = "un membro non confronta tumore contro normale ma linfociti infiltranti contro linfociti del sangue: sottopopolazioni cellulari, non tessuti"),
  data.frame(cluster_id = "cgroup_L5_af8f3547", motivo = "popolazioni di base diverse: un membro e' su pazienti asmatici, un altro cambia definizione di controllo introducendo un vaccino, un terzo usa le sigle di visita AV/CV gia' dichiarate irrisolvibili"),
  data.frame(cluster_id = "cgroup_L5_6ce4ac22", motivo = "materiale non omogeneo: un confronto clinico diretto insieme a un disegno longitudinale con donatore fisso (fino a 526 giorni) e a uno su linfonodo"),
  data.frame(cluster_id = "cgroup_L5_855ca642", motivo = "ESCLUSO SU DECISIONE DELL'UTENTE (2026-08-03): 6 membri su 7 sono puliti, ma il settimo (GSE235768) usa come riferimento un 'vehicle (bortezomib)' invece del veicolo del confronto gemello nello stesso studio. Deciderlo richiederebbe il testo dello studio; si esclude invece di tenerlo per buono. Costo: si perdono anche i 6 confronti puliti"),
  stringsAsFactors = FALSE)
stopifnot(nrow(nuovi) == 18L, !anyDuplicated(nuovi$cluster_id))

# --- la chiave del contrasto, presa dall'oggetto vero ------------------------
cl <- readRDS(file.path(V13, "clusters.rds"))
m  <- match(nuovi$cluster_id, cl$cluster_id)
stopifnot(!anyNA(m))
nuovi$ckey <- paste(cl$contrast_entity[m], cl$contrast_direction[m],
                    cl$contrast_control_key[m], sep = "||")

vecchi <- utils::read.csv(VECCHI, stringsAsFactors = FALSE)
cat("verdetti esistenti:", nrow(vecchi), " | nuovi:", nrow(nuovi), "\n")

# Le sei chiavi vecchie non devono collidere con le nuove.
stopifnot(length(intersect(vecchi$ckey, nuovi$ckey)) == 0L)

fin <- rbind(vecchi[, c("ckey", "motivo")], nuovi[, c("ckey", "motivo")])
utils::write.csv(fin, OUT, row.names = FALSE)
cat("scritto:", OUT, "-", nrow(fin), "verdetti di incoerenza\n")
cat("\nNessun dubbio residuo: il gruppo H2O2 e' stato ESCLUSO su decisione dell'utente.\n")
