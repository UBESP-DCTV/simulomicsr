source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
i40 <- fread(file.path(S5, "80-insieme-40.csv")); i172 <- fread(file.path(S5, "80-insieme-172.csv"))
cat("40:", nrow(i40), sum(i40$cluster_id %in% d$cluster_id), " 172:", nrow(i172), sum(i172$cluster_id %in% d$cluster_id), "\n")
d[, prefisso := sub(":.*", "", contrast_entity)]
d[, insieme := fcase(cluster_id %in% i40$cluster_id, "40", cluster_id %in% i172$cluster_id, "132", default = "fuori")]
print(table(d$insieme))
print(table(d$prefisso, d$insieme))
print(table(d$kind_effective_resolved, d$prefisso))
print(table(d$contrast_direction))
options(width = 200)
print(as.data.frame(d[order(prefisso, -k_effective), .(contrast_entity, lab = substr(contrast_entity_label, 1, 40), kind = kind_effective_resolved, dir = contrast_direction, ctrl = substr(contrast_control_key, 1, 20), k = k_effective, ins = insieme)]), right = FALSE)
