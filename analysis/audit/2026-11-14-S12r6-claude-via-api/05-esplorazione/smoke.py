import os, sys, json, time
for l in open(".Renviron.local"):
    if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"]=l.strip().split("=",1)[1]
import anthropic
c=anthropic.Anthropic()
MODELLI=["claude-haiku-5-5","claude-sonnet-5-5","claude-opus-5-5","claude-fable-5-1"]
for m in MODELLI:
    try:
        info=c.models.retrieve(m)
        t=time.time()
        r=c.messages.create(model=m,max_tokens=2000,messages=[{"role":"user","content":"Reply with the single word: ok"}])
        txt="".join(b.text for b in r.content if b.type=="text")
        print(m,"| max_input",getattr(info,"max_input_tokens",None),"| max_out",getattr(info,"max_tokens",None),"| stop",r.stop_reason,"| testo",repr(txt[:20]),"| usage in/out",r.usage.input_tokens,r.usage.output_tokens,"| %.1fs"%(time.time()-t))
    except anthropic.APIStatusError as e:
        print(m,"ERRORE",e.status_code,str(e)[:300])
    except anthropic.APIConnectionError as e:
        print(m,"CONNESSIONE",str(e)[:200])
