#!/usr/bin/env python3
# analysis/audit/2026-08-21-S3-test-retest/10-campione-umano.py
#
# Estrae VENTI delle 194 meta-analisi a caso, col seme scritto qui sotto, e scrive
# per ciascuna una SCHEDA CIECA in umano/: prima il materiale ESATTO che il modello
# ha letto (la sezione del blocco-XX.txt), poi la scheda di A0-schema-verificabile.R
# con le stringhe grezze per campione, SENZA la riga «verdetto della rilettura».
# L'ordine dei file e' rimescolato (stesso seme) perche' la numerazione di A0 segue
# k decrescente e lascerebbe indovinare.
#
# Uso: python3 analysis/audit/2026-08-21-S3-test-retest/10-campione-umano.py
import csv, os, random, re, glob

SEME = 20260821
N = 20
R = 'analysis/audit/2026-08-20-rilettura-194'
S = 'analysis/audit/2026-08-21-S3-test-retest'
U = os.path.join(S, 'umano')
os.makedirs(U, exist_ok=True)

idx = list(csv.DictReader(open(os.path.join(R, 'INDICE-194.csv'))))
assert len(idx) == 194, len(idx)
idx.sort(key=lambda r: r['cluster_id'])            # ordine deterministico, poi il seme
rng = random.Random(SEME)
campione = rng.sample(idx, N)
rng.shuffle(campione)

# sezione del blocco per ogni cluster_id
sezioni, blocco_di = {}, {}
for f in sorted(glob.glob(os.path.join(R, 'blocco-*.txt'))):
    txt = open(f).read()
    b = re.search(r'blocco-(\d\d)\.txt$', f).group(1)
    parti = re.split(r'(?m)^(?=## GRUPPO )', txt)
    for p in parti:
        m = re.match(r'## GRUPPO (\S+)', p)
        if m:
            sezioni[m.group(1)] = p.rstrip() + '\n'
            blocco_di[m.group(1)] = b

INTESTAZIONE = """LETTURA CIECA — S3 (2026-08-21) — scheda {i:02d} di {n}
==============================================================================
Il verdetto del modello NON e' in questa scheda. Dai il tuo, e scrivilo in
umano/RISPOSTE.csv (istruzioni in umano/ISTRUZIONI.md).

PARTE 1 — IL MATERIALE CHE IL MODELLO HA LETTO (blocco {b}, invariato).
  Le etichette sono quelle dello Stadio 2, intere. La riga «verdetto attuale» e'
  il gate automatico della pipeline (Stadio 3), visto anche dal modello: NON e'
  il verdetto della rilettura. Le righe [RIFERIMENTO]/DIVERGENZA confrontano con
  l'altra esecuzione: per il tuo verdetto non servono, guarda i CONFRONTI POOLATI.
  Dai il verdetto su questa parte, PRIMA di leggere la seconda.

PARTE 2 — LE STRINGHE GREZZE PER CAMPIONE (scheda di A0, senza verdetto).
  Qui vedi piu' di quanto il modello vedesse. Se cambia il tuo verdetto, scrivilo
  nella colonna verdetto_dopo_parte2: misura quanto l'etichetta nasconde.
==============================================================================

"""
righe_campione, righe_risposte = [], []
for i, r in enumerate(campione, 1):
    cid = r['cluster_id']
    nome = re.sub(r'[^A-Za-z0-9._-]+', '_', r['nome'])[:40]
    fn = f"{i:02d}-{nome}.txt"
    scheda = open(os.path.join(R, 'schede', r['scheda'])).read()
    scheda_cieca, n_sost = re.subn(r'(?m)^verdetto della rilettura: .*$',
                                   'verdetto della rilettura: [NASCOSTO - lettura cieca]', scheda)
    assert n_sost == 1, (fn, n_sost)
    scheda_cieca = re.sub(r'(?m)^META-ANALISI \d+ di 194$', f'META-ANALISI (scheda cieca {i:02d})', scheda_cieca)
    with open(os.path.join(U, fn), 'w') as f:
        f.write(INTESTAZIONE.format(i=i, n=N, b=blocco_di[cid]))
        f.write("########## PARTE 1 — materiale del modello ##########\n\n")
        f.write(sezioni[cid])
        f.write("\n\n########## PARTE 2 — stringhe grezze per campione ##########\n\n")
        f.write(scheda_cieca)
    righe_campione.append({'ordine': i, 'file': fn, 'cluster_id': cid, 'nome': r['nome'],
                           'blocco': blocco_di[cid], 'studi': r['studi']})
    righe_risposte.append({'ordine': i, 'file': fn, 'cluster_id': cid, 'nome': r['nome'],
                           'verdetto_parte1': '', 'studi_difettosi_parte1': '',
                           'verdetto_dopo_parte2': '', 'note': ''})

with open(os.path.join(S, 'campione-umano.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(righe_campione[0])); w.writeheader(); w.writerows(righe_campione)
with open(os.path.join(U, 'RISPOSTE.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(righe_risposte[0])); w.writeheader(); w.writerows(righe_risposte)

open(os.path.join(U, 'ISTRUZIONI.md'), 'w').write(f"""# Lettura cieca di {N} meta-analisi — istruzioni

Seme dell'estrazione: **{SEME}** (`10-campione-umano.py`). Le {N} sono estratte a
caso dalle 194; l'ordine dei file e' rimescolato. **Il verdetto del modello non e'
scritto da nessuna parte in questa cartella**: non aprire `verdetti-194.csv`,
`INDICE-194.csv` o `quadro-194.csv` prima di aver finito.

Per ogni scheda `NN-nome.txt`, compila la riga corrispondente di `RISPOSTE.csv`:

| colonna | che cosa scrivere |
|---|---|
| `verdetto_parte1` | `corretta` / `difettosa` / `incerta`, letto sulla **PARTE 1** (le etichette, come il modello) |
| `studi_difettosi_parte1` | gli `GSE` che accusi, separati da `;` (vuoto se nessuno) |
| `verdetto_dopo_parte2` | lo stesso verdetto DOPO aver letto le stringhe grezze, **solo se cambia** (altrimenti vuoto) |
| `note` | libere |

Le regole sono quelle del modello (`C1-workflow-rilettura.js`, blocco REGOLE): una
meta-analisi e' *corretta* se tutti i confronti poolati misurano lo stesso
contrasto (stessa entita', stessa direzione, stesso tipo di controllo) e i due
bracci di ciascun confronto sono appaiati; *difettosa* se almeno un confronto ha
un difetto leggibile nell'etichetta; *incerta* se le etichette non bastano.
Nei caso-controllo di malattia i soggetti diversi sono il disegno, non un difetto.

Quando hai finito (anche con meno di {N}: il conteggio e' su quante ne hai lette):

    python3 analysis/audit/2026-08-21-S3-test-retest/40-accordo-umano.py
""")
print(f"scritte {N} schede cieche in {U}; seme {SEME}")
for r in righe_campione: print(f"  {r['file']:45s} blocco {r['blocco']}  k={r['studi']}")
