# Spec di design — Anchor derivato-dal-contrasto per lo Stadio 3 (coerenza = gate)

**Data:** 2026-07-24 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟡 **DESIGN da decidere con l'utente** (bivio scientifico). Validato sulla coerenza su
campione (`docs/findings/2026-07-24-anchor-contrast-coherence-simulation.md`). **Nessun re-cluster
lanciato.** Regola [[feedback_explain_then_decide]]: opzioni + tradeoff + preferenza, poi FERMARSI.

---

## 1. Problema (una riga) e criterio di accettazione

L'anchor Stadio 3 è **comparison-blind**: ancora sulla perturbazione del **campione trattato**, non su
ciò che il **contrasto** isola (delta trattato↔controllo). Risultato: 85% dei cluster del deliverable
sono minestroni (contrasti diversi sotto un anchor). **Criterio di accettazione = COERENZA** (ogni
cluster = meta-analisi difendibile = stesso contrasto), MAI copertura-nomi / conteggio-cluster / I²-pooled.
La consistenza (k, I²/PI, ADR-0021) è la **forza** da riportare accanto, non la barriera.

## 2. Il principio di design (da cui derivano le opzioni)

Una meta-analisi è **trattato-vs-controllo**. Due studi sono lo stesso contrasto **sse e solo se**
(a) la stessa **entità/perturbazione** è ciò che cambia (delta), **e** (b) contro lo stesso **tipo di
controllo**. Quindi l'anchor deve codificare il **contrasto completo**, derivato dal confronto Stadio 2:

> **anchor_entity = canonicalize( perturbazioni(trattato) ∖ perturbazioni(controllo) )**  (il DELTA)
> **+ control_type** (per i casi disease/none dove il delta è "case vs healthy")

Questo **riusa TUTTA la macchina dei nomi** (resolver HGNC/ChEBI/MeSH/ChEMBL, matura dopo v5-v10): le
dà solo l'entità **giusta** (il delta), non la perturbazione del campione. Corollario: le perturbazioni
**held-constant** (SARS in "SARS+farmaco vs SARS") non ancorano più → i frammenti vanno al loro contrasto
vero.

## 3. Le opzioni (mechanics + NUMERI misurati + tradeoff)

I numeri vengono dalla simulazione su dati reali (nessun re-cluster). Baseline oggi: **26/184 difendibili
(14%)**.

### Opzione A — Contrast-anchor "solo controllo" (`treated_anchor + control_type`)
- **Mechanics:** estende ai group la codifica pair `treated__VS__control`. L'entità resta quella attuale.
- **Misura:** **INSUFFICIENTE. Coerenza 11% (3/28 LLM).** Il controllo normalizzato collassa in
  `vehicle_untreated` e il trattato resta eterogeneo (farmaci diversi vs DMSO, malattie diverse vs healthy).
- **Verdetto:** ❌ scartare come fix primario. Utile solo come componente (il control_type serve, ma non basta).

### Opzione B — Anchor derivato-dal-contrasto (delta-entity canonica + control_type) **[RACCOMANDATA]**
- **Mechanics (a monte, nel build Stadio 3):** per ogni membro, calcola il delta dei `factor_levels`
  Stadio 2 (chiavi che cambiano trattato↔controllo), estrai l'entità del delta, **canonicalizzala col
  resolver esistente**; l'anchor entity diventa quella (non la perturbazione del campione). Aggiungi il
  `control_type`. Scarta i delta `<none>`/solo-nuisance e i degeneri.
- **Misura (proxy DC, entità grezza-da-label = LOWER BOUND):** **coerenza 80% (89% escl. `<none>`)**;
  i minestroni noti si sciolgono (SARS→"SARS-CoV-2 vs mock"; enzalutamide/fulvestrant/osimertinib/R1881/
  vemurafenib/HCC puliti). **~95-107 meta-analisi difendibili** k≥3 (lower bound within-cluster) **vs 26**.
- **Con entità CANONICA (il build vero, non il proxy):** i sinonimi non frammentano e i **merge
  cross-cluster** si materializzano → k più alto e più cluster difendibili del lower bound. I 26 coerenti
  restano interi (il proxy grezzo ne spezza 18/26 = artefatto label, §3.5 finding).
- **Costo:** richiede build comparison-aware dell'anchor + re-cluster (~8h) + re-pool (~50h). Tocca il
  cuore dello Stadio 3.
- **Tradeoff:** ✅ fix alla radice, coerenza alta, riusa i nomi. ❌ k più basso (mediana 8→3-4), malattie
  low-k, lavoro non banale.

### Opzione C — Filtro di contrasto a valle (stesso split, ma al pooling, NO re-cluster)
- **Mechanics:** tieni gli anchor attuali; al momento del pool, **spezza** ogni cluster per firma di
  contrasto (delta+control) e pool solo i sotto-cluster k≥3 coerenti; scarta il resto.
- **Misura:** **è esattamente la simulazione within-cluster** = il **lower bound** dell'Opzione B:
  **~126 poolabili k≥3 (107 classificati), coerenza ~80-89%**. NON cattura i merge cross-cluster.
- **Costo:** solo re-pool (~50h) o persino solo re-selezione; nessun re-cluster.
- **Tradeoff:** ✅ molto più economico, stessa coerenza. ❌ k strettamente ≤ Opzione B (niente merge);
  è un **cerotto**: non corregge l'anchor, la frammentazione resta nel prodotto, e i frammenti k<3 (validi
  ma piccoli) restano non-poolati invece di fondersi.
- **Nota "a monte vs travestito":** la partizione è la stessa di B; la differenza reale è (i) B **fonde**
  i frammenti cross-cluster (k più alto), (ii) B **corregge** l'anchor (i nomi/etichette a valle tornano
  giusti), (iii) C lascia il difetto nel dato e filtra alla fine. C **non è equivalente** a B: è il suo
  lower bound.

### Opzione D — "Accetta la quantità" (nessun fix, riporta la consistenza)
- Scartata dal mandato: i minestroni non sono difendibili per quanta consistenza abbiano.

## 4. Sotto-problema: le MALATTIE (meccanismo 2)

Anche con l'anchor derivato-dal-contrasto, `disease_vs_normal` resta il caso duro: il delta è "case vs
healthy" ovunque, la coerenza richiede l'**entità-malattia specifica** → ogni malattia ha **pochi studi**
(DC: 13 poolabili disease, k_med 3, k_max 6). Opzioni:
- **(D1)** accettare meta-analisi disease **coerenti ma low-k** (forza debole, riportata onestamente); oppure
- **(D2)** raggruppamenti disease-family (es. "autoimmuni") = **minestrone per la nostra definizione** → no.
Raccomandazione: **D1**. Serve la decisione dell'utente sulla soglia k minima per le disease.

## 5. Raccomandazione

**Opzione B** (anchor derivato-dal-contrasto con entità canonica + control_type + drop dei delta
degeneri), perché è l'unico fix **alla radice** che i dati mostrano efficace (80-89% vs 11% del solo
controllo), riusa la macchina dei nomi, e recupera k via merge cross-cluster che C non può. **Opzione C
come ripiego** se l'utente non vuole il re-cluster: dà già ~126 difendibili vs 26, a costo molto minore,
ma è un cerotto e lascia k sul tavolo.

## 6. DECISIONI (prese dall'utente 2026-07-24)

1. **Direzione: OPZIONE B** — re-anchor a monte (anchor derivato-dal-contrasto, entità-delta canonica +
   control_type). ✅ deciso.
2. **Trade-off k↔coerenza: SÌ** — ~100 meta-analisi difendibili (molte k=3-4) > 184 minestroni; la
   consistenza si riporta come forza, non è gate. ✅ deciso.
3. **Soglia k minima: k≥3** (globale, incluse le disease low-k; le disease sotto k=3 restano non-poolate,
   coerenti-ma-troppo-piccole). ✅ deciso.
4. **Delta `<none>`/degeneri: SCARTARE** (provvisorio, da confermare — vedi nota sotto). Regola minima:
   (a) scarta i **degeneri** `treated_label == control_label` (errori Stadio 2, non contrasti); (b) richiedi
   che il **delta contenga una perturbazione reale** (drug/infection/genetic/disease), NON solo dimensioni
   nuisance (donor/linea-cellulare/età/sesso). **NOTA (intuizione utente "k<3 si scarta da solo"):** vera
   solo in parte — la simulazione mostra **12 sotto-cluster nuisance-only che RAGGIUNGONO k≥3** (più studi
   che fanno un non-contrasto si accumulano), quindi la soglia k≥3 NON li elimina tutti da sola. La regola
   di drop costa ~zero e toglie ~12 gruppi-spazzatura k≥3. Da validare sul campione.
5. **Combo (estradiolo+fulvestrant, ecc.): ENTITÀ A SÉ** — l'entità-delta della combo è la combo intera
   (come già fa il resolver combo con ID-combo `+`); non si spezza né si scarta. Se poi la combo ha k<3 si
   scarta da sola per la soglia. ✅ deciso.

## 7. Gate di validazione PRIMA di qualunque re-cluster (regola hard 3)

Una volta scelto il design, PRIMA del re-cluster (~8h):
1. implementare l'anchor derivato-dal-contrasto con **entità canonica** (resolver) su un **campione** di
   studi; misurare la coerenza col tool (`R/stage3-coherence.R` + deep-dive LLM) e confrontare col lower
   bound di questa simulazione (deve **migliorare** k a parità di coerenza, grazie alla canonica);
2. verificare che i **26 coerenti attuali restano interi** (regola hard 5: il controllo di prima classe);
3. solo con il GO dell'utente → re-cluster + re-pool.

## 8. Cosa NON fa questa spec
- Non lancia re-cluster/re-pool. Non tocca master. Non dichiara nulla "finale/paper-grade".
- Non ricostruisce la vetrina Layer B (secondaria, viene dopo il clustering irreprensibile).
- Non risolve i nomi ancora sbagliati (ethanol→TNF ecc.): ortogonali, dopo la coerenza.
