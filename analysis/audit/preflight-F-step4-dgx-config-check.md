# Pre-flight F step 4 — verifica config DGX + container vLLM

> **Data**: 2026-05-28, sessione 8 RED ALERT FASE F pre-flight.
> **Tipo**: verifica statica (codice) + probe SSH non-distruttivo (live).

## Verifica statica (codice repo)

| item | valore | file:linea | match running config |
|---|---|---|---|
| Container base image | `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` | `inst/dgx/Dockerfile:18` | ✓ ADR-0010 / CLAUDE.md |
| Modello | `mistralai/Mistral-Small-3.2-24B-Instruct-2506` | `inst/dgx/Makefile:44`, `smoke_vllm.py:16` | ✓ ADR-0008 |
| Sampling | `temperature=0.0`, `repetition_penalty` config-driven, `microbatch` (stage2=50) | `run_p4_vllm.py:118,145,177` | ✓ ADR-0008/0010/0013 |
| Login | `u0044@logindgx.hpc.ict.unipd.it` | `R/dgx-config.R:32-33` | ✓ memoria p4_dgx_paths |
| Partition | `dgx12cluster` | `R/dgx-config.R:35` | ✓ |
| remote_root | `/home/u0044/simulomicsr-dgx` (NON `/mnt/home/`) | `R/dgx-config.R:88` | ✓ memoria p4_dgx_paths |

## Probe SSH live (BatchMode, non-distruttivo)

```
SSH_OK (keys configurate, no password prompt)
.sif: simulomicsr-vllm.sif -> simulomicsr-vllm-v0.20.2.sif (9.385.271.296 B = 9.4 GB), May 10 18:09
sinfo dgx12cluster: up | infinite | 2 nodes | state plnd
modello: /home/u0044/simulomicsr-dgx/models/HF_HOME/models--mistralai--Mistral-Small-3.2-24B-Instruct-2506 (cached)
```

**Esito**: DGX raggiungibile, container v0.20.2 presente (no refresh
necessario), partition infinite disponibile, modello cached. Setup pronto
per F2 submit.

## Finding — default `time` di `dgx_p4_submit`

`R/dgx-submit.R:27` ha `time = "12:00:00"` come default. Contraddice la
preferenza utente documentata (memoria `feedback_dgx_time_limit_default`:
"default minimo 72:00:00, mai cap orari stretti; partition dgx12cluster è
infinite"). Innocuo per F2-smoke (~30 min) ma è un footgun per F2-fullrun
(~12-15h prossima sessione): un cap 12h rischia TIMEOUT.

**Mitigazione obbligatoria comunque**: il plan F2 deve passare `time`
esplicito (memoria `feedback_dgx_respect_plan_time`). Decisione aperta:
bumpare il default a `72:00:00` (allinea codice a preferenza standing).
