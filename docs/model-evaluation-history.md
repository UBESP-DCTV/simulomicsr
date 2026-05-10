# Model evaluation history (pre-Mistral selection)

> Documentazione storica delle valutazioni LLM condotte tra **P3.5-C**
> (multi-provider closed) e **P3.5-D** (cheap models / open-weights via
> OpenRouter) prima di selezionare **mistral-small-3.2-24b-instruct**
> come modello di produzione P4.
>
> Estratto da CLAUDE.md durante il cleanup post-α (2026-05-10) per
> preservare la traccia decisionale fuori dal contesto persistente del
> repository. Tutti i test sono stati eseguiti su mini-gold v5
> (`inst/extdata/p35c-minigold-reviewed-v5.csv`, 100 sample reviewati a
> mano dall'autore).

## P3.5-C v5 (2026-05-04 – 2026-05-05): multi-provider closed

Cinque modelli closed (OpenAI + Anthropic) testati con dispatch
unificato `llm_call_structured()` e schema `study_design.stage2.v2`.
Adapter Anthropic Messages API aggiunto; multi-model classifier con
confidence score via cross-model agreement.

| Modello              | Easy | Hard | Overall | vs v3 |
|----------------------|------|------|---------|-------|
| **gpt-5.5**          | 96%  | 92%  | **94%** |  +3pp |
| **gpt-5.4-mini**     | 96%  | 90%  |   93%   | **+30pp** |
| claude-sonnet-4-6    | 96%  | 86%  |   91%   | +11pp |
| claude-haiku-4-5     | 100% | 60%  |   80%   |  +1pp |
| gpt-5.4-nano         | 42%  |  6%  |   24%   | -24pp |

| Metrica                           | Valore                                           |
|-----------------------------------|--------------------------------------------------|
| Modello P3.5-C scelto             | **gpt-5.4-mini** (drop -1pp vs gpt-5.5, costo ~5-10x cheaper) |
| Estrapolazione P4 con gpt-5.4-mini | ~$5-7k vs $32k full-gpt-5.5 (saving ~80%)       |
| Architettura tier-aware ibrida    | Haiku per `easy` + gpt-5.4-mini per medium/hard, P4 ~$4-5k |
| Soglia confidence raccomandata    | >= 0.45 (esclude tier hard)                      |
| Costo cumulativo (v3 + v5)        | ~$50-60                                          |
| Invalid rate v5                   | 3 / 250 (1.2%)                                   |

## P3.5-D (2026-05-06): cheap models + open-weights via OpenRouter

Adapter `R/llm-client-openrouter.R` aggiunto. Provider `openrouter` nel
dispatch. Testati 21 modelli su 50 GSE × mini-gold v5 (n=100).

| Modello                              | Provider     | Overall | $/sample  | Note                                     |
|--------------------------------------|--------------|---------|-----------|------------------------------------------|
| **gemini-2.5-flash**                 | OpenRouter   | **97%** | $0.0035   | Closed                                   |
| **mistral-small-3.2-24b-instruct**   | OpenRouter   | **96%** | **$0.0004** | Apache 2.0 ✓ ★ VINCITORE              |
| qwen3-30b-a3b-instruct-2507          | OpenRouter   | 95%     | $0.0006   | Apache 2.0 ✓                             |
| gpt-5.5                              | OpenAI       | 94%     | $0.046    | Closed                                   |
| gpt-5.4-mini                         | OpenAI       | 93%     | $0.005    | Closed                                   |
| claude-sonnet-4-6                    | Anthropic    | 91%     | $0.025    | Closed                                   |
| mistral-medium-3-5                   | OpenRouter   | 90%     | $0.0035   | Closed-ish                               |
| ~google/gemini-flash-latest          | OpenRouter   | 89%     | $0.0005   | Closed (alias dinamico, tilde required)  |
| mistral-small-2603                   | OpenRouter   | 86%     | $0.00015  | Apache 2.0 (più recente di 3.2 ma peggio)|
| claude-haiku-4-5                     | Anthropic    | 80%     | $0.008    | Closed                                   |
| deepseek-v4-flash                    | OpenRouter   | 80%     | $0.0003   | DeepSeek License                         |
| qwen3-max                            | OpenRouter   | 76%     | $0.0105   | Apache 2.0                               |
| deepseek-chat-v3.1                   | OpenRouter   | 71%     | $0.0009   | DeepSeek License                         |
| llama-4-maverick (MoE)               | OpenRouter   | 61%     | $0.001    | Llama 4 Community                        |
| deepseek-v3.2-speciale               | OpenRouter   | 60%     | $0.004    | DeepSeek License (32% invalid)           |
| qwen3.6-flash                        | OpenRouter   | 58%     | $0.001    | Apache 2.0                               |
| llama-3.3-70b-instruct               | OpenRouter   | 58%     | $0.0006   | Llama 3 Community                        |
| hermes-3-llama-3.1-405b              | OpenRouter   | 49%     | $0.015    | Apache 2.0 fine-tune (405B)              |
| deepseek-v4-pro                      | OpenRouter   | 48%     | $0.004    | DeepSeek License (46% invalid)           |
| qwen3.6-max-preview                  | OpenRouter   | 42%*    | $0.0156   | Apache 2.0 (parziale 30/50)              |
| gpt-5.4-nano                         | OpenAI       | 24%     | $0.0014   | Closed                                   |

## Pattern strutturali emersi

1. **Mid-size mature (24-30B) > flagship latest (70-405B)**. Mistral
   Small 3.2 24B batte Llama 3.3 70B, Llama 4 Maverick, Qwen 3 max,
   Hermes 405B, DeepSeek V3.2/V4. Per task di JSON-structured output
   con tassonomia controllata, il bottleneck NON è capability scalata
   ma strict instruction following + schema conformance.

2. **Latest peggio del predecessore stabile**: gemini-flash-latest (89%)
   < gemini-2.5-flash (97%); mistral-small-2603 (86%) <
   mistral-small-3.2 (96%); qwen3.6-flash (58%) <<
   qwen3-30b-a3b-instruct-2507 (95%). I modelli più recenti sono
   ottimizzati su capability che il nostro task non richiede.

3. **Big open-weights (70B+) hanno alto invalid rate** (14-46%) per
   schema conformance. *CAVEAT*: OpenRouter potrebbe servirli in
   quantizzazione aggressiva (Q3-Q4) vendor-side, degradando la
   qualità. In FP16 self-hosted potrebbero recuperare 5-15pp — non
   verificato.

4. **REPLICA mistral-small-3.2 → 96% (idem run originale)**.
   Anti-variance check OK, valore stabile.

## Decisione finale per P4

**Modello scelto**: `mistralai/mistral-small-3.2-24b-instruct`
(Apache 2.0).

**Hardware**: self-hosted in **FP16 nativo su DGX H100** (1 sola H100
basta, ~48 GB VRAM, sotto gli 80 GB disponibili).

**Costo P4**: $0 (solo elettricità).

**Tempo P4**: stima ~30 min – qualche ora su 4× H100 con vLLM
continuous batching (poi raffinato sperimentalmente, vedi NEWS.md
0.0.0.9009+).

**Quality attesa**: 96-97% accuracy (no degrado da quantizzazione
vendor-side).

## Hardware self-hosting confermato (2026-05-06)

- **RTX 4090 (24 GB VRAM)**: gestibile per Mistral Small 3.2 in Q8 (al
  limite) o Q4. Stima P4: 3-6h. Costo $0.
- **DGX H100 (8× H100 80GB)**: gestibile in FP16/FP8 nativo. Sblocca
  rivalidazione modelli big in FP16 puro. Stima P4 mistral-small-3.2
  in FP16: ~30 min. Costo $0.

Decisione: P4 default su DGX FP16 (max qualità, tempo trascurabile). La
rivalidazione dei big in FP16 NON è entrata nello scope (decisione
utente 2026-05-06).

## Riusabilità del codice

`R/llm-client-openrouter.R` è compatibile con vLLM locale: vLLM espone
un endpoint OpenAI-compatible. Per puntarlo al server locale, basta
passare `model = "..."` con il path locale e riconfigurare
`.OPENROUTER_CHAT_URL` a `http://<dgx>:8000/v1/chat/completions` (o
creare un adapter `R/llm-client-vllm.R` mirror con URL parametrico).

## Riferimenti

- `analysis/run_openrouter_p35c.R` — script multi-modello sequenziale
- `analysis/run_openrouter_single.R` — script parallel single-model
- `analysis/openrouter_*.rds` — artefatti P3.5-D (non committati,
  ricostruibili da OpenRouter cache)
- `R/llm-client-openrouter.R` — adapter base per vLLM local
- `inst/extdata/p35c-minigold-reviewed-v5.csv` — mini-gold riconvertito,
  100 sample reviewati per validare smoke test FP16
- `analysis/eval/p35a-benchmark.html` (980 KB) — report Quarto P3.5-A
  scaled benchmark
- `analysis/eval/p35-benchmark.html` (838 KB) — report Quarto P3.5-B
  prototipo
- `docs/decisions/0006-stato-arte-vs-simulomicsr.md` — ADR positioning
  competitor 2024-2026
