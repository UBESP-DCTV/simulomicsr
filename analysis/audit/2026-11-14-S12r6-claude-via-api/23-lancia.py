#!/usr/bin/env python3
# PROVA DA BUTTARE
# 23-lancia.py — S12r6: una corsa del lettore dello studio con un modello Claude via API, sui 47 studi di sviluppo.
# Solo misura (ADR-0030, aggiornamento 2026-11-14): niente entra nella pipeline. Legge SOLO gli ingressi congelati
# di S12r2 e S12r3 (47 studi di sviluppo): gli 82 studi di giudizio restano chiusi.
#
#   <venv>/bin/python analysis/audit/2026-11-14-S12r6-claude-via-api/23-lancia.py MODELLO FORMA CORSA [--paralleli N] [--prova]
#
#   MODELLO  haiku | sonnet | opus | fable
#   FORMA    T = schema B0 dato come TESTO nel messaggio (sistema: prompt v2; utente: testo dello studio + frase
#                fissa 20-frase-schema.md + schema dello studio in JSON compatto); nessun vincolo sull'uscita
#            V = schema v1 VINCOLATO dall'API (sistema: prompt v1; utente: testo dello studio; output_config.format)
#   CORSA    1 | 2
#   --prova  un solo messaggio neutro, senza il testo di uno studio: prova il percorso, non scrive uscite
#
# Regole depositate in 00-previsioni.md:
# - impostazioni uguali per i quattro modelli: output_config.effort = "high", ragionamento di default (acceso),
#   nessuna temperature, nessun modello di riserva, max_tokens 64000, flusso (streaming);
# - uno studio che ha ricevuto una risposta intera (qualunque stop_reason) NON si chiama una seconda volta in
#   quella corsa: il file parziale tiene le risposte e una ripresa salta gli studi gia' fatti;
# - un errore di trasporto o del servizio senza risposta intera (429, 5xx, rete, tempo scaduto) si ritenta;
# - un errore 400 dell'API e' della richiesta: lo studio si scrive con `saltato` e non si ritenta;
# - forma T: `raw` = testo della risposta senza spazi ai bordi e senza UN recinto di codice markdown che lo
#   avvolge tutto; `raw_api` = testo com'e' arrivato; nessun'altra riparazione. Forma V: `raw` = `raw_api`.
# La chiave sta in .Renviron.local (gitignored): non si stampa e non si scrive in nessun file.
import sys, os, re, json, time, hashlib, threading, argparse, datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

MODELLI = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5", "opus": "claude-opus-5-5", "fable": "claude-fable-5-1"}
QUI = "analysis/audit/2026-11-14-S12r6-claude-via-api"
FORME = {
    "T": dict(ingresso="analysis/input/S12r3-lettore-v2-ingresso.jsonl",
              sha_ingresso="36285df303bceb3585adb153de6ce7d1537d6464b7074ce7c56cee003e8c7cba",
              prompt="analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md",
              sha_prompt="fc33a20d8b1739c8f457be07750b415f89b0cee27c00d0396e9c0fce5fcc4f2a"),
    "V": dict(ingresso="analysis/input/S12r2-lettore-v1-ingresso.jsonl",
              sha_ingresso="867f9787295b1df129bd6695aad908e5f7b9b16627691e8972c9301570296247",
              prompt="analysis/audit/2026-11-10-S12r2-prova-ripetuta/21-prompt-v1.md",
              sha_prompt="9be21089fe5b158d1b6c75ba970965fc58fc2aa09c46d7aa916f70ec7f545b1d"),
}
SCHEMA_V1 = "analysis/audit/2026-11-10-S12r2-prova-ripetuta/20-schema-v1.json"
SHA_SCHEMA_V1 = "6a3fc587c0b6e16128cd2101e8bbdbda2565c3be237007b3fda06a98f4afd2a6"
FRASE = f"{QUI}/20-frase-schema.md"
USCITE = "analysis/p4-output/S12r6-claude"
MAX_TOKENS = 64000
SFORZO = "high"
TENTATIVI = 8

def sha_file(f): return hashlib.sha256(open(f, "rb").read()).hexdigest()
def ora(): return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def estrai(t):
    """Forma T: toglie gli spazi ai bordi e un solo recinto di codice che avvolge tutto il testo."""
    s = t.strip()
    m = re.fullmatch(r"```[A-Za-z]*[ \t]*\r?\n(.*)\r?\n```", s, flags=re.S)
    return (m.group(1).strip(), True) if m else (s, False)

def messaggio_utente(forma, rec, frase):
    if forma == "V": return rec["testo"]
    return rec["testo"] + "\n\n" + frase + json.dumps(rec["schema"], ensure_ascii=False, separators=(",", ":"))

def richiesta(forma, modello, sistema, utente, schema_v1, max_tokens=MAX_TOKENS):
    oc = {"effort": SFORZO}
    if forma == "V": oc["format"] = {"type": "json_schema", "schema": schema_v1}
    return dict(model=modello, max_tokens=max_tokens, system=sistema,
                messages=[{"role": "user", "content": utente}], output_config=oc)

def chiama(client, anthropic, kw):
    """Una risposta intera, oppure ('400', testo) per un errore della richiesta. Gli altri errori si ritentano."""
    ultimo = None
    for k in range(1, TENTATIVI + 1):
        try:
            t0 = time.time()
            with client.messages.stream(**kw) as s:
                m = s.get_final_message()
            return m, k, time.time() - t0, None
        except anthropic.APIStatusError as e:
            if e.status_code in (400, 413, 422): return None, k, 0.0, f"errore_{e.status_code}: {str(e)[:400]}"
            if e.status_code in (401, 403, 404): raise
            ultimo = e
        except (anthropic.APIConnectionError, anthropic.APITimeoutError) as e:
            ultimo = e
        except Exception as e:                                   # flusso interrotto a meta': nessuna risposta intera
            ultimo = e
        time.sleep(min(120, 5 * 2 ** (k - 1)))
    raise RuntimeError(f"nessuna risposta dopo {TENTATIVI} tentativi: {type(ultimo).__name__}: {str(ultimo)[:300]}")

def riga(forma, rec, m, n_tent, secondi, err, run_id):
    if m is None:
        return dict(record_id=rec["record_id"], raw="", saltato=err, n_prompt=None, n_out=None, fine=None, ts=ora(),
                    worker="api", run_id=run_id, raw_api="", recinto=False, stop_reason=None, modello_api=None,
                    id_risposta=None, uso=None, pensiero="", n_tentativi=n_tent, secondi=round(secondi, 1))
    testo = "".join(b.text for b in m.content if b.type == "text")
    pensiero = "\n".join(getattr(b, "thinking", "") or "" for b in m.content if b.type == "thinking")
    raw, recinto = estrai(testo) if forma == "T" else (testo, False)
    fine = {"end_turn": "stop", "stop_sequence": "stop", "max_tokens": "length"}.get(m.stop_reason, m.stop_reason)
    return dict(record_id=rec["record_id"], raw=raw, saltato=None, n_prompt=m.usage.input_tokens, n_out=m.usage.output_tokens,
                fine=fine, ts=ora(), worker="api", run_id=run_id, raw_api=testo, recinto=recinto, stop_reason=m.stop_reason,
                modello_api=m.model, id_risposta=m.id, uso=m.usage.model_dump(mode="json"), pensiero=pensiero,
                n_tentativi=n_tent, secondi=round(secondi, 1))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("modello", choices=MODELLI); ap.add_argument("forma", choices=FORME); ap.add_argument("corsa", choices=["1", "2"])
    ap.add_argument("--paralleli", type=int, default=8); ap.add_argument("--prova", action="store_true")
    a = ap.parse_args()
    for l in open(".Renviron.local"):
        if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"] = l.strip().split("=", 1)[1]
    import anthropic
    client = anthropic.Anthropic(max_retries=0, timeout=1800)
    F = FORME[a.forma]; modello = MODELLI[a.modello]
    assert sha_file(F["ingresso"]) == F["sha_ingresso"], "CANCELLO: ingresso diverso da quello congelato"
    assert sha_file(F["prompt"]) == F["sha_prompt"], "CANCELLO: prompt diverso da quello committato"
    assert sha_file(SCHEMA_V1) == SHA_SCHEMA_V1, "CANCELLO: schema v1 diverso da quello committato"
    sistema = open(F["prompt"], encoding="utf-8").read()            # come il runner del DGX: il file com'e'
    frase = open(FRASE, encoding="utf-8").read()
    schema_v1 = json.load(open(SCHEMA_V1, encoding="utf-8"))
    recs = [json.loads(l) for l in open(F["ingresso"], encoding="utf-8")]
    assert len(recs) == 47 and len({r["record_id"] for r in recs}) == 47
    nome = f"{a.forma}-{a.modello}-corsa{a.corsa}"
    if a.prova:
        kw = richiesta(a.forma, modello, sistema, "Write an empty factor table for a series named GSE0 with no samples and no factors."
                       + ("" if a.forma == "V" else "\n\n" + frase + json.dumps(schema_v1)), schema_v1, max_tokens=4000)
        m, k, sec, err = chiama(client, anthropic, kw)
        r = riga(a.forma, {"record_id": "GSE0"}, m, k, sec, err, "prova")
        print(f"PROVA {nome}: stop_reason={r['stop_reason']} modello={r['modello_api']} n_prompt={r['n_prompt']} n_out={r['n_out']} "
              f"caratteri={len(r['raw'])} pensiero={len(r['pensiero'])} recinto={r['recinto']} secondi={r['secondi']} errore={r['saltato']}")
        print("uso:", json.dumps(r["uso"])); return
    os.makedirs(USCITE, exist_ok=True)
    f_fin = f"{USCITE}/{nome}.jsonl"; f_par = f"{USCITE}/{nome}.parziale.jsonl"
    if os.path.exists(f_fin): sys.exit(f"{f_fin} esiste gia': una corsa congelata non si rifa'")
    fatti = {}
    if os.path.exists(f_par):
        for l in open(f_par, encoding="utf-8"):
            x = json.loads(l); assert x["record_id"] not in fatti; fatti[x["record_id"]] = x
    run_id = f"{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-s12r6-{nome}"
    da_fare = [r for r in recs if r["record_id"] not in fatti]
    print(f"{ora()} {nome}: modello {modello}, {len(fatti)} gia' fatti, {len(da_fare)} da fare, {a.paralleli} in parallelo", flush=True)
    serratura = threading.Lock()
    def uno(rec):
        kw = richiesta(a.forma, modello, sistema, messaggio_utente(a.forma, rec, frase), schema_v1)
        m, k, sec, err = chiama(client, anthropic, kw)
        r = riga(a.forma, rec, m, k, sec, err, run_id)
        with serratura:
            with open(f_par, "a", encoding="utf-8") as o: o.write(json.dumps(r, ensure_ascii=False) + "\n"); o.flush(); os.fsync(o.fileno())
            fatti[rec["record_id"]] = r
            print(f"{ora()} {rec['record_id']} {r['stop_reason'] or r['saltato']} in={r['n_prompt']} out={r['n_out']} {r['secondi']}s tentativi={k}", flush=True)
    falliti = []
    with ThreadPoolExecutor(max_workers=a.paralleli) as ex:
        fut = {ex.submit(uno, r): r["record_id"] for r in da_fare}
        for f in as_completed(fut):
            try: f.result()
            except Exception as e: falliti.append((fut[f], f"{type(e).__name__}: {str(e)[:300]}"))
    if falliti:
        for g, e in falliti: print(f"SENZA RISPOSTA {g}: {e}")
        sys.exit(f"{nome}: {len(falliti)} studi senza risposta; rilancia lo stesso comando per riprendere")
    assert set(fatti) == {r["record_id"] for r in recs}
    with open(f_fin, "w", encoding="utf-8") as o:
        for r in recs: o.write(json.dumps(fatti[r["record_id"]], ensure_ascii=False) + "\n")
    os.remove(f_par)
    ti = sum(x["n_prompt"] or 0 for x in fatti.values()); to = sum(x["n_out"] or 0 for x in fatti.values())
    print(f"{ora()} {nome} FINITA: 47 studi, token in {ti}, token out {to}, sha256 {sha_file(f_fin)}  {f_fin}", flush=True)

if __name__ == "__main__":
    main()
