<!-- Rapporto di un agente di ricerca («Censimento modelli open-weights»), 2026-11-15. Testo dell'agente come consegnato: i numeri e le fonti vanno riletti alla fonte prima di citarli. -->

# Modelli a pesi aperti per il secondo lettore: rapporto della ricerca (2026-11-15)

Non ho scritto file nel repository. Gli appunti stanno in `/tmp/claude-1000/-home-user-simulomicsr/984b0ca3-e456-4689-b566-767a1f0f30af/scratchpad/hf/` (schede HF in `cards/`, letteratura in `lit_report.txt`).

## Come leggere le marche

- **[V]** = verificato. Ho aperto oggi la pagina (API o scheda di Hugging Face, API di GitHub per vLLM) e ho letto il fatto.
- **[VA]** = verificato dall'agente di letteratura. Lui ha aperto la fonte. Io ho letto il suo rapporto, non la fonte.
- **[NV]** = non verificato. È una mia deduzione o viene da un riassunto.
- Il numero di H100 con contesto a 64K è sempre una mia stima (pesi + cache KV + margine): **[NV]**, salvo dove la scheda lo dichiara.
- La VRAM in BF16 è il conto «parametri dell'API × 2 byte»: il numero dei parametri è [V].

## In breve

1. **Nessun candidato soddisfa tutti i vincoli insieme.** I vincoli sono: famiglia diversa da Mistral, uscita vincolata, `temperature=0`, niente thinking, ripetibilità al carattere. Ogni candidato ne manca almeno uno, oppure non ha evidenza indipendente.
2. **I primi tre da provare sono `ibm-granite/granite-4.2-30b`, `openai/gpt-oss-120b` e `meta-models/Muse-Glimmer-30B`.** Granite parte sul contenitore di oggi e ha il thinking disattivabile. gpt-oss-120b ha la migliore evidenza nel dominio, ma il ragionamento non si disattiva. Muse-Glimmer è densa e Apache, ma la scheda non nomina vLLM.
3. **La ripetibilità al carattere è il vincolo più difficile.** vLLM non ammette `VLLM_BATCH_INVARIANT=1` per gli strati GDN (Qwen 3.5, 3.6, 3.8) e per Mamba-2 (Nemotron, Jamba): le PR sono ancora aperte [V]. Gemma 4 non sta nell'elenco dei modelli provati [V].
4. **La letteratura dice che cambiare famiglia riduce poco la correlazione degli errori**: 0,52 nella stessa famiglia, 0,47 fra famiglie (Liu 2026) [VA]. Il guadagno di indipendenza di un secondo lettore va misurato, non assunto.
5. **Nessun benchmark pubblico misura il compito del progetto** (fattori, livello di base, schema chiuso su tabelle lunghe) [VA]. Vale solo la misura sui 47 studi.

## Stato di vLLM che tocca tutti i candidati

- Ultimo rilascio stabile: **v0.32.0** (2026-10-18). C'è la v0.33.0rc3 (2026-11-02). Il contenitore del progetto è v0.20.2 [V].
- **Batch invariance e GDN:** PR #49827 chiusa senza merge, PR #45819 e #60033 aperte. L'errore su main è `VLLM batch_invariant mode is not supported for GDN_ATTN` [V]. È la stessa causa del mancato avvio di Qwen3.5-122B.
- **Batch invariance, modelli provati (documentazione, main)** [V]: Qwen3 densi fino a 8B, `Qwen/Qwen3-30B-A3B`, gpt-oss-20b e 120b, Granite 3.1, **EXAONE 4.0 (compreso `EXAONE-4.0.1-32B`)**, Llama 3.1 e 3.2, phi-4, DeepSeek V3. Non ci sono Gemma 4, Granite 4.x, EXAONE 4.5, Muse, Nemotron, Kolibri, Ripple.
- **gpt-oss:** la PR #59972 (aperta) dice che gpt-oss non parte più in modo batch-invariant («attention sinks not supported») [V].
- **Uscite strutturate:** issue #42110 aperta (Gemma 4: prompt con requisiti JSON più `json_schema` dà timeout); #53181 aperta (xgrammar «Failed to advance FSM», Qwen3.8-27B NVFP4); #49460 aperta (pool di compilazione delle grammatiche); PR #66147 aperta (col parser `granite` la grammatica non si applica); issue #60664 chiusa (gpt-oss: il vincolo partiva dal token 0 e cancellava il ragionamento, v0.30.0) [V].
- **Schema da 220.000 caratteri:** non ho trovato nessuna issue e nessun limite documentato. Resta **[NV]**. JSONSchemaBench misura una copertura bassa sugli schemi difficili (Guidance 0,41, XGrammar 0,28, Outlines 0,03) [VA].
- **Temperatura:** molte schede prescrivono `temperature` 1,0 (Granite 4.2, Muse-Glimmer, Kolibri, MiniMax, DeepSeek V4.1) o 1,1 (Seed-OSS) [V]. L'effetto di `temperature=0` su questi modelli non è documentato.

## Tabella dei candidati, in ordine di priorità di prova

| # | (1) id HF | (2) produttore, data | (3) parametri, VRAM BF16, H100 a 64K | (4) contesto | (5) licenza | (6) vLLM | (7) evidenza indipendente | (8) motivi contro |
|---|---|---|---|---|---|---|---|---|
| 1 | `ibm-granite/granite-4.2-30b` [V] | IBM, Granite 4.2, creato 2026-08-07 [V] | 29,28 mld, densa; 58,6 GB; 1 H100 stretta, 2 consigliate | 128K, estensione 512K [V] | Apache-2.0 [V] | «requires vLLM v0.20+»: parte sul contenitore di oggi [V]. `enable_thinking=False` [V]. Solo Granite 3.1 è nell'elenco batch-invariant [V]. PR #66147 aperta sul parser `granite` (testo riferito a Granite 3.2); effetto sul parser di 4.2 [NV] | Nessuna per 4.2. Vectara: Granite-4.0-h-small 5,2% di allucinazioni [VA] | La scheda prescrive `temperature=1.0` per ogni compito [V]. Modello di ragionamento per disegno. Nessuna evidenza indipendente |
| 2 | `openai/gpt-oss-120b` [V] | OpenAI, 2025-08-04; nessun successore nell'org [V] | 116,8 mld, MoE, 5,1 mld attivi, pesi MXFP4 (non BF16); «fit into a single 80GB GPU» [V]; 1-2 H100 | 131K [NV] | Apache-2.0 [V] | Da `0.10.1+gptoss` [V]. Formato Harmony: serve una versione dopo la PR #45560 (merged 2026-08-01) e la issue #60664 [V]. Batch invariance incerta (PR #59972) [V] | Shintani et al.: F1 0,99, migliore aperto su 150 progetti RNA-seq, temperatura 0 [VA]. MMTU 0,543; TeleTables 90,90 [VA]. Vectara 14,2% [VA] | Il ragionamento non si disattiva (low, medium, high) [V]. Vectara alto. gpt-oss-20b è ultimo in SOB [VA] |
| 3 | `meta-models/Muse-Glimmer-30B` [V] | Meta, Muse, 2026-08-09 [V] | 29,78 mld, densa con encoder visivo; 59,6 GB; 1-2 H100 | «131,072+» [V] | Apache-2.0 [V] | La scheda non nomina vLLM [V]. Le PR #64822, #64568, #64270 citano un «Muse parser» [V]. Versione minima [NV] | Nessuna. Solo il produttore: IFBench 77,0 contro 76,0 di Gemma-4-31B [V, fonte di parte] | Forza del ragionamento nel system prompt, nessun modo senza ragionamento nella scheda [V]. `temperature=1.0` consigliata [V] |
| 4 | `ByteDance-Seed/Seed-OSS-36B-Instruct` [V] | ByteDance Seed, 2025-08-20; nessun successore testuale nell'org [V] | 36,15 mld, densa; 72,3 GB; 2 H100 | 512K [V] | Apache-2.0 [V] | «vllm >= 0.10.0», con il `chat_template.jinja` del repository [V]. `thinking_budget` (default −1, illimitato) [V]; budget 0 per disattivare [NV] | TeleTables 90,91, secondo [VA] | Modello del 2025. La scheda consiglia `temperature=1.1` [V]. Disattivazione del thinking non verificata |
| 5 | `LGAI-EXAONE/EXAONE-4.5-33B` [V]; variante `LGAI-EXAONE/EXAONE-4.0.1-32B` [V] | LG AI Research, 2026-04-04 (4.0.1: 2025-07-29) [V] | 34,35 mld, densa (31,7 lingua + 1,29 visione); 68,7 GB; 2 H100. La 4.0.1: 32,0 mld, 64,0 GB | 262.144 (4.0.1: 131.072) [V] | other (`exaone`) [V]; testo della licenza non letto | 4.5: parser `qwen3`, `enable_thinking=False` [V]; la scheda scrive «vllm >= 0.5.8», numero poco credibile [V]. 4.0: vLLM 0.10.0, **4.0.1-32B nell'elenco batch-invariant** [V] | Nessuna trovata | Licenza non libera. Conoscenza fino a dicembre 2024 (4.5) [V]. Nessuna evidenza |
| 6 | `Qwen/Qwen3.8-27B` [V]; variante `Qwen/Qwen3.6-27B` [V] | Alibaba, 2026-08-05 (3.6: 2026-04-21) [V] | 27,78 mld, densa con encoder visivo; 55,6 GB; 1-2 H100. Esistono le `-FP8` [V] | 262.144 [V] | Apache-2.0 [V] | 3.6: «vllm>=0.19.0», `--language-model-only`, parser `qwen3`, `enable_thinking: False` per richiesta [V]. **Strati GDN: niente batch invariance** [V]. Issue #53181, #55313 su xgrammar [V] | SOB: Qwen3.5-35B 0,974 JSON valido e 0,828 valori, secondo [VA]. Vectara: Qwen3.5-27b 12,1% [VA] | Non ripetibile con la flag. Con `max_num_seqs=1` forse sì [NV]. Vectara alto. Campionamento consigliato 0,7 con `presence_penalty` [V] |
| 7 | `ricursiveAI/Ripple-65B-Preview` [V] | Ricursive Intelligence, 2026-11-04 [V] | 64,78 mld, densa, 80 strati; 129,6 GB; 2 H100 strette, 4 consigliate | fino a 1.048.576 [V] | Apache-2.0 [V] | PR #65745 merged il 2026-11-05, dopo la v0.33.0rc3: serve main [V]. Parser `ripple`, `<think>` facoltativo [V]. La scheda non nomina vLLM [V] | Nessuna. Il modello ha 11 giorni | «Preview», post-addestramento leggero e centrato sul codice [V]. Troppo nuovo |
| 8 | `google/gemma-4-12B-it` [V]; variante `google/gemma-4-26B-A4B-it` [V] | Google, 2026-05-23 (26B: 2026-03-11) [V] | 11,96 mld, densa; 23,9 GB; 1 H100. 26B: 25,81 mld, MoE, 3,8 attivi; 51,6 GB; 1 H100 | 256K [V] | Apache-2.0 [V] | `enable_thinking=False` [V]. Issue #42110 aperta [V]. Nessun Gemma 4 nell'elenco batch-invariant [V] | Szczepaniak e Wren: gemma-4-12B-it su vLLM, 804.427 campioni GEO, F1 del trattamento 0,907 [VA]. Vectara: 26b-a4b 5,2%, 31b 7,4% [VA] | Stessa famiglia del 31B già provato: non ripetibilità probabile [NV]. Il 12B è più piccolo del 31B |
| 9 | `Aleph-Alpha/Kolibri-1-BF16` [V]; FP8 in `Aleph-Alpha/Kolibri-1` [V] | Aleph Alpha, 2026-10-02 [V] | 78,1 mld, MoE, 3,46 mld attivi; 156,2 GB; scheda: 4×H100 (FP8: 2×H100) [V] | 1.048.576; consigliato ≤262.144 [V] | Apache-2.0 [V] | «vllm>=0.33.0» (oggi solo rc), PR #60827 merged 2026-10-13; prima serve il plugin `aleph-alpha-inference` [V]. `enable_thinking=False` [V] | Nessuna. La scheda nomina l'estrazione strutturata fra gli usi [V, fonte di parte] | Solo 3,46 mld attivi. Centrato su tedesco e inglese. `temperature=1.0` consigliata [V] |
| 10 | `nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-BF16` [V]; variante `nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-BF16` [V] | NVIDIA, 2026-08-01 (Bolt: 2026-10-09) [V] | 31,6 mld, MoE con Mamba-2; 65,8 GB; 1 H100 (scheda: 256K su una H100) [V]. Bolt: 74,89 mld, 149,8 GB, 4 H100 | fino a 1M (Bolt 256K) [V] | other (OpenMDW-1.1) [V] | Immagine `vllm/vllm-openai:v0.27.1` [V]. `enable_thinking=False` [V]. Batch invariance per Mamba-2 solo in PR aperte (#62017, #56244, #55905, #55895) [V] | Solo per la generazione prima: Nemotron-3-Nano-30B, SOB 0,991 e 0,774, Vectara 9,6% [VA] | Niente batch invariance. 3 mld attivi. Nessuna evidenza per la 3.5 |
| 11 | `zai-org/GLM-4.7-Flash` [V] | Z.ai, 2026-01-19 [V] | 31,22 mld, MoE 30B-A3B; 62,9 GB; 1-2 H100 | non letto nella scheda [NV] | MIT [V] | A gennaio 2026 solo sul ramo main [V]; oggi in un rilascio [NV]. Parser `glm45` [V]. Modo senza thinking non letto [NV] | SOB: «GLM-4.7» primo, 0,972 e 0,830; non so se è la Flash [VA, NV]. Vectara: GLM-4.7 11,7% [VA] | L'evidenza riguarda altri modelli della famiglia. Vectara alto |
| 12 | `zai-org/GLM-5.3-Flash` (pesi FP8) [V] | Z.ai, 2026-08-25 [V] | 321,3 mld, MoE, 18 mld attivi; circa 321 GB in FP8; 8 H100. La BF16 (642,7 GB) non entra [V] | non letto [NV] | MIT [V] | Ricetta `recipes.vllm.ai/zai-org/GLM-5.3-Flash` [V]. `reasoning_effort` low, high, max; nessun modo senza ragionamento [V]. Issue #55541 e #54317 aperte [V] | Pavlidis et al.: GLM 5.2 buono sui fattori sperimentali, senza numeri [VA]. Romanov et al.: GLM-5.1 migliore aperto [VA]. Vectara: GLM-5 10,1% [VA] | Occupa tutte le 8 GPU. Ragionamento non disattivabile. L'evidenza è sul modello pieno, troppo grande |
| 13 | `CohereLabs/command-a-plus-05-2026-bf16` [V]; esistono `-fp8`, `-w4a4` [V] | Cohere, 2026-05-11 [V] | 218,75 mld, MoE, 25 mld attivi; 437,6 GB; 8 H100 (FP8: 4 H100 [NV]) | 128K in ingresso, 64K in uscita [V] | Apache-2.0 [V] | «vllm>=0.21.0» più la libreria `cohere-melody`; parser `cohere_command4` [V]. Thinking disattivabile [NV] | Nessuna trovata | Grande. Libreria esterna. Nessuna evidenza |
| 14 | `deepseek-ai/DeepSeek-V4-Flash-0731` [V]; successore `deepseek-ai/DeepSeek-V4.1-Flash-1017` [V] | DeepSeek, 2026-07-31 (V4.1: 2026-10-17) [V] | 304,2 mld (I8 + FP8), 166,9 GB, 4 H100. V4.1: 510,8 GB, 8 H100 con poco margine | non letto [NV] | MIT [V] | Nessun chat template Jinja, solo script Python in `encoding` [V]. Ricetta con `flashinfer_mxfp4`, esempio su 4×GB300 [V]. Avvio su H100 [NV]. PR batch-invariant aperte (#64441, #64884, #65053) [V] | Misura del progetto: deepseek-v4-flash 80% sul compito più facile. Vectara: DeepSeek-V4.1-Flash 4,2% [VA] | Già provato via API. Avvio su H100 incerto. Nessun template. `temperature` 1,0 nella scheda V4.1 [V] |
| 15 | `BSC-LT/ALIA-40b-instruct-2606` [V] | Barcelona Supercomputing Center, 2026-06-30 [V] | 40,43 mld, densa, 48 strati; 80,9 GB; 2 H100 | 163.840 [V] | Apache-2.0 [V] | La scheda dice che vLLM va bene per la versione non quantizzata [V]. Nessun modo di ragionamento nella scheda [V]. **La scheda consiglia temperatura 0-0,2 e nessuna `repetition_penalty`** [V] | Nessuna. Solo il produttore (rispetto del formato su FoFo, giudice gpt-oss-120b) [V, fonte di parte] | Post-addestramento centrato su spagnolo, catalano, basco, galiziano e inglese [V]. Nessuna evidenza |

Nota sui già provati: `Qwen/Qwen3-30B-A3B` sta nell'elenco batch-invariant di vLLM [V]. Fra i modelli già provati dal progetto, `qwen3-30b-a3b-instruct-2507` (95% sul compito più facile) è quello con il rischio più basso sulla ripetibilità. Non è una novità e non l'ho messo in tabella.

## Scartati, una riga ciascuno

- **Troppo grandi per 640 GB** [V sui parametri]: Qwen3.8-2.4T-A95B, Nemotron-3-Ultra-550B, K-EXAONE-2.0-750B-A37B, Hy4-preview, GLM-5, 5.1, 5.2, 5.3 pieni, DeepSeek-V4-Pro-0813, Kimi K2.5, K2.6, K2.7-Code, K3, K3.1-Pro, Ling-3.1-flash, Inkling-2-Small, Muse-Spark-Open-816B-A42B, `arcee-ai/Trinity-Large-Thinking` (797 GB in BF16), `dots-studio/dots3-note-prev` (577 GB).
- `reflection/Beam-1.0-501B-A23B-FP8`: 503 GB in FP8, margine troppo stretto su 8 H100 [V sui GB].
- `tencent/Hy3-FP8`: 300 GB; la scheda consiglia GPU più grandi delle H100 per 8 GPU [V]. Ha `no_think` di default [V]: resta una riserva.
- `Qwen/Qwen3.8-Flash-Next`: 360 GB in BF16, strati GDN, licenza qwen-community [V].
- `Qwen/Qwen3.6-35B-A3B`: MoE con strati GDN, stesso limite della riga 6 [V].
- Derivati di Qwen: `NousResearch/Arete-27B` (base Qwen3.8-27B [V]), `allenai/tmax-27b` (base Qwen3.6-27B [V]), `apple/SimpleSD-30B-instruct` (base Qwen3-30B-A3B, licenza di ricerca Apple [V]), `InternScience/Sage-A1.5` e `internlm/Intern-S2-Mobius` (35,95 mld; base Qwen3.6-35B-A3B [NV]).
- `stepfun-ai/Step-3.7-Flash`: 402,7 GB in BF16, immagine vLLM dedicata, nessuna evidenza [V].
- `upstage/Solar-Open-100B`: serve un fork di vLLM v0.12.0 [V]. `upstage/Solar-Open2-250B`: chiede 8 GPU da 141 GB [V].
- `MiniMaxAI/MiniMax-M2.7`, `MiniMaxAI/MiniMax-M3.1-Flash`: 230-252 GB, licenza non libera, ragionamento da low a max senza spegnimento, `temperature=1.0` [V].
- `ai21labs/AI21-Jamba2-Mini`: 52 mld, architettura SSM (Mamba), quantizzazione `experts_int8` consigliata [V]; batch invariance [NV]. Non ha ragionamento [V]: resta una riserva.
- `LiquidAI/LFM2.5-24B-A2B`: ragiona sempre prima di rispondere, licenza lfm1.0 [V].
- `openai/gpt-oss-20b`: ultimo in SOB (0,858 e 0,693) [VA].
- `numind/NuExtract3`: 4,5 mld, base Qwen3.5-4B, usa un suo template e non uno schema JSON [V]. Troppo piccolo per prompt da 60 mila token [NV].
- `NousResearch/Hermes-4.3-36B`: derivato di Seed-OSS-36B-Base [V]; preferisco l'originale (riga 4).
- `swiss-ai/Apertus-v1.5-70B`: 72 mld, Apache, 145,6 GB [V]. Pagina con accesso a richiesta: **scheda non letta** (errore 401). Riserva.
- `sarvamai/sarvam-105b`: su vLLM serve un fork o una correzione a mano [V].
- `utter-project/EuroLLM-22B-Instruct-2512`: densa, Apache [V]; contesto non trovato nella scheda.
- `baidu/ERNIE-5.5-Flash-Base`, `XiaomiMiMo/MiMo-V2.6-Flash-RL`, `thinkingmachines/Inkling-Small`: oltre 260 mld; schede non lette.
- `kakaocorp/kanana-2-30b-a3b-instruct-2601`, `naver-hyperclovax/HyperCLOVAX-SEED-Think-32B`, `ServiceNow-AI/SuperApriel-15B-Instruct`, `EssentialAI/rnj-1.5-instruct`, `ornith-ai/Ornith-1.0-35B`, `amazon/LAR-27B`: esistono [V]; schede non lette.
- **Llama:** nessun modello nuovo nell'org `meta-llama` dal 2025-11 [V]. I modelli nuovi di Meta stanno in `meta-models` (Muse).
- **Phi:** nessun Phi nuovo nel 2026 nell'org `microsoft` [V].
- **xAI, 01.AI, Writer, deepcogito:** nessun modello nuovo [V]. **Reka:** solo `reka-edge-2603` [V]. **Falcon (`tiiuae`):** solo modelli piccoli [V].
- **Biomedici:** `google/medgemma-27b-text-it` (2025-05, base Gemma 3, accesso a richiesta, scheda non letta) [V]; `google/txgemma-27b-chat` (2025-03) [V]; nessun MedGemma o TxGemma ufficiale su Gemma 4 trovato. OpenBioLLM e BioMistral: nessun modello nuovo [V]. Il compito è leggere tabelle, non sapere di medicina.
- **Successori Mistral (solo da riportare)** [V]: Mistral-Medium-3.5-128B, Mistral-Large-4-1T-A52B, Leanstral-1.5-119B-A6B, Devstral-2. `speakleash/Bielik-11B-v3.1-Instruct` (polacco): famiglia di base [NV].

## Che cosa non ho potuto verificare

- I server MCP di GitHub e Playwright non si sono connessi. Ho usato l'API pubblica di GitHub.
- Tre schede con accesso a richiesta non lette: Apertus-v1.5-70B, medgemma-27b-text-it, medgemma-1.5-4b-it.
- Nessuna prova di avvio: tutti i fatti su vLLM vengono da schede, PR e issue.
- Il comportamento con uno schema da 220.000 caratteri non è documentato per nessun modello.
- I numeri della letteratura sono marcati [VA]: non ho aperto io quelle pagine.

## Fonti

**Hugging Face (API e schede, lette il 2026-11-15).** Ogni id della tabella si apre come `https://huggingface.co/<id>`. Metadati: `https://huggingface.co/api/models/<id>`. Censimento per organizzazione: `https://huggingface.co/api/models?author=<org>`.

**vLLM (API di GitHub).**
- Rilasci: https://github.com/vllm-project/vllm/releases
- Batch invariance: https://github.com/vllm-project/vllm/blob/main/docs/features/batch_invariance.md
- GDN: https://github.com/vllm-project/vllm/pull/49827 · https://github.com/vllm-project/vllm/pull/45819 · https://github.com/vllm-project/vllm/pull/60033 · https://github.com/vllm-project/vllm/issues/63593
- gpt-oss: https://github.com/vllm-project/vllm/pull/59972 · https://github.com/vllm-project/vllm/pull/65931 · https://github.com/vllm-project/vllm/issues/60664 · https://github.com/vllm-project/vllm/pull/45560
- Granite: https://github.com/vllm-project/vllm/pull/66147 · https://github.com/vllm-project/vllm/pull/65216
- Gemma 4: https://github.com/vllm-project/vllm/issues/42110 · https://github.com/vllm-project/vllm/pull/67351
- Uscite strutturate: https://github.com/vllm-project/vllm/issues/53181 · https://github.com/vllm-project/vllm/issues/55313 · https://github.com/vllm-project/vllm/issues/49460 · https://github.com/vllm-project/vllm/pull/66761
- Nemotron e Mamba-2: https://github.com/vllm-project/vllm/pull/62017 · https://github.com/vllm-project/vllm/pull/56244
- Kolibri: https://github.com/vllm-project/vllm/pull/60827 · Ripple: https://github.com/vllm-project/vllm/pull/65745
- GLM-5.3-Flash: https://github.com/vllm-project/vllm/issues/55541 · https://github.com/vllm-project/vllm/issues/54317
- DeepSeek V4: https://github.com/vllm-project/vllm/pull/64441 · https://github.com/vllm-project/vllm/pull/41834
- Ricette: https://recipes.vllm.ai/Qwen/Qwen3.8-27B · https://recipes.vllm.ai/zai-org/GLM-5.3-Flash · https://recipes.vllm.ai/tencent/Hy3

**Letteratura (aperta dall'agente di letteratura).**
- Pavlidis et al. 2026: https://www.biorxiv.org/content/10.64898/2026.07.30.741874v1.full
- Shintani et al. 2026: https://www.biorxiv.org/content/10.64898/2026.02.16.706241v1
- Szczepaniak e Wren 2026: https://doi.org/10.21203/rs.3.rs-10844781/v1
- Hak et al. 2026: https://doi.org/10.1093/bioinformatics/btag166
- Ikeda et al. 2025: https://doi.org/10.1093/gigascience/giaf070
- Rogic et al. 2026: https://doi.org/10.1093/database/baag041
- SOB: https://arxiv.org/abs/2604.25359
- JSONSchemaBench: https://arxiv.org/abs/2501.10868
- IFStruct (fonte di produttore): https://www.liquid.ai/blog/ifstruct-v1.0
- Classifica Vectara: https://github.com/vectara/hallucination-leaderboard/
- MMTU: https://arxiv.org/html/2506.05587v3
- TeleTables: https://arxiv.org/html/2601.04202
- Kim et al. 2025: https://arxiv.org/abs/2506.07962
- Romanov et al. 2026: https://arxiv.org/abs/2608.19025
- Liu 2026: https://arxiv.org/html/2607.10139
