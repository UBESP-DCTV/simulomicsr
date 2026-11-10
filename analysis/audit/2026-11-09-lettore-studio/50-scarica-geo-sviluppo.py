#!/usr/bin/env python3
# PROVA DA BUTTARE
"""50-scarica-geo-sviluppo.py — S12r, Task 9, passo 2.

Congela i testi GEO (formato SOFT, vista «brief», senza tabelle di dati) dei 47 studi
di SVILUPPO di 30-divisione.tsv. Gli studi di giudizio sono chiusi: lo script legge
solo le righe con parte == sviluppo e non fa richieste per gli altri.

Per ogni studio due file:
  <GSE>.serie.soft.txt     acc.cgi?acc=<GSE>&targ=self&form=text&view=brief   (titolo, riassunto, disegno)
  <GSE>.campioni.soft.txt  acc.cgi?acc=<GSE>&targ=gsm&form=text&view=brief    (tutti i campioni dello studio)

Riuso: per gli studi con nei_993 == 1 il testo dei campioni esiste gia', congelato da
S12 il 2026-11-08 (26-scarica-geo.py, stesso URL). Lo script copia quei byte dopo
aver verificato lo SHA-256 sul manifesto committato di S12, e nel manifesto scrive
URL e data originali con fonte = S12. Gli altri file hanno fonte = geo.

Congelamento: byte grezzi, un file per risposta; il manifesto registra file, URL,
data UTC, byte, SHA-256, numero di blocchi ^SAMPLE e fonte. Riprende da dove si e'
fermato. Stampa solo conteggi e nomi di file: nessun contenuto va in uscita.

Uso (cartella di uscita propria, separata dagli script; Python isolato):
  python3 -I 50-scarica-geo-sviluppo.py 30-divisione.tsv <cartella_uscita> <manifesto.tsv> \
      <cartella_S12> <manifesto_S12.tsv>
"""
import datetime, hashlib, os, re, sys, time, urllib.request

DIV, OUT, MAN, S12_DIR, S12_MAN = sys.argv[1:6]
os.makedirs(OUT, exist_ok=True)
PAUSA = 0.4          # secondi fra le richieste, cortesia verso NCBI
TENTATIVI = 5
BASE = "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=%s&targ=%s&form=text&view=brief"

righe = [r.rstrip("\n").split("\t") for r in open(DIV)]
col = {n: i for i, n in enumerate(righe[0])}
studi = sorted((r[col["gse"]], r[col["nei_993"]]) for r in righe[1:] if r[col["parte"]] == "sviluppo")
assert len(studi) == 47 and len({g for g, _ in studi}) == 47, "attesi 47 studi di sviluppo distinti"
assert all(re.fullmatch(r"GSE\d+", g) for g, _ in studi)

s12 = {}
for riga in open(S12_MAN):
    c = riga.rstrip("\n").split("\t")
    if c[0] != "file":
        s12[c[0]] = c

fatti = {}
if os.path.exists(MAN):
    for riga in open(MAN):
        c = riga.rstrip("\n").split("\t")
        if c[0] != "file":
            fatti[c[0]] = c
man = open(MAN, "a")
if not fatti:
    man.write("file\turl\tscaricato_utc\tbyte\tsha256\tn_campioni_nel_testo\tfonte\n"); man.flush()

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

def registra(nome, url, quando, b, fonte):
    with open(os.path.join(OUT, nome + ".tmp"), "wb") as f:
        f.write(b)
    os.replace(os.path.join(OUT, nome + ".tmp"), os.path.join(OUT, nome))
    n = len(re.findall(rb"^\^SAMPLE = GSM\d+", b, re.M))
    riga = [nome, url, quando, str(len(b)), hashlib.sha256(b).hexdigest(), str(n), fonte]
    man.write("\t".join(riga) + "\n"); man.flush()
    fatti[nome] = riga

n_serie = n_camp_geo = n_camp_s12 = 0; falliti = []
for gse, nei_993 in studi:
    nome = f"{gse}.serie.soft.txt"
    if nome not in fatti or not os.path.exists(os.path.join(OUT, nome)):
        url = BASE % (gse, "self")
        b = scarica(url, b"^SERIES = " + gse.encode())
        if b is None:
            falliti.append(nome)
        else:
            registra(nome, url, ora(), b, "geo"); time.sleep(PAUSA)
    n_serie += nome in fatti

    nome = f"{gse}.campioni.soft.txt"
    if nome not in fatti or not os.path.exists(os.path.join(OUT, nome)):
        vecchio = f"{gse}.soft.txt"
        if nei_993 == "1":
            # Riuso del testo congelato da S12: i byte devono tornare col manifesto committato.
            assert vecchio in s12, f"{vecchio} assente dal manifesto di S12"
            b = open(os.path.join(S12_DIR, vecchio), "rb").read()
            assert str(len(b)) == s12[vecchio][3] and hashlib.sha256(b).hexdigest() == s12[vecchio][4], \
                f"{vecchio}: i byte non tornano col manifesto di S12"
            registra(nome, s12[vecchio][1], s12[vecchio][2], b, "S12")
        else:
            url = BASE % (gse, "gsm")
            b = scarica(url, b"^SAMPLE = GSM")
            if b is None:
                falliti.append(nome)
            else:
                registra(nome, url, ora(), b, "geo"); time.sleep(PAUSA)
    if nome in fatti:
        n_camp_s12 += fatti[nome][6] == "S12"; n_camp_geo += fatti[nome][6] == "geo"
man.close()

# Verifica finale: ogni file del manifesto ha i byte e lo SHA-256 scritti.
guasti = 0
for nome, c in fatti.items():
    b = open(os.path.join(OUT, nome), "rb").read()
    if str(len(b)) != c[3] or hashlib.sha256(b).hexdigest() != c[4]:
        guasti += 1
print(f"FINE {ora()}: studi di sviluppo {len(studi)}, testi dello studio {n_serie}, "
      f"testi dei campioni da GEO {n_camp_geo}, testi dei campioni riusati da S12 {n_camp_s12}, "
      f"falliti {len(falliti)} {falliti}, file nel manifesto {len(fatti)}, file che non tornano col manifesto {guasti}")
sys.exit(1 if falliti or guasti or len(fatti) != 2 * len(studi) else 0)
