# ADR-0021: Metrica di consistenza/riproducibilità cross-studio per la selezione Layer B

- **Status:** Proposed
- **Date:** 2026-06-15
- **Deciders:** lucavd, Claude (RED ALERT FASE F6)
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

I 776 cluster Stadio 4 v3 vanno filtrati/rankati per selezionare i ~15 case study
pilota che devono **dimostrare la validità** della pipeline in un paper di metodi.
Serve una metrica di consistenza cross-studio scientificamente difendibile. Il proxy
usato in F5 (mediana delle correlazioni di Spearman dei logFC per-studio sui top-2000
geni per min-p) è **selection-biased** (winner's curse indotto dal ranking per min-p;
Li et al. 2011 critica esplicitamente lo Spearman su liste rankate) e scarta la
magnitudine. Una deep research metodologica (2026-06-15) ha indicato l'asse corretto:
la **varianza between-study come frazione della varianza totale** (replicabilità,
NAS 2019), non un conteggio di DE né una correlazione di ranghi.

## Decision Drivers

- Difendibilità davanti a reviewer di bioinformatica (metriche canoniche, non ad-hoc).
- Asimmetria dei tre metodi: rem (effect-size meta-analysis, I²/τ² nativi), mega
  (modello pooled, no per-study DE), mega_aug (k=2, eterogeneità non stimabile).
- 575/776 cluster sono mega_aug a k=2 → la consistenza interna lì è intrinsecamente
  fragile.
- Tracciabilità: la scelta guida la selezione dei pilota, deve essere a libro.

## Considered Options

1. **%DE come guard** — scartare i cluster ad alta frazione di geni DE.
   Scientificamente sbagliato: la %DE alta può essere biologia vera (la validazione
   F5 ha mostrato che i cluster ad alta %DE sono per lo più *concordi*).
2. **Spearman dei logFC per-studio sui top-N geni** (il proxy F5) — selection-biased
   (winner's curse), magnitude-free, threshold-dependent.
3. **Asse di consistenza basato sulla varianza between-study**, realizzato
   per-metodo: 1−I² (rem) / 1−ICC(study) (mega) / sign-concordance (mega_aug), sui
   geni FDR-significativi, su scala unica [0,1]; più prediction interval (rem) e
   dispersione assoluta (τ²/IQR) riportati a fianco.

## Decision Outcome

Scelta: **Opzione 3**.

Motivazione: è l'unico asse ancorato alla statistica canonica della replicabilità
(I² = τ²/(τ²+σ²) è un ICC; il VPC dell'effetto-studio random è il suo analogo nel
modello pooled, Hoffman & Schadt 2016) e copre i tre metodi su una scala omogenea
[0,1] senza fabbricare numeri dove non sono stimabili (mega_aug k=2 → sign-concordance,
I²/τ² = NA esplicito). La %DE (opz. 1) è stata empiricamente smentita; lo Spearman
selezionato (opz. 2) è selection-biased e indifendibile. Design completo:
`docs/superpowers/specs/2026-06-15-f6-reproducibility-consistency-metric-design.md`.

Decisioni di dettaglio (gate utente 2026-06-15):
- **Gene set**: geni FDR-significativi del pooled (misura se il *segnale* replica, non
  il rumore).
- **Asse unico**: consistenza = 1 − frazione varianza between-study (mega/rem),
  sign-concordance allineata (mega_aug); τ²/PI assoluti riportati a fianco (I²/ICC
  sono relativi — Borenstein 2017).
- **mega_aug k=2**: sign-concordance dei 2 studi sui geni sig (direction-concordance,
  raccomandato a k basso dalla deep research).

## Consequences

- **Positive:** metrica difendibile e citabile; copertura dei 3 metodi; PI rem dà la
  risposta diretta "replicherà in uno studio nuovo"; i mega_aug k=2 hanno un proxy
  onesto. Distribuzione completa riportabile (anti-cherry-picking, Weber 2019).
- **Negative / limiti:** I²/ICC sono ratio relativi (vanno accoppiati all'assoluto);
  k=2 (la maggioranza) ha consistenza interna fragile → richiede la validazione
  esterna (Fase C: LOO/LINCS/pathway) come evidenza primaria; l'equivalenza REM↔ICC è
  strutturale non numerica (assi analoghi, non valori intercambiabili).
- **Validazione esterna** (Fase C, solo sui candidati dello shortlist): LINCS
  connectivity (copertura ~40–55% degli anchor, two-tier con pathway), pathway/Hallmark
  enrichment, leave-one-study-out stability. ADR separato se servirà.
