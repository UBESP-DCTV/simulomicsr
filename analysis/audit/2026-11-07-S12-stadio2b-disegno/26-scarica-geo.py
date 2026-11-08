#!/usr/bin/env python3
"""26-scarica-geo.py — S12, seconda parte (decisione 1 del PI, 2026-11-08).

Scarica da GEO il testo SOFT (vista «brief», senza tabelle di dati) di tutti i
campioni di ciascuno dei 993 studi dei 1.903 confronti: una richiesta per studio
(acc.cgi?acc=<GSE>&targ=gsm&form=text&view=brief), lo stesso formato di
24-campi-geo-assenti.py. Per ogni campione dei bracci che la risposta dello studio
non contiene: una richiesta per campione (targ=self).

Congelamento: ogni risposta si salva come byte grezzi, un file per richiesta, e
il manifesto registra URL, data UTC, byte e SHA-256. Il testo NON si modifica qui:
l'estrazione dei campi la fa 27-estrai-campi-geo.py.

Riprende da dove si e' fermato: un file gia' nel manifesto non si riscarica.

Uso (cartella di uscita nuova, separata dagli script; Python isolato):
  python3 -I 26-scarica-geo.py 26-studi-gsm.json <cartella_uscita> > <log> 2>&1
"""
import datetime, hashlib, json, os, re, sys, time, urllib.request

studi = json.load(open(sys.argv[1]))
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
MAN = os.path.join(OUT, "manifesto.tsv")
PAUSA = 0.4          # secondi fra le richieste, cortesia verso NCBI
TENTATIVI = 5

fatti = {}
if os.path.exists(MAN):
    for riga in open(MAN):
        c = riga.rstrip("\n").split("\t")
        if c[0] != "file":
            fatti[c[0]] = c
man = open(MAN, "a")
if not fatti:
    man.write("file\turl\tscaricato_utc\tbyte\tsha256\tn_campioni_nel_testo\n")
    man.flush()

def ora():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

CANCELLATO = b"was deleted by the GEO staff"

def scarica(url, accetta_cancellato=False):
    for k in range(TENTATIVI):
        try:
            b = urllib.request.urlopen(url, timeout=300).read()
            if accetta_cancellato and CANCELLATO in b:
                return b
            if b"^SAMPLE = GSM" not in b:
                raise ValueError("risposta senza blocchi ^SAMPLE (%d byte)" % len(b))
            return b
        except Exception as e:
            print(f"  {ora()} tentativo {k + 1} fallito per {url}: {e.__class__.__name__}: {e}", flush=True)
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
    time.sleep(PAUSA)

def salva(nome, url):
    if nome in fatti:
        return open(os.path.join(OUT, nome), "rb").read()
    b = scarica(url)
    if b is None:
        print(f"FALLITO {nome} {url}", flush=True)
        return None
    registra(nome, url, b)
    return b

t0 = time.time()
falliti = []
mancanti = {}
for i, (gse, gsms) in enumerate(sorted(studi.items()), 1):
    url = f"https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc={gse}&targ=gsm&form=text&view=brief"
    b = salva(f"{gse}.soft.txt", url)
    if b is None:
        falliti.append(gse)
        continue
    presenti = set(m.decode() for m in re.findall(rb"^\^SAMPLE = (GSM\d+)", b, re.M))
    gsms = gsms if isinstance(gsms, list) else [gsms]
    m = [g for g in gsms if g not in presenti]
    if m:
        mancanti[gse] = m
    if i % 50 == 0 or i == len(studi):
        print(f"{ora()} studi {i}/{len(studi)}  falliti {len(falliti)}  studi con campioni mancanti {len(mancanti)}"
              f"  ({time.time() - t0:.0f} s)", flush=True)

# Ripiego per campione. Se GEO risponde con la pagina «was deleted by the GEO
# staff» (accettata dal 2026-11-08, dopo la prima esecuzione che la rifiutava),
# la pagina si salva come <GSM>.cancellato.txt: e' la prova della cancellazione.
n_ripiego = 0; cancellati = []
for gse, gsms in sorted(mancanti.items()):
    for g in gsms:
        url = f"https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc={g}&targ=self&form=text&view=brief"
        gia = [n for n in (f"{g}.soft.txt", f"{g}.cancellato.txt") if n in fatti]
        if gia:
            b = open(os.path.join(OUT, gia[0]), "rb").read()
        else:
            b = scarica(url, accetta_cancellato=True)
            if b is not None:
                registra(f"{g}.soft.txt" if b"^SAMPLE = GSM" in b else f"{g}.cancellato.txt", url, b)
        if b is None:
            print(f"FALLITO {g} {url}", flush=True)
            falliti.append(g)
        elif b"^SAMPLE = GSM" not in b and CANCELLATO in b:
            cancellati.append(g)
        n_ripiego += 1

print(f"\nFINE {ora()}: studi {len(studi)}, falliti {len(falliti)} {falliti[:20]}, "
      f"campioni scaricati uno per uno {n_ripiego}, cancellati da GEO {len(cancellati)} {cancellati}, "
      f"durata {time.time() - t0:.0f} s", flush=True)
man.close()
