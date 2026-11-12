import csv, collections, statistics, sys
D='/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/'
rd=lambda f: list(csv.DictReader(open(D+f,encoding='utf-8')))
ST=rd('27-stati.csv'); DIA=rd('27-diagnosi.csv'); PEG=rd('27-peggioramenti.csv'); PF=rd('27-per-forma.csv')
st=collections.defaultdict(dict)
for r in ST: st[r['errore']][r['corsa']]=r['stato']
corse=list(dict.fromkeys(r['corsa'] for r in ST))
print('corse',len(corse),corse); print('errori',len(st))
print('stati:',collections.Counter(r['stato'] for r in ST))
T=[(x,'B0',d) for x,d in zip("RP RPa RPb RPc RPd RP5 RC RC3 RA1 RA4 RR".split(),"P Pa Pb Pc Pd P5 C C3 A1 A4 R".split())]+[('RA4A3','RA4','A3')]
Mm=[('A0','A0A2','A2'),('A0','A0A3','A3'),('A0','A0C','C'),('A0','A0A1','A1'),
   ('A0A2','A0A2A3','A3'),('A0A2A3','A0A2A3A4','A4'),('A0A2A3A4','A0A2A3A4R','R'),('RA1PP5C','RA1PP5','C'),('RA1PP5','RA1P','P5'),('RA1P','RA1','P'),('RA1','B0','A1')]
PL={'B0':['B0pl1','B0pl2'],'A0':['A0pl1','A0pl2']}
def mov(s,a,b):
    if s[a]=='assente' and s[b]=='presente': return 'appare'
    if s[a]=='presente' and s[b]=='assente': return 'sparisce'
    if 'non valutabile' in (s[a],s[b]): return 'nv'
    return ''
def diagnosi(e, variante='codice'):
    s=st[e]
    kt={(d,mov(s,a,b)) for a,b,d in T if mov(s,a,b) in('appare','sparisce')}
    km={(d,mov(s,a,b)) for a,b,d in Mm if mov(s,a,b) in('appare','sparisce')}
    if variante=='mette_indip':  # la coppia (RA1,B0) non vale come «mette»
        km={(d,mov(s,a,b)) for a,b,d in Mm if (a,b)!=('RA1','B0') and mov(s,a,b) in('appare','sparisce')}
    doppie=kt&km; sole=(kt|km)-doppie
    inst_any=any(s[p]!=s[b] for b in PL for p in PL[b])
    inst_pres=any(s[p]!=s[b] for b in PL for p in PL[b] if s[b]=='presente')
    val=[v for v in s.values() if v!='non valutabile']
    anynv=any(mov(s,a,b)=='nv' for a,b,d in T+Mm)
    if variante=='placebo_tutti': inst_pres=inst_any
    if variante=='solo_basi':   # lettera stretta: le due prove definite solo per errori presenti in una base sola, verso coerente
        if s['B0']=='presente' and s['A0']=='assente': doppie={x for x in doppie if x[1]=='appare'}
        elif s['A0']=='presente' and s['B0']=='assente': doppie={x for x in doppie if x[1]=='sparisce'}
        else: doppie=set()
    if all(v=='presente' for v in val) and s['B0']=='presente' and s['A0']=='presente': return 'del modello'
    if doppie and not inst_pres: return 'della forma (%s)'%', '.join(sorted({d for d,_ in doppie}))
    if inst_any: return 'non deciso: instabile col placebo'
    if len(sole)==1: return 'non deciso: una direzione sola'
    if len(sole)>1: return 'non deciso: più cambi, nessuna prova doppia'
    if anynv: return 'non deciso: non valutabile'
    return 'non deciso: nessuna coppia a un cambio lo sposta'
import re
norm=lambda x: re.sub(r'\((.*)\)', lambda m:'('+', '.join(sorted(t.strip() for t in m.group(1).split(',')))+')', x) if x.startswith('della forma') else re.sub(r' \(.*$','',x)
nd=0
for r in DIA:
    mio=diagnosi(r['errore'])
    if norm(r['esito'])!=mio: nd+=1; print('DIVERSO',r['errore'],'|',r['esito'],'|',mio)
    # conti
    c=collections.Counter(st[r['errore']].values())
    assert (int(r['presente']),int(r['assente']),int(r['non_valutabile']))==(c['presente'],c['assente'],c['non valutabile']), r['errore']
print('esiti ricalcolati: diversi',nd,'su',len(DIA))
for v in ('codice','mette_indip','placebo_tutti','solo_basi'):
    cc=collections.Counter(re.sub(r' \(.*$','',diagnosi(e,v)) for e in st)
    print(v,dict(cc))
    if v!='codice':
        for e in st:
            a,b=diagnosi(e),diagnosi(e,v)
            if a!=b: print('    ',e,':',a,'->',b)
# severa del codice = mette_indip + placebo_tutti
