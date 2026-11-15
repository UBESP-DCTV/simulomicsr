#!/usr/bin/env python3
"""10-scarica-geo-gemma.py — congela i testi GEO (formato SOFT, vista «brief», senza tabelle di dati) degli studi
con un disegno curato di Gemma (UBC) che l'adattatore ha chiuso in una tabella dei fattori.

Studi: le voci di 11-da-scaricare.csv con parte == gemma e con esito == tabella in 30-esiti.csv, per numero GEO
distinto (una voce di Gemma puo' essere una parte di uno studio GEO: GSE52778.2 -> GSE52778).
Gli studi di giudizio sono chiusi e gli studi di sviluppo hanno gia' i testi: lo script si ferma se un numero GEO
dell'elenco sta nella divisione di Atlas (30-divisione.tsv) o fra le voci di giudizio o di sviluppo di Gemma.

Per ogni studio due file, stesso URL e stessa forma dei 47 studi di sviluppo (50-scarica-geo-sviluppo.py):
  <GSE>.serie.soft.txt     acc.cgi?acc=<GSE>&targ=self&form=text&view=brief   (titolo, riassunto, disegno)
  <GSE>.campioni.soft.txt  acc.cgi?acc=<GSE>&targ=gsm&form=text&view=brief    (tutti i campioni dello studio)
Nessun riuso dei testi congelati da S12: tutti i testi hanno la stessa data.

Congelamento: byte grezzi, un file per risposta; il manifesto registra file, URL, data UTC, byte, SHA-256, numero
di blocchi ^SAMPLE. Riprende da dove si e' fermato. Stampa solo conteggi e nomi di file.

Uso (Python isolato; cartella di uscita separata dagli script):
  python3 -I 10-scarica-geo-gemma.py 11-da-scaricare.csv 30-esiti.csv 30-divisione.tsv <cartella_uscita> <manifesto.tsv>
"""
import csv, datetime, hashlib, os, re, sys, time, urllib.request

ELENCO, ESITI, DIV, OUT, MAN = sys.argv[1:6]
os.makedirs(OUT, exist_ok=True)
PAUSA = 0.4          # secondi fra le richieste, cortesia verso NCBI
TENTATIVI = 5
BASE = "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=%s&targ=%s&form=text&view=brief"

voci = list(csv.DictReader(open(ELENCO)))
esiti = {r["shortName"]: r["esito"] for r in csv.DictReader(open(ESITI))}
studi = sorted({r["gse"] for r in voci if r["parte"] == "gemma" and esiti.get(r["shortName"]) == "tabella"})
assert all(re.fullmatch(r"GSE\d+", g) for g in studi)
chiusi = {r["gse"] for r in voci if r["parte"] != "gemma"}
righe = [r.rstrip("\n").split("\t") for r in open(DIV)]
chiusi |= {r[righe[0].index("gse")] for r in righe[1:]}
assert not (set(studi) & chiusi), "uno studio dell'elenco e' di giudizio o di sviluppo"
print(f"studi da congelare: {len(studi)}", flush=True)

fatti = {}
if os.path.exists(MAN):
    for riga in open(MAN):
        c = riga.rstrip("\n").split("\t")
        if c[0] != "file":
            fatti[c[0]] = c
man = open(MAN, "a")
if not fatti:
    man.write("file\turl\tscaricato_utc\tbyte\tsha256\tn_campioni_nel_testo\n"); man.flush()

def ora():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def scarica(url, segno):
    for k in range(TENTATIVI):
        try:
            b = urllib.request.urlopen(url, timeout=300).read()
            if segno not in b:
                raise ValueError("risposta senza %r (%d byte)" % (segno, len(b)))
            return b
        except Exception as e:
            print(f"  {ora()} tentativo {k + 1} fallito per {url}: {e.__class__.__name__}", flush=True)
            time.sleep(5 * (k + 1))
    return None

def registra(nome, url, b):
    with open(os.path.join(OUT, nome + ".tmp"), "wb") as f:
        f.write(b)
    os.replace(os.path.join(OUT, nome + ".tmp"), os.path.join(OUT, nome))
    n = len(re.findall(rb"^\^SAMPLE = GSM\d+", b, re.M))
    riga = [nome, url, ora(), str(len(b)), hashlib.sha256(b).hexdigest(), str(n)]
    man.write("\t".join(riga) + "\n"); man.flush()
    fatti[nome] = riga

falliti = []
for i, gse in enumerate(studi):
    for targ, suff, segno in (("self", "serie", b"^SERIES = " + gse.encode()), ("gsm", "campioni", b"^SAMPLE = GSM")):
        nome = f"{gse}.{suff}.soft.txt"
        if nome in fatti and os.path.exists(os.path.join(OUT, nome)):
            continue
        url = BASE % (gse, targ)
        b = scarica(url, segno)
        if b is None:
            falliti.append(nome)
        else:
            registra(nome, url, b); time.sleep(PAUSA)
    if (i + 1) % 100 == 0:
        print(f"{ora()} studi fatti {i + 1} su {len(studi)}, falliti {len(falliti)}", flush=True)
man.close()

# Verifica finale: ogni file del manifesto ha i byte e lo SHA-256 scritti.
guasti = 0
for nome, c in fatti.items():
    b = open(os.path.join(OUT, nome), "rb").read()
    if str(len(b)) != c[3] or hashlib.sha256(b).hexdigest() != c[4]:
        guasti += 1
print(f"FINE {ora()}: studi {len(studi)}, file nel manifesto {len(fatti)}, falliti {len(falliti)} {falliti}, "
      f"file che non tornano col manifesto {guasti}")
sys.exit(1 if falliti or guasti or len(fatti) != 2 * len(studi) else 0)
