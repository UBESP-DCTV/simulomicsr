import sys, csv, json
sys.path.insert(0,"rev")
from leggi_grezzo import *
D="/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/"
out=[]
SIGLE=None
for k in CORSE:
    # GSE57945: Sex scritto come fattore
    r,j,fine=carica(k,"GSE57945")
    if j is None: out.append((k,"GSE57945","non leggibile",fine))
    else:
        F=fattori(j)
        sx=[f for f in F if any(s.lower() in("sex","gender") for s in f["src"]) or (f["name"] or "").lower() in ("sex","gender")]
        ruolo=[ro for c,ro,sk,m in colonne(j) if c=="Sex"]
        out.append((k,"GSE57945","presente" if sx else "assente", f"fattori={[ (f['name'],f['type'],f['src']) for f in sx]} ruolo Sex={ruolo} fine={fine}"))
    r,j,fine=carica(k,"GSE60340")
    if j is None: out.append((k,"GSE60340","non leggibile",fine))
    else:
        F=fattori(j)
        tr=[f for f in F if "treated with" in f["src"]]
        # anche: i valori di 'treated with' letti dentro un altro fattore?
        ruolo=[ro for c,ro,sk,m in colonne(j) if c=="treated with"]
        out.append((k,"GSE60340","assente" if tr else "presente", f"fattori={[(f['name'],f['type'],f['src'],f['base']) for f in F]} ruolo treated with={ruolo} fine={fine}"))
for o in out: print(*o,sep=" | ")
