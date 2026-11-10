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
