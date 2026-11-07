#!/usr/bin/env python3
"""S14, due passi col modello: spiegazione delle anomalie viste a fine catena.

Uso, dalla radice del repository:  python3 -I analysis/audit/2026-11-05-S14-re-run-modello/91-anomalie.py > analysis/audit/2026-11-05-S14-re-run-modello/91-anomalie.txt

1. GSE157657, l'unico studio di riferimento con un record diverso (62-s2-confronto.txt):
   input di recupero di agosto contro input di recupero del run nuovo, e controllo positivo sui
   quattro studi recuperati sia nella prova sia nel run nuovo.
2. «stesso ordine FALSE» in 62-s2-confronto.txt: l'ordine degli studi senza GSE9135.
3. Gli outlier dello Stadio 1, rifatti con max_model_len 32768: confronto con la prova (4096).
4. I tre campioni senza record valido: studio e confronto con la prova.
5. Q7: ore effettive dello Stadio 1, dal primo invio alla fine del recupero, e costo della fermata.
"""
import glob, json, re
from datetime import datetime

D = "analysis/audit/2026-11-05-S14-re-run-modello"
A3S = set(open("analysis/audit/2026-08-16-A3/A3-studi.txt").read().split())
NUOVI = set(open("analysis/audit/2026-11-04-S8b-prova/campione-nuovi.txt").read().split())
RESC = open(f"{D}/studi-recupero-s2.txt").read().split()
PAT = re.compile(r'^\{"record_id": ?"([^"]+)"')
SID = re.compile(r'"series_id": ?"([^"]+)"')


def righe_studio(path, s):
    return [l for l in open(path) if f'"series_id":"{s}"' in l]


print("== 1. Studi recuperati nello Stadio 2 e riferimento")
for s in RESC:
    rif = "agosto" if s in A3S else ("prova" if s in NUOVI else "fuori")
    print(f"{s}\triferimento: {rif}")
a = righe_studio("analysis/input/A3-stage2-rescue.jsonl", "GSE157657")
b = righe_studio("analysis/input/S14-stage2-rescue.jsonl", "GSE157657")
ja, jb = json.loads(a[0]), json.loads(b[0])
print(f"GSE157657: record di recupero agosto {len(a)}, run nuovo {len(b)}, righe identiche {sum(x == y for x, y in zip(a, b))}")
print(f"  chiavi del record, agosto: {list(ja.keys())}")
print(f"  chiavi del record, nuovo:  {list(jb.keys())}")
print(f"  chiavi del campione, agosto: {list(ja['samples'][0].keys())}")
print(f"  chiavi del campione, nuovo:  {list(jb['samples'][0].keys())}")
print(f"  tipo di sample_facts.organism, agosto: {type(ja['samples'][0]['sample_facts']['organism']).__name__}, nuovo: {type(jb['samples'][0]['sample_facts']['organism']).__name__}")
print(f"  stessi campioni nello stesso ordine: {all([s['geo_accession'] for s in json.loads(x)['samples']] == [s['geo_accession'] for s in json.loads(y)['samples']] for x, y in zip(a, b))}")
print(f"  stesso study_summary: {all(json.loads(x)['study_summary'] == json.loads(y)['study_summary'] for x, y in zip(a, b))}")
for f in ["archs4-human-stage2-rescue-v3.jsonl", "S8b-stage2-rescue.jsonl", "S14-stage2-rescue.jsonl", "S14-stage2-input.jsonl", "A3-stage2-rescue.jsonl"]:
    r = json.loads(open(f"analysis/input/{f}").readline())
    print(f"  formato di {f}: campione {list(r['samples'][0].keys())}, organism {type(r['samples'][0]['sample_facts']['organism']).__name__}")
print("Controllo positivo: studi recuperati nella prova e nel run nuovo")
for s in [x for x in RESC if x in NUOVI]:
    p = righe_studio("analysis/input/S8b-stage2-rescue.jsonl", s)
    n = righe_studio("analysis/input/S14-stage2-rescue.jsonl", s)
    print(f"  {s}: record {len(n)}, input di recupero identico alla prova: {p == n}")
m_new = {SID.search(l).group(1): l for l in open("analysis/p4-output/S14-stage2-master.jsonl")}
ref = {}
for f, keep in [("analysis/p4-output/A3-stage2-master-parziale.jsonl", A3S), ("analysis/p4-output/S8b-stage2-master-parziale.jsonl", NUOVI)]:
    for l in open(f):
        s = SID.search(l).group(1)
        if s in keep and s in RESC:
            ref[s] = l
for s in sorted(ref):
    print(f"  record assemblato di {s} identico al riferimento: {m_new[s] == ref[s]}")

print("\n== 2. Ordine degli studi nel master dello Stadio 2")
n = list(m_new.keys())
o = [SID.search(l).group(1) for l in open("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")]
print(f"studi: nuovo {len(n)}, vecchio {len(o)}; nel vecchio e non nel nuovo {sorted(set(o) - set(n))}; nel nuovo e non nel vecchio {sorted(set(n) - set(o))}")
print(f"stesso ordine dopo aver tolto gli studi assenti: {[s for s in o if s in set(n)] == n}")
print("sigle divergenti fra input e modello (input Stadio 2):")
print(open("analysis/input/S14-stage2-input.jsonl.series-divergenti.csv").read().strip())

print("\n== 3. Outlier dello Stadio 1 (max_model_len 32768 nel run nuovo, 4096 nella prova)")
ids = [json.loads(l)["record_id"] for l in open("analysis/input/S14-stage1-outliers.jsonl")]
g = {}
for l in open("analysis/input/archs4-human-stage1-input-v2.jsonl"):
    i = l.find('"record_id":"'); r = l[i + 13:l.find('"', i + 13)]
    if r in set(ids) | {"GSM4763004", "GSM4763053", "GSM4763082"}:
        j = l.find('"series_id":"'); g[r] = l[j + 13:l.find('"', j + 13)]
s14, s8 = {}, {}
for f, dst in [("analysis/p4-output/S14-stage1-master.jsonl", s14), ("analysis/p4-output/S8b-stage1-master-innestato.jsonl", s8)]:
    for l in open(f):
        m = PAT.match(l)
        if m and m.group(1) in set(ids):
            dst[m.group(1)] = json.loads(l)["raw_output"]
for s in sorted(set(g[r] for r in ids)):
    rr = [r for r in ids if g[r] == s]
    rif = "agosto" if s in A3S else ("prova" if s in NUOVI else "fuori")
    print(f"{s} ({rif}): {len(rr)} record, identici al master della prova {sum(s14[r] == s8[r] for r in rr)}")
for p in sorted(glob.glob("analysis/p4-bundles/*s8b-s1-s8b-stage1-outliers*/generation.json")) + sorted(glob.glob("analysis/p4-bundles/*s14-s1-s14-stage1-outliers-ml32768*/generation.json")):
    gj = json.load(open(p))
    print(f"  {p.split('/')[2]}: max_model_len {gj.get('max_model_len')}, max_tokens {gj.get('max_tokens')}")

print("\n== 4. Campioni senza record valido dopo il recupero dello Stadio 1")
for r in open(f"{D}/residui-stadio1.txt").read().split():
    print(f"{r}\t{g.get(r)}\tnel riferimento: {g.get(r) in A3S | NUOVI}")
print(f"stessi residui della prova: {sorted(open(f'{D}/residui-stadio1.txt').read().split()) == sorted(open('analysis/audit/2026-11-04-S8b-prova/residui-stadio1.txt').read().split())}")

print("\n== 5. Tempi dal log della catena")
L = open(f"{D}/log/catena.log").read().splitlines()
t = lambda l: datetime.strptime("2026-" + l[1:15], "%Y-%m-%d %H:%M:%S")
primo = next(l for l in L if "inviato s14-s1-chunk-00" in l)
fine1 = next(l for l in L if "FINE s1-recupero" in l)
blocchi = next(l for l in L if "job: COMPLETED 51, RUNNING 1" in l)
outl = next(l for l in L if "slurm 455951: COMPLETED" in l)
fine = next(l for l in L if "CATENA FINITA" in l)
print(f"Q7, ore effettive dello Stadio 1: {(t(fine1) - t(primo)).total_seconds() / 3600:.2f} ({primo[1:15]} -> {fine1[1:15]})")
print(f"ritardo della fermata degli outlier: {(t(outl) - t(blocchi)).total_seconds() / 60:.1f} min (51 blocchi finiti {blocchi[1:15]}, outlier finiti {outl[1:15]})")
print(f"durata della catena dal primo invio: {(t(fine) - t(primo)).total_seconds() / 3600:.2f} h ({primo[1:15]} -> {fine[1:15]})")
print(f"errori ssh all'invio, ripresi dalla catena: {open(f'{D}/log/catena.out').read().count('kex_exchange_identification')}")
