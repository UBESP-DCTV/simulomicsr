#!/usr/bin/env python3
# PROVA DA BUTTARE
# 22-controllo-positivo.py — S12r6, cancello K2 e prova a secco dello script di misura. NON chiama l'API.
# Scrive in una cartella FUORI dal repository le uscite congelate di Mistral-Small 3.2 (gia' viste) nel formato
# del programma di lancio (23-lancia.py), passate per la sua funzione estrai():
#   T-mistral-corsa1    forma B0 (S12r5, B0.jsonl), ogni uscita avvolta in un recinto di codice markdown
#   T-mistral-corsa2    forma B0 con una frase del prompt riscritta (S12r4, B0pl1.jsonl): prova la ripetibilita'
#   T-mistralrotto-corsa1  come T-mistral-corsa1 con tre uscite rotte apposta: una graffa tolta; testo prima
#                       del JSON; l'uscita valida di un altro studio (valori fuori dall'elenco chiuso)
#   V-mistral-corsa1/2  schema v1 (S12r2, M-corsa1 e M-corsa2), senza recinto
# e il file 23-uscite-sha256.txt. Poi: PROVA=<cartella> Rscript .../24-misura.R
#   python3 analysis/audit/2026-11-14-S12r6-claude-via-api/22-controllo-positivo.py <cartella fuori dal repo>
import hashlib, importlib.util, json, os, sys
QUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("lancia", f"{QUI}/23-lancia.py"); lancia = importlib.util.module_from_spec(spec); spec.loader.exec_module(lancia)
dest = os.path.abspath(sys.argv[1]); assert not dest.startswith(os.path.abspath(".") + os.sep), "la cartella deve stare fuori dal repository"
os.makedirs(dest, exist_ok=True)
leggi = lambda f: [json.loads(l) for l in open(f, encoding="utf-8")]
def riga(r, testo, forma):
    raw, recinto = lancia.estrai(testo) if forma == "T" else (testo, False)
    return dict(record_id=r["record_id"], raw=raw, saltato=r["saltato"], n_prompt=r["n_prompt"], n_out=r["n_out"], fine=r["fine"], ts="2026-11-14T00:00:00Z",
                worker="api", run_id="prova-a-secco", raw_api=testo, recinto=recinto, stop_reason={"stop": "end_turn", "length": "max_tokens"}.get(r["fine"], r["fine"]),
                modello_api="mistral", id_risposta="", uso={"input_tokens": r["n_prompt"], "output_tokens": r["n_out"], "output_tokens_details": {"thinking_tokens": 0}},
                pensiero="", n_tentativi=1, secondi=0.0)
recinto = lambda t: "```json\n" + t + "\n```"
b0 = leggi("analysis/p4-output/S12r5-letture/B0.jsonl"); pl = leggi("analysis/p4-output/S12r4-forme/B0pl1.jsonl")
m1 = leggi("analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl"); m2 = leggi("analysis/p4-output/S12r2-lettore-v1/M-corsa2.jsonl")
# l'estrazione ridà il testo di Mistral, a meno degli spazi ai bordi, in 47 uscite su 47
assert all(lancia.estrai(recinto(r["raw"]))[0] == r["raw"].strip() and lancia.estrai(recinto(r["raw"]))[1] for r in b0)
# senza recinto estrai() non tocca il testo; un recinto solo in testa o con testo fuori non e' tolto
assert all(lancia.estrai(r["raw"]) == (r["raw"].strip(), False) for r in b0)
assert lancia.estrai("Here is it:\n```json\n{}\n```") == ("Here is it:\n```json\n{}\n```", False) and lancia.estrai("```json\n{}") == ("```json\n{}", False)
rotto = []
buoni = [i for i, r in enumerate(b0) if r["fine"] == "stop" and r["raw"].strip().endswith("}")]
i1, i2, i3, i4 = buoni[0], buoni[1], buoni[2], buoni[3]
for i, r in enumerate(b0):
    t = r["raw"]
    if i == i1: t = t.strip()[:-1]
    elif i == i2: t = "Here is the JSON object:\n" + t
    elif i == i3: t = b0[i4]["raw"]
    rotto.append(riga(r, recinto(t) if i != i2 else t, "T"))
corse = {"T-mistral-corsa1": [riga(r, recinto(r["raw"]), "T") for r in b0], "T-mistral-corsa2": [riga(r, recinto(r["raw"]), "T") for r in pl],
         "T-mistralrotto-corsa1": rotto, "V-mistral-corsa1": [riga(r, r["raw"], "V") for r in m1], "V-mistral-corsa2": [riga(r, r["raw"], "V") for r in m2]}
with open(f"{dest}/23-uscite-sha256.txt", "w") as reg:
    for nome, righe in corse.items():
        f = f"{dest}/{nome}.jsonl"
        with open(f, "w", encoding="utf-8") as o:
            for x in righe: o.write(json.dumps(x, ensure_ascii=False) + "\n")
        reg.write(f"{hashlib.sha256(open(f, 'rb').read()).hexdigest()}  {f}\n")
print(f"scritte {len(corse)} corse di prova in {dest}; rotte apposta: {b0[i1]['record_id']} (graffa tolta), {b0[i2]['record_id']} (testo prima), {b0[i3]['record_id']} (uscita di {b0[i4]['record_id']})")
open(f"{dest}/rotte.txt", "w").write(" ".join(b0[i]["record_id"] for i in (i1, i2, i3)) + "\n")
