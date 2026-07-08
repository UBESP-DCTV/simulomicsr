# Spec design — Recupero dei farmaci esclusi (augmentation "passo 3")

**Data:** 2026-07-09
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Handout base:** `docs/superpowers/specs/2026-07-08-stage4-augmentation-farmaci-esclusi-NEXT-SESSION-handout.md`
**Finding-misura:** `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`
**Stato:** decisioni prese in autonomia (sessione notturna), **in attesa di gate utente sulla
direzione** — la misura ha riformato il compito (vedi §0).

---

## 0. Perché questa spec propone un cambio di direzione (leggere prima)

L'handout immaginava il "passo 3" come *estendere il prestito di controlli esterni* (stile
`mega_aug`) al ramo `rem_group`. La misura sui dati veri (finding) ha mostrato tre cose che riformano
il compito:

1. Dei 279 caduti, **195 sono irrecuperabili** (dati troppo sottili) e **38 si recupererebbero
   senza prestare nulla** (controllo interno già presente, non collegato). Il prestito esterno
   riguarda al più **46 cluster**, di cui solo **13 ben ancorati**.
2. La **validazione** (scambio controllo-interno → controllo-prestato su farmaci noti-buoni) mostra
   che prestare un controllo da un altro laboratorio **preserva la direzione dell'effetto** ma
   **distrugge la scoperta di geni** (tamoxifene: recupero 7%, I² 92→98; enzalutamide con più studi:
   recupero **1%**, I² 86→99 — più studi *non* aiutano).
3. Quindi il prestito, su base larga, produrrebbe meta-analisi deboli e sovra-eterogenee — l'opposto
   della "buona scienza" che il progetto promette.

Di conseguenza questa spec **non** progetta un prestito indiscriminato. Progetta un recupero
**a strati di rischio crescente**, raccomanda di fermarsi agli strati sicuri, e lascia all'utente la
scelta di quanto spingersi (§7 Opzioni).

## 1. Le 6 domande di design (decise in autonomia, con alternative scartate)

### D1 — Da dove pescare i controlli / quanto stringente la comparabilità?

**Decisione:** in ordine di preferenza (a) **stessa linea cellulare** (Cellosaurus), (b) stesso
**tessuto + piattaforma di sequenziamento** con ruolo veicolo/baseline/sano. **Mai** solo tessuto.
Motivo: la validazione mostra che perfino il prestito *migliore possibile* (stesso farmaco, stesso
tessuto) perde la gran parte delle scoperte; un abbinamento più largo sarebbe peggio. Il prestito è
ammesso **solo** con l'abbinamento stretto (a) o (b), altrimenti il cluster resta non processato.

*Scartato:* abbinamento solo-tessuto (troppo largo, inietta batch — dimostrato); nessun vincolo
(assurdo).

### D2 — Unità di sintesi (ibrido vs omogeneo)?

**Decisione:** unità = **studio distinto** (k = numero di studi trattati, non coppie
trattato×controllo). Ogni studio trattato contribuisce **un** effect-size: trattato-in-studio vs
controllo (interno se c'è, altrimenti **un solo** pool prestato). Si riusa il collapse dei bracci
intra-studio già adottato in v8 (opzione C) per evitare pseudo-replicazione. Gli studi a controllo
prestato sono **etichettati come "ibridi"** nel tracciamento e conteggiati a parte.

*Scartato:* contare le coppie trattato×controllo come studi (pseudo-replicazione, gonfia k e sgonfia
I²); passare a un modello MEGA congiunto (confonde metodologia tra cluster, viola l'uniformità di
config).

### D3 — Correlazione da controllo condiviso (Franchini)?

**Decisione:** quando **≥2 studi trattati prestano lo stesso pool di controllo**, i loro effect-size
non sono indipendenti (condividono il denominatore) → si applica la **matrice di covarianza di
Franchini** (`rma.mv`, `.build_franchini_V_matrix`) con **rho = 0,5** (conservativo, come in
`mega_aug`) + un **run di sensibilità a rho = 0** riportato. Attivata automaticamente al primo pool
condiviso in un cluster.

*Scartato:* ignorare la correlazione (SE sottostimati → falsa confidenza); rho alto senza base
empirica.

### D4 — Soglie (k minimo, dimensione pool, cap, **ancoraggio**)?

**Decisione:** `k_eff≥3` e `n_min=2` invariati; pool prestato ≥2, cap `max_baseline_per_arm=350`
(riuso `mega_aug`). **Nuovo gate di ancoraggio:** un cluster può usare studi a controllo prestato
**solo se ha già ≥2 contrasti veri interni** (`k_eff_v8 ≥ 2`). Questo esclude i 13 cluster
interamente prestati (indifendibili) e i 20 a singola ancora. Motivo: una meta-analisi con ≥2 ancore
reali resta radicata nella biologia interna; i prestiti la rinforzano ma non la definiscono.

*Scartato:* ammettere cluster interamente prestati (k_eff=0) — la validazione li rende indifendibili;
cap rimosso (memoria/tempo).

### D5 — Batch/covariate adeguate?

**Decisione + limite dichiarato:** le covariate esistenti (`instrument_model`, `aligner_class`)
sono **single-level dentro un singolo studio** → auto-droppate nel DE per-studio → **non modellano**
la differenza-di-laboratorio del contrasto trattato-studio-X-vs-controllo-studio-Y. È un **gap
noto**: il batch del prestito NON è corretto dal design attuale. Questo è un ulteriore argomento a
favore del prestito ristretto (D1/D4) e va **dichiarato nei limiti**. Un raffinamento futuro
(rimozione batch cross-studio tipo ComBat/RUV prima del DE) è fuori scope.

*Scartato:* assumere che le covariate attuali bastino (non bastano per contrasti cross-studio).

### D6 — Gate di validazione before-fullrun?

**Decisione:** il gate È la validazione swap del finding (§4). Esito: **FALLITO** per il prestito
largo (recupero 7% su tamoxifene). Quindi il gate **blocca** l'approccio largo. Un prestito ammesso
solo se, ripetendo lo swap sul cluster candidato ben ancorato, il recupero dei geni veri è alto
(soglia proposta ≥60%) — verifica per-cluster, non globale.

## 2. Lo strato "sicuro" separato: recupero in-studio (classe A, 38 cluster)

Emerso dalla misura, **non** è prestito: sono trattati (≥2) con controllo interno (≥2) **già
presenti** ma non collegati dallo Stadio 2 (disegni che lo Stadio 2 non ha sciolto, gruppi gemelli).
Recuperarli = estendere il dispatch a costruire l'abbinamento interno mancante. Batch nullo (stesso
studio). **Ma** va verificato per-cluster che l'abbinamento sia biologicamente corretto (lo Stadio 2
li ha saltati per una ragione): non appaiare "malato-trattato" a "sano-veicolo", ecc. Serve una
regola di scelta del controllo che rispetti i fattori di disegno, non "il primo controllo che trovo".

## 3. Architettura proposta (se si procede)

Additiva, come `rem_group` fu additivo a v7. Nessuna modifica ai 4 rami esistenti.

- **Classe A (in-studio):** in `.build_group_rem_dispatch_from_stage3`, quando
  `.lookup_cmp_by_treated_group` fallisce ma lo studio ha un controllo interno ≥2 **compatibile per
  fattori di disegno**, costruire l'entry `{study_id, treated, control-interno}`. Gate biologico sui
  fattori.
- **Classe B (prestito, ancorato):** nuovo `.build_borrowed_control_dispatch` che, per uno studio
  trattato senza controllo interno in un cluster con `k_eff_v8≥2`, pesca il pool prestato meglio
  abbinato (D1) e emette `{study_id, treated, control-prestato, baseline_pool_id}`. A valle, REM con
  Franchini (D3) sui pool condivisi.
- Tracciamento: ogni studio marcato `contrast_kind ∈ {in_study, in_study_recovered, borrowed}`;
  `non_processable` per chi resta sotto k_eff con reason distinta per classe.

## 4. Testing e validazione (se si procede)

TDD bite-sized. Fixture stage2 sintetico per: classe A (controllo interno non collegato → recuperato;
controllo biologicamente incompatibile → NON appaiato), classe B (prestito ancorato → entry; cluster
non ancorato → escluso; pool condiviso → Franchini attiva). Retrocompat byte-identica dei 4 rami.
**Gate empirico per-cluster** (swap recall ≥60%) prima di ammettere ogni prestito nel fullrun.

## 5. Cosa NON fa

- Non presta su base larga (validazione contraria).
- Non ammette cluster interamente prestati (k_eff=0).
- Non corregge il batch cross-studio a monte del DE (gap dichiarato).
- Non tocca i 4 rami esistenti; non richiede re-cluster Stadio 3.

## 6. Rischio scientifico principale

Il prestito inietta differenza-di-laboratorio non modellata; la validazione lo quantifica
(−93% scoperte su tamoxifene). Mitigazione: strati di rischio + gate di ancoraggio + Franchini +
verifica per-cluster + limiti dichiarati.

## 7. Opzioni per l'utente (raccomandazione in grassetto)

> Nota: la seconda validazione (enzalutamide, k≈12) ha bocciato il prestito **più nettamente** della
> prima (recupero geni 1%), e la classe A è risultata **più delicata** del previsto (solo ~3/38 con
> abbinamento non ambiguo). La raccomandazione si è quindi spostata verso la prudenza massima.

- **Opzione 4 (RACCOMANDATA): documentare i 279 come limite noto.** I pool esistenti restano
  corretti; è un errore di *omissione*, non di *commissione*. Il rendimento affidabile del recupero è
  piccolo e ogni via ha rischio biologico reale. È la scelta più difendibile per un paper.
- **Opzione 1 (accettabile, ristretta): solo classe A non ambigua** — recuperare i ~3–pochi cluster
  in-studio con controllo unico e disegno chiaro, uno per uno con verifica manuale. Nessun prestito.
- **Opzione 2 (sconsigliata): + prestito ben ancorato** — i 13 con k_eff_v8≥2, ma con gate empirico
  per-cluster (recupero ≥60%); la validazione suggerisce che quasi nessuno lo passerebbe.
- **Opzione 3: prestito largo (handout originale)** — **da scartare** (validazione nettamente
  contraria).

## 8. Riferimenti

- Finding-misura: `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`
- Tabella 279: `analysis/audit/2026-07-09-stage4-279-recovery-classification.csv`
- Codice: `R/stage4-dispatch.R`, `R/stage4-baseline-pool-pairing.R`,
  `R/stage4-franchini-correction.R`, `R/stage4-orchestrator.R`.
- Correlati: ADR-0022 (ramo rem_group), spec/plan rem_group 2026-07-05.
- Memorie: `feedback_validate_before_fullrun`, `feedback_explain_then_decide`,
  `feedback_no_fretta_paper_grade`, `feedback_pipeline_config_uniformity`.
