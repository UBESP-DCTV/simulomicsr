#!/usr/bin/env python3
"""Misura un testo italiano contro le regole di frase dello stile STE adattato.

Uso: python3 controlla_stile.py FILE [FILE ...]   (oppure il testo su stdin)

Una frase è conforme se rispetta tutte queste regole:
- al massimo 25 parole, al massimo 20 se è un'istruzione;
- nessuna forma passiva riconoscibile;
- nessun punto e virgola dentro la frase;
- al massimo un connettivo fra due idee (perché, quindi, ma, ...).

Lo script conta anche i paragrafi oltre 6 frasi e le lineette come punteggiatura.
Blocchi di codice, tabelle, titoli e frontmatter non contano: non sono frasi.
Una voce di lista è un blocco a sé.

Il controllo è meccanico. Non vede il significato né le metafore.
Non vede il passivo con «essere» senza agente («sono ripetuti qui»), perché
in italiano ha la stessa forma di un participio usato come aggettivo.
"""
import re
import sys

LIM_DESCR = 25
LIM_PROC = 20
SOGLIA = 80.0
MEDIA_MINIMA = 11

NON_PARTICIPIO = (
    r"(?!(?:da|dal|dallo|dalla|dai|dalle|dagli|fuori|a|al|allo|alla|ai|alle|agli|in|su|"
    r"prima|dopo|il|lo|la|i|gli|le|l|un|uno|una|anche|sempre|solo|poi|qui|per|con|di|del|"
    r"della|dei|delle|così|più|meno)\b)"
)
PASSIVO = re.compile(
    r"\b(?:viene|vengono|venne|vennero|verrà|verranno|veniva|venivano)\s+" + NON_PARTICIPIO + r"\w+"
    r"|\b(?:è|sono|era|erano|sarà|saranno)\s+stat[oaie]\s+" + NON_PARTICIPIO + r"\w+"
    r"|\b(?:è|sono|era|erano|sarà|saranno)\s+\w+(?:at|ut|it|tt|ss|st)[oaie]\s+"
    r"da(?:l|llo|lla|i|gli|lle)?\b",
    re.IGNORECASE,
)
CONNETTIVI = re.compile(
    r"\b(perché|poiché|quindi|ma|però|mentre|sebbene|benché|tuttavia|dunque|cioè|oppure|"
    r"anche se|dato che|in quanto|affinché|invece)\b",
    re.IGNORECASE,
)
ABBREVIAZIONI = re.compile(r"\b(es|p\.es|cfr|ecc|fig|tab|vs|n|art|sez)\.$", re.IGNORECASE)
IMPERATIVO = re.compile(
    r"^(apri|leggi|scrivi|usa|verifica|controlla|calcola|ferma|fermati|chiedi|manda|"
    r"non|porta|registra|committa|lancia|rileggi|conta|misura|dichiara|aggiorna|"
    r"marca|segna|sposta|togli|aggiungi|indica|ripeti|confronta|esegui|riproduci|"
    r"metti|tieni|nomina|riportalo|scrivilo|deposita|fai|riferisci|descrivi)\b",
    re.IGNORECASE,
)
VOCE = re.compile(r"^\s*([-*+]\s+|\d+[.)]\s+)")


def pulisci_riga(riga):
    riga = re.sub(r"^\s*(>\s*)+", "", riga)
    riga = VOCE.sub("", riga)
    riga = riga.replace("**", "").replace("__", "")
    return re.sub(r"`([^`]*)`", lambda m: m.group(1).replace(" ", "_"), riga)


def blocchi_di(testo):
    """Restituisce le coppie (è_paragrafo, testo). Una voce di lista non è un paragrafo."""
    testo = re.sub(r"\A---\n.*?\n---\n", "", testo, flags=re.DOTALL)
    testo = re.sub(r"```.*?```", "", testo, flags=re.DOTALL)
    blocchi, corrente = [], []

    def chiudi():
        if corrente:
            blocchi.append((True, " ".join(corrente)))
            corrente.clear()

    for riga in testo.splitlines():
        grezza = riga.strip()
        if not grezza or grezza.startswith("|") or grezza.startswith("#"):
            chiudi()
        elif VOCE.match(riga):
            chiudi()
            blocchi.append((False, pulisci_riga(riga).strip()))
        else:
            corrente.append(pulisci_riga(riga).strip())
    chiudi()
    return blocchi


def frasi_di(blocco):
    pezzi, corrente = [], ""
    for parte in re.split(r"(?<=[.!?…])\s+", blocco.strip()):
        corrente = (corrente + " " + parte).strip()
        if ABBREVIAZIONI.search(corrente):
            continue
        if corrente:
            pezzi.append(corrente)
        corrente = ""
    if corrente:
        pezzi.append(corrente)
    return pezzi


def giudica(frase):
    parole = [w for w in re.split(r"\s+", frase) if re.search(r"\w", w)]
    limite = LIM_PROC if IMPERATIVO.match(frase) else LIM_DESCR
    motivi = []
    if len(parole) > limite:
        motivi.append(f"{len(parole)}>{limite} parole")
    if PASSIVO.search(frase):
        motivi.append("passiva")
    if ";" in frase.rstrip("; "):
        motivi.append("punto e virgola")
    if len(CONNETTIVI.findall(frase)) >= 2:
        motivi.append("più idee")
    return len(parole), motivi


def analizza(testo):
    blocchi = blocchi_di(testo)
    esiti, lunghi = [], 0
    for paragrafo, blocco in blocchi:
        frasi = frasi_di(blocco)
        if paragrafo and len(frasi) > 6:
            lunghi += 1
        for frase in frasi:
            parole, motivi = giudica(frase)
            esiti.append({"frase": frase, "parole": parole, "motivi": motivi})
    lineette = len(re.findall(r"\s[–—]\s", testo))
    return esiti, lunghi, lineette


def main():
    percorsi = sys.argv[1:]
    testi = [(p, open(p, encoding="utf-8").read()) for p in percorsi] or [("stdin", sys.stdin.read())]
    esito_globale = 0
    for nome, testo in testi:
        esiti, lunghi, lineette = analizza(testo)
        n = len(esiti)
        ok = sum(1 for e in esiti if not e["motivi"])
        quota = 100.0 * ok / n if n else 0.0
        parole = sum(e["parole"] for e in esiti) / n if n else 0.0
        stato = "OK" if quota >= SOGLIA and lineette == 0 and lunghi == 0 else "SOTTO SOGLIA"
        if stato != "OK":
            esito_globale = 1
        print(f"{nome}: {stato} | frasi {n} | conformi {ok} ({quota:.0f}%) | "
              f"parole per frase {parole:.1f} | paragrafi >6 frasi {lunghi} | lineette {lineette}")
        if n >= 10 and parole < MEDIA_MINIMA:
            print(f"  [nota] media sotto {MEDIA_MINIMA} parole: il testo è troppo spezzato. Riunisci le frasi legate.")
        for e in esiti:
            if e["motivi"]:
                print(f"  [{', '.join(e['motivi'])}] {e['frase'][:100]}")
    return esito_globale


if __name__ == "__main__":
    sys.exit(main())
