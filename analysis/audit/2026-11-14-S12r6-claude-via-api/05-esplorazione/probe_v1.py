import os, json, sys
for l in open(".Renviron.local"):
    if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"]=l.strip().split("=",1)[1]
import anthropic
c=anthropic.Anthropic(max_retries=2, timeout=600)
S=json.load(open("analysis/audit/2026-11-10-S12r2-prova-ripetuta/20-schema-v1.json"))
def sp(o, top=True):
    if isinstance(o,list): return [sp(x,False) for x in o]
    if not isinstance(o,dict): return o
    return {k:sp(v,False) for k,v in o.items() if k not in ("$schema","$id","title")}
variants={"intero":S,"senza_meta":sp(S)}
for nome,sc in variants.items():
    for m in ["claude-haiku-5-5","claude-sonnet-5-5","claude-opus-5-5","claude-fable-5-1"]:
        try:
            r=c.messages.create(model=m,max_tokens=1,system="You write JSON.",
                messages=[{"role":"user","content":"Write an empty factor table for a series named GSE0 with no factors."}],
                output_config={"effort":"high","format":{"type":"json_schema","schema":sc}})
            print(nome,m,"compila",r.stop_reason,r.usage.input_tokens, r.model)
        except Exception as e:
            print(nome,m,"ERRORE",str(e)[:300])
