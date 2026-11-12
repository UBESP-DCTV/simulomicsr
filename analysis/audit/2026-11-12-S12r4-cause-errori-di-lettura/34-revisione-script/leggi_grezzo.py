import json, sys
R="/home/user/simulomicsr/analysis/p4-output/S12r4-forme/"
CORSE=["B0","RP","RPa","RPb","RPc","RPd","RP5","RC","RC3","RA1","RA4","RA4A3","RR","RA1P","RA1PP5","RA1PP5C","F1","F2","F12","B0pl1","B0pl2","A0","A0C","A0A1","A0A3","A0A2","A0A2A3","A0A2A3A4","A0A2A3A4R","A0pl1","A0pl2"]
_c={}
def rec(f,s):
    if f not in _c:
        _c[f]={}
        for l in open(R+f+".jsonl"):
            r=json.loads(l); _c[f][r["record_id"]]=r
    return _c[f].get(s)
def fattori(j):
    out=[]
    for f in j.get("factors",[]) or []:
        src=[]; ass=[]
        if "source_columns" in f: src+=list(f["source_columns"] or [])
        if "source_column" in f: src.append(f["source_column"])
        a=f.get("assignment")
        if isinstance(a,dict):
            if a.get("column"): src.append(a["column"])
            for v in a.get("values",[]) or []:
                val=v.get("value") if "value" in v else v.get("values")
                ass.append((val, v.get("level") if "level" in v else v.get("special")))
            for v in a.get("special",[]) or []:
                ass.append((v.get("value"),"<"+str(v.get("special",v.get("level")))+">"))
        elif isinstance(a,list):
            for v in a:
                wh=v.get("when")
                if isinstance(wh,list):
                    for w in wh:
                        if w.get("column") and w["column"] not in src: src.append(w["column"])
                    val=" & ".join(f'{w.get("column")}={w.get("value")}' for w in wh) if len(wh)>1 else (wh[0].get("value") if wh else None)
                else: val=str(wh)
                ass.append((val,v.get("level")))
        lev=[l.get("level") for l in f.get("levels",[]) or []]
        out.append(dict(name=f.get("name"),type=f.get("type"),src=list(dict.fromkeys(src)),levels=lev,base=f.get("baseline_level"),ass=ass,raw=f))
    return out
def colonne(j):
    c=j.get("columns") or j.get("other_columns") or []
    return [(x.get("column"),x.get("role"),x.get("subject_kind"),x.get("missing_values")) for x in c]
def carica(f,s):
    r=rec(f,s)
    if r is None: return None,None,"assente"
    try: j=json.loads(r["raw"])
    except Exception as e: return r,None,"json rotto ("+str(r.get("fine"))+")"
    return r,j,r.get("fine")
def stampa(f,s,ass=True,maxass=40):
    r,j,fine=carica(f,s)
    print(f"===== {f} {s} fine={fine} n_out={r and r.get('n_out')}")
    if j is None:
        print("   RAW:",(r or {}).get("raw","")[:300]); return
    for x in fattori(j):
        print(f"  F {x['name']} [{x['type']}] src={x['src']} base={x['base']!r} levels={x['levels']}")
        if ass:
            a=x["ass"]
            print("     ass:", "; ".join(f"{v!r}->{l}" for v,l in a[:maxass]) + (f" ...(+{len(a)-maxass})" if len(a)>maxass else ""))
    print("  C", "; ".join(f"{c}:{ro}{'/'+sk if sk else ''}{' miss='+str(m) if m else ''}" for c,ro,sk,m in colonne(j)))
    if j.get("not_understood"): print("  NU",j["not_understood"])
if __name__=="__main__":
    s=sys.argv[1]; fs=sys.argv[2].split(",") if len(sys.argv)>2 else CORSE
    for f in fs: stampa(f,s)
