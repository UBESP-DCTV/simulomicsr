# Verifica meccanica delle letture supplementari: per ogni (studio, firma) di 26-letture-senza-unita.csv e per ogni corsa che
# ha quella firma, scrive i fattori dell'uscita grezza (nome, tipo, base, colonne, livelli con i valori) e i ruoli delle colonne
# nominate. Le corse con lo stesso testo sono riunite. Uso: python3 fattori_celle.py <cartella audit> [<GSE> ...]
import csv,json,glob,os,sys,collections
D=sys.argv[1].rstrip('/')+'/'; solo=set(sys.argv[2:])
celle=collections.defaultdict(list)
for r in csv.DictReader(open(D+"27-celle-senza-unita.csv")): celle[(r['studio'],r['firma'])].append(r['corsa'])
def voci(f):
    a=f.get('assignment'); o=[]
    if isinstance(a,dict):
        c=a.get('column') or f.get('source_column') or ''
        for v in a.get('values') or []:
            if isinstance(v,dict): o.append((c, str(v.get('value', v.get('values'))), v.get('level')))
    elif isinstance(a,list):
        for v in a:
            if not isinstance(v,dict): continue
            ww=v.get('when') or []
            o.append((' & '.join(str(w.get('column')) for w in ww if isinstance(w,dict)), ' & '.join(str(w.get('value')) for w in ww if isinstance(w,dict)), v.get('level')))
    return o
raws={}
def raw(k,g):
    if (k,g) not in raws:
        for l in open(f'analysis/p4-output/S12r4-forme/{k}.jsonl'):
            if g not in l: continue
            d=json.loads(l)
            try: x=json.loads(d['raw'])
            except Exception: continue
            if x.get('series_id')==g: raws[(k,g)]=x
    return raws.get((k,g))
for r in csv.DictReader(open(D+"26-letture-senza-unita.csv")):
    g,fi=r['studio'],r['firma']
    if solo and g not in solo: continue
    print(f"\n##### {g} {fi} | {r['errore'] or '-'} | {r['descrizione'][:200]}")
    testi=collections.defaultdict(list)
    for k in celle[(g,fi)]:
        x=raw(k,g)
        if x is None: testi['uscita non leggibile'].append(k); continue
        o=[]
        for f in x.get('factors',[]):
            lv=collections.defaultdict(list)
            for c,v,l in voci(f): lv[str(l)].append(v[:22])
            cols=sorted({c for c,_,_ in voci(f)})
            o.append(f"  {f.get('name')}[{f.get('type')}; base «{f.get('baseline_level')}»; {','.join(cols)[:60]}] "+' ; '.join(f"{l}({len(v)}): {', '.join(v[:3])}{' …' if len(v)>3 else ''}" for l,v in lv.items()))
        sn=[c for c in (x.get('columns') or [])+(x.get('other_columns') or []) if isinstance(c,dict) and c.get('column')=='source_name_ch1']
        o.append("  source_name_ch1: "+('; '.join(f"{c.get('role')}/{c.get('subject_kind','')}" for c in sn) or '-'))
        testi['\n'.join(o)].append(k)
    for t,kk in testi.items(): print(' '.join(kk)); print(t)
