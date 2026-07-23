# HANDOUT — REWORK DELL'ANCORAGGIO Stadio 3 per la COERENZA DI CONTRASTO (opzione 2)

**Data prep:** 2026-07-24
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Stato:** 🔴🔴 il problema CORE del RED ALERT è ancora aperto. Decisione utente presa: **opzione 2 —
rifare l'ancoraggio a monte.** Questa è la sessione che lo affronta.

---

## 0. LEGGI QUESTO PRIMA DI QUALSIASI COSA — il fallimento, senza sconti

L'obiettivo dello studio è UNO: **raggruppare campioni di studi diversi che misurano lo STESSO
contrasto** (stesso trattamento vs stesso tipo di controllo), così che la meta-analisi cross-studio
**guadagni segnale vero**. Questa è la promessa unica di `simulomicsr`.

Per **mesi** (v5 → v10) l'audit ha ottimizzato una cosa DIVERSA: i **NOMI** dei cluster (recupero
deterministico MeSH/ChEBI/ChEMBL, de-frammentazione, LLM-fallback). Ha dichiarato "vittoria",
"END-TO-END COMPLETO", "DELIVERABLE FINALE", "18 case study publication-grade" — **senza mai
verificare se gli studi raggruppati misurano lo stesso contrasto.** La coerenza di contrasto è stata
**mancata almeno tre volte** (F6, i vari re-gate di omogeneità, la vetrina Layer B), perché si è
scambiato un PROXY (nome corretto; I² del pooled basso) per l'obiettivo.

Quando è stata finalmente misurata (2026-07-23, `docs/findings/2026-07-23-stage3-cluster-coherence.md`):

- **157/184 (85%)** dei raggruppamenti del deliverable (rem_group v10) sono **MINESTRONI**.
- Solo **19/184 (10%)** reggono come meta-analisi difendibili (e 11/19 hanno k<5 → consistenza debole).
- **Vetrina Layer B: 0/9** dei flagship sopravvive.

**Lezione non negoziabile: "nome recuperato" ≠ "cluster omogeneo" ≠ "stesso contrasto".** L'I² basso
del pooled NON è coerenza (breast era I²≈1,6 = "consistentissimo" ma minestrone). Aumentare il NUMERO
di cluster nominati (161→184) non è progresso se sono incoerenti.

---

## 0.5 DEFINIZIONE DI COERENZA — il criterio di accettazione (def. utente 2026-07-24)

**Un cluster è COERENTE se è in grado di generare una meta-analisi SCIENTIFICAMENTE DIFENDIBILE**
(REM per-studio, mega_aug, mega, …): cioè raggruppa studi/campioni che misurano lo **STESSO
contrasto** (stesso tipo di trattamento vs stesso tipo di controllo), così che poolarli stimi UNA
quantità biologica reale e non la media di quantità diverse.

- **La BARRIERA è binaria**: *difendibile* (stesso contrasto) vs *minestrone* (contrasti diversi). Un
  minestrone NON è difendibile per quanta consistenza abbia (breast: I²≈1,6 = "consistentissimo" ma
  minestrone). La consistenza NON è la barriera.
- **La FORZA è un GRADIENTE, da RIPORTARE, non un gate della coerenza**: numerosità k, eterogeneità
  (I²/PI, ADR-0021), potenza. Alcuni cluster saranno più forti di altri **solo per numerosità** — è OK
  e atteso. Un cluster coerente ma eterogeneo (stesso contrasto, I² alto) è **comunque un REM
  difendibile** (il REM *modella* l'eterogeneità), semplicemente più debole — NON invalido.
- **GOAL DEL PAPER = un CLUSTERING IRREPRENSIBILE**: OGNI cluster deve raggiungere la barriera
  (difendibile). La **vetrina** (Layer B / case study) viene DOPO ed è **secondaria** — è solo la
  selezione dei casi migliori da mostrare. Il prodotto scientifico primario è la **qualità del
  clustering**, non la vetrina. Per questo serve un clustering irreprensibile: ogni cluster = input
  valido per una meta-analisi.

**Conseguenza operativa (correzione del finding 2026-07-23):** i cluster DIFENDIBILI nel deliverable
v10 sono **26/184** (stesso contrasto, D2=one_contrast, ~92% verificati a mano), NON 19. Il **19** era
il sottoinsieme difendibile **E forte** (consistenza≥0,5): è la FORZA, non la barriera. I **157**
minestroni sono i falliti. **Il gate del rework è la barriera di coerenza su OGNI cluster** (rendere
difendibile ogni cluster), con la forza riportata come gradiente accanto.

---

## 1. La causa radice (PROVATA, non ipotesi)

Vedi il finding §2-4 + le tabelle `analysis/audit/2026-07-23-coherence/deliverable-184-verdicts.csv`
(colonna `dd_reason` = il perché, per-cluster). Due meccanismi:

1. **Il controllo è LIBERO in group-mode (95% dei cluster k≥2).** L'anchor codifica solo il lato
   **TRATTATO** (`kind|agent|...|tissue|...`). Il controllo è quello che ogni studio ha appaiato nella
   sua comparison Stadio 2 → studi diversi portano controlli diversi (mock / DMSO / timepoint-0 / dieta
   / ipossia / scramble genetico / persino il trattato stesso). Stesso anchor, contrasti diversi.
   Esempio: SARS `b6a3eabd` mescola infezione-vs-mock + farmaco-vs-DMSO + KO-vs-WT sotto "SARS-CoV-2".
2. **L'anchor entità è troppo grezzo/sbagliato per disease_vs_normal e "none" (i kind più numerosi).**
   Un nome-malattia UNK o generico + un "Healthy Control" generico fa collassare **malattie diverse**
   (SLE + Crohn + SLA + glioblastoma) in un cluster. Il lato trattato è eterogeneo.
3. Corollario: i cluster **pair-mode** (5%, `treated__VS__control` esplicito) sono più coerenti — perché
   l'anchor lì porta ENTRAMBI i lati. Questo è l'indizio della direzione giusta.

**Conclusione:** un anchor che non porta il **contrasto completo** (trattato E tipo-di-controllo) non
può garantire cluster coerenti. Il fix è nell'ancoraggio/clustering, non in un filtro a valle.

---

## 2. Obiettivo di questa sessione

Ridisegnare come lo Stadio 3 forma i cluster in modo che **per costruzione** un cluster raggruppi solo
studi che misurano lo stesso contrasto (stesso trattato + stesso tipo di controllo), e provarlo a scala
con la metrica di coerenza che ora ESISTE. NON un altro giro di nomi. NON un cerotto a valle (a meno che
il brainstorming non provi che è equivalente e sufficiente).

---

## 3. REGOLE HARD (non negoziabili — sono le lezioni dei mesi persi)

1. **Il GATE di accettazione è la COERENZA (= meta-analisi difendibile = stesso contrasto), non i
   nomi.** Vedi §0.5. Metrica della BARRIERA = coerenza di contrasto (omogeneità del controllo +
   non-degenere) + deep-dive LLM "un contrasto o molti?" sul campione. La **consistenza (ADR-0021) è
   la FORZA da riportare accanto, NON la barriera** (un coerente-ma-eterogeneo resta difendibile).
   Tool: `R/stage3-coherence.R` + `analysis/audit/2026-07-23-coherence/` + `R/stage4-consistency.R`.
   Copertura nomi / conteggio cluster / I² del pooled da soli = NON sufficienti, MAI più come criterio
   di successo. L'obiettivo è che OGNI cluster raggiunga la barriera (clustering irreprensibile).
2. **VIETATO dichiarare "paper-grade"/"publication-grade"/"finale"/"done" senza la prova di coerenza
   PER-CLUSTER sui dati.** Se lo scrivi senza averlo dimostrato è una bugia (è già successo).
3. **VALIDA-PRIMA-DEL-FULLRUN sulla coerenza.** Ogni design candidato dell'anchor va misurato con la
   metrica di coerenza su un CAMPIONE reale (ricostruendo i contrasti) PRIMA di qualunque re-cluster
   (~8h) o re-pool (~50h). Non spendere ore su un design non validato sulla coerenza.
4. **Il design dell'anchor è un BIVIO SCIENTIFICO → brainstorming + spec PRIMA, FERMATI e chiedi.**
   Non partire a inventare (è l'errore già fatto). Presenta le opzioni con tradeoff onesti, la tua
   preferenza, aspetta la direttiva. Vedi [[feedback_explain_then_decide]].
5. **Il lato CONTROLLO è di prima classe.** Una meta-analisi è trattato-vs-controllo: l'anchor deve
   garantire che ENTRAMBI i lati matchino. Se un design non tocca il controllo, spiega perché basta.
6. **Non fidarti dei subagent/LLM senza controllo** contro i dati veri (i revisori del 2026-07-23
   avevano dato premesse false; anche i deep-dive di questa sessione sono stati verificati ~92% a mano).
7. **Fail onesto coi NUMERI.** Se un design candidato lascia il 50% minestrone, scrivi 50%.

---

## 4. Direzioni di design da valutare nel brainstorming (NON prescrizioni — punti di partenza)

- **(A) Contrast-anchor**: la chiave di clustering include SIA il trattato SIA il **tipo di controllo**
  normalizzato (estendere ai group la logica `treated__VS__control` già usata dai pair, che sono più
  coerenti). Più vicino a ciò che una meta-analisi richiede; costo: ricostruire il controllo per ogni
  membro (il dispatch lo fa già, `.lookup_cmp_by_treated_group` → control_group).
- **(B) Split per coerenza alla formazione del cluster**: mantenere gli anchor attuali ma **spezzare**
  ogni cluster per tipo-di-controllo (e scartare/flaggare gli eterogenei) usando il normalizzatore del
  controllo. Valutare se è davvero "a monte" o solo un filtro travestito.
- **(C) Fix della granularità disease**: per disease_vs_normal l'entità deve essere una malattia
  specifica e corretta; malattie diverse NON devono fondersi. Si intreccia col name-recovery ma con la
  COERENZA come gate (non la copertura).
- Combinazioni. Il brainstorming decide; ogni opzione va **misurata sulla coerenza su un campione** prima
  di scegliere.

Domanda aperta onesta da portare all'utente: se un anchor più stretto **riduce** drasticamente k (meno
studi poolabili ma coerenti), va bene? Meglio 30 meta-analisi vere che 184 minestroni — probabile, ma è
una scelta scientifica dell'utente (trade-off coerenza vs quantità).

---

## 5. Materiali di partenza (già prodotti, riusabili — NON ripartire da zero)

- **Finding coerenza**: `docs/findings/2026-07-23-stage3-cluster-coherence.md` (numeri + prove + gate).
- **Tool coerenza** (testato, 22 test): `R/stage3-coherence.R`
  (`.reconstruct_cluster_contrasts` = ricostruisce il contrasto via dispatch reale Stadio 4;
  `.normalize_control_type`; `.cluster_coherence_signals`; `.coherence_verdict`; `.meta_analysis_valid`).
- **Verdetti per-cluster**: `analysis/audit/2026-07-23-coherence/` →
  `deliverable-184-verdicts.csv` (i 184 con verdetto + `dd_reason` = perché), `cluster-verdicts.rds`
  (tutti i 13.287), `verdict-by-kind.csv`, `consistency-pooled.csv`, `deepdive-verdicts/`.
- **Script**: `10-signals-all-clusters.R` (segnali su tutti), `20-consistency-pooled.R` (ADR-0021 sui
  poolati), `30-deepdive-prep.R` + deep-dive LLM (bundle di evidenza), `40-assemble-verdict.R`,
  `50-gate-diagnosis.R`.
- **Dispatch** (come si ricostruisce treated/control): `R/stage4-dispatch.R`
  (`.lookup_cmp` pair / `.lookup_cmp_by_treated_group` group / `.lookup_rg` / `.split_record_id`).
- **Consistenza** (ADR-0021, invariata): `R/stage4-consistency.R`.
- **Input**: Stage 3 v10 `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/`; Stadio 2 master
  `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`; Stadio 4 v10
  `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/`.
- **Anchor attuale**: `R/stage3-anchor-levels.R`, `R/anchors.R`, `R/stage3-build.R`.

---

## 6. Cosa NON fare (trappole già cadute)

- NON un altro giro di recupero-nome / de-frammentazione / fallback come obiettivo primario (i nomi sono
  già a posto; il problema è la coerenza).
- NON misurare il successo con l'I² del pooled o la copertura dei nomi.
- NON dichiarare deliverable finali / vetrine / paper prima del gate di coerenza per-cluster.
- NON lanciare re-cluster/re-pool (ore/giorni) prima di aver validato il design sulla coerenza su un
  campione.
- NON fidarti dei blocchi 🟢 "DELIVERABLE FINALE / publication-grade" nel CLAUDE.md sopra: sono RITRATTATI.

---

## 7. Bug/TODO ortogonali emersi (annotare, non distrarsi)

- **Nomi ancora sbagliati** su alcuni cluster anche COERENTI (ethanol→TNF, Met-tRNA→TGFB1,
  anisole→calcitriolo, 4-maleylacetoacetate→DHT, "carnitine" ancora `pathogen`). Da correggere DOPO che
  la coerenza è risolta (non è la priorità).
- 33 cluster (a bassa confidenza, non poolati) risultano degeneri (trattato==controllo) = errori Stadio 2.
