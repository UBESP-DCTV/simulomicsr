import os, sys, json, time, copy
sys.path.insert(0, os.path.dirname(__file__))
src=open(os.path.join(os.path.dirname(__file__),"varianti.py")).read().split("studi=[")[0]
exec(src)
import jsonschema
def indietro(o,sc):
    # V3 -> forma B0: dove lo schema B0 ha prefixItems e l'uscita e' un oggetto v0..vn, torna a elenco
    if isinstance(sc,dict) and "anyOf" in sc and not isinstance(o,list):
        for alt in sc["anyOf"]:
            try: r=indietro(copy.deepcopy(o),alt); jsonschema.validate(r,alt); return r
            except Exception: pass
        return o
    if isinstance(sc,dict) and sc.get("type")=="array":
        if "prefixItems" in sc and isinstance(o,dict): return [indietro(o["v%d"%i],p) for i,p in enumerate(sc["prefixItems"])]
        if isinstance(o,list) and "items" in sc: return [indietro(x,sc["items"]) for x in o]
        return o
    if isinstance(sc,dict) and sc.get("type")=="object" and isinstance(o,dict):
        return {k:indietro(x,sc["properties"].get(k,{})) for k,x in o.items()}
    return o
for v,s in [(a,b) for b in sys.argv[2:] for a in sys.argv[1].split(",")]:
    x=R[s]; sc=tr(copy.deepcopy(x["schema"]),v); t=time.time()
    try:
        with c.messages.stream(model="claude-haiku-5-5",max_tokens=32000,system=P,messages=[{"role":"user","content":x["testo"]}],output_config={"format":{"type":"json_schema","schema":sc}}) as st:
            r=st.get_final_message()
        txt="".join(b.text for b in r.content if b.type=="text")
        try:
            o=json.loads(txt); o=indietro(o,x["schema"]) if v=="V3" else o
            err=sorted(jsonschema.Draft202012Validator(x["schema"]).iter_errors(o),key=lambda e:list(e.path))
            val="valido per lo schema B0" if not err else "NON valido per B0: %d errori; primo: %s @ %s"%(len(err),err[0].message[:160],list(err[0].path)[:6])
        except Exception as e: val="JSON non letto: "+str(e)[:100]
        print(v,s,"OK stop",r.stop_reason,"in/out",r.usage.input_tokens,r.usage.output_tokens,"%.0fs"%(time.time()-t),"|",val)
        open(os.path.join(os.path.dirname(__file__),"prova-%s-%s.json"%(v,s)),"w").write(txt)
    except anthropic.APIStatusError as e:
        print(v,s,"ERRORE",e.status_code,str(e)[:500],"%.0fs"%(time.time()-t))
    except anthropic.APIError as e:
        print(v,s,"ERRORE",type(e).__name__,str(e)[:300],"%.0fs"%(time.time()-t))
