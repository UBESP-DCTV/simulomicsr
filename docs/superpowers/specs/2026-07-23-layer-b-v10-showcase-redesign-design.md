# Layer B v10 — Showcase redesign (report publication-grade) + selezione critica

**Data:** 2026-07-23
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Tipo:** spec di design (brainstorming → writing-plans)
**Contesto a monte:** finding `docs/findings/2026-07-23-layer-b-v10-case-studies.md`
(18 case study rem_group generati), ADR-0017 (Layer B), ADR-0024 (v10).

## 0. Obiettivo in una riga

Il report Layer B v10 attuale (`layer_b_report.html`) è il deliverable finale della
pipeline ma è **grezzo e mal impaginato**: dump YAML della config, 6 PNG impilati a tutta
larghezza senza note, top-gene table `knitr::kable` con float a 16 cifre, narrative stub
`_TODO_`. Va trasformato in una **vetrina publication-grade "venduta bene"**, con una
**selezione critica** dei casi (meno, ma solidi) validata da revisione scientifica.

## 1. Decisioni prese (brainstorming, gate utente)

| # | Decisione | Scelta |
|---|---|---|
| D1 | **Pubblico/scopo** | **Ibrido a 2 livelli**: vetrina divulgativa (note "per la gente") + supplementary tecnico ripiegabile (collapsible) |
| D2 | **Impianto** | **Restyle in Quarto** (tema SCSS custom, layout, callout) + fix dei builder R. Resta rigenerabile dalla pipeline |
| D3 | **Note/narrativa** | Note "come si legge la figura" (riusabili) + racconto statistico + **micro-narrativa biologica SOLO sui top-gene verificati** (con fonte). Zero prosa speculativa |
| D4 | **Selezione** | **Core solido = 9 casi**; drop dei 6 deboli; 3 borderline parcheggiati |

## 2. Selezione critica (revisione a 3 subagent, verifica su letteratura)

Tre revisori (malattie / farmaci / patogeni) hanno valutato la difendibilità biologica dei
18 casi con verifica dei top-gene su letteratura. Esito:

**VETRINA — 9 casi tenuti** (copertura: 4 tumori · 3 virus respiratori · 1 batterio · 1 farmaco):

| Caso | cluster_id | Verdetto | Geni-headline verificati (da promuovere) |
|---|---|---|---|
| gastric cancer (stomach) | group_L4_c8600f54 | STRONG KEEP | PGA5, ATP4B, GKN2 (perdita differenziazione gastrica) |
| Renal cell carcinoma (kidney) | group_L4_7b3e137b | STRONG KEEP | CA9/CAIX, SLC6A3 ↑; UMOD/AQP2 ↓ (nefrone perso) |
| RSV (lung) | group_L4_7059e6f2 | STRONG KEEP | IFNL1/IFNB1, RSAD2, OAS2, MX1, ISG15, ACOD1 |
| influenza (lung) | group_L4_1f404c0b | STRONG KEEP | UBD/FAT10, IFNL1-3, RSAD2, IFNB1 |
| Lung Neoplasms (lung) | group_L4_eda28231 | KEEP | CST1, FAM83A ↑; AGER/SFTPC ↓ (alveolo perso) |
| Enzalutamide (prostate) | group_L4_b128b80d | KEEP | KLK3/TMPRSS2/FKBP5 ↓, CYP11A1 ↓ (blocco AR) |
| SARS-CoV-2 (lung) | group_L4_b6a3eabd | KEEP | IFNB1/IFNL, TNF (IFN "muted" + TNF); **non** TTLL8 |
| M. tuberculosis (blood) | group_L4_274f387d | KEEP | IFI27, OTOF (firma TB-sangue, Berry 2010) |
| hepatocellular carcinoma (liver) | group_L4_c51b10c1 | KEEP + caveat | MAGEA3, MT1G, FCN2/CLEC4M; **caveat I²≈99%** |

**DROP — 6 casi esclusi** (biologia non coerente col label; k_eff↑ ma minestrone/mislabel):

| Caso | cluster_id | Perché droppa |
|---|---|---|
| breast cancer | group_L4_4d2d5aa0 | mislabel kind, GO vuoto, tutti k=2, minestrone pancreas/cute/ciglia/fegato; zero marker mammari |
| prostate cancer | group_L4_c2a27b6c | mislabel kind, GO vuoto, tutti k=2, CTA generici; zero marker prostatici |
| Lipopolysaccharide (blood) | group_L4_59db95a9 | firma epiteliale squamosa su "blood", zero geni innati LPS |
| fulvestrant (breast) | group_L4_b4975123 | GO vuoto, firma epatica (fibrinogeni/APOA1) su tessuto "breast" |
| bleomycin (prostate) | group_L4_02a1fb3f | minestrone neuronale, artefatto identità-split |
| physostigmine (prostate) | group_L4_f4b9f686 | stesso identico artefatto neuronale di bleomycin |

**PARCHEGGIATI — 3 borderline** (fuori dalla vetrina v1, decisione futura):
TGFB1 (group_L4_f477e6a4, fibrosi/ECM coerente ma non SMAD canonico, k=5), colorectal
(group_L4_2d512638, segnale vero solo a k≥3, top-30 contaminazione epatica), tamoxifen
(group_L4_3c38c897, identità ER giusta ma zero geni ER canonici).

## 3. Anatomia del report (Quarto restyle, ibrido 2-livelli)

**① Apertura** — sostituisce il dump YAML:
- Titolo + hero: un paragrafo in lingua semplice su cosa fa la pipeline (metadati grezzi GEO
  → meta-analisi cross-studio nominate con effect-size random-effects).
- **Primer "Come si legge questo report"**: legenda che spiega UNA VOLTA ogni tipo di figura
  (volcano / forest / MA / heatmap / eterogeneità / GO) — testo semplice + nota tecnica ripiegabile.
- **Indice a colpo d'occhio**: tabella pulita/ordinabile dei 9 casi (entità, categoria, tessuto,
  n° studi, n° geni significativi).

**② Sezione per caso** (una "card" per i 9):
- Header leggibile: titolo umano + badge categoria + tessuto + striscia-stat "N studi · M geni sig".
  **Relabel del kind mislabellato** (display-layer, non tocca l'anchor pipeline).
- 1-2 frasi di framing + **micro-narrativa sui geni-headline verificati** (tabella §2, con fonte).
- Figure in **griglia 2-col responsive** (non impilate), ognuna con nota "cosa mostra" (link al primer).
- **Top-gene table rifatta** (vedi §4).
- **Callout "Dettaglio tecnico" ripiegabile**: I², τ², k_effective, safety_min, metodo. (2° livello.)
- Nessuno stub TODO: la micro-narrativa verificata è il contenuto; se assente, si nasconde.

**③ Footer** — nota methods breve/leggibile + config completa ripiegabile (riproducibilità).

## 4. Fix trasversali della top-gene table (raccomandati indipendentemente da 2 revisori)

1. **Ordinamento per significatività × robustezza**, NON per |logFC|. L'ordine |logFC| pesca
   geni ad alta varianza (recettori olfattivi, cheratine, k=2) e seppellisce i marcatori canonici.
   Ordinare per FDR (e/o pesare k_effective per-gene) fa emergere la biologia vera (es. enzalutamide
   → KLK3/TMPRSS2/FKBP5; TB → IFI27/OTOF).
2. **Dedup righe Ensembl** sullo stesso simbolo (RDH13 ×7, AGER ×4 = mappatura multi-Ensembl ARCHS4):
   collassare al più significativo / annotare.
3. **Colonne umane**: Gene (symbol) · log2FC con freccia ↑/↓ + colore · FDR formattato · n° studi (k).
   Top 10-15 mostrati + "mostra tutti i 30" ripiegabile.
4. **Coerenza heatmap↔table**: la heatmap seleziona "top 30 DE"; allinearla allo stesso criterio di
   ranking della table (significatività) per non mostrare due set di geni diversi.

## 5. Approccio implementativo (raccomandato)

Fixare i builder R (top-gene table + selezione geni heatmap per significatività; note esplicative;
relabel kind; via il dump config; nascondere gli stub) e **ri-lanciare il build Layer B solo sui 9
casi** con una selection CSV dedicata (`analysis/layer-b-selection-v10-showcase.csv`) → bundle
rigenerati coerenti (~6-10 min), poi render del template restyled. Più pulito e riproducibile del
patch post-hoc sui PNG esistenti. La selection completa a 18 resta in git per provenienza.

## 6. Unità di lavoro (cosa cambia)

- `inst/templates/layer-b-report.qmd` — restyle completo (hero, primer, indice, card, footer) +
  SCSS custom (nuovo `inst/templates/layer-b-report.scss`) + callout collapsible.
- `R/layer-b-plot-top-gene-table.R` — ranking per significatività, dedup Ensembl, colonne umane.
- `R/layer-b-plot-heatmap.R` — allineare la selezione geni al ranking per significatività.
- `R/layer-b-summary-card.R` — output "a colpo d'occhio" leggibile (via gergo interno); relabel kind.
- Note esplicative per-figura (riusabili) + micro-narrative verificate per i 9 (nuovo data file /
  captions arricchite).
- `analysis/layer-b-selection-v10-showcase.csv` — i 9 casi curati (label umane, categoria, headline genes).
- `analysis/p5-stage4-layer-b-build-v10-showcase.R` (o riuso del build v10 con la nuova selection).
- Test: aggiornare/estendere i test dei builder toccati (ranking, dedup, relabel).

## 7. Task di follow-up (documentati, a valle del showcase)

- **[UTENTE, esplicito] Investigazione root-cause dei DROP.** Alla fine, guardare per bene i 6 casi
  droppati: *che problema hanno avuto* e in particolare **se lo Stadio 3 ha messo insieme
  campioni/studi sbagliati** (minestrone a livello di membership) ed è per quello che "vengono di
  merda". Metodo: tracciare per ciascun cluster droppato gli studi/GSM membri (assignments +
  stage2_master) e verificare se la biologia è omogenea o mescolata (tessuti/entità diverse nello
  stesso cluster), collegando alle firme geniche incoerenti trovate dai revisori (es. bleomycin ≡
  physostigmine = stessi studi neuronali; breast = pancreas/cute/fegato; LPS = epiteliale squamoso).
  Output: un finding diagnostico; NON impegna un re-cluster (decisione separata se emerge causa
  sistematica).
- **Caveat paper.** 3 flagship opzione-C (breast/prostate/LPS) non reggono la biologia: k_eff↑ ≠
  coerenza. Da verbalizzare come limite onesto (aggiorna `project_paper_known_limitations` / finding).
- **narrative.qmd per il paper.** Compilare Biological context/Findings/Discussion per i 9 (o
  usare le micro-narrative verificate come base).

## 8. Fuori scope (YAGNI)

- Ri-cluster / re-pool della pipeline (il showcase riusa i risultati v10 esistenti).
- Recupero dei borderline (TGFB1/colorectal/tamoxifen) — decisione futura, non v1.
- HTML bespoke / microsite (scelto Quarto restyle).
- Narrativa biologica estesa non verificata (scelto: solo bio verificata).

## 9. Criteri di successo

- Report HTML autocontenuto, esteticamente publication-grade, ibrido 2-livelli funzionante
  (note divulgative + collapsible tecnici).
- 9 casi, ognuno con headline sui geni GIUSTI (verificati), figure in griglia con note, top-gene
  table leggibile e ordinata per significatività.
- Rigenerabile dalla pipeline con un comando. Test dei builder toccati verdi.
- Finding di follow-up sui drop pianificato.
