# Aggiunge un'etichetta a una scheda gia' letta: python3 aggiungi.py <prefisso della scheda> "<GSE:etichetta>" ["<testo da accodare alla descrizione>"]
import csv,sys
F="analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/26-letture-schede.csv"
p,e=sys.argv[1],sys.argv[2]; piu=sys.argv[3] if len(sys.argv)>3 else ""
rr=list(csv.DictReader(open(F))); m=[r for r in rr if r["scheda"].startswith(p)]
assert len(m)==1, f"schede trovate: {len(m)}"
r=m[0]; ee=[x for x in r["errore"].split(";") if x]
if e not in ee: ee.append(e)
r["errore"]=";".join(sorted(ee))
if piu: r["descrizione"]=r["descrizione"]+"; "+piu
w=csv.DictWriter(open(F,"w",newline=""),fieldnames=list(rr[0].keys()),quoting=csv.QUOTE_ALL); w.writeheader(); w.writerows(rr)
print(r["scheda"],"|",r["errore"])
