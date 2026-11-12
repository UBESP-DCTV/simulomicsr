# Ruolo scritto per una colonna in ogni corsa: python3 ruoli.py <GSE> <colonna> [<colonna> ...]
import json,glob,os,sys
g=sys.argv[1]; cc=sys.argv[2:]
for f in sorted(glob.glob('analysis/p4-output/S12r4-forme/*.jsonl')):
    k=os.path.basename(f)[:-6]
    for l in open(f):
        if g not in l: continue
        d=json.loads(l)
        try: raw=json.loads(d['raw'])
        except Exception: print(k,'uscita non leggibile'); continue
        if raw.get('series_id')!=g: continue
        cols=(raw.get('columns') or [])+(raw.get('other_columns') or [])
        o=[]
        for c in cc:
            r=[x for x in cols if isinstance(x,dict) and x.get('column')==c]
            fa=[fx.get('name') for fx in raw.get('factors',[]) if c in json.dumps(fx.get('assignment',''))+json.dumps(fx.get('source_columns',''))]
            o.append(f"{c}: "+("; ".join(f"{x.get('role')}/{x.get('subject_kind','')} mancanti={x.get('missing_values')}" for x in r) or '-')+(f" fattori={fa}" if fa else ''))
        print(f"{k:10s}", ' | '.join(o))
