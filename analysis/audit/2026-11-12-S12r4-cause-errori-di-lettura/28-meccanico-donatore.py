# Controllo meccanico: l'etichetta «<GSE>:source_name_ch1 come donatore» contro il ruolo scritto nelle uscite.
# Uso: python3 meccanico_donatore.py <cartella audit>
import json,glob,os,csv,collections,sys
D=sys.argv[1]
st=list(csv.DictReader(open(D+'/27-stati.csv')))
lab={(r['studio'],r['corsa']):r['stato'] for r in st if r['errore'].endswith(':source_name_ch1 come donatore')}
studi=sorted({g for g,_ in lab})
mecc=collections.defaultdict(dict); tutti=collections.defaultdict(dict)
for f in sorted(glob.glob('analysis/p4-output/S12r4-forme/*.jsonl')):
    k=os.path.basename(f)[:-6]
    for l in open(f):
        d=json.loads(l)
        try: raw=json.loads(d['raw'])
        except Exception: continue
        g=raw.get('series_id'); cols=(raw.get('columns') or [])+(raw.get('other_columns') or [])
        v=any(c.get('column')=='source_name_ch1' and c.get('role')=='subject' and c.get('subject_kind')=='donor' for c in cols if isinstance(c,dict))
        tutti[g][k]=v
n=0; disc=0
for (g,k),s in sorted(lab.items()):
    if k not in tutti.get(g,{}): print('SENZA USCITA LEGGIBILE',g,k,s); continue
    n+=1
    if (s=='presente')!=tutti[g][k]: disc+=1; print('DISCORDE',g,k,'meccanico',tutti[g][k],'stato',s)
print('celle confrontate',n,'discordi',disc,'studi con etichetta',len(studi))
senza=sorted(g for g in tutti if g not in studi and any(tutti[g].values()))
print('studi SENZA etichetta con source_name_ch1 subject/donor in almeno una corsa:',len(senza))
for g in senza: print('  ',g,' '.join(k for k,v in sorted(tutti[g].items()) if v))
