import os, json, statistics as st
from concurrent.futures import ThreadPoolExecutor
for l in open(".Renviron.local"):
    if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"]=l.strip().split("=",1)[1]
import anthropic
c=anthropic.Anthropic(max_retries=5)
P=open("analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md",encoding="utf-8").read()
R=[json.loads(l) for l in open("analysis/input/S12r3-lettore-v2-ingresso.jsonl",encoding="utf-8")]
MODELLI=["claude-haiku-5-5","claude-sonnet-5-5","claude-opus-5-5","claude-fable-5-1"]
def conta(a):
    m,x=a
    return c.messages.count_tokens(model=m,system=P,messages=[{"role":"user","content":x["testo"]}]).input_tokens
out={}
for m in MODELLI:
    with ThreadPoolExecutor(4) as ex: n=list(ex.map(conta,[(m,x) for x in R]))
    out[m]=n
    print(m,"somma",sum(n),"mediana",st.median(n),"max",max(n),R[n.index(max(n))]["record_id"],"oltre 100K:",sum(v>100000 for v in n))
json.dump({"studi":[x["record_id"] for x in R],"token":out},open(os.path.join(os.path.dirname(__file__),"token-ingresso.json"),"w"))
