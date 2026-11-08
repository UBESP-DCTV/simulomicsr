# S12p: conteggio esatto dei token del prompt (sistema + testo) dei 1.903 confronti, per ciascun modello, su CPU
# nel container di produzione (vLLM 0.20.2), con la stessa funzione del runner (run_p4_vllm.count_prompt_tokens).
# Uso: python3 25-conta-token.py <runtime/python> <prompt.txt> <ingresso.jsonl> <uscita.tsv>
import json, sys, time
sys.path.insert(0, sys.argv[1])
from run_p4_vllm import count_prompt_tokens
from vllm.tokenizers import get_tokenizer
sistema = open(sys.argv[2], encoding="utf-8").read()
recs = [json.loads(l) for l in open(sys.argv[3], encoding="utf-8")]
MODELLI = [("mistral", "mistralai/Mistral-Small-3.2-24B-Instruct-2506", "95a6d26c4bfb886c58daf9d3f7332c857cb27b43", "mistral"),
           ("magistral", "mistralai/Magistral-Small-2509", "a31cc96ab10cf19bc42c628fedf1e359e0853c49", "mistral"),
           ("gemma", "google/gemma-4-31B-it", "842da3794eaa0b77d5f08bae87a17459d91ff475", "auto")]
with open(sys.argv[4], "w", encoding="utf-8") as out:
    out.write("modello\trecord_id\tcaratteri\tn_token\n")
    for nome, mid, rev, mode in MODELLI:
        t0 = time.time()
        tok = get_tokenizer(mid, tokenizer_mode=mode, revision=rev)
        for r in recs:
            conv = [{"role": "system", "content": sistema}, {"role": "user", "content": r["testo"]}]
            out.write("%s\t%s\t%d\t%d\n" % (nome, r["record_id"], len(sistema) + len(r["testo"]), count_prompt_tokens(tok, conv)))
        print(nome, type(tok).__name__, len(recs), "%.1f s" % (time.time() - t0), flush=True)
