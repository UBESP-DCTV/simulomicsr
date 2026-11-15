#!/usr/bin/env python3
# 20-lancia-lotti.py — i modelli Claude sugli studi APERTI curati da Gemma (carta: 00-previsioni.md). Termine di
# misura: niente entra nella pipeline. Legge SOLO analysis/input/gemma-b0-ingresso-aperta.jsonl (2.016 studi della
# parte aperta) e ne usa solo il campo `testo`. La parte chiusa di Gemma, gli studi di giudizio e di sviluppo non
# entrano in nessuna richiesta (cancello KC5, controllato qui a ogni invio).
#
# Forma V della prova del 2026-11-14 (S12r6, 23-lancia.py), senza cambi: sistema = prompt v1; utente = testo dello
# studio; output_config = {effort: "high", format: schema v1}; ragionamento di default; nessuna temperature;
# max_tokens 64000. Le richieste vanno a LOTTI (Message Batches API, meta' prezzo), un lotto per pezzo e per corsa.
#
#   <venv>/bin/python .../20-lancia-lotti.py prova MODELLO          un messaggio neutro in tempo reale e un lotto neutro
#   <venv>/bin/python .../20-lancia-lotti.py invia CORSA PEZZI      CORSA = haiku-corsa1 | haiku-corsa2 | opus-corsa1 | sonnet-corsa1
#                                                                   PEZZI = 1 | 1-8 | 2,3 | r (r = rimanda i falliti, una volta)
#   <venv>/bin/python .../20-lancia-lotti.py stato                  lo stato dei lotti nel registro
#   <venv>/bin/python .../20-lancia-lotti.py aspetta [SECONDI]      aspetta che i lotti aperti finiscano (al massimo SECONDI)
#   <venv>/bin/python .../20-lancia-lotti.py raccogli               scarica le risposte dei lotti finiti e conta la spesa
#   <venv>/bin/python .../20-lancia-lotti.py spesa                  la spesa contata da `usage` sui pezzi raccolti
#   <venv>/bin/python .../20-lancia-lotti.py congela CORSA          scrive <CORSA>.jsonl in ordine d'ingresso, sola lettura, SHA-256
#   <venv>/bin/python .../20-lancia-lotti.py annulla ID_LOTTO
#
# Regole depositate: uno studio con una risposta intera non si chiama due volte nella stessa corsa (un pezzo gia'
# nel registro non si rimanda); un errore della richiesta e' `saltato`; un fallimento del servizio o una scadenza si
# rimanda una volta sola (pezzo `r`); la spesa si conta da `usage` al prezzo di listino, meta' per i lotti.
# La chiave sta in .Renviron.local (non tracciato): non si stampa e non si scrive in nessun file.
import sys, os, json, time, hashlib, datetime, stat

MODELLI = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5", "opus": "claude-opus-5-5"}
CORSE = {"haiku-corsa1": "haiku", "haiku-corsa2": "haiku", "opus-corsa1": "opus", "sonnet-corsa1": "sonnet"}
QUI = "analysis/audit/2026-11-15-claude-su-gemma"
INGRESSO = "analysis/input/gemma-b0-ingresso-aperta.jsonl"
SHA_INGRESSO_FILE = "analysis/audit/2026-11-15-lettori-su-gemma/22-ingresso-sha256.txt"
DIVISIONE = "analysis/audit/2026-11-15-lettori-su-gemma/21-divisione.csv"
PROMPT = "analysis/audit/2026-11-10-S12r2-prova-ripetuta/21-prompt-v1.md"
SHA_PROMPT = "9be21089fe5b158d1b6c75ba970965fc58fc2aa09c46d7aa916f70ec7f545b1d"
SCHEMA_V1 = "analysis/audit/2026-11-10-S12r2-prova-ripetuta/20-schema-v1.json"
SHA_SCHEMA_V1 = "6a3fc587c0b6e16128cd2101e8bbdbda2565c3be237007b3fda06a98f4afd2a6"
SVILUPPO = "analysis/input/S12r2-lettore-v1-ingresso.jsonl"
USCITE = "analysis/p4-output/claude-su-gemma-V"
REGISTRO = f"{QUI}/20-lotti.jsonl"
SHA_USCITE = f"{QUI}/20-uscite-sha256.txt"
MAX_TOKENS = 64000; SFORZO = "high"; N_PEZZI = 8; TETTO = 75.0
PREZZI = {"haiku": (0.10, 0.50), "sonnet": (2.0, 10.0), "opus": (4.0, 20.0)}     # dollari per milione di token: ingresso, uscita
HAIKU_SOPRA_100K = (0.50, 2.50)
SCONTO_LOTTI = 0.5

def sha_file(f): return hashlib.sha256(open(f, "rb").read()).hexdigest()
def ora(): return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
def dici(*a):
    s = " ".join(str(x) for x in a); print(s, flush=True)
    os.makedirs(f"{QUI}/20-log", exist_ok=True)
    with open(f"{QUI}/20-log/20-lancia-lotti.log", "a", encoding="utf-8") as f: f.write(f"{ora()} {s}\n")

def cliente():
    for l in open(".Renviron.local"):
        if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"] = l.strip().split("=", 1)[1]
    import anthropic
    return anthropic, anthropic.Anthropic(max_retries=2, timeout=1800)

def oggetto():
    """Cancelli KC2 e KC5 sull'oggetto: impronte congelate, solo studi aperti, nessuno studio di sviluppo."""
    atteso = open(SHA_INGRESSO_FILE).read().split()[0]
    assert sha_file(INGRESSO) == atteso, "CANCELLO KC2: ingresso diverso da quello congelato"
    assert sha_file(PROMPT) == SHA_PROMPT, "CANCELLO KC2: prompt v1 diverso da quello committato"
    assert sha_file(SCHEMA_V1) == SHA_SCHEMA_V1, "CANCELLO KC2: schema v1 diverso da quello committato"
    recs = [json.loads(l) for l in open(INGRESSO, encoding="utf-8")]
    ids = [r["record_id"] for r in recs]
    assert len(ids) == 2016 and len(set(ids)) == 2016
    parte = {}
    righe = open(DIVISIONE, encoding="utf-8").read().splitlines(); col = [c.strip('"') for c in righe[0].split(",")]
    ig, ip = col.index("gse"), col.index("parte")
    for l in righe[1:]:
        c = [x.strip('"') for x in l.split(",")]; parte[c[ig]] = c[ip]
    assert all(parte.get(g) == "aperta" for g in ids), "CANCELLO KC5: uno studio dell'ingresso non e' della parte aperta"
    sv = {json.loads(l)["record_id"] for l in open(SVILUPPO, encoding="utf-8")}
    assert not (set(ids) & sv), "CANCELLO KC5: uno studio di sviluppo nell'ingresso"
    ordine = sorted(ids, key=lambda g: hashlib.sha256(g.encode()).hexdigest())      # l'ordine per costruzione della carta
    assert ordine[:5] == ["GSE144208", "GSE195877", "GSE57871", "GSE141756", "GSE197959"]
    n = len(ordine) // N_PEZZI; assert n * N_PEZZI == len(ordine) == 2016
    pezzo = {g: i // n + 1 for i, g in enumerate(ordine)}
    return {r["record_id"]: r for r in recs}, ids, pezzo

def parametri(modello, sistema, utente, schema_v1, max_tokens=MAX_TOKENS):
    # uguale a richiesta("V", ...) di 23-lancia.py (S12r6)
    return dict(model=modello, max_tokens=max_tokens, system=sistema, messages=[{"role": "user", "content": utente}],
                output_config={"effort": SFORZO, "format": {"type": "json_schema", "schema": schema_v1}})

def registro():
    if not os.path.exists(REGISTRO): return []
    return [json.loads(l) for l in open(REGISTRO, encoding="utf-8") if l.strip()]
def scrivi_registro(righe):
    tmp = REGISTRO + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for r in righe: f.write(json.dumps(r, ensure_ascii=False) + "\n")
        f.flush(); os.fsync(f.fileno())
    os.replace(tmp, REGISTRO)

def file_pezzo(corsa, pezzo): return f"{USCITE}/{corsa}.pezzo{pezzo}.jsonl"

def costo(modello, uso, lotto=True):
    if not uso: return 0.0
    t_in = (uso.get("input_tokens") or 0); t_cw = (uso.get("cache_creation_input_tokens") or 0); t_cr = (uso.get("cache_read_input_tokens") or 0)
    t_out = (uso.get("output_tokens") or 0)
    p_in, p_out = PREZZI[modello]
    if modello == "haiku" and (t_in + t_cw + t_cr) > 100000: p_in, p_out = HAIKU_SOPRA_100K
    c = (t_in * p_in + t_cw * p_in * 1.25 + t_cr * p_in * 0.1 + t_out * p_out) / 1e6
    return c * (SCONTO_LOTTI if lotto else 1.0)

def riga_da_messaggio(gse, m, run_id, lotto_id, pezzo):
    # stessi campi di riga() di 23-lancia.py, forma V: raw = raw_api
    testo = "".join(b.text for b in m.content if b.type == "text")
    pensiero = "\n".join(getattr(b, "thinking", "") or "" for b in m.content if b.type == "thinking")
    fine = {"end_turn": "stop", "stop_sequence": "stop", "max_tokens": "length"}.get(m.stop_reason, m.stop_reason)
    return dict(record_id=gse, raw=testo, saltato=None, n_prompt=m.usage.input_tokens, n_out=m.usage.output_tokens, fine=fine, ts=ora(),
                worker="api-lotti", run_id=run_id, raw_api=testo, recinto=False, stop_reason=m.stop_reason, modello_api=m.model,
                id_risposta=m.id, uso=m.usage.model_dump(mode="json"), pensiero=pensiero, lotto=lotto_id, pezzo=pezzo)
def riga_senza(gse, motivo, run_id, lotto_id, pezzo, saltato):
    return dict(record_id=gse, raw="", saltato=(motivo if saltato else None), n_prompt=None, n_out=None, fine=None, ts=ora(), worker="api-lotti",
                run_id=run_id, raw_api="", recinto=False, stop_reason=None, modello_api=None, id_risposta=None, uso=None, pensiero="",
                lotto=lotto_id, pezzo=pezzo, fallita=(None if saltato else motivo))

def leggi_pezzo(f): return [json.loads(l) for l in open(f, encoding="utf-8") if l.strip()]

def spesa(stampa=True):
    tot = {}; n = {}
    for r in registro():
        if not r.get("raccolto") or r["corsa"] == "prova": continue
        for x in leggi_pezzo(r["file"]):
            tot[r["corsa"]] = tot.get(r["corsa"], 0.0) + costo(CORSE[r["corsa"]], x.get("uso")); n[r["corsa"]] = n.get(r["corsa"], 0) + 1
    prove = sum(r.get("costo_prova", 0.0) for r in registro())
    s = sum(tot.values()) + prove
    if stampa:
        for c in sorted(tot): dici(f"  spesa {c}: {tot[c]:.2f} dollari su {n[c]} record raccolti")
        dici(f"  prove del percorso: {prove:.3f} dollari; SPESA TOTALE contata da usage: {s:.2f} dollari (tetto {TETTO:.0f})")
    return s, tot

def cmd_prova(modello):
    anthropic, client = cliente(); recs, ids, pezzo = oggetto()
    sistema = open(PROMPT, encoding="utf-8").read(); schema_v1 = json.load(open(SCHEMA_V1, encoding="utf-8"))
    neutro = "Write an empty factor table for a series named GSE0 with no samples and no factors."
    kw = parametri(MODELLI[modello], sistema, neutro, schema_v1, max_tokens=4000)
    with client.messages.stream(**kw) as s: m = s.get_final_message()
    c1 = costo(modello, m.usage.model_dump(mode="json"), lotto=False)
    dici(f"prova in tempo reale {modello}: stop={m.stop_reason} modello={m.model} in={m.usage.input_tokens} out={m.usage.output_tokens} costo={c1:.4f}")
    b = client.messages.batches.create(requests=[dict(custom_id=f"GSE0-{i}", params=kw) for i in (1, 2)])
    dici(f"prova a lotti {modello}: lotto {b.id} stato {b.processing_status}")
    righe = registro(); righe.append(dict(corsa="prova", modello=modello, pezzo=0, lotto=b.id, n=2, ts=ora(), raccolto=False, costo_prova=c1)); scrivi_registro(righe)

def pezzi_da(testo):
    if testo == "r": return ["r"]
    out = []
    for p in testo.split(","):
        if "-" in p: a, b = p.split("-"); out += list(range(int(a), int(b) + 1))
        else: out.append(int(p))
    assert all(1 <= k <= N_PEZZI for k in out) and len(set(out)) == len(out); return out

def cmd_invia(corsa, pezzi_testo):
    assert corsa in CORSE; modello = CORSE[corsa]
    anthropic, client = cliente(); recs, ids, pezzo = oggetto()
    sistema = open(PROMPT, encoding="utf-8").read(); schema_v1 = json.load(open(SCHEMA_V1, encoding="utf-8"))
    righe = registro(); fatti = {r["pezzo"] for r in righe if r["corsa"] == corsa}
    for k in pezzi_da(pezzi_testo):
        assert k not in fatti, f"il pezzo {k} della corsa {corsa} e' gia' nel registro: non si manda due volte"
        if k == "r":
            aperti = [r for r in righe if r["corsa"] == corsa and not r.get("raccolto")]
            assert not aperti, "prima raccogli tutti i lotti della corsa"
            gruppo = [x["record_id"] for r in righe if r["corsa"] == corsa for x in leggi_pezzo(r["file"]) if x.get("fallita")]
            if not gruppo: dici(f"{corsa}: nessuna richiesta fallita da rimandare"); continue
        else:
            gruppo = [g for g in ids if pezzo[g] == k]; assert len(gruppo) == 252
        assert all(g in recs for g in gruppo)
        richieste = [dict(custom_id=g, params=parametri(MODELLI[modello], sistema, recs[g]["testo"], schema_v1)) for g in gruppo]
        b = client.messages.batches.create(requests=richieste)
        righe.append(dict(corsa=corsa, modello=modello, pezzo=k, lotto=b.id, n=len(gruppo), ts=ora(), raccolto=False, file=file_pezzo(corsa, k)))
        scrivi_registro(righe)
        dici(f"inviato {corsa} pezzo {k}: lotto {b.id}, {len(gruppo)} richieste, stato {b.processing_status}")

def cmd_stato(client=None):
    if client is None: _, client = cliente()
    aperti = 0
    for r in registro():
        if r.get("raccolto"): continue
        b = client.messages.batches.retrieve(r["lotto"]); c = b.request_counts
        if b.processing_status != "ended": aperti += 1
        dici(f"  {r['corsa']} pezzo {r['pezzo']} {r['lotto']}: {b.processing_status}; in corso {c.processing}, riuscite {c.succeeded}, errori {c.errored}, annullate {c.canceled}, scadute {c.expired}")
    return aperti

def cmd_aspetta(secondi):
    _, client = cliente(); t0 = time.time()
    while True:
        aperti = sum(1 for r in registro() if not r.get("raccolto") and client.messages.batches.retrieve(r["lotto"]).processing_status != "ended")
        if aperti == 0 or time.time() - t0 > secondi: break
        time.sleep(45)
    cmd_stato(client)

def cmd_raccogli():
    _, client = cliente(); recs, ids, pezzo = oggetto(); righe = registro(); os.makedirs(USCITE, exist_ok=True)
    for r in righe:
        if r.get("raccolto"): continue
        b = client.messages.batches.retrieve(r["lotto"])
        if b.processing_status != "ended": dici(f"  {r['corsa']} pezzo {r['pezzo']}: non finito ({b.processing_status})"); continue
        if r["corsa"] == "prova":
            c = 0.0; esiti = []
            for res in client.messages.batches.results(r["lotto"]):
                esiti.append(res.result.type)
                if res.result.type == "succeeded": c += costo(r["modello"], res.result.message.usage.model_dump(mode="json"))
                else: dici("   prova a lotti, esito:", res.result.type, str(getattr(res.result, "error", ""))[:300])
            r["raccolto"] = True; r["costo_prova"] = r.get("costo_prova", 0.0) + c; scrivi_registro(righe)
            dici(f"  prova a lotti {r['modello']}: esiti {esiti}, costo {c:.4f}"); continue
        run_id = f"{r['corsa']}"; out = []; visti = set(); conta = {}
        for res in client.messages.batches.results(r["lotto"]):
            g = res.custom_id; assert g in recs and g not in visti; visti.add(g); t = res.result.type; conta[t] = conta.get(t, 0) + 1
            if t == "succeeded": out.append(riga_da_messaggio(g, res.result.message, run_id, r["lotto"], r["pezzo"]))
            elif t == "errored":
                e = res.result.error; tipo = getattr(getattr(e, "error", e), "type", "") ; testo = str(e)[:400]
                out.append(riga_senza(g, f"errore_{tipo}: {testo}", run_id, r["lotto"], r["pezzo"], saltato=(tipo == "invalid_request_error")))
            else: out.append(riga_senza(g, t, run_id, r["lotto"], r["pezzo"], saltato=False))
        assert len(visti) == r["n"], f"lotto {r['lotto']}: {len(visti)} risposte su {r['n']} richieste"
        f = r["file"]; assert not os.path.exists(f), f"{f} esiste gia'"
        with open(f, "w", encoding="utf-8") as fh:
            for x in out: fh.write(json.dumps(x, ensure_ascii=False) + "\n")
            fh.flush(); os.fsync(fh.fileno())
        r["raccolto"] = True; r["esiti"] = conta; r["costo"] = round(sum(costo(r["modello"], x.get("uso")) for x in out), 4); scrivi_registro(righe)
        t_in = sum(x["n_prompt"] or 0 for x in out); t_out = sum(x["n_out"] or 0 for x in out)
        fini = {}
        for x in out: fini[str(x["stop_reason"])] = fini.get(str(x["stop_reason"]), 0) + 1
        dici(f"  raccolto {r['corsa']} pezzo {r['pezzo']}: {conta}; fine {fini}; token in {t_in} out {t_out}; costo {r['costo']:.2f} dollari")
    spesa()

def cmd_congela(corsa):
    recs, ids, pezzo = oggetto(); righe = [r for r in registro() if r["corsa"] == corsa]
    assert righe and all(r.get("raccolto") for r in righe), "ci sono lotti della corsa non raccolti"
    per = {}
    for r in sorted(righe, key=lambda r: (r["pezzo"] == "r", str(r["pezzo"]))):       # il pezzo `r` (rimandati) copre i falliti
        for x in leggi_pezzo(r["file"]):
            if x["record_id"] in per: assert per[x["record_id"]].get("fallita"), "uno studio con una risposta intera ha due record"
            per[x["record_id"]] = x
    fatti = [g for g in ids if g in per]
    f = f"{USCITE}/{corsa}.jsonl"; assert not os.path.exists(f), f"{f} esiste gia'"
    with open(f, "w", encoding="utf-8") as fh:
        for g in fatti: fh.write(json.dumps(per[g], ensure_ascii=False) + "\n")
        fh.flush(); os.fsync(fh.fileno())
    os.chmod(f, stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)
    with open(SHA_USCITE, "a", encoding="utf-8") as fh: fh.write(f"{sha_file(f)}  {f}\n")
    pz = sorted({str(r["pezzo"]) for r in righe})
    dici(f"congelata {corsa}: {len(fatti)} studi (pezzi {','.join(pz)}), senza risposta {sum(1 for g in fatti if per[g].get('fallita'))}, saltati {sum(1 for g in fatti if per[g].get('saltato'))}, SHA-256 {sha_file(f)}")

def main():
    a = sys.argv[1:]; assert a, "comando mancante"
    if a[0] == "prova": cmd_prova(a[1])
    elif a[0] == "invia": cmd_invia(a[1], a[2])
    elif a[0] == "stato": cmd_stato()
    elif a[0] == "aspetta": cmd_aspetta(int(a[1]) if len(a) > 1 else 540)
    elif a[0] == "raccogli": cmd_raccogli()
    elif a[0] == "spesa": spesa()
    elif a[0] == "congela": cmd_congela(a[1])
    elif a[0] == "annulla":
        _, client = cliente(); b = client.messages.batches.cancel(a[1]); dici(f"annullato {a[1]}: {b.processing_status}")
    else: raise SystemExit("comando non noto")

if __name__ == "__main__": main()
