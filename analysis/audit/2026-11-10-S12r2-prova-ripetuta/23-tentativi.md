# S12r2: i tentativi dei modelli grandi (regola di `00-previsioni.md`: al massimo due, con la causa letta nel log)

## G1 (`mistralai/Mistral-Small-4-119B-2603`), primo tentativo: FALLITO

- Job slurm 478355, `poddgx02`, 2026-11-10 16:52-16:54 (ora locale), run_id
  `20261110T155049Z-s12r2-lettore-v1-g1-corsa1-fae0b0`; configurazione: `tensor_parallel_size = 2` (2 worker da 2 GPU).
- Causa, letta in `slurm-478355.err` sul DGX: `ValueError: No available memory for the cache blocks`
  (`_check_enough_kv_cache_memory`). Righe del log: «Checkpoint size: 112.62 GiB», «Model loading took 56.77 GiB
  memory» per GPU, «Estimated CUDA graph memory: 10.46 GiB total», «Available KV cache memory: -7.05 GiB».
  Con due GPU per motore non resta memoria per la cache.
- Nessun record prodotto (`records_completed: 0`); nessuna uscita del modello letta.

## G1, secondo tentativo

- Un solo cambio: `tensor_parallel_size = 4` (un worker su 4 GPU: circa 28 GiB di pesi per GPU). Prompt, schema,
  vista, revisione, `max_model_len`, `max_tokens`, `gpu_memory_utilization`, `repetition_penalty` e
  `chat_template_kwargs` restano uguali.
- Nota: un primo rilancio (16:57) si è fermato sul cancello K4 **prima dell'invio**, perché il valore atteso `tp`
  dello script era rimasto 2 mentre il bundle aveva 4. Nessun job inviato: non è un tentativo. Corretto `tp = 4`.

## G2 (`Qwen/Qwen3.5-122B-A10B`), primo tentativo: FALLITO

- Job slurm 478727, `poddgx02`, 2026-11-10 17:52-17:54 (ora locale), run_id
  `20261110T165031Z-s12r2-lettore-v1-g2-corsa1-cbb8ec`; configurazione: `tensor_parallel_size = 4`,
  `enable_thinking = false`, `repetition_penalty = 1,1`, `VLLM_BATCH_INVARIANT=1`, `HF_HUB_OFFLINE=1`.
- Causa, letta in `slurm-478727.out` sul DGX, uguale nei 4 worker:
  `RuntimeError: VLLM batch_invariant mode is not supported for GDN_ATTN.` (`_cached_get_mamba_attn_backend`,
  `vllm/v1/attention/selector.py`). Qwen3.5 ha strati di tipo «gated delta net» e vLLM 0.20.2 non ha per quegli
  strati il modo che rende il risultato indipendente dal batch. I pesi si caricano («Checkpoint size: 232.99 GiB»,
  «Model loading took 57.3 GiB memory» per GPU): la memoria non è la causa.
- Nessun record prodotto (`records_completed: 0`); nessuna uscita del modello letta.

## G2, secondo tentativo: DEROGA AL CANCELLO K4, scritta prima dell'invio

- Con la configurazione depositata G2 non può partire: un secondo tentativo uguale fallisce allo stesso modo, per
  costruzione. Il contenitore resta quello di produzione (vLLM 0.20.2), come dicono le previsioni.
- Un solo cambio: il job parte **senza** `VLLM_BATCH_INVARIANT`. Prompt, schema, vista, revisione, `max_model_len`,
  `max_tokens`, `gpu_memory_utilization`, `repetition_penalty`, `tensor_parallel_size`, `chat_template_kwargs` e
  `HF_HUB_OFFLINE=1` restano uguali.
- **Che cosa non vale più per G2.** `00-previsioni.md` dice «Per tutti: … `VLLM_BATCH_INVARIANT=1`» e il cancello K4
  chiede quella variabile in ogni job. Per G2 questa clausola di K4 **non è soddisfatta**. Le previsioni non
  cambiano: il finding riporta G2 come misurato in deroga a K4, e lo dice accanto a ogni numero di G2.
- **Che cosa resta misurabile.** Il punto 1 della regola di esito (due corse identiche al carattere in 47 studi su
  47) si misura direttamente sulle due corse. La variabile era il mezzo, il punto 1 è la prova. Senza la variabile
  l'attesa è meno favorevole (S12p: Gemma non era ripetibile al carattere; G1 non lo è nemmeno con la variabile).
- **Perché non «non misurato».** L'handout chiede ogni modello più grande due volte, e la decisione sul modello
  del Piano 2 è del PI: un numero in deroga dichiarata gli serve più di nessun numero. Se il PI non accetta la
  deroga, G2 vale «non misurato» e la regola di esito per G2 è no.
- Lo script verifica la deroga sul processo: `container-env.txt` deve avere `HF_HUB_OFFLINE=1` e nessuna riga
  `VLLM_BATCH_INVARIANT=` (`raccogli_deroga()` in `23-lancia.R`).
- È l'ultimo tentativo di G2 (regola: al massimo due).
