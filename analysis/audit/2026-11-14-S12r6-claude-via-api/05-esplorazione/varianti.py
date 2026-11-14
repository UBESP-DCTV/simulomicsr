import os, sys, json, time, copy
for l in open(".Renviron.local"):
    if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"]=l.strip().split("=",1)[1]
import anthropic
c=anthropic.Anthropic(max_retries=2, timeout=900)
P=open("analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md",encoding="utf-8").read()
R={json.loads(l)["record_id"]:json.loads(l) for l in open("analysis/input/S12r3-lettore-v2-ingresso.jsonl",encoding="utf-8")}
def tr(o,v):
    if isinstance(o,list): return [tr(x,v) for x in o]
    if not isinstance(o,dict): return o
    o={k:tr(x,v) for k,x in o.items() if k not in ("$schema","title")}
    if o.get("type")=="array":
        mn,mx=o.pop("minItems",None),o.pop("maxItems",None)
        if "prefixItems" in o:
            pi=o["prefixItems"]
            if v=="V1": pass                                   # solo senza min/max
            elif v=="V2":                                      # elenco libero di voci a scelta chiusa
                del o["prefixItems"]; o["items"]={"anyOf":pi} if len(pi)>1 else pi[0]
            elif v=="V3":                                      # oggetto con una chiave per posizione, tutte richieste
                return {"type":"object","additionalProperties":False,"required":["v%d"%i for i in range(len(pi))],
                        "properties":{"v%d"%i:p for i,p in enumerate(pi)}}
        elif mx==0 and v!="V1":
            pass
    return o
studi=["GSE67812","GSE71595","GSE57945"]
for v in ("V1","V2","V3"):
    for s in studi:
        x=R[s]; sc=tr(copy.deepcopy(x["schema"]),v); t=time.time()
        try:
            n=c.messages.count_tokens(model="claude-haiku-5-5",system=P,messages=[{"role":"user","content":x["testo"]}],output_config={"format":{"type":"json_schema","schema":sc}}).input_tokens
            print(v,s,len(json.dumps(sc)),"count_tokens OK",n)
        except anthropic.APIStatusError as e:
            print(v,s,len(json.dumps(sc)),"ERRORE",e.status_code,str(e)[60:420])
