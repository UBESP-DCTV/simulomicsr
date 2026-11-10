#!/usr/bin/env python3
"""Genera le due infografiche del piano «lettore dello studio» da stato.json.

Uso (dalla radice del repository):
    python3 docs/superpowers/plans/2026-11-09-lettore-studio-mappa/genera.py            # solo stato-del-piano.pdf
    python3 docs/superpowers/plans/2026-11-09-lettore-studio-mappa/genera.py --mappa-pi # anche mappa-per-il-PI.pdf

- stato-del-piano.pdf  : lo aggiorna l'agente a ogni task (stato.json è la fonte).
- mappa-per-il-PI.pdf  : tre pagine A4 da stampare. Non dipende dallo stato: si rigenera
                         solo se cambia il piano.

Solo libreria standard. Il PDF lo scrive google-chrome in modalità headless.
Lo script si ferma con un errore se stato.json non è coerente: nessuna riga si scarta in silenzio.
"""
import argparse
import html
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

QUI = pathlib.Path(__file__).resolve().parent
STATO = QUI / "stato.json"

STATI_TASK = {"da_fare": "da fare", "in_corso": "in corso", "fatto": "fatto", "bloccato": "bloccato"}
STATI_CANCELLO = {"da_valutare": "da valutare", "passato": "passato", "fallito": "fallito"}
ESITI = {"da_misurare": "da misurare", "confermata": "confermata", "smentita": "smentita",
         "indeterminata": "indeterminata"}
STATI_PIANO = {"da_scrivere": "da scrivere", "scritto": "scritto, da eseguire", "in_corso": "in corso",
               "chiuso": "chiuso"}
STATI_FERMATA = {"da_raggiungere": "da raggiungere", "in_attesa_del_pi": "in attesa del PI", "decisa": "decisa"}
STATI_DUBBIO = {"aperto": "aperto", "chiuso": "chiuso"}

PANNELLI = {
    "quota": {"titolo": "Quote, in percento", "dominio": (0, 100), "tacche": [0, 25, 50, 75, 100], "unita": "%"},
    "punti": {"titolo": "Differenza, in punti percentuali", "dominio": (-20, 60),
              "tacche": [-20, 0, 20, 40, 60], "unita": " punti"},
    "studi": {"titolo": "Numero di studi, su 47", "dominio": (0, 47), "tacche": [0, 10, 20, 30, 40, 47],
              "unita": ""},
}


def e(testo):
    return html.escape(str(testo), quote=True)


def errore(msg):
    sys.exit(f"genera.py: stato.json non coerente: {msg}")


# ----------------------------------------------------------------------------------------------
# Controlli su stato.json
# ----------------------------------------------------------------------------------------------
def controlla(s):
    numeri = [t["n"] for t in s["task"]]
    if numeri != list(range(1, 12)):
        errore(f"i task devono essere 1..11 in ordine, trovati {numeri}")
    for t in s["task"]:
        if t["stato"] not in STATI_TASK:
            errore(f"task {t['n']}: stato «{t['stato']}» non ammesso ({', '.join(STATI_TASK)})")
        if t["stato"] == "fatto" and not (re.fullmatch(r"[0-9a-f]{7,40}", t["commit"]) and t["data"]):
            errore(f"task {t['n']}: un task «fatto» vuole il commit (hash) e la data")
        if t["stato"] == "bloccato" and not t["nota"]:
            errore(f"task {t['n']}: un task «bloccato» vuole la nota con il motivo")
    idc = [c["id"] for c in s["cancelli"]]
    if idc != ["K1", "K2", "K3", "K4", "K5"]:
        errore(f"i cancelli devono essere K1..K5, trovati {idc}")
    for c in s["cancelli"]:
        if c["stato"] not in STATI_CANCELLO:
            errore(f"cancello {c['id']}: stato «{c['stato']}» non ammesso")
        if c["stato"] == "fallito" and not c["nota"]:
            errore(f"cancello {c['id']}: un cancello fallito vuole la nota")
    if len(s["previsioni"]) != 9:
        errore(f"le righe di previsione devono essere 9 (P5 ne ha due), trovate {len(s['previsioni'])}")
    for p in s["previsioni"]:
        if p["pannello"] not in PANNELLI:
            errore(f"{p['id']}: pannello «{p['pannello']}» non ammesso")
        if p["esito"] not in ESITI:
            errore(f"{p['id']}: esito «{p['esito']}» non ammesso")
        if (p["esito"] != "da_misurare") != (p["risultato"] is not None):
            errore(f"{p['id']}: risultato ed esito vanno scritti insieme")
        if p["ic95"] is not None and (len(p["ic95"]) != 2 or p["risultato"] is None):
            errore(f"{p['id']}: ic95 vuole due numeri e un risultato")
    for p in s["piani"]:
        if p["stato"] not in STATI_PIANO:
            errore(f"piano {p['n']}: stato «{p['stato']}» non ammesso")
    for f in s["fermate"]:
        if f["stato"] not in STATI_FERMATA:
            errore(f"fermata {f['n']}: stato «{f['stato']}» non ammesso")
        if f["stato"] == "decisa" and not f["esito"]:
            errore(f"fermata {f['n']}: una fermata decisa vuole l'esito")
    for d in s["dubbi"]:
        if d["stato"] not in STATI_DUBBIO:
            errore(f"dubbio «{d['testo'][:30]}…»: stato non ammesso")
        if d["stato"] == "chiuso" and not d["chiusura"]:
            errore("un dubbio chiuso vuole il modo della chiusura (spiegato, corretto, deciso, rinviato)")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", s["aggiornato"]):
        errore("«aggiornato» vuole una data AAAA-MM-GG")


# ----------------------------------------------------------------------------------------------
# Segni grafici
# ----------------------------------------------------------------------------------------------
def icona(stato):
    """Lo stato non è mai solo un colore: ogni icona ha una forma sua e sta accanto alla parola."""
    base = '<svg class="ico" viewBox="0 0 12 12" aria-hidden="true">'
    if stato in ("fatto", "passato", "confermata", "chiuso", "decisa"):
        return base + ('<circle cx="6" cy="6" r="5.5" fill="#0c7a0c"/>'
                       '<path d="M3.2 6.3l1.9 1.9 3.7-4" fill="none" stroke="#fff" stroke-width="1.5" '
                       'stroke-linecap="round" stroke-linejoin="round"/></svg>')
    if stato in ("in_corso", "in_attesa_del_pi", "indeterminata"):
        return base + ('<circle cx="6" cy="6" r="5" fill="#fff" stroke="#1f4e9c" stroke-width="1.2"/>'
                       '<path d="M6 1a5 5 0 0 1 0 10z" fill="#1f4e9c"/></svg>')
    if stato in ("bloccato", "fallito", "smentita"):
        return base + ('<circle cx="6" cy="6" r="5.5" fill="#c5302f"/>'
                       '<path d="M3.8 3.8l4.4 4.4M8.2 3.8l-4.4 4.4" stroke="#fff" stroke-width="1.5" '
                       'stroke-linecap="round"/></svg>')
    return base + '<circle cx="6" cy="6" r="5" fill="#fff" stroke="#8a919c" stroke-width="1.2"/></svg>'


def casella():
    return '<span class="casella"></span>'


L_TRACCIA, H_TRACCIA, MARG = 520, 40, 20


def _x(v, dom):
    lo, hi = dom
    return MARG + (v - lo) / (hi - lo) * (L_TRACCIA - 2 * MARG)


def traccia(p):
    """Una riga: fascia = intervallo di rilevanza, cerchio vuoto = atteso, rombo pieno = risultato."""
    dom = PANNELLI[p["pannello"]]["dominio"]
    lo, hi = p["intervallo"]
    y = H_TRACCIA / 2
    out = [f'<svg class="traccia" viewBox="0 0 {L_TRACCIA} {H_TRACCIA}">']
    for t in PANNELLI[p["pannello"]]["tacche"]:
        forte = p["pannello"] == "punti" and t == 0
        out.append(f'<line x1="{_x(t, dom):.1f}" y1="2" x2="{_x(t, dom):.1f}" y2="{H_TRACCIA - 2}" '
                   f'stroke="{"#5a6270" if forte else "#dfe3e8"}" stroke-width="{1.4 if forte else 1}"/>')
    x1 = _x(lo, dom)
    if hi is None:  # intervallo aperto a destra: «sopra lo zero»
        x2 = _x(dom[1], dom)
        out.append(f'<rect x="{x1:.1f}" y="{y - 9}" width="{x2 - x1:.1f}" height="18" fill="#dbe6f6"/>')
        out.append(f'<path d="M{x1:.1f} {y - 9}V{y + 9}M{x1:.1f} {y - 9}H{x2:.1f}M{x1:.1f} {y + 9}H{x2:.1f}" '
                   'stroke="#1f4e9c" stroke-width="1.2" fill="none"/>')
        out.append(f'<path d="M{x2 - 12:.1f} {y - 5}l7 5-7 5" fill="none" stroke="#1f4e9c" stroke-width="1.6"/>')
    elif lo == hi:
        out.append(f'<line x1="{x1:.1f}" y1="{y - 11}" x2="{x1:.1f}" y2="{y + 11}" stroke="#1f4e9c" '
                   'stroke-width="3.2"/>')
    else:
        x2 = _x(hi, dom)
        out.append(f'<rect x="{x1:.1f}" y="{y - 9}" width="{x2 - x1:.1f}" height="18" rx="3" fill="#dbe6f6" '
                   'stroke="#1f4e9c" stroke-width="1.2"/>')
    xa = _x(p["atteso"], dom)
    out.append(f'<circle cx="{xa:.1f}" cy="{y}" r="6" fill="#fff" stroke="#1f4e9c" stroke-width="2.4"/>')
    if p["risultato"] is not None:
        xr = _x(min(max(p["risultato"], dom[0]), dom[1]), dom)
        if p["ic95"]:
            a = _x(max(p["ic95"][0], dom[0]), dom)
            b = _x(min(p["ic95"][1], dom[1]), dom)
            out.append(f'<line x1="{a:.1f}" y1="{y}" x2="{b:.1f}" y2="{y}" stroke="#16181d" stroke-width="2.6"/>')
            out.append(f'<path d="M{a:.1f} {y - 5}v10M{b:.1f} {y - 5}v10" stroke="#16181d" stroke-width="1.6"/>')
        out.append(f'<path d="M{xr:.1f} {y - 10}l9 10-9 10-9-10z" fill="#16181d" stroke="#fff" stroke-width="1.6"/>')
    out.append("</svg>")
    return "".join(out)


def asse(pannello):
    info = PANNELLI[pannello]
    dom = info["dominio"]
    out = [f'<svg class="traccia asse" viewBox="0 0 {L_TRACCIA} 30">']
    for t in info["tacche"]:
        segno = "+" if pannello == "punti" and t > 0 else ""
        out.append(f'<text x="{_x(t, dom):.1f}" y="23" text-anchor="middle">{segno}{t}</text>')
    out.append("</svg>")
    return "".join(out)


def fmt_num(v, pannello):
    if v is None:
        return ""
    txt = f"{v:g}".replace(".", ",")
    if pannello == "quota":
        return f"{txt}%"
    if pannello == "punti":
        return f"{'+' if v > 0 else ''}{txt} punti"
    return f"{txt} su 47"


def fmt_intervallo(p):
    lo, hi = p["intervallo"]
    if hi is None:
        return "tutto sopra 0"
    if lo == hi:
        return fmt_num(lo, p["pannello"])
    if p["pannello"] == "quota":
        return f"{lo:g}-{hi:g}%"
    return f"da {lo:g} a {hi:g}"


def tabella_previsioni(s, per_il_pi):
    """Tre pannelli, un asse per pannello: quote, punti, numero di studi."""
    blocchi = []
    for chiave, info in PANNELLI.items():
        righe = [p for p in s["previsioni"] if p["pannello"] == chiave]
        r = [f'<table class="prev"><thead><tr><th class="pid"></th><th class="ptesto">{e(info["titolo"])}</th>'
             f'<th class="ptraccia">{asse(chiave)}</th><th class="patteso">atteso</th>'
             f'<th class="pint">intervallo di rilevanza</th><th class="pris">risultato</th>'
             f'<th class="pesito">esito</th></tr></thead><tbody>']
        for p in righe:
            if per_il_pi:
                ris, esito = '<span class="riga-vuota"></span>', '<span class="riga-vuota"></span>'
            else:
                ris = e(fmt_num(p["risultato"], chiave)) or '<span class="muto nz">non misurato</span>'
                if p["ic95"]:
                    ris += ('<br><span class="muto nz">95%: ' +
                            f'{p["ic95"][0]:g}, {p["ic95"][1]:g}'.replace(".", ",").replace(", ", " a ") + "</span>")
                esito = f'<span class="nz">{icona(p["esito"])} {e(ESITI[p["esito"]])}</span>'
                if p["nota"]:
                    esito += f'<br><span class="muto">{e(p["nota"])}</span>'
            r.append(f'<tr><td class="pid">{e(p["id"])}</td><td class="ptesto">{e(p["testo"])}</td>'
                     f'<td class="ptraccia">{traccia(p)}</td>'
                     f'<td class="patteso">{e(fmt_num(p["atteso"], chiave))}</td>'
                     f'<td class="pint">{e(fmt_intervallo(p))}</td>'
                     f'<td class="pris">{ris}</td><td class="pesito">{esito}</td></tr>')
        r.append("</tbody></table>")
        blocchi.append("".join(r))
    legenda = ('<div class="legenda">'
               '<span><svg class="leg" viewBox="0 0 30 14"><rect x="1" y="2" width="28" height="10" rx="3" '
               'fill="#dbe6f6" stroke="#1f4e9c" stroke-width="1.2"/></svg> intervallo di rilevanza</span>'
               '<span><svg class="leg q" viewBox="0 0 14 14"><circle cx="7" cy="7" r="4.6" fill="#fff" '
               'stroke="#1f4e9c" stroke-width="2.2"/></svg> valore atteso</span>'
               '<span><svg class="leg" viewBox="0 0 30 14"><line x1="2" y1="7" x2="28" y2="7" stroke="#16181d" '
               'stroke-width="2.4"/><path d="M15 1l6 6-6 6-6-6z" fill="#16181d"/></svg> '
               'risultato con il suo intervallo di confidenza al 95%</span></div>')
    return legenda + "".join(blocchi)


# ----------------------------------------------------------------------------------------------
# Stile
# ----------------------------------------------------------------------------------------------
CSS = """
@page { size: A4; margin: 10mm 13mm 10mm; }
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body { font-family: "Noto Sans", "DejaVu Sans", sans-serif; font-size: 8.6pt; line-height: 1.34; color: #16181d;
       -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.pagina { break-after: page; }
.pagina:last-child { break-after: auto; }
.occhiello { font-size: 7.4pt; letter-spacing: .06em; text-transform: uppercase; color: #5a6270;
             display: flex; justify-content: space-between; border-bottom: 1.2pt solid #16181d;
             padding-bottom: 1.4mm; margin-bottom: 3mm; }
h1 { font-size: 17pt; line-height: 1.12; margin: 0 0 1.4mm; font-weight: 700; letter-spacing: -.01em; }
h2 { font-size: 10.4pt; margin: 3.6mm 0 1.6mm; font-weight: 700; }
h2 .sotto { font-weight: 400; color: #5a6270; font-size: 8.6pt; }
p { margin: 0 0 1.6mm; }
.guida { font-size: 9.4pt; color: #2a2f38; max-width: 176mm; margin-bottom: 2.8mm; }
.muto { color: #5a6270; }
.ico { width: 3.1mm; height: 3.1mm; vertical-align: -0.5mm; }
.casella { display: inline-block; width: 3.4mm; height: 3.4mm; border: 1.1pt solid #16181d; border-radius: .6mm;
           vertical-align: -0.6mm; background: #fff; }
.riga-vuota { display: inline-block; width: 100%; border-bottom: .8pt solid #8a919c; height: 4.6mm; }
code { font-family: "DejaVu Sans Mono", monospace; font-size: 7.8pt; background: #eef0f3; padding: 0 .8mm;
       border-radius: .6mm; }

/* tre numeri */
.numeri { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3mm; margin-bottom: 2.6mm; }
.numero { border: .8pt solid #cfd4dc; border-radius: 1.6mm; padding: 1.8mm 3mm 1.6mm; }
.numero b { display: block; font-size: 16pt; line-height: 1.1; font-weight: 700; color: #1f4e9c; }
.numero .et { font-size: 7.2pt; letter-spacing: .05em; text-transform: uppercase; color: #5a6270; }
.numero span.t { display: block; margin-top: .6mm; font-size: 8.2pt; color: #2a2f38; }

/* percorso */
.percorso { position: relative; }
.percorso::before { content: ""; position: absolute; left: 4.4mm; top: 5mm; bottom: 6mm; width: 1.3pt;
                    background: #8a919c; }
.tappa { display: grid; grid-template-columns: 9mm 1fr; column-gap: 3mm; margin-bottom: 1.5mm;
         position: relative; break-inside: avoid; }
.tappa .n { width: 9mm; height: 9mm; border-radius: 50%; background: #1f4e9c; color: #fff; font-weight: 700;
            font-size: 11pt; display: flex; align-items: center; justify-content: center; }
.tappa .corpo { border: .8pt solid #cfd4dc; border-radius: 1.6mm; padding: 1.6mm 3mm 1.5mm; background: #fff; }
.tappa .testa { display: flex; justify-content: space-between; align-items: baseline; gap: 3mm; }
.tappa .testa b { font-size: 10.4pt; }
.tappa .quando { font-size: 7.6pt; color: #5a6270; white-space: nowrap; }
.tappa .sess { font-size: 8pt; color: #2a2f38; margin: .3mm 0 .8mm; }
.tappa ul { margin: 0; padding-left: 3.6mm; columns: 2; column-gap: 6mm; }
.tappa li { margin: 0 0 .5mm; break-inside: avoid; }
.tappa .spunta { font-size: 7.6pt; color: #5a6270; display: flex; gap: 4mm; white-space: nowrap; font-weight: 400; }
.etich.pieno { background: #1f4e9c; border-color: #1f4e9c; color: #fff; margin-left: 2mm; }
.fermata .n { background: #fff; color: #16181d; border: 1.3pt solid #16181d; border-radius: 1.2mm;
              transform: rotate(45deg); width: 7.2mm; height: 7.2mm; margin: .9mm; font-size: 0; }
.fermata .corpo { border: 1.1pt solid #16181d; background: #f4f5f7; }
.fermata .etf { font-size: 7.2pt; letter-spacing: .06em; text-transform: uppercase; font-weight: 700; }

/* barra dei 129 studi */
.barra { display: flex; gap: .7mm; height: 8.6mm; margin: 1.6mm 0 1.2mm; }
.barra div { display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 10pt;
             border-radius: 1mm; }
.barra .aperto { background: #1f4e9c; color: #fff; }
.barra .chiuso { color: #16181d; border: .9pt solid #16181d;
                 background: repeating-linear-gradient(45deg, #fff 0 1.1mm, #cfd4dc 1.1mm 1.6mm); }
.barra .chiuso span { background: #fff; padding: 0 1.4mm; border-radius: .8mm; }
.sottobarra { display: flex; gap: .7mm; font-size: 8pt; }
.sottobarra div { padding-right: 2mm; }
.fermo { margin-top: 2.4mm; border-top: .8pt solid #cfd4dc; padding-top: 1.8mm; font-size: 8.2pt; color: #2a2f38; }

/* definizione */
.defin { border: 1.1pt solid #1f4e9c; border-radius: 1.6mm; padding: 2.6mm 3.2mm; margin-bottom: 1mm; }
.defin .frase { font-size: 10.4pt; font-weight: 700; margin-bottom: 2mm; }
.esempi { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3mm; }
.esempio { border-top: .8pt solid #cfd4dc; padding-top: 1.6mm; font-size: 8.1pt; }
.gruppi { display: flex; align-items: center; gap: 1.2mm; margin-bottom: 1.2mm; }
.gruppo { border: .9pt solid #16181d; border-radius: 1mm; padding: .5mm 1.4mm; font-size: 7.8pt;
          background: #fff; white-space: nowrap; }
.gruppo.base { background: #dbe6f6; border-color: #1f4e9c; }
.gruppo em { font-style: normal; font-weight: 700; text-decoration: underline; text-underline-offset: .5mm; }
.verd { font-weight: 700; }

/* passi */
.colonne { display: grid; grid-template-columns: 1fr 1fr; gap: 0 5mm; }
.fase { break-inside: avoid; margin-bottom: 2.4mm; }
.fase h3 { font-size: 7.4pt; letter-spacing: .05em; text-transform: uppercase; color: #5a6270; font-weight: 700;
           margin: 0 0 1mm; border-bottom: .8pt solid #cfd4dc; padding-bottom: .7mm; }
.passo { display: grid; grid-template-columns: 4.4mm 6mm 1fr; column-gap: 1.4mm; margin-bottom: 1.5mm; }
.passo .num { font-weight: 700; color: #1f4e9c; font-size: 10pt; line-height: 1.15; text-align: right; }
.passo b { display: block; }
.passo .da { color: #2a2f38; font-size: 8.2pt; }
.etich { display: inline-block; border: .8pt solid #16181d; border-radius: .8mm; font-size: 6.8pt; font-weight: 700;
         padding: 0 1mm; margin-left: 1mm; vertical-align: .2mm; white-space: nowrap; }
.cancelli { display: grid; grid-template-columns: 1fr 1fr; gap: 1.4mm 5mm; }
.cancello { display: grid; grid-template-columns: 4.4mm 1fr; column-gap: 1.6mm; font-size: 8.2pt;
            break-inside: avoid; }

/* misure */
.misure { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3mm; }
.misura { border: .8pt solid #cfd4dc; border-radius: 1.6mm; padding: 2.2mm 3mm; }
.misura .let { font-size: 13pt; font-weight: 700; color: #1f4e9c; line-height: 1; }
.misura b { display: block; margin: .6mm 0; }
.due { display: grid; grid-template-columns: 1fr 1fr; gap: 0 6mm; }
.riquadro { border: .8pt solid #cfd4dc; border-radius: 1.6mm; padding: 2.2mm 3mm; break-inside: avoid; }
.riquadro.forte { border: 1.1pt solid #16181d; background: #f4f5f7; }
.riquadro ol, .riquadro ul { margin: .6mm 0 0; padding-left: 4.4mm; }
.riquadro li { margin-bottom: .7mm; }

/* previsioni */
table { border-collapse: collapse; width: 100%; }
.prev { margin-bottom: 2mm; table-layout: fixed; }
.prev th { font-size: 7.2pt; font-weight: 400; color: #5a6270; text-align: left; padding: 0 1mm .4mm;
           vertical-align: bottom; }
.prev th.ptesto { font-size: 7.4pt; letter-spacing: .05em; text-transform: uppercase; font-weight: 700; }
.prev td { padding: .5mm 1mm; border-top: .6pt solid #dfe3e8; vertical-align: middle; font-size: 8.2pt; }
.prev .pid { width: 6.5mm; font-weight: 700; color: #5a6270; font-size: 7.6pt; padding-left: 0; }
.prev .ptesto { width: 50mm; }
.prev .ptraccia { width: 52mm; padding: 0; }
.prev .patteso { width: 17mm; padding-left: 2.4mm; }
.prev .pint { width: 17mm; }
.prev .pris { width: 19mm; }
.nz { white-space: nowrap; }
.traccia { width: 52mm; display: block; }
.asse text { font-size: 21px; fill: #5a6270; font-family: "Noto Sans", sans-serif; }
.legenda { display: flex; gap: 6mm; font-size: 7.8pt; color: #2a2f38; margin-bottom: 1.4mm; }
.leg { width: 7mm; height: 3.2mm; vertical-align: -0.6mm; }
.leg.q { width: 3.2mm; }

/* stato del piano */
.dove { display: grid; grid-template-columns: 1.25fr 1fr; gap: 4mm; margin-bottom: 1mm; }
.avanz { display: flex; gap: .8mm; margin: 1.4mm 0 1mm; }
.avanz div { flex: 1; height: 5mm; border: .9pt solid #8a919c; border-radius: .8mm; font-size: 7pt; font-weight: 700;
             display: flex; align-items: center; justify-content: center; color: #5a6270; }
.avanz .fatto { background: #0c7a0c; border-color: #0c7a0c; color: #fff; }
.avanz .in_corso { background: #dbe6f6; border-color: #1f4e9c; color: #1f4e9c; }
.avanz .bloccato { background: #c5302f; border-color: #c5302f; color: #fff; }
.grande { font-size: 17pt; font-weight: 700; line-height: 1.1; }
.allarme { border: 1.4pt solid #c5302f; border-radius: 1.6mm; padding: 2mm 3mm; margin-bottom: 3mm; font-weight: 700; }
.tab th { text-align: left; font-size: 7.2pt; letter-spacing: .05em; text-transform: uppercase; color: #5a6270;
          border-bottom: 1pt solid #16181d; padding: .6mm 1.2mm; font-weight: 700; }
.tab td { padding: 1mm 1.2mm; border-bottom: .6pt solid #dfe3e8; vertical-align: top; font-size: 8.2pt; }
.tab tr { break-inside: avoid; }
.tab td.n { font-weight: 700; color: #1f4e9c; width: 7mm; }
.tab td.st { white-space: nowrap; width: 22mm; }
.tab td.cm { width: 17mm; font-family: "DejaVu Sans Mono", monospace; font-size: 7.4pt; }
.tab td.dt { width: 19mm; white-space: nowrap; }
.catena { display: grid; grid-template-columns: repeat(4, 1fr); gap: 2mm; }
.anello { border: .8pt solid #cfd4dc; border-radius: 1.6mm; padding: 1.8mm 2.4mm; font-size: 8pt; }
.anello b { display: block; }
.fermate { display: grid; grid-template-columns: 1fr 1fr; gap: 2mm; margin-top: 2mm; }
.blocco { break-inside: avoid; }
h2 { break-after: avoid; }
.piede { margin-top: 4mm; border-top: .8pt solid #cfd4dc; padding-top: 1.4mm; font-size: 7.2pt; color: #5a6270; }
"""


def documento(titolo, corpo):
    return (f'<!doctype html><html lang="it"><head><meta charset="utf-8"><title>{e(titolo)}</title>'
            f"<style>{CSS}</style></head><body>{corpo}</body></html>")


# ----------------------------------------------------------------------------------------------
# Mappa per il PI (tre pagine, da stampare)
# ----------------------------------------------------------------------------------------------
def occhiello(testo, pagina):
    return f'<div class="occhiello"><span>simulomicsr · {e(testo)}</span><span>{e(pagina)}</span></div>'


def tappa(n, titolo, quando, sess, voci, qui=False):
    li = "".join(f"<li>{v}</li>" for v in voci)
    marca = '<span class="etich pieno">si parte da qui</span>' if qui else ""
    return (f'<div class="tappa"><div class="n">{n}</div><div class="corpo">'
            f'<div class="testa"><b>Piano {n} · {e(titolo)}{marca}</b>'
            f'<span class="spunta"><span>{casella()} iniziato il _________</span>'
            f'<span>{casella()} chiuso il _________</span></span></div>'
            f'<div class="sess">{e(quando)} {sess}</div><ul>{li}</ul></div></div>')


def fermata(n, titolo, testo):
    return (f'<div class="tappa fermata"><div class="n"></div><div class="corpo">'
            f'<div class="testa"><span class="etf">Fermata {n} · {e(titolo)}</span>'
            f'<span class="spunta"><span>{casella()} deciso il _________</span></span></div>'
            f'{testo}</div></div>')


def pagina_percorso():
    return f"""<section class="pagina">
{occhiello("lettore dello studio · mappa per il PI", "pagina 1 di 3 · il percorso")}
<h1>Il lettore dello studio: il percorso fino all'articolo</h1>
<p class="guida">Un modello locale legge ogni studio GEO una volta sola e scrive la tabella dei fattori.
Un codice fisso forma i confronti da una definizione sola. I curatori di Expression Atlas danno il riferimento esterno.
Il piano è approvato dal 10 novembre 2026.</p>

<div class="numeri">
 <div class="numero"><span class="et">il problema</span><b>473 su 1.903</b>
  <span class="t">confronti del deliverable di oggi che non confrontano bracci confrontabili (24,9%).</span></div>
 <div class="numero"><span class="et">l'idea</span><b>1 lettura</b>
  <span class="t">del modello per studio, al posto dei due passi di oggi: la classificazione dei campioni (Stadio 1) e il disegno dello studio (Stadio 2).</span></div>
 <div class="numero"><span class="et">il riferimento</span><b>129 studi</b>
  <span class="t">del nostro bacino che i curatori di Expression Atlas hanno già diviso in gruppi e confronti.</span></div>
</div>

<h2>I 129 studi di riferimento <span class="sotto">· quanti si possono leggere, quanti restano chiusi</span></h2>
<div class="barra">
 <div class="aperto" style="flex:47">47</div>
 <div class="chiuso" style="flex:42"><span>42</span></div>
 <div class="chiuso" style="flex:40"><span>40</span></div>
</div>
<div class="sottobarra">
 <div style="flex:47"><b>Sviluppo, aperti.</b> Servono per costruire, misurare e correggere.</div>
 <div style="flex:42"><b>Primo giudizio (A), chiusi.</b> Si aprono alla Fermata 2.</div>
 <div style="flex:40"><b>Secondo giudizio (B), chiusi.</b> Si aprono dopo il primo.</div>
</div>
<p class="muto" style="margin-top:1mm">Chiusi: nessuno, agente compreso, legge fattori, confronti o uscite del modello
di questi 82 studi prima dell'apertura.</p>

<h2>Quattro piani, due fermate <span class="sotto">· ogni piano si scrive quando il precedente ha dato i suoi numeri</span></h2>
<div class="percorso">
{tappa(1, "Fondamenta e prova", "Scritto e approvato.",
       "Sessione <b>S12r</b>.",
       ["la misura della pipeline di oggi contro i curatori, su 47 studi",
        "la misura di un lettore di prova, da buttare",
        "la causa di ogni disaccordo fra lettore e curatori",
        "le tue decisioni alla Fermata 1"], qui=True)}
{fermata(1, "decidi tu", "Andiamo al Piano 2? Che cosa facciamo dei confronti in cui i curatori uniscono due agenti "
         "in un livello solo? Quali modelli più grandi proviamo?")}
{tappa(2, "Il lettore nel pacchetto", "Si scrive dopo la Fermata 1.",
       "Sessione <b>S12s</b>.",
       ["i testi GEO di tutti i 24.393 studi",
        "vista, schema e prompt definitivi, poi congelati",
        "il modello scelto, con la prova di ripetibilità",
        "il cancello sui due insiemi di giudizio"])}
{fermata(2, "il cancello", "Si apre il primo giudizio (42 studi). Se il lettore non fa errori, si apre subito il secondo "
         "(40 studi) e i due numeri insieme sono il numero dell'articolo. Se fa errori, la causa si corregge a monte e "
         "il secondo giudizio dà il numero dell'articolo. Se anche il secondo mostra errori, decidi tu.")}
{tappa(3, "Corsa intera e deliverable nuovo (v17)", "Si scrive dopo il cancello.",
       "Sessioni <b>S12c con S12b</b> (nomi delle entità), <b>S12d</b> (tabelle dei nomi), "
       "<b>S13</b> (corsa e ricalcolo).",
       ["il lettore su tutti i 24.393 studi",
        "i nomi delle entità corretti",
        "le meta-analisi nuove, con le correzioni già decise",
        "il controllo di coerenza su tutti i gruppi"])}
{tappa(4, "Validazione del risultato", "Si scrive dopo il deliverable nuovo.",
       "Sessioni <b>S15</b> (rilettura cieca), <b>S7c</b> e <b>S7b</b> (validazione esterna), "
       "<b>S16</b> (figure), <b>S17</b> (Methods).",
       ["LINCS, Tahoe-100M e TCGA con un confronto nullo",
        "meta-analisi contro singolo studio",
        "rilettura cieca delle meta-analisi nuove",
        "figure e testo dell'articolo"])}
</div>
<div class="fermo"><b>Resta fermo fino al deliverable nuovo:</b> il deliverable di oggi (v16, 194 meta-analisi) e i file
principali delle uscite del modello non si toccano. I job girano solo su poddgx02. L'agente non fa mai
<code>git push</code>. Nessun Claude entra nella pipeline e nei numeri dell'articolo.</div>
</section>"""


def pagina_piano1(s):
    fasi, ordine = {}, []
    for t in s["task"]:
        if t["gruppo"] not in fasi:
            fasi[t["gruppo"]] = []
            ordine.append(t["gruppo"])
        fasi[t["gruppo"]].append(t)
    blocchi = []
    for g in ordine:
        righe = []
        for t in fasi[g]:
            et = "".join(f'<span class="etich">cancello {e(k)}</span>' for k in t["cancelli"])
            if t["n"] == 11:
                et += '<span class="etich">Fermata 1</span>'
            righe.append(f'<div class="passo"><div>{casella()}</div><div class="num">{t["n"]}</div>'
                         f'<div><b>{e(t["titolo"])}{et}</b><span class="da">{e(t["da"])}</span></div></div>')
        blocchi.append(f'<div class="fase"><h3>{e(g)}</h3>{"".join(righe)}</div>')
    canc = "".join(
        f'<div class="cancello"><div>{casella()}</div><div><b>{e(c["id"])}</b> '
        f'<span class="muto">({"tutti i passi" if c["task"] == 0 else "passo " + str(c["task"])})</span> '
        f'{e(c["testo"])}</div></div>' for c in s["cancelli"])
    return f"""<section class="pagina">
{occhiello("lettore dello studio · mappa per il PI", "pagina 2 di 3 · il Piano 1, passo per passo")}
<h1>Piano 1: fondamenta e prova</h1>
<p class="guida">La sessione S12r esegue undici passi in ordine. Ogni passo chiude con un commit.
Segna la casella quando l'agente ti dice che il passo è fatto.</p>

<div class="defin">
 <div class="frase">La definizione di confronto: due gruppi dello stesso studio, uguali in tutti i fattori tranne uno,
 e in quel fattore uno dei due è al livello di base.</div>
 <div class="esempi">
  <div class="esempio"><div class="gruppi"><span class="gruppo base"><em>veicolo</em> · 24 h</span> contro
   <span class="gruppo"><em>farmaco</em> · 24 h</span></div>
   <span class="verd">{icona("fatto")} È un confronto.</span> Cambia solo il trattamento, e il veicolo è il livello di base.</div>
  <div class="esempio"><div class="gruppi"><span class="gruppo base"><em>veicolo</em> · <em>0 h</em></span> contro
   <span class="gruppo"><em>farmaco</em> · <em>24 h</em></span></div>
   <span class="verd">{icona("fallito")} Non è un confronto.</span> Cambiano due fattori: il trattamento e il tempo.</div>
  <div class="esempio"><div class="gruppi"><span class="gruppo"><em>farmaco A</em> · 24 h</span> contro
   <span class="gruppo"><em>farmaco B</em> · 24 h</span></div>
   <span class="verd">{icona("fallito")} Non è un confronto.</span> Nessuno dei due gruppi è al livello di base.</div>
 </div>
 <p class="muto" style="margin:1.8mm 0 0">Anche i soggetti contano: donatore, sesso, età e passaggio si confrontano fra i due
 bracci come insiemi. Ogni coppia di gruppi non formata riceve un motivo scritto in un registro.</p>
</div>

<h2>Gli undici passi <span class="sotto">· che cosa dà ogni passo</span></h2>
<div class="colonne" style="display:block; columns:2; column-gap:6mm">{"".join(blocchi)}</div>

<h2>I cinque cancelli <span class="sotto">· controlli con esito sì o no. Se uno fallisce, la sessione non vale</span></h2>
<div class="cancelli">{canc}</div>
<div class="fermo"><b>Che cosa il Piano 1 non fa.</b> Non apre gli 82 studi di giudizio. Non scrive il lettore
definitivo e non sceglie il modello. Non tocca il deliverable, i file principali delle uscite del modello e gli stadi
a valle. Non lancia la corsa su tutti gli studi.</div>
</section>"""


def pagina_giudizio(s):
    return f"""<section class="pagina">
{occhiello("lettore dello studio · mappa per il PI", "pagina 3 di 3 · come si giudica il Piano 1")}
<h1>Come si giudica il Piano 1</h1>
<p class="guida">Tre misure confrontano i nostri gruppi e i nostri confronti con quelli dei curatori, sui 47 studi di
sviluppo. Le stesse misure valgono per la pipeline di oggi e per il lettore di prova.</p>

<div class="misure">
 <div class="misura"><span class="let">a</span><b>I gruppi sono gli stessi?</b>
  Quota di studi in cui i nostri gruppi di campioni sono identici ai gruppi dei curatori.</div>
 <div class="misura"><span class="let">b</span><b>Ritroviamo i loro confronti?</b>
  Quota dei confronti dei curatori che ritroviamo, fra quelli che rispettano la definizione.</div>
 <div class="misura"><span class="let">c</span><b>I nostri confronti in più sono giusti?</b>
  Quota di errori fra i confronti che i curatori non elencano, giudicati con i fattori dei curatori.</div>
</div>

<h2>Le previsioni, scritte prima del calcolo <span class="sotto">· unità: lo studio. Scrivi tu il risultato quando arriva</span></h2>
{tabella_previsioni(s, per_il_pi=True)}
<p class="muto">I valori attesi sono un giudizio motivato dell'agente: non esiste una misura precedente contro un
riferimento esterno. Una previsione è <b>confermata</b> se la stima con il suo intervallo al 95% sta tutta dentro
l'intervallo di rilevanza, <b>smentita</b> se sta tutta fuori, <b>indeterminata</b> se sta a cavallo di un estremo.
Per P3 l'intervallo di rilevanza è «sopra 0»: tutto l'intervallo al 95% della differenza deve stare sopra 0.</p>

<div class="due" style="margin-top:3.4mm">
 <div class="riquadro forte"><b>La regola di esito: si passa al Piano 2 se valgono tutte e tre.</b>
  <ol>
   <li>{casella()} Il lettore ritrova più confronti dei curatori rispetto a oggi (previsione P3 confermata).</li>
   <li>{casella()} Il lettore fa meglio di oggi anche nelle misure (a) e (c).</li>
   <li>{casella()} Ogni disaccordo del lettore ha una causa che la vista, lo schema o un modello più grande possono togliere.</li>
  </ol>
  In ogni altro caso vedi numeri e cause, e decidi tu.</div>
 <div class="riquadro"><b>Alla Fermata 1 ricevi al massimo tre domande.</b>
  <ol>
   <li>Andiamo al Piano 2 oppure no?</li>
   <li>Che cosa facciamo dei confronti in cui i curatori scrivono due agenti come un livello solo, se sono molti?</li>
   <li>Quali modelli più grandi proviamo nel Piano 2?</li>
  </ol></div>
</div>
<div class="fermo"><b>Dove guardare durante il lavoro.</b> Lo stato aggiornato sta in <code>stato-del-piano.pdf</code>,
nella stessa cartella di questa mappa: l'agente lo rigenera a ogni passo. Il piano completo sta in
<code>docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md</code>.
Per aprire la sessione scrivi: «sessione simulomicsr S12r, leggi prima la skill di progetto».</div>
</section>"""


def mappa_pi(s):
    return documento("Lettore dello studio: mappa per il PI",
                     pagina_percorso() + pagina_piano1(s) + pagina_giudizio(s))


# ----------------------------------------------------------------------------------------------
# Stato del piano (lo aggiorna l'agente)
# ----------------------------------------------------------------------------------------------
def stato_del_piano(s):
    fatti = sum(t["stato"] == "fatto" for t in s["task"])
    falliti = [c["id"] for c in s["cancelli"] if c["stato"] == "fallito"]
    smentite = [p["id"] for p in s["previsioni"] if p["esito"] == "smentita"]
    allarme = ""
    if falliti:
        allarme += (f'<div class="allarme">{icona("fallito")} Cancello fallito: {e(", ".join(falliti))}. '
                    "La sessione non vale finché il cancello non passa.</div>")
    if smentite:
        allarme += (f'<div class="allarme">{icona("smentita")} Previsione smentita: {e(", ".join(smentite))}. '
                    "Lo scarto è un risultato e apre un dubbio.</div>")
    avanz = "".join(f'<div class="{t["stato"]}">{t["n"]}</div>' for t in s["task"])
    anelli = "".join(
        f'<div class="anello"><b>Piano {p["n"]} · {e(p["titolo"])}</b>'
        f'<span class="muto">sessioni: {e(p["sessioni"])}</span><br>{icona(p["stato"])} {e(STATI_PIANO[p["stato"]])}</div>'
        for p in s["piani"])
    ferm = "".join(
        f'<div class="anello"><b>Fermata {f["n"]} · {e(f["titolo"])}</b>'
        f'{icona(f["stato"])} {e(STATI_FERMATA[f["stato"]])}'
        f'{("<br>" + e(f["esito"])) if f["esito"] else ""}</div>' for f in s["fermate"])
    righe_task = "".join(
        f'<tr><td class="n">{t["n"]}</td><td><b>{e(t["titolo"])}</b>'
        f'{"".join(f" <span class=etich>cancello {e(k)}</span>" for k in t["cancelli"])}'
        f'{("<br><span class=muto>" + e(t["nota"]) + "</span>") if t["nota"] else ""}</td>'
        f'<td class="st">{icona(t["stato"])} {e(STATI_TASK[t["stato"]])}</td>'
        f'<td class="cm">{e(t["commit"][:9])}</td><td class="dt">{e(t["data"])}</td></tr>' for t in s["task"])
    righe_canc = "".join(
        f'<tr><td class="n">{e(c["id"])}</td><td>{e(c["testo"])}'
        f'{("<br><span class=muto>" + e(c["nota"]) + "</span>") if c["nota"] else ""}</td>'
        f'<td class="dt">{"tutti i passi" if c["task"] == 0 else "passo " + str(c["task"])}</td>'
        f'<td class="st">{icona(c["stato"])} {e(STATI_CANCELLO[c["stato"]])}</td></tr>' for c in s["cancelli"])
    righe_dubbi = "".join(
        f'<tr><td>{e(d["testo"])}</td><td>{e(d["dove"])}</td>'
        f'<td class="st">{icona(d["stato"])} {e(STATI_DUBBIO[d["stato"]])}'
        f'{("<br><span class=muto>" + e(d["chiusura"]) + "</span>") if d["chiusura"] else ""}</td></tr>'
        for d in s["dubbi"])
    righe_reg = "".join(f'<tr><td class="dt">{e(r["data"])}</td><td>{e(r["che_cosa"])}</td></tr>'
                        for r in s["registro"])
    corpo = f"""
{occhiello("lettore dello studio · stato del piano", "aggiornato il " + s["aggiornato"])}
<h1>Lettore dello studio: stato del piano</h1>
{allarme}
<div class="dove">
 <div class="riquadro forte"><b>Prossimo passo</b><br>{e(s["prossimo_passo"])}
  <p class="muto" style="margin:1.2mm 0 0">Sessione: {e(s["sessione"])}. Branch <code>{e(s["branch"])}</code>.</p></div>
 <div class="riquadro"><b>Piano 1 · fondamenta e prova</b><br>
  <span class="grande">{fatti} di 11</span> passi fatti
  <div class="avanz">{avanz}</div>
  <span class="muto">{icona("fatto")} fatto &nbsp; {icona("in_corso")} in corso &nbsp; {icona("da_fare")} da fare &nbsp;
  {icona("bloccato")} bloccato o fallito</span></div>
</div>

<div class="blocco">
<h2>Il percorso intero <span class="sotto">· quattro piani, due fermate</span></h2>
<div class="catena">{anelli}</div>
<div class="fermate">{ferm}</div>

</div><div class="blocco">
<h2>Piano 1: gli undici passi <span class="sotto">· nel piano si chiamano Task 1-11</span></h2>
<table class="tab"><thead><tr><th></th><th>passo</th><th>stato</th><th>commit</th><th>data</th></tr></thead>
<tbody>{righe_task}</tbody></table>

</div><div class="blocco">
<h2>I cinque cancelli <span class="sotto">· se uno fallisce, la sessione non vale</span></h2>
<table class="tab"><thead><tr><th></th><th>che cosa controlla</th><th>dove</th><th>stato</th></tr></thead>
<tbody>{righe_canc}</tbody></table>

</div><div class="blocco">
<h2>Le previsioni e i risultati <span class="sotto">· unità: lo studio, 47 studi di sviluppo</span></h2>
{tabella_previsioni(s, per_il_pi=False)}
<p class="muto">Le previsioni si committano nel passo 1 e dopo il risultato non cambiano. Questa tabella le riporta,
la fonte è <code>analysis/audit/2026-11-09-lettore-studio/00-previsioni.md</code>. Lettere: (a) gruppi uguali ai
curatori, (b) confronti dei curatori ritrovati, (c) confronti in più giudicati con i fattori dei curatori.</p>

</div><div class="blocco">
<h2>Dubbi e cose da ricordare</h2>
<table class="tab"><thead><tr><th>che cosa</th><th>dove si chiude</th><th>stato</th></tr></thead>
<tbody>{righe_dubbi}</tbody></table>

</div><div class="blocco">
<h2>Registro degli aggiornamenti</h2>
<table class="tab"><thead><tr><th>data</th><th>che cosa è cambiato</th></tr></thead><tbody>{righe_reg}</tbody></table>

<div class="piede">Fonte: <code>docs/superpowers/plans/2026-11-09-lettore-studio-mappa/stato.json</code>.
Questo PDF si rigenera con <code>genera.py</code> e non si modifica a mano. Nessuna riga contiene fattori, confronti
o uscite del modello degli 82 studi di giudizio.</div>
</div>
"""
    return documento("Lettore dello studio: stato del piano", corpo)


# ----------------------------------------------------------------------------------------------
# Scrittura dei PDF
# ----------------------------------------------------------------------------------------------
def pagine_pdf(percorso):
    dati = percorso.read_bytes()
    return len(re.findall(rb"/Type\s*/Page[^s]", dati))


def scrivi_pdf(testo_html, uscita, pagine_attese=None):
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    if not chrome:
        sys.exit("genera.py: serve google-chrome o chromium per scrivere il PDF")
    with tempfile.TemporaryDirectory() as tmp:
        sorgente = pathlib.Path(tmp) / "pagina.html"
        sorgente.write_text(testo_html, encoding="utf-8")
        provvisorio = pathlib.Path(tmp) / "pagina.pdf"
        r = subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                            f"--user-data-dir={tmp}/profilo", f"--print-to-pdf={provvisorio}",
                            sorgente.as_uri()], capture_output=True, text=True, timeout=180)
        if r.returncode != 0 or not provvisorio.exists():
            sys.exit(f"genera.py: chrome non ha scritto il PDF\n{r.stderr[-2000:]}")
        n = pagine_pdf(provvisorio)
        if pagine_attese is not None and n != pagine_attese:
            sys.exit(f"genera.py: {uscita.name} ha {n} pagine, attese {pagine_attese}: "
                     "il contenuto non sta nelle pagine previste, niente è stato scritto")
        shutil.copyfile(provvisorio, uscita)
    print(f"scritto {uscita.relative_to(pathlib.Path.cwd()) if uscita.is_relative_to(pathlib.Path.cwd()) else uscita} "
          f"({n} pagine)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--mappa-pi", action="store_true", help="rigenera anche mappa-per-il-PI.pdf")
    ap.add_argument("--html", metavar="DIR", help="scrive anche gli HTML in DIR (per controllo)")
    ap.add_argument("--stato", metavar="FILE", default=str(STATO), help="un altro file di stato (per prova)")
    ap.add_argument("--uscita", metavar="DIR", default=str(QUI), help="un'altra cartella per i PDF (per prova)")
    a = ap.parse_args()
    s = json.loads(pathlib.Path(a.stato).read_text(encoding="utf-8"))
    controlla(s)
    documenti = [("stato-del-piano", stato_del_piano(s), None)]
    if a.mappa_pi:
        documenti.append(("mappa-per-il-PI", mappa_pi(s), 3))
    for nome, testo, pagine in documenti:
        if a.html:
            pathlib.Path(a.html, nome + ".html").write_text(testo, encoding="utf-8")
        scrivi_pdf(testo, pathlib.Path(a.uscita).resolve() / (nome + ".pdf"), pagine)


if __name__ == "__main__":
    main()
