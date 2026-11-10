#!/usr/bin/env python3
"""32-scarica-ena.py — S12r, Task 6, passo 2.

Per ognuno dei 129 studi legge dalla configurazione di Atlas SOLO gli identificativi
dei run (testo degli elementi <assay>), poi chiede a ENA:
  1. lo studio ENA del primo run        -> <accession>.run-<RUN>.tsv
  2. tutti i run di quello studio ENA   -> <accession>.studio-<PRJ>.tsv
     (campi: run_accession, experiment_accession, sample_alias, experiment_alias)
Se dopo il passo 2 restano run di Atlas non coperti (uno studio GEO puo' avere piu'
studi ENA), ripete 1 e 2 con il primo run non coperto.

Congelamento: una risposta per file, byte grezzi; il manifesto registra file, URL,
data UTC, byte, SHA-256. Riprende da dove si e' fermato. Stampa solo conteggi:
nessun contenuto di Atlas (etichette, nomi, fattori) viene letto o scritto.

Uso (Python isolato):
  python3 -I 32-scarica-ena.py 30-divisione.tsv <cartella_atlas> <cartella_uscita> <manifesto.tsv>
"""
import datetime, hashlib, os, re, sys, time, urllib.request

DIV, ATLAS, OUT, MAN = sys.argv[1:5]
os.makedirs(OUT, exist_ok=True)
PAUSA = 0.4
TENTATIVI = 5
API = "https://www.ebi.ac.uk/ena/portal/api/filereport"
MAX_GIRI = 20        # studi ENA diversi per uno studio di Atlas: oltre, lo studio si segnala

righe = [r.rstrip("\n").split("\t") for r in open(DIV)]
col = {n: i for i, n in enumerate(righe[0])}
studi = [r[col["accession"]] for r in righe[1:]]

fatti = {}
if os.path.exists(MAN):
    for riga in open(MAN):
        c = riga.rstrip("\n").split("\t")
        if c[0] != "file":
            fatti[c[0]] = c
man = open(MAN, "a")
if not fatti:
    man.write("file\turl\tscaricato_utc\tbyte\tsha256\n"); man.flush()

def ora():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def scarica(url):
    for k in range(TENTATIVI):
        try:
            r = urllib.request.urlopen(url, timeout=300)
            b = r.read()
            # ENA risponde 204 senza corpo quando non trova niente: e' una risposta valida, vuota.
            if b and not b.startswith(b"run_accession"):
                raise ValueError("risposta senza intestazione (%d byte)" % len(b))
            return b
        except Exception as e:
            print(f"  {ora()} tentativo {k + 1} fallito per {url}: {e.__class__.__name__}", flush=True)
            time.sleep(5 * (k + 1))
    return None

def salva(nome, url):
    if nome in fatti and os.path.exists(os.path.join(OUT, nome)):
        return open(os.path.join(OUT, nome), "rb").read()
    b = scarica(url)
    if b is None:
        return None
    with open(os.path.join(OUT, nome + ".tmp"), "wb") as f:
        f.write(b)
    os.replace(os.path.join(OUT, nome + ".tmp"), os.path.join(OUT, nome))
    riga = [nome, url, ora(), str(len(b)), hashlib.sha256(b).hexdigest()]
    man.write("\t".join(riga) + "\n"); man.flush()
    fatti[nome] = riga
    time.sleep(PAUSA)
    return b

def tabella(b):
    r = [x.split("\t") for x in b.decode("utf-8", "replace").splitlines() if x]
    if not r:
        return []
    return [dict(zip(r[0], x)) for x in r[1:]]

RUN_OK = re.compile(r"^[SED]RR[0-9]+$")
n_run_tot = n_coperti = 0; falliti = []; non_run = 0; studi_incompleti = 0; n_prj = 0
for i, acc in enumerate(studi, 1):
    t = open(os.path.join(ATLAS, f"{acc}-configuration.xml"), encoding="utf-8", errors="replace").read()
    # I curatori tolgono un run mettendolo in un commento XML: un run commentato non e' dello studio.
    t = re.sub(r"<!--.*?-->", "", t, flags=re.S)
    run = sorted(set(x.strip() for x in re.findall(r"<assay(?:\s[^>]*)?>([^<]*)</assay>", t)))
    buoni = [x for x in run if RUN_OK.match(x)]
    non_run += len(run) - len(buoni)
    n_run_tot += len(run)
    coperti = set(); provati = set()
    for _ in range(MAX_GIRI):
        resto = [x for x in buoni if x not in coperti and x not in provati]
        if not resto:
            break
        primo = resto[0]; provati.add(primo)
        b = salva(f"{acc}.run-{primo}.tsv",
                  f"{API}?accession={primo}&result=read_run&fields=run_accession,study_accession&format=tsv")
        if b is None:
            falliti.append(f"{acc}.run-{primo}"); continue
        prj = sorted(set(x.get("study_accession", "") for x in tabella(b)) - {""})
        for p in prj:
            if not re.match(r"^[A-Z]+[0-9]+$", p):
                continue
            b2 = salva(f"{acc}.studio-{p}.tsv",
                       f"{API}?accession={p}&result=read_run"
                       "&fields=run_accession,experiment_accession,sample_alias,experiment_alias&format=tsv")
            if b2 is None:
                falliti.append(f"{acc}.studio-{p}"); continue
            n_prj += 1
            coperti |= set(x.get("run_accession", "") for x in tabella(b2))
    n_coperti += len([x for x in buoni if x in coperti])
    if any(x not in coperti for x in run):
        studi_incompleti += 1
    if i % 20 == 0 or i == len(studi):
        print(f"{ora()} studi {i}/{len(studi)}  run {n_run_tot}  coperti da ENA {n_coperti}  falliti {len(falliti)}", flush=True)
man.close()
print(f"FINE {ora()}: studi {len(studi)}, run nelle configurazioni {n_run_tot}, identificativi che non sono run {non_run}, "
      f"run coperti da ENA {n_coperti}, studi con almeno un run non coperto {studi_incompleti}, "
      f"risposte di studio ENA {n_prj}, richieste fallite {len(falliti)}, file nel manifesto {len(fatti)}")
sys.exit(1 if falliti else 0)
