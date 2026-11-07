#!/usr/bin/env python3
"""30-riferimento.py — S10: il riferimento al livello del confronto.

difetti.csv e' indicizzato per (gruppo, studio). Qui ogni riga si aggancia ai
confronti dei 1.903 che nomina come colpevoli:

  unico   la coppia (gruppo, studio) ha un solo confronto: si aggancia da sola;
  parser  il primo «TRATTATO <etichetta>» (e «CONTROLLO <etichetta>», se c'e')
          della riga, in uno dei quattro formati di citazione ('…', «…», "…",
          `…`), con le lettere greche tradotte, coincide con un confronto della
          coppia. Se piu' confronti hanno le stesse due etichette, la riga non
          li puo' distinguere e li prende tutti;
  mano    confronti che la riga nomina oltre al primo («e la gemella», «idem»,
          «stessa forma per», «tutti e due», «entrambi»), o righe che il parser
          non chiude. Ogni attribuzione ha il suo motivo, in A_MANO.

Il testo dopo «a fronte di», «accanto», «nello stesso studio» e simili nomina
un confronto di paragone, non il colpevole: il parser legge solo la prima
citazione dopo TRATTATO.

Uscite: 30-riferimento.csv (una riga per riga di difetti.csv e confronto),
30-a-mano.csv, 30-conto.txt.
Uso: python3 analysis/audit/2026-11-07-S10-rilevatore/30-riferimento.py
"""
import csv, collections, re

D = 'analysis/audit/2026-11-07-S10-rilevatore/'
A = list(csv.DictReader(open(D + '30-confronti-1903.csv')))
dif = list(csv.DictReader(open('analysis/audit/2026-08-20-rilettura-194/difetti.csv')))
assert len(A) == 1903 and len(dif) == 97

GRECHE = {'α': 'alpha', 'β': 'beta', 'γ': 'gamma', 'δ': 'delta', 'ε': 'epsilon', 'κ': 'kappa',
          'λ': 'lambda', 'μ': 'u', 'µ': 'u', 'ß': 'beta', 'τ': 'tau', 'ω': 'omega', 'θ': 'theta'}

def norm(s):
    s = ''.join(GRECHE.get(ch, ch) for ch in s)
    return re.sub(r'\s+', ' ', s.lower()).strip()

Q = r"(?:'([^']*?)'(?=\s|$|[,|)(;.:/])|«([^»]*)»|\"([^\"]*)\"|`([^`]*)`)"
RX_T = re.compile(r'TRATTATO\s*:?\s*' + Q)
RX_C = re.compile(r'CONTROLLO\s*:?\s*' + Q)

def primo(rx, testo):
    m = rx.search(testo)
    if not m:
        return None
    return next(g for g in m.groups() if g is not None)

by = collections.defaultdict(list)
for a in A:
    by[(a['cluster_id'], a['study_id'])].append(a)

# Attribuzioni a mano: (numero di riga di difetti.csv, 1-based) -> lista di
# (etichetta del trattato, etichetta del controllo) da AGGIUNGERE, e il motivo.
A_MANO = {
    13: ([('MIA PaCa-2 cells treated with Gemcitabine and Torin 1', 'Untreated MIA PaCa-2 cells')],
         'la riga nomina «la gemella ... Gemcitabine and Torin 1» contro lo stesso controllo'),
    14: ([('T3 and LPS 4h', 'RPMI media 4h')], "la riga nomina anche 'T3 and LPS 4h' vs 'RPMI media 4h'"),
    21: ([('DLD-1 AFF1_AFF4_AID hypoxia 6h', 'DLD-1 AFF1_AFF4_AID NT normoxia 6h')],
         'la riga dice «stessa forma per» il braccio AFF1_AFF4_AID'),
    26: ([('SHP1705 (10 µM) + Carfilzomib (10 nM) for 8hr', 'DMSO for 8hr')], 'la riga dice «identico a 8hr»'),
    37: ([('MGG4 temozolomide 25uM 2', 'MGG4 DMSO')],
         'la riga nomina «tutti e due» i trattati contro lo stesso controllo e non sceglie quale e\' appaiato'),
    40: ([('PC9_erlotinib_7days', 'PC9_DMSO'), ('PC9_erlotinib_21days', 'PC9_DMSO'),
          ('PC9_erlotinib_75jours', 'PC9_DMSO'), ('HCC4006_erlotinib_no_duration', 'HCC4006_DMSO_24h')],
         'la riga nomina i quattro trattati PC9 «tutti vs» PC9_DMSO e HCC4006_erlotinib_no_duration'),
    51: ([('Everolimus 4hr differentiated', 'Control')],
         'la riga nomina «entrambi» i trattati contro lo stesso controllo e non sceglie quale e\' appaiato'),
    52: ([('PMA 24h', 'Control')], 'la riga nomina «entrambi» i trattati contro lo stesso controllo'),
    54: ([('Afatinib-treated cardiac myocytes (MSN05)', 'DMSO-treated cardiac myocytes')],
         'la riga nomina «entrambi» i trattati contro lo stesso controllo'),
    55: ([('HBEC2_YAP_TAZ_knockdown', 'Control_siRNA_1')], 'la riga nomina «entrambi» i trattati contro lo stesso controllo'),
    71: ([('Endothelial cells treated with BI-3802 and IFNγ', 'Untreated endothelial cells'),
          ('Endothelial cells treated with BI-3812 and IFNγ', 'Untreated endothelial cells')],
         "la riga dice «idem 'BI-3802 and IFNγ' e 'BI-3812 and IFNγ'»; la categoria dice 3 confronti su 4"),
    75: ([('IFN-γ, IL-1β (combined)', 'No treatment')], 'la riga dice «in entrambi i suoi confronti»'),
    83: ([('TAMs - Breast Cancer', 'TAMs - Normal Breast')], "la riga nomina anche 'TAMs - Breast Cancer' contro 'TAMs - Normal Breast'"),
    85: ([('MIA PaCa-2 treated with SCH772984 1uM for x8 weeks', 'MIA PaCa-2 treated with DMSO 1:1000 for 1 week'),
          ('SW1573 treated with SCH772984 1uM for x8 weeks', 'SW1573 treated with DMSO 1:1000 for 1 week'),
          ('SW620 treated with SCH772984 1uM for x8 weeks', 'SW620 treated with DMSO 1:1000 for 1 week')],
         'la riga dice «stessa forma per» MIA PaCa-2, SW1573 e SW620 a 8 settimane'),
    87: ([('Healthy IEIL cells stimulated with IL21 for 4 hours', 'Healthy IEIL cells vehicle control (time zero)'),
          ('Healthy IEIL cells stimulated with IL21 for 30 minutes', 'Healthy IEIL cells vehicle control (time zero)')],
         'la riga dice «e le analoghe a 4 ore e 30 minuti, tutte contro lo stesso time zero»'),
    96: ([('COVID-19 CD16High', 'Healthy NDN')], "la riga nomina anche 'COVID-19 CD16High' vs 'Healthy NDN'"),
}

out, mano_rows = [], []
stato_riga = {}
for i, r in enumerate(dif, 1):
    cand = by[(r['cluster_id'], r['study_id'])]
    assert cand, (i, r['study_id'])
    presi = []
    if len(cand) == 1:
        presi = [(cand[0], 'unico')]
    else:
        t, c = primo(RX_T, r['etichetta']), primo(RX_C, r['etichetta'])
        if t is not None:
            hit = [a for a in cand if norm(a['etichetta_trattato']) == norm(t)
                   and (c is None or norm(a['etichetta_controllo']) == norm(c))]
            coppie = {(a['etichetta_trattato'], a['etichetta_controllo']) for a in hit}
            if hit and len(coppie) == 1:
                presi = [(a, 'parser') for a in hit]
    gia = {a['record_id'] for a, _ in presi}
    if i in A_MANO:
        for (tl, cl) in A_MANO[i][0]:
            hit = [a for a in cand if a['etichetta_trattato'] == tl and a['etichetta_controllo'] == cl]
            assert hit, (i, tl, cl)
            for a in hit:
                if a['record_id'] not in gia:
                    presi.append((a, 'mano')); gia.add(a['record_id'])
                    mano_rows.append({'riga': i, 'study_id': r['study_id'], 'record_id': a['record_id'],
                                      'etichetta_trattato': tl, 'etichetta_controllo': cl,
                                      'motivo': A_MANO[i][1]})
    modi = {m for _, m in presi}
    stato_riga[i] = ('non_agganciata' if not presi else 'unico' if modi == {'unico'} else
                     'parser' if modi == {'parser'} else 'parser+mano' if modi == {'parser', 'mano'} else 'mano')
    nonprov = bool(re.search(r'NON PROVATO|NON difetto provato|sospetto dichiarato', r['categoria']))
    for a, m in presi:
        out.append({'riga': i, 'cluster_id': r['cluster_id'], 'study_id': r['study_id'],
                    'record_id': a['record_id'], 'modo': m, 'non_provato': nonprov,
                    'categoria': r['categoria'], 'etichetta_trattato': a['etichetta_trattato'],
                    'etichetta_controllo': a['etichetta_controllo']})

with open(D + '30-riferimento.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
with open(D + '30-a-mano.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(mano_rows[0].keys())); w.writeheader(); w.writerows(mano_rows)

# Controllo: nelle righe «unico» la prima citazione dopo TRATTATO coincide con
# l'unico confronto della coppia?
unico_ok = 0
for o in out:
    if o['modo'] == 'unico':
        t = primo(RX_T, dif[o['riga'] - 1]['etichetta'])
        unico_ok += t is not None and norm(t) == norm(o['etichetta_trattato'])

cnt = collections.Counter(stato_riga.values())
rec = {o['record_id'] for o in out}
rec_np = {o['record_id'] for o in out if not o['non_provato']}
coppie_acc = {(r['cluster_id'], r['study_id']) for r in dif}
n199 = sum(len(by[k]) for k in coppie_acc)
righe = [
    'Riferimento al livello del confronto (S10), costruito da difetti.csv (97 righe)',
    '',
    'righe di difetti.csv per stato:',
    *[f'  {k:15s} {v:3d}' for k, v in sorted(cnt.items())],
    f'  {"totale":15s} {sum(cnt.values()):3d}',
    '',
    f'righe «unico» in cui la prima citazione coincide con il confronto: {unico_ok} su {cnt["unico"]}',
    f'righe agganciate senza intervento (unico + parser): {cnt["unico"] + cnt["parser"]}',
    f'righe con almeno un confronto attribuito a mano: {cnt["parser+mano"] + cnt["mano"]}',
    f'confronti attribuiti a mano: {len(mano_rows)}',
    f'righe non agganciate: {cnt["non_agganciata"]}',
    '',
    f'confronti difettosi distinti (D): {len(rec)}',
    f'  senza le righe «non provato / sospetto»: {len(rec_np)}',
    f'confronti delle coppie accusate: {n199}',
    f'altri negativi (confronti delle coppie accusate non nominati): {n199 - len(rec)}',
    f'puliti (confronti delle coppie non accusate): {1903 - n199}',
]
open(D + '30-conto.txt', 'w').write('\n'.join(righe) + '\n')
print('\n'.join(righe))
