# Le voci scritte per una colonna in ogni corsa: python3 voci.py <GSE> <colonna> [<parte del valore>]
# Per ogni fattore che legge la colonna: nome, tipo, base e livello dato a ogni valore.
import json,glob,os,sys
g=sys.argv[1]; col=sys.argv[2]; filtro=sys.argv[3] if len(sys.argv)>3 else None
def voci(f):
    a=f.get('assignment'); o=[]
    if isinstance(a,dict):
        c=a.get('column') or f.get('source_column') or ''
        for v in a.get('values') or []:
            if isinstance(v,dict): o.append((c, str(v.get('value', v.get('values'))), v.get('level')))
    elif isinstance(a,list):
        for v in a:
            if not isinstance(v,dict): continue
            for w in v.get('when') or []:
                if isinstance(w,dict): o.append((w.get('column'), str(w.get('value')), v.get('level')))
    return o
for fp in sorted(glob.glob('analysis/p4-output/S12r4-forme/*.jsonl')):
    k=os.path.basename(fp)[:-6]
    for l in open(fp):
        if g not in l: continue
        d=json.loads(l)
        try: raw=json.loads(d['raw'])
        except Exception: print(f"{k:10s} uscita non leggibile"); continue
        if raw.get('series_id')!=g: continue
        o=[]
        for f in raw.get('factors',[]):
            vv=[(v,lv) for c,v,lv in voci(f) if c==col and (filtro is None or filtro.lower() in v.lower())]
            if vv: o.append(f"{f.get('name')}[{f.get('type')}; base «{f.get('baseline_level')}»]: "+"; ".join(f"{v[:28]}→{lv}" for v,lv in vv[:12])+(" …" if len(vv)>12 else ""))
        print(f"{k:10s}", ' || '.join(o) or '-')
