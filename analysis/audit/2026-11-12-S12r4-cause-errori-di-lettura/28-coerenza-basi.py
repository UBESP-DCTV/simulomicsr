# Passata meccanica sulle basi: python3 coerenza_basi.py [<csv di uscita>]
# Per ogni corsa, studio e fattore di tipo perturbation o state:
#  (a) base_vuota: il fattore non scrive il livello di base;
#  (b) base_senza_campioni: la base e' scritta ma nessuna voce la assegna.
# Non giudica: elenca. Le righe si confrontano con le etichette di 26-letture.csv.
import json,glob,os,sys,csv
def voci(f):
    a=f.get('assignment'); o=[]
    if isinstance(a,dict):
        for v in a.get('values') or []:
            if isinstance(v,dict): o.append(v.get('level'))
    elif isinstance(a,list):
        for v in a:
            if isinstance(v,dict): o.append(v.get('level'))
    return o
righe=[]
for fp in sorted(glob.glob('analysis/p4-output/S12r4-forme/*.jsonl')):
    k=os.path.basename(fp)[:-6]
    for l in open(fp):
        try: d=json.loads(l); raw=json.loads(d['raw'])
        except Exception: continue
        g=raw.get('series_id')
        for f in raw.get('factors',[]) or []:
            if not isinstance(f,dict) or f.get('type') not in ('perturbation','state'): continue
            b=f.get('baseline_level'); lv=[str(x) for x in voci(f) if x is not None]
            if b is None or str(b).strip()=='' : righe.append((k,g,f.get('name'),f.get('type'),'base_vuota',''))
            elif str(b) not in lv: righe.append((k,g,f.get('name'),f.get('type'),'base_senza_campioni',str(b)))
out=sys.argv[1] if len(sys.argv)>1 else None
if out:
    w=csv.writer(open(out,'w',newline='')); w.writerow(['corsa','studio','fattore','tipo','difetto','base']); w.writerows(righe)
import collections
c=collections.Counter((r[4]) for r in righe); print(dict(c), 'righe', len(righe), 'studi', len({r[1] for r in righe}))
