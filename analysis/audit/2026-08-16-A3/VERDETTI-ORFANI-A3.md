# I due verdetti tolti per la ricomposizione di A3, e la prova

**Data:** 2026-08-19 · **Pool A3:** 194 gruppi (dai 16 pezzi)

La ricomposizione si è fermata sulla guardia dei verdetti orfani — come deve:

```
VERDETTI ORFANI (2): CHEBI:59132||gain||vehicle_untreated; STR:adenoma||gain||vehicle_untreated
Il loro gruppo non e' nel poolato: senza aggiornarli un gruppo INCOERENTE
verrebbe marcato `coherent`.
```

Entrambi erano fra gli undici gruppi dichiarati **incoerenti**. Nel run A3 non
sono più poolabili:

| entità | k nel riferimento | k in A3 | poolabile (k≥3) |
|---|---:|---:|---|
| `CHEBI:59132` (antigen, classe ombrello) | 3 | **1** | no |
| `STR:adenoma` | 4 | **1** | no |

**Perché toglierli è sicuro.** La verifica che conta non è che il gruppo con
*quella chiave* sia sparito, ma che l'entità non ricompaia nel poolato **con
un'altra chiave**: è esattamente il difetto pagato il 2026-08-01, quando
`adenoma` era presente nel poolato sotto chiave diversa e, tolto il verdetto,
usciva marcato `coherent`. Misurato sui 194 gruppi poolati di A3:

- `CHEBI:59132` → **0 gruppi**
- `STR:adenoma` → **0 gruppi**
- ricerca per parola su `contrast_entity` (`antigen`, `adenoma`) → **0 gruppi**

Nessun gruppo da marcare, quindi nessun gruppo che possa passare per coerente.
Stessa situazione dei tredici verdetti tolti il 2026-08-05
(`analysis/audit/2026-08-02-fix/81-verdetti-tolti-e-perche.md`), e stessa
procedura.

**La guardia nel codice non è stata toccata** e resta fatale. Il file usato per
la ricomposizione è `analysis/audit/2026-08-16-A3/verdetti-A3.csv`, che è quello
di v13 meno queste due righe.

**Limite della verifica:** `clusters.rds` non porta la colonna
`contrast_entity_label`, quindi la ricerca per parola ha potuto guardare solo
l'identificativo del contrasto, non l'etichetta leggibile.
