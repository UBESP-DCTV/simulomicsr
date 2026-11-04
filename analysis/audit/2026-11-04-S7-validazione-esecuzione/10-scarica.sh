#!/usr/bin/env bash
# Passo A, punto 1: scarica le fonti della validazione esterna. Ogni ripresa continua dal punto raggiunto (curl -C -).
# Uso: setsid nohup bash 10-scarica.sh lincs|tahoe|tcga-elenco|tcga < /dev/null >> log 2>&1 &
set -uo pipefail
R=/mnt/wwn-0x5000039d58caca35/lincs-meta/level5
E=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$R/tahoe100m" "$R/tcga"
case "$1" in
lincs)
  cd "$R"
  B=https://s3.amazonaws.com/macchiato.clue.io/builds/LINCS2020/level5
  for f in level5_beta_trt_misc_n8283x12328.gctx level5_beta_trt_cp_n720216x12328.gctx; do
    curl -fsS -C - --retry 20 --retry-delay 30 --retry-all-errors -o "$f" "$B/$f" && echo "fatto $f $(date -Is)" || echo "ERRORE $f $(date -Is)"
  done ;;
tahoe)
  cd "$R/tahoe100m"
  python3 - "$E/10-tahoe-elenco.tsv" <<'PY'
import json,sys,urllib.request
url="https://huggingface.co/api/datasets/tahoebio/Tahoe-100M/tree/main/metadata/pseudobulk_differential_expression?recursive=true&limit=1000"
righe=[]
while url:
    r=urllib.request.urlopen(url,timeout=120); d=json.load(r)
    righe+=[(x["path"],x["size"],x["lfs"]["oid"]) for x in d if x["type"]=="file"]
    l=r.headers.get("Link"); url=l.split(";")[0].strip("<> ") if l and 'rel="next"' in l else None
with open(sys.argv[1],"w") as f:
    for p,s,o in sorted(righe): f.write(f"{p}\t{s}\t{o}\n")
print(len(righe),"file")
PY
  cut -f1 "$E/10-tahoe-elenco.tsv" | xargs -P 6 -I{} sh -c 'b=$(basename {}); curl -fsSL -C - --retry 20 --retry-delay 30 --retry-all-errors -o "$b" "https://huggingface.co/datasets/tahoebio/Tahoe-100M/resolve/main/{}" || echo "ERRORE $b"'
  echo "fatto tahoe $(date -Is)" ;;
tcga-elenco)
  python3 - "$E/10-tcga-file.tsv" <<'PY'
import json,sys,urllib.request
prog=["TCGA-BRCA","TCGA-KIRC","TCGA-LUAD","TCGA-THCA","TCGA-PRAD","TCGA-LUSC","TCGA-LIHC","TCGA-HNSC","TCGA-COAD","TCGA-STAD","TCGA-UCEC","TCGA-KIRP","TCGA-KICH","TCGA-BLCA","TCGA-ESCA","TCGA-READ"]
filt={"op":"and","content":[{"op":"in","content":{"field":"cases.project.project_id","value":prog}},
 {"op":"=","content":{"field":"data_type","value":"Gene Expression Quantification"}},
 {"op":"=","content":{"field":"analysis.workflow_type","value":"STAR - Counts"}},
 {"op":"in","content":{"field":"cases.samples.sample_type","value":["Primary Tumor","Solid Tissue Normal"]}}]}
q={"filters":filt,"format":"JSON","size":20000,"fields":"file_id,file_name,md5sum,file_size,access,cases.submitter_id,cases.project.project_id,cases.samples.sample_type,cases.samples.submitter_id"}
r=urllib.request.Request("https://api.gdc.cancer.gov/files",data=json.dumps(q).encode(),headers={"Content-Type":"application/json"})
h=json.load(urllib.request.urlopen(r,timeout=300))["data"]["hits"]
n=0
with open(sys.argv[1],"w") as f:
    f.write("progetto\tcaso\ttipo\tcampione\tfile_id\tfile_name\tmd5\tbyte\taccess\n")
    for x in h:
        c=x["cases"][0]
        for s in c["samples"]:
            if s["sample_type"] in("Primary Tumor","Solid Tissue Normal"):
                f.write("\t".join([c["project"]["project_id"],c["submitter_id"],s["sample_type"],s["submitter_id"],x["file_id"],x["file_name"],x["md5sum"],str(x["file_size"]),x["access"]])+"\n"); n+=1
print(len(h),"file;",n,"righe")
PY
  ;;
tcga)
  cd "$R/tcga"
  python3 - "$E/10-tcga-file.tsv" "$E/10-tcga-coppie.tsv" <<'PY'
import csv,sys
from collections import defaultdict
righe=list(csv.DictReader(open(sys.argv[1]),delimiter="\t"))
per=defaultdict(dict)
for r in sorted(righe,key=lambda r:r["file_id"]):
    k=(r["progetto"],r["caso"])
    per[k].setdefault(r["tipo"],r)     # il primo per file_id
with open(sys.argv[2],"w") as f:
    f.write("progetto\tcaso\ttipo\tcampione\tfile_id\tfile_name\tmd5\tbyte\n")
    for (p,c),d in sorted(per.items()):
        if len(d)==2:
            for t,r in sorted(d.items()):
                f.write("\t".join([p,c,t,r["campione"],r["file_id"],r["file_name"],r["md5"],r["byte"]])+"\n")
PY
  tail -n +2 "$E/10-tcga-coppie.tsv" | cut -f5 | sort -u | xargs -P 8 -I{} sh -c '[ -s {}.tsv ] || curl -fsS --retry 20 --retry-delay 30 --retry-all-errors -o {}.tsv "https://api.gdc.cancer.gov/data/{}" || echo "ERRORE {}"'
  echo "fatto tcga $(date -Is)" ;;
esac
