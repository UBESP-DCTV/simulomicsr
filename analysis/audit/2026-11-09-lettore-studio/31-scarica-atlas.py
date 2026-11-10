#!/usr/bin/env python3
"""31-scarica-atlas.py — S12r, Task 6, passo 1.

Scarica dall'FTP di EBI i file di Expression Atlas dei 129 studi di 30-divisione.tsv:
  <accession>-configuration.xml       per tutti i 129 studi;
  <accession>.condensed-sdrf.tsv      SOLO per gli studi di sviluppo (parte == sviluppo).
Gli studi di giudizio sono chiusi: il loro SDRF (fattori e livelli) non si scarica.

Congelamento: ogni risposta si salva come byte grezzi, un file per richiesta; il
manifesto registra file, URL, data UTC, byte e SHA-256. Riprende da dove si e'
fermato. Stampa solo conteggi: nessun contenuto dei file va in uscita.

Uso (cartella di uscita propria, separata dagli script; Python isolato):
  python3 -I 31-scarica-atlas.py 30-divisione.tsv <cartella_uscita> <manifesto.tsv>
"""
import datetime, hashlib, os, sys, time, urllib.request

DIV, OUT, MAN = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
PAUSA = 0.4          # secondi fra le richieste, cortesia verso EBI
TENTATIVI = 5
BASE = "https://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/experiments"

righe = [r.rstrip("\n").split("\t") for r in open(DIV)]
col = {n: i for i, n in enumerate(righe[0])}
studi = [(r[col["accession"]], r[col["parte"]]) for r in righe[1:]]

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

def valido(nome, b):
    if nome.endswith(".xml"):
        return b"<configuration" in b and b"</configuration>" in b
    return b"\t" in b and len(b) > 0

def scarica(nome, url):
    for k in range(TENTATIVI):
        try:
            b = urllib.request.urlopen(url, timeout=300).read()
            if not valido(nome, b):
                raise ValueError("risposta non valida (%d byte)" % len(b))
            return b
        except Exception as e:
            print(f"  {ora()} tentativo {k + 1} fallito per {url}: {e.__class__.__name__}", flush=True)
            time.sleep(5 * (k + 1))
    return None

def salva(nome, url):
    if nome in fatti and os.path.exists(os.path.join(OUT, nome)):
        return True
    b = scarica(nome, url)
    if b is None:
        return False
    with open(os.path.join(OUT, nome + ".tmp"), "wb") as f:
        f.write(b)
    os.replace(os.path.join(OUT, nome + ".tmp"), os.path.join(OUT, nome))
    riga = [nome, url, ora(), str(len(b)), hashlib.sha256(b).hexdigest()]
    man.write("\t".join(riga) + "\n"); man.flush()
    fatti[nome] = riga
    time.sleep(PAUSA)
    return True

n_xml = n_sdrf = 0; falliti = []
for acc, parte in studi:
    nome = f"{acc}-configuration.xml"
    if salva(nome, f"{BASE}/{acc}/{nome}"):
        n_xml += 1
    else:
        falliti.append(nome)
    if parte == "sviluppo":
        nome = f"{acc}.condensed-sdrf.tsv"
        if salva(nome, f"{BASE}/{acc}/{nome}"):
            n_sdrf += 1
        else:
            falliti.append(nome)
man.close()

# Verifica finale: ogni file del manifesto ha i byte e lo SHA-256 scritti.
guasti = 0
for nome, c in fatti.items():
    b = open(os.path.join(OUT, nome), "rb").read()
    if str(len(b)) != c[3] or hashlib.sha256(b).hexdigest() != c[4]:
        guasti += 1
print(f"FINE {ora()}: studi {len(studi)}, configurazioni {n_xml}, SDRF (solo sviluppo) {n_sdrf}, "
      f"falliti {len(falliti)} {falliti}, file nel manifesto {len(fatti)}, file che non tornano col manifesto {guasti}")
sys.exit(1 if falliti or guasti else 0)
