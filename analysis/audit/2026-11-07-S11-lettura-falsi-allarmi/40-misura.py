#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/40-misura.py
# Dalla lettura (30-note-lettura.tsv, 25-lettura-allargata.csv) al riferimento corretto e alle misure di 00-previsioni.md.
# Uso: python3 -I analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/40-misura.py
import csv, random
from collections import Counter, defaultdict
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
B = 'analysis/audit/2026-11-07-S10b-metadati-campioni/'
S10 = 'analysis/audit/2026-11-07-S10-rilevatore/'
R = 'analysis/audit/2026-08-20-rilettura-194/'
SEME, NB = 20261107, 2000
conf = {c['record_id']: c for c in csv.DictReader(open(B + '20-confronti.csv'))}
es = {x['record_id']: x for x in csv.DictReader(open(B + '40-esiti.csv'))}
ordine = {int(x['n']): x for x in csv.DictReader(open(D + '23-ordine.csv'))}
note = list(csv.DictReader(open(D + '30-note-lettura.tsv'), delimiter='\t'))
alla = list(csv.DictReader(open(D + '25-lettura-allargata.csv')))
rif = list(csv.DictReader(open(S10 + '30-riferimento.csv')))
rif_id = {r['record_id'] for r in rif}
assert len(rif_id) == 129, len(rif_id)

# classi delle cause dei falsi allarmi (riga della lettura -> classe), assegnate leggendo la colonna causa
CLASSE = {
    9: 'modifica genetica o condizione di sfondo scritta solo sul trattato', 21: 'modifica genetica o condizione di sfondo scritta solo sul trattato',
    34: 'modifica genetica o condizione di sfondo scritta solo sul trattato', 72: 'modifica genetica o condizione di sfondo scritta solo sul trattato',
    79: 'modifica genetica o condizione di sfondo scritta solo sul trattato', 86: 'modifica genetica o condizione di sfondo scritta solo sul trattato',
    8: 'agente comune ai due bracci marcato come controllo nel controllo', 69: 'agente comune ai due bracci marcato come controllo nel controllo',
    74: 'agente comune ai due bracci marcato come controllo nel controllo',
    31: 'durata uguale scritta in modo diverso', 75: 'durata uguale scritta in modo diverso', 76: 'durata uguale scritta in modo diverso',
    4: 'campo del passaggio: valori vicini o non un passaggio', 68: 'campo del passaggio: valori vicini o non un passaggio',
    84: 'campo del passaggio: valori vicini o non un passaggio',
    35: 'mutazione del paziente scritta come knockout', 81: "nome dell'entita' non riconosciuto nell'agente",
    82: "nome dell'entita' non riconosciuto nell'agente", 87: 'perturbazione vuota contata come agente',
}

righe = []
for x in note:
    n = int(x['n']); o = ordine[n]; c = conf[o['record_id']]; e = es[o['record_id']]
    righe.append(dict(n=n, sezione=o['sezione'], record_id=o['record_id'], cluster_id=c['cluster_id'], study=c['study'],
                      trattato=c['tl'], controllo=c['cl'], insieme_S10=e['insieme'], combinazione=e['PROPOSTA'],
                      esito=x['esito'], fonte=x['fonte'], famiglia=x['famiglia'], motivo=x['motivo'], causa=x['causa'],
                      classe_causa=CLASSE.get(n, '')))
for i, x in enumerate(alla, 1):
    c = conf[x['record_id']]; e = es[x['record_id']]
    righe.append(dict(n=f'E{i:02d}', sezione='E', record_id=x['record_id'], cluster_id=c['cluster_id'], study=c['study'],
                      trattato=c['tl'], controllo=c['cl'], insieme_S10=e['insieme'], combinazione=e['PROPOSTA'],
                      esito=x['esito'], fonte=x['fonte'], famiglia=x['famiglia'], motivo=x['motivo'], causa=x['causa'], classe_causa=''))
# decisione del PI dopo il riassunto: una differenza solo tecnica fra i bracci e' un errore (28-lettura-tecnica.py)
idx_r = {r['record_id']: r for r in righe}; nt = 0
for x in csv.DictReader(open(D + '28-lettura-tecnica.csv')):
    if x['record_id'] in idx_r:
        r = idx_r[x['record_id']]
        r.update(esito=x['esito'], fonte=x['fonte'], famiglia=x['famiglia'], motivo=r['motivo'] + ' | DECISIONE TECNICA: ' + x['motivo'])
    else:
        nt += 1; c = conf[x['record_id']]; e = es[x['record_id']]
        righe.append(dict(n=f'T{nt:02d}', sezione='T', record_id=x['record_id'], cluster_id=c['cluster_id'], study=c['study'],
                          trattato=c['tl'], controllo=c['cl'], insieme_S10=e['insieme'], combinazione=e['PROPOSTA'],
                          esito=x['esito'], fonte=x['fonte'], famiglia=x['famiglia'], motivo=x['motivo'], causa='', classe_causa=''))
assert len({r['record_id'] for r in righe}) == len(righe) == 116 + nt, (len(righe), nt)
w = csv.DictWriter(open(D + '30-lettura.csv', 'w'), fieldnames=list(righe[0].keys())); w.writeheader(); w.writerows(righe)
L = {r['record_id']: r for r in righe}

out = []
def p(*a): out.append(' '.join(str(x) for x in a))

p('=== C3 copertura')
A = [r for r in righe if r['sezione'] == 'A']
p('righe A (elenco S10b):', len(A), '| con esito e motivo:', sum(bool(r['esito']) and bool(r['motivo']) for r in A))
tz = list(csv.DictReader(open(D + '22-candidati-tempo-zero.csv')))
p('candidati a tempo zero (22):', len(tz), '| letti:', sum(t['record_id'] in L for t in tz))
p('candidati allargati (24):', len(alla), '| letti:', sum(x['record_id'] in L for x in alla))
tec = list(csv.DictReader(open(D + '27-candidati-tecnici.csv')))
p('candidati tecnici (27):', len(tec), '| letti:', sum(x['record_id'] in L for x in tec))

p('=== C4 controlli')
attesi = {5: 'giusto', 23: 'sbagliato', 24: 'giusto', 55: 'sbagliato', 89: 'sbagliato'}
for n, a in attesi.items():
    r = [x for x in righe if x['n'] == n][0]
    p(f"  [{n:03d}] {r['study']} {r['trattato']!r}: atteso {a}, letto {r['esito']} -> {'OK' if r['esito'] == a else 'FALLITO'}")
p('  GSE126409 nel censimento:', sum(t['study'] == 'GSE126409' for t in tz), 'su 11; GSE221804:', sum(t['study'] == 'GSE221804' for t in tz), 'su 10')

p('=== Esiti della lettura')
p('righe A per insieme e esito:', sorted(Counter((r['insieme_S10'], r['esito']) for r in A).items()))
p('righe A per fonte (sbagliato):', dict(Counter(r['fonte'] for r in A if r['esito'] == 'sbagliato')))
for s in ('B', 'E', 'T'):
    X = [r for r in righe if r['sezione'] == s]
    p(f'sezione {s}:', len(X), sorted(Counter((r['insieme_S10'], r['esito']) for r in X).items()))

# --- riferimento corretto
nuovi = []
for r in righe:
    if r['sezione'] == 'C' and r['record_id'] in rif_id: continue
    if r['record_id'] in rif_id:
        if r['esito'] == 'giusto': raise SystemExit('un difettoso di agosto letto giusto: ' + r['record_id'])
        continue
    if r['esito'] in ('sbagliato', 'incerto'):
        nuovi.append(r)
# cambi di categoria su righe gia' nel riferimento (decisi nella lettura, scritti nel motivo)
CAT = {'GSE163241__GSE163241__grp_0002_vs_grp_0001__1': 'tempo zero (il passaggio non e\' confermato nei metadati)'}
reg = []
for r in nuovi:
    reg.append(dict(record_id=r['record_id'], cluster_id=r['cluster_id'], study=r['study'], prima=r['insieme_S10'],
                    dopo='difettoso' + (' (non provato)' if r['esito'] == 'incerto' else ''), fonte=r['fonte'],
                    famiglia=r['famiglia'], motivo=r['motivo'], riga_lettura=r['n']))
for rid, cat in CAT.items():
    r = L[rid]
    reg.append(dict(record_id=rid, cluster_id=r['cluster_id'], study=r['study'], prima='difettoso (passaggio di coltura non appaiato)',
                    dopo='difettoso (' + cat + ')', fonte=r['fonte'], famiglia=r['famiglia'], motivo=r['motivo'], riga_lettura=r['n']))
for r in righe:  # altri negativi letti giusti: diventano puliti
    if r['insieme_S10'] == 'altro_negativo' and r['esito'] == 'giusto':
        reg.append(dict(record_id=r['record_id'], cluster_id=r['cluster_id'], study=r['study'], prima='altro_negativo', dopo='pulito',
                        fonte='', famiglia='', motivo=r['motivo'], riga_lettura=r['n']))
w = csv.DictWriter(open(D + '40-registro-cambi.csv', 'w'), fieldnames=list(reg[0].keys())); w.writeheader(); w.writerows(reg)

rif2 = []
for r in rif:
    r2 = dict(r); r2['fonte'] = 'etichetta'; r2['sessione'] = 'S10 (rilettura di agosto)'
    if r['record_id'] in CAT: r2['categoria'] = CAT[r['record_id']]; r2['sessione'] += ', categoria cambiata in S11'
    rif2.append(r2)
for i, r in enumerate(nuovi, 1):
    rif2.append(dict(riga=f'S11-{i:03d}', cluster_id=r['cluster_id'], study_id=r['study'], record_id=r['record_id'], modo='lettura S11',
                     non_provato=str(r['esito'] == 'incerto'), categoria=r['famiglia'], etichetta_trattato=r['trattato'],
                     etichetta_controllo=r['controllo'], fonte=r['fonte'], sessione='S11'))
w = csv.DictWriter(open(D + '41-riferimento-dopo-S11.csv', 'w'), fieldnames=list(rif2[0].keys())); w.writeheader(); w.writerows(rif2)
dif = list(csv.DictReader(open(R + 'difetti.csv')))
dif2 = [dict(d, fonte='etichetta', sessione='agosto', non_provato='', record_id='') for d in dif]
for r in nuovi:
    dif2.append(dict(cluster_id=r['cluster_id'], study_id=r['study'], categoria=r['famiglia'],
                     etichetta=f"TRATTATO '{r['trattato']}' | CONTROLLO '{r['controllo']}' | {r['motivo']}",
                     fonte=r['fonte'], sessione='S11', non_provato=str(r['esito'] == 'incerto'), record_id=r['record_id']))
w = csv.DictWriter(open(D + '42-difetti-dopo-S11.csv', 'w'), fieldnames=list(dif2[0].keys())); w.writeheader(); w.writerows(dif2)

DIF_OLD = rif_id
DIF_NEW = rif_id | {r['record_id'] for r in nuovi}
DIF_NEW_P = rif_id | {r['record_id'] for r in nuovi if r['esito'] == 'sbagliato'}
p('=== Riferimento corretto')
p('difettosi prima:', len(DIF_OLD), '| nuovi:', len(nuovi), '(provati', sum(r['esito'] == 'sbagliato' for r in nuovi),
  ', non provati', sum(r['esito'] == 'incerto' for r in nuovi), ') | dopo:', len(DIF_NEW))
p('nuovi per fonte:', dict(Counter(r['fonte'] for r in nuovi)), '| per sezione:', dict(Counter(r['sezione'] for r in nuovi)))
p('nuovi per famiglia:', sorted(Counter(r['famiglia'] for r in nuovi).items(), key=lambda x: -x[1]))
p('nuovi segnalati dalla combinazione:', sum(es[r['record_id']]['PROPOSTA'] == '1' for r in nuovi), 'su', len(nuovi))

# --- sensibilita' e falsi allarmi
studi = sorted({c['study'] for c in conf.values()})
per_studio = defaultdict(list)
for rid, c in conf.items(): per_studio[c['study']].append(rid)
def sens(difset, flag='PROPOSTA', boot=True):
    num = sum(es[r][flag] == '1' for r in difset); den = len(difset)
    if not boot: return num, den, None
    rng = random.Random(SEME); v = []
    for _ in range(NB):
        nn = dd = 0
        for s in (rng.choice(studi) for _ in studi):
            for r in per_studio[s]:
                if r in difset: dd += 1; nn += es[r][flag] == '1'
        v.append(nn / dd if dd else float('nan'))
    v.sort(); return num, den, (v[int(0.025 * NB)], v[int(0.975 * NB) - 1])
p('=== Sensibilita\' della combinazione (bootstrap degli studi, B=2000, seme 20261107)')
for nome, S in (('riferimento S10', DIF_OLD), ('riferimento corretto', DIF_NEW), ('corretto, solo provati', DIF_NEW_P)):
    n_, d_, ic = sens(S); p(f'  {nome}: {n_}/{d_} = {100*n_/d_:.1f}% IC95 [{100*ic[0]:.1f}; {100*ic[1]:.1f}]')
flag = {r for r in conf if es[r]['PROPOSTA'] == '1'}
fa_old = sum(es[r]['insieme'] == 'pulito' for r in flag)
fa_new = sum(r not in DIF_NEW for r in flag)
p('  allarmi della combinazione:', len(flag), '| falsi allarmi prima (puliti):', fa_old, '| dopo la lettura:', fa_new)

p('=== Per parte della combinazione: allarmi veri e falsi dopo la lettura')
for k in ('R1', 'R2a', 'R2b', 'R6', 'S10_pulita'):
    F = [r for r in conf if es[r][k] == '1']
    p(f'  {k}: allarmi {len(F)} | difetti {sum(r in DIF_NEW for r in F)} | falsi {sum(r not in DIF_NEW for r in F)}')

p('=== Cause dei falsi allarmi (righe A lette giuste)')
G = [r for r in A if r['esito'] == 'giusto']
for k, v in Counter(r['classe_causa'] for r in G).most_common(): p(f'  {v:2d}  {k}')
p('  allarmi veri scattati per un motivo diverso dal difetto:', [r['n'] for r in A if r['esito'] == 'sbagliato' and r['causa']])

p('=== Tempo zero (decisione 1)')
T0 = [r for r in righe if 'tempo zero' in r['famiglia'] and r['esito'] == 'sbagliato']
p('confronti difettosi per tempo zero:', len(T0), '| studi:', len({r['study'] for r in T0}), '| meta-analisi:', len({r['cluster_id'] for r in T0}))
p('  di cui gia\' nel riferimento:', sum(r['record_id'] in rif_id for r in T0), '| segnalati dalla combinazione:', sum(es[r['record_id']]['PROPOSTA'] == '1' for r in T0))
tzid = {t['record_id']: t for t in tz}
solo_geo = [r for r in T0 if not (tzid.get(r['record_id'], {}).get('s1') == '1')]
p('P3 tempo zero leggibile nei metadati GEO senza tempo zero nello Stadio 1:', len(solo_geo), [r['study'] for r in solo_geo])

p('=== Previsione P2: righe A lette giuste (errori della regola)')
p('  giusto', sum(r['esito'] == 'giusto' for r in A), '| sbagliato', sum(r['esito'] == 'sbagliato' for r in A), '| incerto', sum(r['esito'] == 'incerto' for r in A))

# --- verdetti delle meta-analisi
ver = {v['cluster_id']: v['verdetto_finale'] for v in csv.DictReader(open(R + 'verdetti-194.csv'))}
in40 = {x['cluster_id'] for x in csv.DictReader(open('analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv')) if x['in40'] == 'TRUE'}
idx = {x['cluster_id']: x['nome'] for x in csv.DictReader(open(R + 'INDICE-194.csv'))}
nuovi_per = defaultdict(list)
for r in nuovi: nuovi_per[r['cluster_id']].append(r)
mov = []
for cid, rs in nuovi_per.items():
    prima = ver[cid]
    prov = any(r['esito'] == 'sbagliato' for r in rs)
    dopo = 'difettosa' if prov else ('incerta' if prima == 'corretta' else prima)
    mov.append(dict(cluster_id=cid, nome=idx[cid], prima=prima, dopo=dopo, nuovi=len(rs), in40=cid in in40,
                    studi=';'.join(sorted({r['study'] for r in rs}))))
w = csv.DictWriter(open(D + '45-verdetti-che-cambiano.csv', 'w'), fieldnames=list(mov[0].keys())); w.writeheader(); w.writerows(sorted(mov, key=lambda m: m['nome']))
p('=== P1 verdetti delle 194')
p('meta-analisi con difetti nuovi:', len(mov), '| transizioni:', sorted(Counter((m['prima'], m['dopo']) for m in mov).items()))
cd = [m for m in mov if m['prima'] == 'corretta' and m['dopo'] == 'difettosa']
p('da corretta a difettosa:', len(cd), [m['nome'] for m in cd])
p('nelle 40:', [(m['nome'], m['prima'], m['dopo']) for m in mov if m['in40'] and m['prima'] != m['dopo']])

# --- studi per meta-analisi, prima e dopo aver tolto i difetti
kdel = {x['cluster_id']: int(x['k_effective']) for x in csv.DictReader(open(D + '50-k-deliverable.csv'))}
st = defaultdict(set); st_old = defaultdict(set); st_new = defaultdict(set)
for rid, c in conf.items():
    st[c['cluster_id']].add(c['study'])
    if rid not in DIF_OLD: st_old[c['cluster_id']].add(c['study'])
    if rid not in DIF_NEW: st_new[c['cluster_id']].add(c['study'])
p('=== C2(c) studi distinti fra i confronti tenuti = k_effective del deliverable:', sum(len(st[c]) == kdel[c] for c in kdel), 'su', len(kdel))
sotto_old = [c for c in kdel if len(st_old[c]) < 3]; sotto_new = [c for c in kdel if len(st_new[c]) < 3]
p('meta-analisi sotto 3 studi togliendo i difettosi: riferimento S10', len(sotto_old), '| riferimento corretto', len(sotto_new))
p('  nuove sotto 3:', [(idx[c], len(st[c]), len(st_new[c])) for c in sotto_new if c not in sotto_old])
p('  nuove sotto 3 nelle 40:', [idx[c] for c in sotto_new if c not in sotto_old and c in in40])
open(D + '40-out.txt', 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
