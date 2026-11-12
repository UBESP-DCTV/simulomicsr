# Passata di coerenza sulle eredita'. Lo stato di un'etichetta in una cella (corsa, studio) viene da una lettura fatta su
# un'altra corsa quando: (s) la cella divide la scheda (firma e unita') con altre corse; (a) ha la firma di una base;
# (b2) ha una firma gia' letta ma unita' diverse; (c) ha una firma letta nella lettura supplementare, condivisa.
# La firma non vede il livello di base ne' il motivo per cui lo studio non chiude. Qui ogni cella prende una impronta di
# struttura = motivi estesi + difetti della base (base vuota, base senza campioni) per fattore; il controllo scrive ogni gruppo
# di eredita' in cui le impronte non sono uguali. Quei gruppi si rileggono corsa per corsa.
# Uso: python3 eredita.py <cartella audit> <coerenza-basi.csv>
import csv,collections,sys,hashlib
D=sys.argv[1].rstrip('/')+'/'
ps={(r['corsa'],r['studio']):r for r in csv.DictReader(open(D+"24-per-studio.csv")) if r['corsa']!='B0-corsa2'}
dif=collections.defaultdict(list)
for r in csv.DictReader(open(sys.argv[2])): dif[(r['corsa'],r['studio'])].append(f"{r['fattore'].lower()}:{r['difetto']}")
def impronta(k,g): return (ps[(k,g)]['motivi_estesi'].lower(), ' ; '.join(sorted(dif[(k,g)])))
L={(r['corsa'],r['studio']):r['scheda'] for r in csv.DictReader(open(D+"24-da-leggere-righe.csv"))}
let=collections.defaultdict(set)
for r in csv.DictReader(open(D+"26-letture.csv")): let[(r['studio'],r['firma'])].add(r['scheda'])
su={(r['studio'],r['firma']) for r in csv.DictReader(open(D+"26-letture-senza-unita.csv"))}
base_di=lambda k: 'A0' if k.startswith('A0') else 'B0'
gruppi=collections.defaultdict(list)
for (k,g),r in ps.items():
    if k in ('B0','A0') or r['valida']!='TRUE': continue
    f12=r['firma'][:12]
    if (k,g) in L: gruppi[('s',L[(k,g)])].append(k); continue
    via=None
    for b in dict.fromkeys([base_di(k),'B0','A0']):
        o=ps[(b,g)]
        if o['valida']=='TRUE' and o['firma']==r['firma']: via=('a',g,b); break
    if via: gruppi[via].append(k); gruppi[via].append(via[2]) if via[2] not in gruppi[via] else None; continue
    sc=f"{g}|{f12}|{hashlib.sha256(r['unita'].encode()).hexdigest()[:8]}"
    if sc in let[(g,f12)]: gruppi[('s',sc)].append(k)
    elif let[(g,f12)]: gruppi[('b2',g,f12,tuple(sorted(let[(g,f12)])))].append(k)
    elif (g,f12) in su: gruppi[('c',g,f12)].append(k)
    else: print('cella senza fonte',k,g)
conta=collections.Counter(); n=0
for via,kk in sorted(gruppi.items(), key=str):
    g=via[1].split('|')[0]; conta[via[0]]+=len(kk)
    celle=list(kk)
    if via[0]=='b2':   # le corse della scheda letta fanno da termine di confronto
        celle+= [k for (k,gg),s in L.items() if gg==g and s in via[3]]
    im=collections.defaultdict(list)
    for k in dict.fromkeys(celle): im[impronta(k,g)].append(k)
    if len(im)>1 or via[0]=='b2':
        n+=1; print(f"\n=== {via}")
        for (m,b),c in im.items(): print(f"   {' '.join(c)}\n      motivi: {m[:260] or '-'}\n      basi: {b[:260] or '-'}")
print('\ncelle per via:',dict(conta),'| gruppi scritti:',n)
