# Disaccordi con i curatori di Gemma: conto ACCANTO, dichiarato DOPO i numeri della lettura (non sta nella carta).
# Domanda: fra le voci con gruppi diversi da Gemma, la causa cambia fra gli studi tenuti dall'accordo dei due lettori
# locali (Mistral B0 e Gemma-4-31B, colonna `tenuto` di 41-per-voce-M-rp11.csv) e gli studi non tenuti?
# Stima di dominio sul campione stratificato (pesi N_h/n_h: piu_fine 307/50, piu_grossa 156/40, incrociata 82/30),
# ricampionamento delle voci dentro le classi, B = 10.000, seme 20261115. Uso: Rscript (senza --vanilla) 32-accanto-tenuti.R
Q <- "analysis/audit/2026-11-15-disaccordi-con-gemma"
x <- read.csv(file.path(Q, "30-cause-per-scheda.csv"), stringsAsFactors = FALSE)
x <- x[x$classe_gruppi != "esca", ]
v <- read.csv("analysis/audit/2026-11-15-lettori-su-gemma/41-per-voce-M-rp11.csv", stringsAsFactors = FALSE)
stopifnot(nrow(x) == 120L, all(x$studio %in% v$studio), !anyDuplicated(v$studio))
x$tenuto <- v$tenuto[match(x$studio, v$studio)]
stopifnot(!anyNA(x$tenuto))
N <- c(piu_fine = 307, piu_grossa = 156, incrociata = 82)
x$w <- N[x$classe_gruppi] / as.numeric(table(x$classe_gruppi)[x$classe_gruppi])
x$err <- x$causa %in% c("errore_del_lettore", "errore_di_tutti_e_due")
x$cur <- x$causa %in% c("errore_del_curatore", "errore_di_tutti_e_due")
x$sce <- x$causa %in% "scelte_diverse"
# tutta la tabella: quante voci con gruppi diversi stanno negli studi tenuti
d <- v[v$classe_gruppi %in% names(N), ]
cat(sprintf("voci chiuse con gruppi diversi: %d; negli studi tenuti %d, negli altri %d\n", nrow(d), sum(d$tenuto), sum(!d$tenuto)))
print(table(classe = d$classe_gruppi, tenuto = d$tenuto))
cat("\ncampione: causa finale per tenuto (non pesato)\n"); print(table(causa = x$causa, tenuto = x$tenuto))
cat("\ncampione: classe dei gruppi per tenuto\n"); print(table(classe = x$classe_gruppi, tenuto = x$tenuto))
stima <- function(y) c(q_ten = sum(y$w * y$err * y$tenuto) / sum(y$w * y$tenuto),
                       q_non = sum(y$w * y$err * !y$tenuto) / sum(y$w * !y$tenuto),
                       n_ten = sum(y$w * y$err * y$tenuto), n_non = sum(y$w * y$err * !y$tenuto),
                       N_ten = sum(y$w * y$tenuto),
                       sce_ten = sum(y$w * y$sce * y$tenuto) / sum(y$w * y$tenuto),
                       cur_ten = sum(y$w * y$cur * y$tenuto) / sum(y$w * y$tenuto),
                       sce_non = sum(y$w * y$sce * !y$tenuto) / sum(y$w * !y$tenuto),
                       cur_non = sum(y$w * y$cur * !y$tenuto) / sum(y$w * !y$tenuto))
s <- stima(x); s["diff"] <- s["q_ten"] - s["q_non"]
set.seed(20261115L); B <- 10000L
idx <- split(seq_len(nrow(x)), x$classe_gruppi)
bb <- t(replicate(B, { i <- unlist(lapply(idx, function(k) k[sample.int(length(k), replace = TRUE)])); r <- stima(x[i, ]); c(r, diff = unname(r["q_ten"] - r["q_non"])) }))
ic <- apply(bb, 2, stats::quantile, c(.025, .975), na.rm = TRUE)
ten <- sum(v$tenuto); nonten <- sum(!v$tenuto)
cat(sprintf("\nvoci negli studi tenuti: %d; negli altri: %d (di cui non chiuse %d)\n", ten, nonten, sum(v$classe_gruppi == "non_chiuso")))
cat(sprintf("stima pesata delle voci con gruppi diversi negli studi tenuti: %.0f (vero: %d)\n", s["N_ten"], sum(d$tenuto)))
for (k in c("q_ten", "q_non", "diff", "sce_ten", "cur_ten", "sce_non", "cur_non"))
  cat(sprintf("%s: %.1f%% (IC95 %.1f, %.1f)\n", k, 100 * s[k], 100 * ic[1, k], 100 * ic[2, k]))
cat(sprintf("errore di lettura del lettore, voci stimate: negli studi tenuti %.0f (IC95 %.0f-%.0f) su %d = %.1f%% (%.1f-%.1f); negli altri %.0f (%.0f-%.0f) su %d = %.1f%% (%.1f-%.1f)\n",
            s["n_ten"], ic[1, "n_ten"], ic[2, "n_ten"], ten, 100 * s["n_ten"] / ten, 100 * ic[1, "n_ten"] / ten, 100 * ic[2, "n_ten"] / ten,
            s["n_non"], ic[1, "n_non"], ic[2, "n_non"], nonten, 100 * s["n_non"] / nonten, 100 * ic[1, "n_non"] / nonten, 100 * ic[2, "n_non"] / nonten))
# quanti dei 9 decisi da me, e la misura senza di loro (sensibilita')
cat(sprintf("\ndecise da me: %d; causa finale: %s\n", sum(x$decisa_da_me), paste(names(table(x$causa[x$decisa_da_me])), table(x$causa[x$decisa_da_me]), collapse = ", ")))
cat("fine ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n")
