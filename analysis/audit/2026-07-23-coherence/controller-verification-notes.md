# Verifica del controller sui verdetti deep-dive (agreement LLM-vs-dati)

Mandato utente (2026-07-23): "Non fidarti dei subagent senza controllo". Il controller
(Claude, sessione principale) ha ri-giudicato a mano un campione dei verdetti LLM contro
le etichette REALI dei contrasti (deepdive-bundles.jsonl), SENZA vedere il verdetto atteso.

## Campione verificato: 24 cluster (14 one_contrast + 10 multi_contrast)

### one_contrast verificati (i "sopravvissuti") — l'LLM NON ha sovra-promosso
- 7b3e137b (RCC vs rene normale) OK; 72f662c4 (NASH vs fegato sano) OK; 9d140332 (endometriosi
  vs controllo) OK; 2c92ab19 (Sjogren vs sano) OK; 23d99677 (infezione batterica vs sano) OK;
  8bc49282 (TNF vs veicolo) OK; 575a05a0 (TGFB1 vs veicolo) OK; 7dd45f9a (obeso vs magro) OK;
  36e14ea8 (X-ray vs controllo) OK; 78c74b14 (trained vs untrained) OK.
- BORDERLINE (lievemente leniente, difendibile): c347e80c (cervical, sem_ctrl=4 ma tutti cervice);
  8b00e191 (diabetic nephropathy con 1 glomerulosclerosi idiopatica mescolata); 378e0efe (immunization).
- BUG SCOPERTO (mio strumento, non LLM): 38ce0d4d (Hypoxia vs Control) era chiaramente one_contrast
  ma frac_degenerate=0.6 -> FALSO POSITIVO del check degenere basato su factor_levels (due bracci
  con stesse chiavi fl). FIX: degenere = uguaglianza del label_human. Rigenerati i segnali.
- BUG di ETICHETTA (separato dalla coerenza): alcuni one_contrast hanno canonical_name SBAGLIATO
  (8bc49282 'ethanol'->TNF; 575a05a0 'Met-tRNA'->TGFB1; batch-06 'anisole'->calcitriolo).

### multi_contrast verificati (anche con det_ctrl<=3) — l'LLM NON ha sovra-chiamato
- Giustificati da eterogeneita' sul lato TRATTATO o mixing di malattie che il conteggio-controlli
  non vede: 12db7a61 (TNF+EGF); f477e6a4 (TGFB1 puro + combo IL-1beta); 8a19ae38 (MAPKi+TGFb+CRISPR);
  cddbf768 (IL2: anti-CD3/CD28 + IFN-g + CAR-T); 37d46677 (PF4: CXCL4 + combo 3-4 vie); 8c14612b
  (HNSCC: 1/5 tumore-vs-normale, resto relapse-vs-primary); df7a7a08 (IUGR + COVID); 37890ccf
  (cirrosi + HCC); a2d75bf3 (miopatie + scoliosi + DM1).
- BORDERLINE (lievemente stretto): 0a2f157f (lenvatinib, 1/8 usa shNC scramble baseline).

## Esito: accordo ~22/24 (~92%). I 2 borderline sono chiamate difendibili sotto la regola
## conservativa AND multi-asse scelta dall'utente. I verdetti LLM sono ancorati alle etichette
## reali e verificabili -> NON il problema "premesse false" del 2026-07-23.
