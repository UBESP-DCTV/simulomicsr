#!/usr/bin/env python3
"""11-scarica-geo.py — congela i testi GEO (formato SOFT, vista «brief», senza tabelle di dati) degli studi del
bacino di ARCHS4 che non li hanno ancora: la classe `nuovo` di 10-elenco.csv (21.249 studi).

Stessa richiesta e stessa forma dei testi gia' congelati (50-scarica-geo-sviluppo.py, 10-scarica-geo-gemma.py):
  <GSE>.serie.soft.txt     acc.cgi?acc=<GSE>&targ=self&form=text&view=brief   (titolo, riassunto, disegno)
  <GSE>.campioni.soft.txt  acc.cgi?acc=<GSE>&targ=gsm&form=text&view=brief    (tutti i campioni dello studio)
Gli studi di giudizio di Atlas sono chiusi: lo script si ferma se un numero GEO della sua lista sta nella divisione
di Atlas (30-divisione.tsv) o non ha la classe `nuovo`.

Due processi in parallelo: il processo PEZZO (0 o 1) prende gli studi con (ordine_scarico - 1) % N == PEZZO,
nell'ordine di `ordine_scarico` (prima il campione della prova piccola). Ogni processo ha il suo manifesto e il suo
file dei falliti; 12-unisci-manifesti.py li unisce e rifa' la verifica.

Congelamento: byte grezzi, un file per risposta; il manifesto registra file, URL, data UTC, byte, SHA-256, numero
di blocchi ^SAMPLE. Riprende da dove si e' fermato. Stampa solo conteggi e nomi di file.
Fallimenti: errore di rete o HTTP -> fino a 5 tentativi (attesa 5, 10, 15, 20 secondi; 60 secondi dopo un HTTP 429);
risposta completa senza il segno dello studio -> fino a 3 tentativi. Se la serie fallisce, i campioni non si chiedono.
Ogni fallito va nel file dei falliti con il motivo e con l'inizio dell'ultima risposta. Nessun ritento a mano.

Uso (Python isolato; cartella di uscita separata dagli script):
  python3 -I 11-scarica-geo.py 10-elenco.csv 30-divisione.tsv <cartella_uscita> <manifesto.tsv> <falliti.tsv> PEZZO N
"""
import csv, datetime, hashlib, os, re, sys, time, urllib.error, urllib.request

ELENCO, DIV, OUT, MAN, FAL = sys.argv[1:6]; PEZZO, N = int(sys.argv[6]), int(sys.argv[7])
os.makedirs(OUT, exist_ok=True)
PAUSA = 0.4          # secondi fra le richieste di un processo, cortesia verso NCBI (limite chiesto: 3 al secondo)
TENTATIVI_RETE = 5; TENTATIVI_SEGNO = 3
BASE = "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=%s&targ=%s&form=text&view=brief"
AGENTE = {"User-Agent": "simulomicsr-geo-freeze/1.0 (python-urllib)"}

el = [r for r in csv.DictReader(open(ELENCO)) if r["ordine_scarico"]]
assert all(r["classe"] == "nuovo" and re.fullmatch(r"GSE\d+", r["gse"]) for r in el)
righe = [r.rstrip("\n").split("\t") for r in open(DIV)]
atlas = {r[righe[0].index("gse")] for r in righe[1:]}
el.sort(key=lambda r: int(r["ordine_scarico"]))
studi = [r["gse"] for r in el if (int(r["ordine_scarico"]) - 1) % N == PEZZO]
assert not (set(studi) & atlas), "uno studio della lista e' di sviluppo o di giudizio"
print(f"processo {PEZZO} di {N}: studi da congelare {len(studi)}", flush=True)

fatti = {}
if os.path.exists(MAN):
    for riga in open(MAN):
        c = riga.rstrip("\n").split("\t")
        if c[0] != "file":
            fatti[c[0]] = c
man = open(MAN, "a")
if not fatti:
    man.write("file\turl\tscaricato_utc\tbyte\tsha256\tn_campioni_nel_testo\n"); man.flush()
nuovo_fal = not os.path.exists(FAL)
fal = open(FAL, "a")
if nuovo_fal:
    fal.write("file\turl\tquando_utc\tmotivo\tinizio_ultima_risposta\n"); fal.flush()

def ora():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def scarica(url, segno):
    """Ritorna (byte, None) oppure (None, (motivo, inizio dell'ultima risposta))."""
    rete = senza = 0; ultimo = ("", "")
    while rete < TENTATIVI_RETE and senza < TENTATIVI_SEGNO:
        attesa = 5
        try:
            b = urllib.request.urlopen(urllib.request.Request(url, headers=AGENTE), timeout=300).read()
            if re.search(segno, b, re.M):
                return b, None
            senza += 1; attesa = 5 * senza
            ultimo = ("risposta senza il segno (%d byte)" % len(b), repr(b[:200]))
        except urllib.error.HTTPError as e:
            rete += 1; attesa = 60 if e.code == 429 else 5 * rete
            ultimo = ("HTTP %d" % e.code, "")
        except Exception as e:
            rete += 1; attesa = 5 * rete
            ultimo = (e.__class__.__name__, "")
        print(f"  {ora()} tentativo fallito per {url}: {ultimo[0]}", flush=True)
        time.sleep(attesa)
    return None, ultimo

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
    for targ, suff, segno in (("self", "serie", rb"^\^SERIES = " + gse.encode() + rb"\s"), ("gsm", "campioni", rb"^\^SAMPLE = GSM\d+")):
        nome = f"{gse}.{suff}.soft.txt"
        if nome in fatti and os.path.exists(os.path.join(OUT, nome)):
            continue
        url = BASE % (gse, targ)
        b, guasto = scarica(url, segno)
        if b is None:
            falliti.append(nome)
            fal.write("\t".join([nome, url, ora(), guasto[0], guasto[1]]) + "\n"); fal.flush()
            break                                  # senza la serie i campioni non si chiedono
        registra(nome, url, b); time.sleep(PAUSA)
    if (i + 1) % 100 == 0:
        print(f"{ora()} processo {PEZZO}: studi fatti {i + 1} su {len(studi)}, file falliti {len(falliti)}", flush=True)
man.close(); fal.close()
print(f"FINE {ora()} processo {PEZZO}: studi {len(studi)}, file nel manifesto {len(fatti)}, file falliti {len(falliti)}", flush=True)
