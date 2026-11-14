import os, sys, json, time
for l in open(".Renviron.local"):
    if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"]=l.strip().split("=",1)[1]
import anthropic
c=anthropic.Anthropic(max_retries=2, timeout=600)
P=open("analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md",encoding="utf-8").read()
R={json.loads(l)["record_id"]:json.loads(l) for l in open("analysis/input/S12r3-lettore-v2-ingresso.jsonl",encoding="utf-8")}
per=sorted(R,key=lambda k:len(json.dumps(R[k]["schema"])))
studi=[per[0],per[len(per)//2],"GSE57945"] if len(sys.argv)<2 else sys.argv[1:]
for s in studi:
    x=R[s]; n=len(json.dumps(x["schema"]))
    for nome,f in (("count_tokens",lambda: c.messages.count_tokens(model="claude-haiku-5-5",system=P,messages=[{"role":"user","content":x["testo"]}],output_config={"format":{"type":"json_schema","schema":x["schema"]}}).input_tokens),
                   ("create",lambda: c.messages.create(model="claude-haiku-5-5",max_tokens=16000,system=P,messages=[{"role":"user","content":x["testo"]}],output_config={"format":{"type":"json_schema","schema":x["schema"]}}))):
        t=time.time()
        try:
            r=f()
            if nome=="create":
                txt="".join(b.text for b in r.content if b.type=="text")
                print(s,n,nome,"OK stop",r.stop_reason,"in/out",r.usage.input_tokens,r.usage.output_tokens,"%.0fs"%(time.time()-t),txt[:150].replace("\n"," "))
            else: print(s,n,nome,"OK",r)
        except anthropic.APIStatusError as e:
            print(s,n,nome,"ERRORE",e.status_code,str(e)[:600])
        except anthropic.APIError as e:
            print(s,n,nome,"ERRORE",type(e).__name__,str(e)[:300])
