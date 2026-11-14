#!/usr/bin/env python3
# PROVA DA BUTTARE
# 23b-completa.py — S12r6: chiama UNA volta i tre studi della corsa 1 di Fable con lo schema v1 vincolato che il
# limite di spesa della chiave ha lasciato senza risposta (25-deviazioni.md par. 1, punto 2).
# Usa le funzioni di 23-lancia.py senza cambi: stesso modello, stesso prompt, stesso ingresso, stesse impostazioni.
# Il file congelato V-fable-corsa1.jsonl NON si tocca: l'uscita completata e' V-fable-corsa1b.jsonl
# (44 righe copiate com'erano + 3 righe nuove, nell'ordine dell'ingresso).
#
#   <venv>/bin/python analysis/audit/2026-11-14-S12r6-claude-via-api/23b-completa.py
import sys, os, json, datetime, importlib.util
QUI = "analysis/audit/2026-11-14-S12r6-claude-via-api"
spec = importlib.util.spec_from_file_location("lancia", f"{QUI}/23-lancia.py"); L = importlib.util.module_from_spec(spec); spec.loader.exec_module(L)
ATTESI = {"GSE83415", "GSE83687", "GSE93624"}
f_in = f"{L.USCITE}/V-fable-corsa1.jsonl"; f_out = f"{L.USCITE}/V-fable-corsa1b.jsonl"; f_par = f"{L.USCITE}/V-fable-corsa1b.parziale.jsonl"
assert L.sha_file(f_in) == "f208b00be3f83d521272601209a5f5e521f7818da74e4a5a3abf5dd6f74f6c83", "la corsa 1 congelata e' cambiata"
if os.path.exists(f_out): sys.exit(f"{f_out} esiste gia'")
for l in open(".Renviron.local"):
    if l.startswith("ANTHROPIC_API_KEY="): os.environ["ANTHROPIC_API_KEY"] = l.strip().split("=", 1)[1]
import anthropic
client = anthropic.Anthropic(max_retries=0, timeout=1800)
F = L.FORME["V"]
assert L.sha_file(F["ingresso"]) == F["sha_ingresso"] and L.sha_file(F["prompt"]) == F["sha_prompt"] and L.sha_file(L.SCHEMA_V1) == L.SHA_SCHEMA_V1
sistema = open(F["prompt"], encoding="utf-8").read(); frase = open(L.FRASE, encoding="utf-8").read()
schema_v1 = json.load(open(L.SCHEMA_V1, encoding="utf-8"))
recs = {r["record_id"]: r for r in (json.loads(l) for l in open(F["ingresso"], encoding="utf-8"))}
vecchie = [json.loads(l) for l in open(f_in, encoding="utf-8")]
saltati = [x["record_id"] for x in vecchie if x["saltato"]]
assert set(saltati) == ATTESI, saltati
nuove = {}
if os.path.exists(f_par):
    for l in open(f_par, encoding="utf-8"):
        x = json.loads(l); nuove[x["record_id"]] = x
run_id = f"{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-s12r6-V-fable-corsa1b"
for s in saltati:
    if s in nuove: continue                                   # ha gia' avuto una risposta: non si chiama due volte
    kw = L.richiesta("V", L.MODELLI["fable"], sistema, L.messaggio_utente("V", recs[s], frase), schema_v1)
    m, k, sec, err = L.chiama(client, anthropic, kw)
    r = L.riga("V", recs[s], m, k, sec, err, run_id)
    with open(f_par, "a", encoding="utf-8") as o: o.write(json.dumps(r, ensure_ascii=False) + "\n"); o.flush(); os.fsync(o.fileno())
    nuove[s] = r
    print(f"{L.ora()} {s} {r['stop_reason'] or r['saltato']} in={r['n_prompt']} out={r['n_out']} {r['secondi']}s tentativi={k}", flush=True)
with open(f_out, "w", encoding="utf-8") as o:
    for x in vecchie: o.write(json.dumps(nuove.get(x["record_id"], x), ensure_ascii=False) + "\n")
os.remove(f_par)
print(f"{L.ora()} V-fable-corsa1b FINITA: 44 righe copiate, 3 nuove, sha256 {L.sha_file(f_out)}  {f_out}", flush=True)
