#!/usr/bin/env python3
"""10-regola.py - S10b: la regola dei confronti mal appaiati sui fatti dello Stadio 1.

FUORI DAL PACCHETTO: R/ non si tocca. Congelata con il commit delle previsioni
(00-previsioni.md), prima di applicarla ai 1.903 confronti e prima di leggere il riferimento.

Per ogni confronto la regola legge i fatti dello Stadio 1 (master A3, quello del deliverable)
dei campioni trattati (gsm_t) e di controllo (gsm_c), e confronta i due bracci campo per campo.

AGGREGAZIONE DI UN BRACCIO (una sola regola per tutti i campi categoriali)
  - L'insieme dei valori del braccio e' l'insieme dei valori non vuoti dei suoi campioni.
  - Due bracci DIFFERISCONO su un campo se entrambi gli insiemi sono non vuoti e non hanno
    nessun valore in comune. Un campo vuoto non e' una prova di assenza: se un braccio non ha il
    campo, la sotto-regola tace.
  - Per gli agenti (che possono mancare in un campione per errore del modello): un agente e' del
    trattato se compare in PIU' DELLA META' dei campioni trattati; si cancella se compare in
    ALMENO UN campione di controllo. Simmetrico per l'agente solo nel controllo.

AGENTI
  - Una perturbazione e' un veicolo, e non conta, se kind e' "none" o "vehicle_only", oppure
    is_negative_control e' TRUE, oppure agent_normalized.type e' "none" o "vehicle".
  - Il nome dell'agente e' agent_raw (se vuoto, agent_normalized.preferred_name; se vuoto anche
    quello, "<kind>"). Il nome si divide sulle congiunzioni di combinazione: "+", " and ",
    ", " (virgola SEGUITA da spazio: "1,25(OH)2D3" resta intero), " with ", "&", ";".
    "/" NON divide: separa ceppi e regimi ("CMV/TB40", "PMA/Ionomycin").
  - Chiave di un nome: NFKC, lettere greche scritte per nome (alpha, beta...), minuscole, solo
    lettere e cifre. Le parti con meno di 2 caratteri si scartano.

ENTITA' DEL GRUPPO (la classe e' quella che la produzione passa alla regola di riga)
  - drug, environment, infection: l'entita' e' un agente (il patogeno e' un agente). Il trattato
    deve avere UN agente in piu' del controllo (l'entita'). R1 segnala da 2 agenti in piu' in su;
    per un'entita' COMBO: con n parti, da n + 1 in su. Nessun confronto di nomi con l'entita'.
  - disease: l'entita' non e' un agente. R1 segnala da 1 agente in piu' in su, dopo aver tolto le
    perturbazioni di tipo "disease_term" e gli agenti che sono l'entita' scritta come agente. Un
    agente e' l'entita' se la sua chiave (almeno 4 caratteri) contiene un token dell'entita', vi e'
    contenuta, o ha con esso un prefisso comune di almeno 4 lettere ("obese" e "obesity"). Token
    = parole di `extra_stop` di almeno 4 lettere che non sono prefissi di ID (chebi, mesh, hgnc,
    chembl, ncbitaxon, combo).

LE SOTTO-REGOLE (nome breve -> famiglia della rilettura)
  R1  agente_in_piu        secondo agente solo nel trattato (soglie sopra)
  R1c agente_solo_ctrl     un agente non veicolo in piu' della meta' dei controlli e in nessun
                           trattato
  R2a tempo_diverso        insiemi di value_hours (tutte le perturbazioni, veicoli compresi)
                           disgiunti, arrotondati a 3 decimali
  R2b ctrl_tempo_zero      ogni campione di controllo ha una perturbazione con evidenza di tempo
                           zero (guard di R/stage1-normalize.R, riscritto qui sotto) e non tutti i
                           trattati ce l'hanno
  R3a sesso                patient_metadata.sex, valori M/F, disgiunti
  R3b etnia                ancestry_or_population (chiave), disgiunti
  R3c donatore             donor_id (chiave), disgiunti; solo classi drug e environment (nelle
                           malattie e nelle infezioni il caso-controllo ha donatori diversi per
                           disegno)
  R4a materiale_tipo       cell_context.context_kind (senza "unclear"), disgiunti
  R4b linea                cell_line_cellosaurus_candidate (chiave), disgiunti
  R5  sede                 cell_context.tissue: due tessuti sono uguali se condividono una parola
                           di almeno 4 lettere fuori da un elenco di parole generiche (sotto);
                           un braccio senza parole utili tace
  R6  passaggio            passage_or_state: chiave = i numeri che contiene (se ne contiene),
                           altrimenti la chiave del testo; disgiunti
  R7  genotipo             engineered_modifications[].label (non vuoti): una modifica in piu'
                           della meta' di un braccio e in nessun campione dell'altro

  Variante di confronto, FUORI dall'unione e dalla scelta:
  R1x agente_tolta_entita  R1 con la soglia a 1 per tutte le classi, dopo aver tolto gli agenti
                           che contengono un token dell'entita' (la logica di V2 della S10).

USCITA: 30-esiti-regola.csv, una riga per confronto: un flag 0/1 per sotto-regola, il dettaglio
dei valori che fanno scattare, e la visibilita' per famiglia (campo scritto su entrambi i bracci).

Uso: python3 -I analysis/audit/2026-11-07-S10b-metadati-campioni/10-regola.py
"""
import csv
import gzip
import json
import os
import re
import unicodedata

OUT = "analysis/audit/2026-11-07-S10b-metadati-campioni"

VEICOLO_KIND = {"none", "vehicle_only"}
VEICOLO_TYPE = {"none", "vehicle"}
SEP = re.compile(r"\s*\+\s*|\s+and\s+|,\s+|\s+with\s+|\s*&\s*|\s*;\s*", re.IGNORECASE)
PREFISSI_ID = {"chebi", "mesh", "hgnc", "chembl", "ncbitaxon", "combo"}
# parole che non dicono la sede anatomica (R5): classe chiusa, nessuna entita'
SEDE_GENERICHE = {"tissue", "tissues", "cell", "cells", "normal", "healthy", "adjacent", "tumor",
                  "tumour", "tumors", "cancer", "cancerous", "primary", "human", "sample", "samples",
                  "biopsy", "biopsies", "derived", "whole", "total", "control", "disease"}

# Guard is_zero_timepoint, riscritto da R/stage1-normalize.R (.ZERO_TIMEPOINT_REGEX e
# .has_zero_timepoint_evidence): value_hours numerico decide; altrimenti regex su value_raw.
ZERO_RE = re.compile(
    r"(\bbaseline\b|"
    r"(?:^|[^0-9.])0+(?:\.0+)?(?![0-9.])\s*"
    r"(?:h|hr|hrs|hour|hours|min|mins|minute|minutes|d|day|days|w|week|weeks|s|sec|secs|second|seconds)?\b)",
    re.IGNORECASE)

SOTTO = ["R1", "R1c", "R2a", "R2b", "R3a", "R3b", "R3c", "R4a", "R4b", "R5", "R6", "R7"]
NOMI = {"R1": "agente_in_piu", "R1c": "agente_solo_ctrl", "R2a": "tempo_diverso",
        "R2b": "ctrl_tempo_zero", "R3a": "sesso", "R3b": "etnia", "R3c": "donatore",
        "R4a": "materiale_tipo", "R4b": "linea", "R5": "sede", "R6": "passaggio",
        "R7": "genotipo", "R1x": "agente_tolta_entita"}


def scalare(v):
    """value_hours puo' essere un array di un elemento (CLAUDE.md, scalari-come-array)."""
    if isinstance(v, list):
        v = v[0] if len(v) == 1 else None
    if isinstance(v, bool):
        return None
    return v


def greche(s):
    out = []
    for ch in s:
        if "Ͱ" <= ch <= "Ͽ":
            try:
                n = unicodedata.name(ch)
                if n.startswith("GREEK"):
                    out.append(n.split()[-1].lower())
                    continue
            except ValueError:
                pass
        out.append(ch)
    return "".join(out)


def chiave(s):
    if s is None:
        return ""
    s = greche(unicodedata.normalize("NFKC", str(s)))
    return re.sub(r"[^0-9a-z]+", "", s.lower())


def ha_zero(d):
    if not isinstance(d, dict):
        return False
    vh = scalare(d.get("value_hours"))
    if isinstance(vh, (int, float)):
        return vh == 0
    vr = d.get("value_raw")
    if isinstance(vr, list):
        vr = vr[0] if len(vr) == 1 else None
    if vr is None:
        return False
    vr = str(vr).strip()
    return bool(vr) and bool(ZERO_RE.search(vr))


def agenti(p):
    """dict chiave -> (kind, type) degli agenti non veicolo di un campione."""
    out = {}
    for q in p.get("perturbations") or []:
        an = q.get("agent_normalized") or {}
        if q.get("kind") in VEICOLO_KIND or q.get("is_negative_control") is True \
                or an.get("type") in VEICOLO_TYPE:
            continue
        nome = q.get("agent_raw") or an.get("preferred_name") or ""
        parti = [chiave(x) for x in SEP.split(str(nome))] if nome else []
        parti = [x for x in parti if len(x) >= 2]
        if not parti:
            parti = ["<" + str(q.get("kind")) + ">"]
        for x in parti:
            out.setdefault(x, (q.get("kind"), an.get("type")))
    return out


def tempi(p):
    s = set()
    for q in p.get("perturbations") or []:
        vh = scalare((q.get("duration") or {}).get("value_hours"))
        if isinstance(vh, (int, float)):
            s.add(round(float(vh), 3))
    return s


def zero(p):
    return any(ha_zero(q.get("duration")) for q in p.get("perturbations") or [])


def pm(p, k):
    return (p.get("patient_metadata") or {}).get(k)


def cc(p, k):
    return (p.get("cell_context") or {}).get(k)


def valori(campioni, f):
    s = set()
    for p in campioni:
        v = f(p)
        if isinstance(v, (set, frozenset)):
            s |= v
        elif v not in (None, ""):
            s.add(v)
    return s


def disgiunti(a, b):
    return bool(a) and bool(b) and not (a & b)


def maggioranza(campioni, f):
    """valori presenti in piu' della meta' dei campioni (f restituisce un insieme)."""
    n = len(campioni)
    conta = {}
    for p in campioni:
        for v in f(p):
            conta[v] = conta.get(v, 0) + 1
    return {v for v, c in conta.items() if c > n / 2}


def sesso(p):
    v = pm(p, "sex")
    return v if v in ("M", "F") else None


def etnia(p):
    return chiave(pm(p, "ancestry_or_population")) or None


def donatore(p):
    return chiave(pm(p, "donor_id")) or None


def tipo_materiale(p):
    v = cc(p, "context_kind")
    return v if v and v != "unclear" else None


def linea(p):
    return chiave(cc(p, "cell_line_cellosaurus_candidate")) or None


def sede_parole(p):
    t = cc(p, "tissue")
    if not t:
        return frozenset()
    w = re.findall(r"[a-z0-9]+", greche(unicodedata.normalize("NFKC", str(t))).lower())
    return frozenset(x for x in w if len(x) >= 4 and x not in SEDE_GENERICHE)


def passaggio(p):
    v = cc(p, "passage_or_state")
    if not v:
        return None
    num = re.findall(r"\d+", str(v))
    if num:
        return "n:" + "-".join(num)
    k = chiave(v)
    return "t:" + k if k else None


def modifiche(p):
    s = set()
    for m in cc(p, "engineered_modifications") or []:
        if isinstance(m, dict) and m.get("label"):
            k = chiave(m["label"])
            if k:
                s.add(k)
    return s


def token_entita(extra_stop):
    return {t for t in re.findall(r"[a-z]+", (extra_stop or "").lower())
            if len(t) >= 4 and t not in PREFISSI_ID}


def e_entita(k, tok):
    return len(k) >= 4 and any(t in k or k in t or os.path.commonprefix([t, k]).__len__() >= 4
                               for t in tok)


def valuta(T, C, classe, entita, extra_stop):
    """T, C: liste di dict parsed_json. Restituisce (flag, dettaglio, visibilita')."""
    f, det, vis = {}, {}, {}
    tok = token_entita(extra_stop)

    # --- agenti -------------------------------------------------------------------------
    aT = [agenti(p) for p in T]
    aC = [agenti(p) for p in C]
    infoT = {}
    for a in aT:
        for k, v in a.items():
            infoT.setdefault(k, v)
    infoC = {}
    for a in aC:
        for k, v in a.items():
            infoC.setdefault(k, v)
    unioneT = set().union(*[set(a) for a in aT]) if aT else set()
    unioneC = set().union(*[set(a) for a in aC]) if aC else set()
    delta = maggioranza(T, lambda p: set(agenti(p))) - unioneC
    delta_c = maggioranza(C, lambda p: set(agenti(p))) - unioneT
    vis["agente"] = bool(unioneT)

    if classe == "disease":
        d1 = {k for k in delta if infoT[k][1] != "disease_term" and not e_entita(k, tok)}
        f["R1"] = len(d1) >= 1
    else:
        n_parti = len(entita.split(":", 1)[1].split("+")) if entita.startswith("COMBO:") else 1
        d1 = delta
        f["R1"] = len(delta) >= n_parti + 1
    det["R1"] = "|".join(sorted(d1))
    f["R1c"] = len(delta_c) >= 1
    det["R1c"] = "|".join(sorted(delta_c))
    dx = {k for k in delta if not e_entita(k, tok) and infoT[k][1] != "disease_term"}
    f["R1x"] = len(dx) >= 1
    det["R1x"] = "|".join(sorted(dx))

    # --- tempo --------------------------------------------------------------------------
    tT, tC = valori(T, tempi), valori(C, tempi)
    f["R2a"] = disgiunti(tT, tC)
    det["R2a"] = f"{sorted(tT)} vs {sorted(tC)}" if f["R2a"] else ""
    zC = bool(C) and all(zero(p) for p in C)
    zT = bool(T) and all(zero(p) for p in T)
    f["R2b"] = zC and not zT
    det["R2b"] = "controllo a tempo zero" if f["R2b"] else ""
    vis["tempo"] = bool(tT) and (bool(tC) or zC)

    # --- soggetto -----------------------------------------------------------------------
    v_sogg = False
    for r, fn in (("R3a", sesso), ("R3b", etnia), ("R3c", donatore)):
        a, b = valori(T, fn), valori(C, fn)
        f[r] = disgiunti(a, b)
        det[r] = f"{sorted(a)} vs {sorted(b)}" if f[r] else ""
        v_sogg = v_sogg or (bool(a) and bool(b))
    if classe not in ("drug", "environment"):
        f["R3c"] = False
        det["R3c"] = ""
    vis["soggetto"] = v_sogg

    # --- materiale ----------------------------------------------------------------------
    v_mat = False
    for r, fn in (("R4a", tipo_materiale), ("R4b", linea)):
        a, b = valori(T, fn), valori(C, fn)
        f[r] = disgiunti(a, b)
        det[r] = f"{sorted(a)} vs {sorted(b)}" if f[r] else ""
        v_mat = v_mat or (bool(a) and bool(b))
    vis["materiale"] = v_mat

    # --- sede ---------------------------------------------------------------------------
    sT = [s for s in (sede_parole(p) for p in T) if s]
    sC = [s for s in (sede_parole(p) for p in C) if s]
    f["R5"] = bool(sT) and bool(sC) and not any(a & b for a in sT for b in sC)
    det["R5"] = (f"{sorted(set().union(*sT))} vs {sorted(set().union(*sC))}" if f["R5"] else "")
    vis["sede"] = bool(sT) and bool(sC)

    # --- passaggio ----------------------------------------------------------------------
    a, b = valori(T, passaggio), valori(C, passaggio)
    f["R6"] = disgiunti(a, b)
    det["R6"] = f"{sorted(a)} vs {sorted(b)}" if f["R6"] else ""
    vis["passaggio"] = bool(a) and bool(b)

    # --- genotipo -----------------------------------------------------------------------
    mT, mC = valori(T, modifiche), valori(C, modifiche)
    gT = maggioranza(T, modifiche) - mC
    gC = maggioranza(C, modifiche) - mT
    f["R7"] = bool(gT) or bool(gC)
    det["R7"] = ("T:" + "|".join(sorted(gT)) + " C:" + "|".join(sorted(gC))) if f["R7"] else ""
    vis["genotipo"] = bool(mT) or bool(mC)

    return f, det, vis


def main():
    fatti = {}
    with gzip.open(os.path.join(OUT, "20-fatti.jsonl.gz"), "rt", encoding="utf-8") as g:
        for line in g:
            r = json.loads(line)
            fatti[r["record_id"]] = r["parsed_json"]
    righe = list(csv.DictReader(open(os.path.join(OUT, "20-confronti.csv"), encoding="utf-8")))
    assert len(righe) == 1903
    campi = ["cluster_id", "study", "record_id", "classe", "entita"]
    tutte = SOTTO + ["R1x"]
    visk = ["agente", "tempo", "soggetto", "materiale", "sede", "passaggio", "genotipo"]
    with open(os.path.join(OUT, "30-esiti-regola.csv"), "w", newline="", encoding="utf-8") as o:
        w = csv.writer(o)
        w.writerow(campi + ["n_t", "n_c"] + tutte + ["M"] + ["det_" + r for r in tutte]
                   + ["vis_" + v for v in visk])
        for r in righe:
            T = [fatti[x] for x in r["gsm_t"].split(",")]
            C = [fatti[x] for x in r["gsm_c"].split(",")]
            f, det, vis = valuta(T, C, r["classe"], r["entita"], r["extra_stop"])
            M = int(any(f[s] for s in SOTTO))
            w.writerow([r[c] for c in campi] + [len(T), len(C)] + [int(f[s]) for s in tutte]
                       + [M] + [det[s] for s in tutte] + [int(vis[v]) for v in visk])
    print("Scritto 30-esiti-regola.csv")


if __name__ == "__main__":
    main()
