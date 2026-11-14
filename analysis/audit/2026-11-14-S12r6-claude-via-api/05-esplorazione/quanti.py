import os, sys, json, copy
src=open(os.path.join(os.path.dirname(__file__),"varianti.py")).read().split("studi=[")[0]
exec(src)
from concurrent.futures import ThreadPoolExecutor
def prova(s):
    x=R[s]; sc=tr(copy.deepcopy(x["schema"]),"V2")
    try:
        c.messages.create(model="claude-haiku-5-5",max_tokens=1,system=P,messages=[{"role":"user","content":x["testo"]}],output_config={"format":{"type":"json_schema","schema":sc}})
        return (s,len(json.dumps(x["schema"])),"compila")
    except anthropic.APIStatusError as e:
        return (s,len(json.dumps(x["schema"])),"troppo grande" if "too large" in str(e) else "altro: "+str(e)[80:300])
with ThreadPoolExecutor(4) as ex: es=sorted(ex.map(prova,R),key=lambda t:t[1])
for e in es: print(*e)
from collections import Counter; print(Counter(e[2][:13] for e in es))
