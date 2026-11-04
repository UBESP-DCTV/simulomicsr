#!/usr/bin/env bash
# Cancello 1: manifesto del deliverable e metadati LINCS. Uso: 12-sha-e-cancello-1.sh [scarichi]
# Con "scarichi" scrive anche gli SHA-256 dei file scaricati e li controlla con l'oid LFS di Hugging Face e l'md5 di GDC.
set -u
E=analysis/audit/2026-11-04-S7-validazione-esecuzione; L=/mnt/wwn-0x5000039d58caca35/lincs-meta
analysis/audit/2026-08-21-S2-deliverable-in-salvo/10-manifesto-e-copia.sh verifica | tail -1
tail -n +2 analysis/audit/2026-08-08-validazione-esterna/provenienza-file-scaricati.csv | while IFS=, read -r f b s u; do
  v=$(sha256sum "$L/$f" | cut -d' ' -f1); [ "$v" = "$s" ] && echo "OK $f" || echo "FALLISCE $f"
done
if [ "${1:-}" = scarichi ]; then
  ( cd "$L/level5" && sha256sum level5_beta_trt_cp_n720216x12328.gctx level5_beta_trt_misc_n8283x12328.gctx ) | tee "$E/12-sha256-lincs-level5.txt"
  ( cd "$L/level5/tahoe100m" && ls | grep parquet$ | xargs -P 16 -I{} sha256sum {} ) | sort -k2 > "$E/12-sha256-tahoe.txt"
  awk -F'\t' '{n=split($1,a,"/"); print $3"  "a[n]}' "$E/10-tahoe-elenco.tsv" | sort -k2 > /tmp/claude-1000/atteso-tahoe.txt
  diff -q /tmp/claude-1000/atteso-tahoe.txt "$E/12-sha256-tahoe.txt" && echo "OK tahoe: $(wc -l < "$E/12-sha256-tahoe.txt") file coincidono con l'oid LFS" || echo "FALLISCE tahoe"
  python3 - <<'PY'
import csv,hashlib,os
d="/mnt/wwn-0x5000039d58caca35/lincs-meta/level5/tcga/"; ko=0; n=0
for r in csv.DictReader(open("analysis/audit/2026-11-04-S7-validazione-esecuzione/10-tcga-coppie.tsv"),delimiter="\t"):
    n+=1
    if hashlib.md5(open(d+r["file_id"]+".tsv","rb").read()).hexdigest()!=r["md5"]: ko+=1; print("FALLISCE",r["file_id"])
print(("OK" if ko==0 else "FALLISCE"),"tcga:",n,"file,",ko,"diversi dall'md5 di GDC")
PY
fi
