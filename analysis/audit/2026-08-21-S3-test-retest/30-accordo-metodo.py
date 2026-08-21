#!/usr/bin/env python3
# analysis/audit/2026-08-21-S3-test-retest/30-accordo-metodo.py
#
# Il metro concorda con se stesso? Accordo fra il run originale (2026-08-19,
# verdetti-194.csv) e il retest (2026-08-21, verdetti-retest.csv), gruppo per
# gruppo, sulle 194: grezzo, kappa di Cohen con IC bootstrap, matrice 3x3,
# binario, per blocco, per fascia di k, sulle coppie gruppo-studio accusate, e
# le previsioni di 00-previsioni.md valutate una per una.
#
# Uso: python3 analysis/audit/2026-08-21-S3-test-retest/30-accordo-metodo.py [verdetti-retest.csv] [difetti-retest.csv] [suffisso output]
import csv, os, sys, re, glob, collections
sys.path.insert(0, 'analysis/audit/2026-08-21-S3-test-retest')
from lib_accordo import *
S = 'analysis/audit/2026-08-21-S3-test-retest'; R = 'analysis/audit/2026-08-20-rilettura-194'
P_RET = sys.argv[1] if len(sys.argv) > 1 else os.path.join(S, 'verdetti-retest.csv')
P_DIF = sys.argv[2] if len(sys.argv) > 2 else os.path.join(S, 'difetti-retest.csv')
SUF = sys.argv[3] if len(sys.argv) > 3 else 'retest'

orig = {r['cluster_id']: r for r in csv.DictReader(open(os.path.join(R, 'verdetti-194.csv')))}
ret  = {r['cluster_id']: r for r in csv.DictReader(open(P_RET))}
quadro = {r['cluster_id']: r for r in csv.DictReader(open(os.path.join(R, 'quadro-194.csv')))}
assert len(orig) == 194 and set(orig) == set(quadro)
mancanti = set(orig) - set(ret); extra = set(ret) - set(orig)
if mancanti or extra: print(f"ATTENZIONE: nel retest mancano {len(mancanti)} gruppi, in piu' {len(extra)}")
ids = sorted(set(orig) & set(ret))
print(f"gruppi confrontati: {len(ids)} (originale 194, retest {len(ret)})")

blocco_di = {}
for f in glob.glob(os.path.join(R, 'blocco-*.txt')):
    b = re.search(r'blocco-(\d\d)', f).group(1)
    for cid in re.findall(r'(?m)^## GRUPPO (\S+)', open(f).read()): blocco_di[cid] = b

a = [orig[i]['verdetto_finale'] for i in ids]; b = [ret[i]['verdetto_finale'] for i in ids]
bin_ = lambda v: ['difettosa' if x == 'difettosa' else 'non-difettosa' for x in v]
bin2 = lambda v: ['corretta' if x == 'corretta' else 'non-corretta' for x in v]

print("\n=== 1. I TOTALI ===")
ca, cb = collections.Counter(a), collections.Counter(b)
for k in CLASSI: print(f"  {k:10s} originale {ca[k]:4d}   retest {cb[k]:4d}   delta {cb[k]-ca[k]:+d}")

print("\n=== 2. ACCORDO A TRE CLASSI ===")
k3 = kappa(a, b); lo, hi = ic_bootstrap(a, b, kappa); alo, ahi = ic_bootstrap(a, b, accordo)
print(f"  accordo grezzo : {100*accordo(a,b):.1f}%  [IC95 {100*alo:.1f}, {100*ahi:.1f}]")
print(f"  kappa di Cohen : {k3:.3f}  [IC95 bootstrap {lo:.3f}, {hi:.3f}]")
stampa_matrice(matrice(a, b), 'originale', 'retest')

print("\n=== 3. ACCORDO BINARIO ===")
ab, bb = bin_(a), bin_(b); kb = kappa(ab, bb); blo, bhi = ic_bootstrap(ab, bb, kappa)
print(f"  difettosa / non-difettosa : accordo {100*accordo(ab,bb):.1f}%   kappa {kb:.3f} [{blo:.3f}, {bhi:.3f}]")
ac, bc = bin2(a), bin2(b)
print(f"  corretta  / non-corretta  : accordo {100*accordo(ac,bc):.1f}%   kappa {kappa(ac,bc):.3f}")

print("\n=== 4. IL VERSO DEL DISACCORDO ===")
rango = {'corretta': 0, 'incerta': 1, 'difettosa': 2}
peggio = sum(rango[y] > rango[x] for x, y in zip(a, b)); meglio = sum(rango[y] < rango[x] for x, y in zip(a, b))
print(f"  verso il peggio (corretta->incerta/difettosa, incerta->difettosa): {peggio}")
print(f"  verso il meglio: {meglio}")
inc_orig = [i for i in ids if orig[i]['verdetto_finale'] == 'incerta']
inc_stabili = sum(ret[i]['verdetto_finale'] == 'incerta' for i in inc_orig)
print(f"  delle {len(inc_orig)} incerte originali restano incerte: {inc_stabili}")

print("\n=== 5. PER BLOCCO (stesso lettore/critici/arbitro, contesto identico) ===")
per_b = collections.defaultdict(list)
for i, x, y in zip(ids, a, b): per_b[blocco_di[i]].append(x == y)
with open(os.path.join(S, f'accordo-per-blocco-{SUF}.csv'), 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['blocco', 'n', 'concordi', 'accordo'])
    for bl in sorted(per_b):
        v = per_b[bl]; w.writerow([bl, len(v), sum(v), round(sum(v)/len(v), 3)])
        print(f"  blocco {bl}: {sum(v):2d}/{len(v):2d}  {100*sum(v)/len(v):5.1f}%")

print("\n=== 6. PER FASCIA DI k (studi poolati) ===")
def fascia(k):
    k = int(k); return 'k=3' if k == 3 else 'k=4-5' if k <= 5 else 'k=6-10' if k <= 10 else 'k>10'
per_k = collections.defaultdict(list)
for i, x, y in zip(ids, a, b): per_k[fascia(quadro[i]['k_effective'])].append((x, y))
for fk in ['k=3', 'k=4-5', 'k=6-10', 'k>10']:
    v = per_k[fk]; aa = [x for x, _ in v]; bb2 = [y for _, y in v]
    print(f"  {fk:7s} n={len(v):3d}  accordo {100*accordo(aa,bb2):5.1f}%  kappa {kappa(aa,bb2):.2f}")

print("\n=== 7. L'ETICHETTA NON CHIUDE ===")
na = [orig[i]['etichetta_non_chiude'] == 'True' for i in ids]; nb = [ret[i]['etichetta_non_chiude'] == 'True' for i in ids]
print(f"  originale {sum(na)}  retest {sum(nb)}  concordi {sum(x == y for x, y in zip(na, nb))}/{len(ids)}  "
      f"entrambi true {sum(x and y for x, y in zip(na, nb))}")

print("\n=== 8. LE COPPIE GRUPPO-STUDIO ACCUSATE ===")
def coppie(p):
    s = set(); st = collections.defaultdict(set)
    for r in csv.DictReader(open(p)):
        if r['cluster_id'] in set(ids): s.add((r['cluster_id'], r['study_id'])); st[r['cluster_id']].add(r['study_id'])
    return s, st
co, so = coppie(os.path.join(R, 'difetti.csv')); cr, sr = coppie(P_DIF)
inter = co & cr
print(f"  coppie originale {len(co)}  retest {len(cr)}  comuni {len(inter)}  "
      f"ritrovate {100*len(inter)/max(len(co),1):.1f}%  Jaccard {len(inter)/max(len(co|cr),1):.3f}")
print(f"  studi distinti accusati: originale {len({s for _, s in co})}  retest {len({s for _, s in cr})}  comuni {len({s for _, s in inter})}")
go, gr = set(so), set(sr)
print(f"  gruppi con >=1 difetto: originale {len(go)}  retest {len(gr)}  comuni {len(go & gr)}")
for nome, cid in [('IL22', None), ('obese', None), ('sals', None)]:
    for i in ids:
        if quadro[i]['contrast_entity_label'] == nome or quadro[i]['contrast_entity'] == nome:
            print(f"  caso di coda {nome:6s}: originale {orig[i]['verdetto_finale']:10s} retest {ret[i]['verdetto_finale']:10s} "
                  f"studi accusati orig={sorted(so.get(i, []))} ret={sorted(sr.get(i, []))}")

print("\n=== 9. I DISACCORDI, uno per riga (disaccordi-<suffisso>.csv) ===")
with open(os.path.join(S, f'disaccordi-{SUF}.csv'), 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['cluster_id', 'nome', 'k', 'blocco', 'originale', 'retest', 'motivo_originale', 'motivo_retest'])
    for i, x, y in zip(ids, a, b):
        if x != y:
            q = quadro[i]; w.writerow([i, q['contrast_entity_label'], q['k_effective'], blocco_di[i], x, y, orig[i]['motivo'], ret[i]['motivo']])
            print(f"  {q['contrast_entity_label'][:28]:28s} k={int(q['k_effective']):3d} b{blocco_di[i]}  {x:10s} -> {y}")

print("\n=== 10. LE PREVISIONI (00-previsioni.md) ===")
acc3 = 100 * accordo(a, b); accb = 100 * accordo(ab, bb)
esiti = [
 ('P1 accordo 3 classi 78-90% e kappa 0,55-0,80', 78 <= acc3 <= 90 and 0.55 <= k3 <= 0.80, f"{acc3:.1f}%, kappa {k3:.2f}"),
 ('P2 accordo binario >= 85%', accb >= 85, f"{accb:.1f}%"),
 ('P3 meno di meta\' delle incerte resta incerta', inc_stabili < len(inc_orig) / 2, f"{inc_stabili}/{len(inc_orig)}"),
 ('P4 totali entro +-12', all(abs(cb[k] - ca[k]) <= 12 for k in CLASSI), ", ".join(f"{k} {cb[k]-ca[k]:+d}" for k in CLASSI)),
 ('P5 coppie accusate ritrovate >= 60% (Jaccard >= 0,45)', len(inter) / max(len(co), 1) >= 0.60 and len(inter) / max(len(co | cr), 1) >= 0.45,
  f"{100*len(inter)/max(len(co),1):.1f}%, Jaccard {len(inter)/max(len(co|cr),1):.2f}"),
 ('P6 piu\' verso il peggio che verso il meglio', peggio > meglio, f"{peggio} contro {meglio}"),
]
for nome, ok, val in esiti: print(f"  {'VERA ' if ok else 'FALSA'}  {nome:55s} -> {val}")
dec = 'ALTO' if (k3 >= 0.60 and accb >= 85) else 'BASSO' if (k3 < 0.40 or accb < 75) else 'ZONA GRIGIA'
print(f"\n  DECISIONE secondo la soglia fissata prima del run: accordo {dec}  (kappa {k3:.2f} [{lo:.2f}, {hi:.2f}], binario {accb:.1f}%)")
