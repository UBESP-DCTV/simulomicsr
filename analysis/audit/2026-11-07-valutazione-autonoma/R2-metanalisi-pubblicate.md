# R2 — Meta-analisi pubblicate sugli stessi GSE dei nostri gruppi (2026-11-07)

**Come ho cercato.** Europe PMC REST, ricerca nel testo pieno per co-citazione dei nostri GSE (query `(GSE… OR GSE…) AND malattia AND (meta-analysis OR integrated…)`) per 19 entità, poi lettura del testo pieno (JATS) dei candidati; 9 ricerche web di complemento (limite 25). Limiti: il testo pieno è indicizzato solo per gli articoli open access; medRxiv, PMC e Nature hanno bloccato alcune letture (segnalato dove conta). Il file `gruppi-benchmark.csv` **non contiene un gruppo «sepsis»**: non cercato. «GSE in comune» = GSE del nostro gruppo usati dall'articolo come dati analitici (la validazione è indicata a parte). Rivista fra parentesi quando è a controllo variabile (MDPI, Frontiers, Dove, Hindawi).

## 1. Per entità

**psoriasis** (nostri: GSE108743, GSE117405, GSE139341, GSE142582, GSE147339, GSE150851, GSE74697, GSE81106, GSE89725, GSE92472)
- Federico et al. 2020 *Sci Data* 10.1038/s41597-020-00696-8: 39 dataset armonizzati (13 RNA-seq), fra cui **GSE74697, GSE117405 (2)**; matrici su Zenodo 10.5281/zenodo.4009497. Nessuna DE né meta-analisi: benchmark di *input*, non di risultato.
- Solvin et al. 2023 medRxiv 10.1101/2023.11.03.23298021 (solo preprint; nessuna versione in rivista trovata): 534 campioni = dati propri + GSE63980, GSE121212, **GSE74697 (1)**; conte unite; 2.269 DEG lesionale/sano, 58 non-lesionale/sano. Geni non leggibili (medRxiv 403).
- Stemmer et al. 2026 *IJMS* (MDPI) 10.3390/ijms27104439: 13 studi RNA-seq (342 campioni), **GSE117405 (1)**; limma con studio come blocco; DEG «available upon request», nel testo solo geni sesso-specifici (SYT6, NELL2, GPR15…). Non eseguibile.
- Swindell et al. 2017 (PMC5234565): meta-analisi RNA-seq PP vs PN su GSE41745, GSE54456/GSE63979, GSE66511 (0 in comune), 2.113 DEG. Riferimento esterno.
- Bassa qualità, non usabili: Shu 2022 *World J Clin Cases*, Gan 2024 *Front Biosci*.

**Crohn Disease** (GSE112057, GSE117875, GSE156044, GSE163314, GSE164871, GSE165512, GSE193677, GSE230113, GSE261086, GSE83687, GSE92472, GSE93624) e **Colitis, Ulcerative** (GSE102746, GSE112057, GSE123141, GSE165512, GSE224758, GSE243625, GSE83687, GSE92472)
- Stemmer et al. 2024 *Front Immunol* 10.3389/fimmu.2024.1353402: «mega-analisi» di 10 dataset RNA-seq uniti (studio come covariata, no effect size); **GSE83687 (1)** analitico, GSE193677 validazione esterna; **GSE93624 escluso come duplicato di GSE101794** (stessi pazienti RISK) — utile per il nostro S5. CD vs ctrl 1.008 DEG, UC vs ctrl 4.027. Geni nominati: su DUOX2, DUOXA2, MMP3, REG1A, CHI3L1, SAA1, SAA2, AQP9, S100A8, S100A9; giù AQP8, CLDN8, CA1, OTOP2, SLC26A2, HMGCS2, DPP10. Lista completa solo in figura.
- Metselaar et al. 2025 *BMC Gastroenterol* 10.1186/s12876-025-04566-8: revisione sistematica + REM (SMD, Hedges g) su **due geni**, 24 dataset tessuto fra cui **GSE193677, GSE83687, GSE112057 (3)**; IBD vs ctrl tessuto: IL1B SMD 0,95 [0,66; 1,24], NLRP3 0,53 [0,36; 0,70]; sangue IL1B 0,20 [0,06; 0,33], NLRP3 n.s. Controllo puntuale di due geni, con sangue separato dal tessuto.
- Rahman et al. 2025 *Genes* (MDPI) 10.3390/genes16111296: **GSE112057, GSE83687 (2)** + GSE135223; intersezione di DEG calcolati in Excel, p non corretto; «hub» TLR2, IFNG, CD163, CXCL9, CCL4, PRF1, TLR8, ARG1, LILRB2, FPR2, PPARG; Table S1 con i DEG per dataset. Qualità bassa.
- Alghamdi et al. 2024 *IJMS* (MDPI) 10.3390/ijms25179751: **GSE83687 (1)** + 5 microarray; Fisher in NetworkAnalyst + intersezione CD∩UC (180 geni); hub PPI IL1B, TLR4, ITGB2, CD86, CXCL8, SPI1, HCK, HIF1A, CYBB.
- Molti altri (116 e 67 hit) sono «hub gene + machine learning» a singolo autore o ML: non benchmark.

**Alzheimer Disease** (GSE113524, GSE125583, GSE161199, GSE203206, GSE207821, GSE228458, GSE95587)
- «Systematic review and meta-analysis of bulk RNAseq studies in human AD brain tissue», 2025 *Alzheimers Dement* 10.1002/alz.70025 (PMC11881636): 24 studi; meta-analisi (METAL, effetti fissi, su p aggiustate) su Mayo, MSBB, ROSMAP (Synapse, **0 GSE in comune**). Temporale 571 DEG: su CLU, PRKD3, HADH, STEAP3, DCAF12, PLPP1, IGF1R, WDR1; giù SST, PARL, GAD1, LRRC39; frontale 189 (GFAP); Tabelle S5–S12. Riferimento di direzione, non di dataset.
- metafun-AD (CIPF, bioinfo.cipf.es/metafun-ad): 9 microarray + **GSE125583 (1)**, REM metafor su logFC; confronto principale = differenze di sesso; AD vs ctrl per sesso disponibile.
- Chai et al. 2026 *Alzheimers Dement* 10.1002/alz.71804: 19 dataset umani, **GSE203206 (1)**; REM su Cohen's d; «Refined107» con MSX1, CDA, TEX22, S100A12, CLDN3, CCR7, SLC6A3, CDH17, EDARADD, CYP24A1, HLA-H — lista poco plausibile per cervello AD.
- Mei et al. 2023 *Front Aging Neurosci* 10.3389/fnagi.2023.1101216 cita GSE125583/GSE95587 ma poola ROSMAP, MSBB, GSE110731 (0 effettivi).
- Nota: la scheda GEO di GSE125583 dichiara **89 soggetti in comune con GSE95587** (blocchi di tessuto diversi): studio doppio parziale nel nostro gruppo.

**Parkinson Disease** (GSE106608, GSE133101, GSE140089, GSE161199, GSE168496, GSE181029, GSE206308, GSE208347, GSE84684, GSE90469)
- Huang et al. 2024 *BMC Med Genomics* 10.1186/s12920-024-01885-9: **GSE168496 (1)** mRNA + un array circRNA + miRNA; GEO2R separati, nessuna meta-analisi; hub PPI su ESR1, DCN, ELN, ISL1, COMP, FMOD, LUM, OTX2, CILP, KRT14, LAMB1; giù DRD2, SLC18A2, DDC, SLC6A3, KCNJ6, TH, PITX3, MT-CO2, MT-CYB, SLC18A1 (geni dopaminergici, attesi in sostanza nera).
- Narváez-Bandera et al. 2024 *Sci Rep* 10.1038/s41598-024-73535-0: **GSE106608 (1)** + microarray; metodo «BioOptimatics» (ottimizzazione multi-criterio, non inferenziale); geni MT1H, MYOM2, RPL18, S100A12, IFIT1, KRT23, GPX3, SLC30A2; CFD, ARHGDIB, MMP9.
- Zhang T et al. 2024 *Mol Biomed* 10.1186/s43556-024-00213-y: **GSE168496 (1)** validazione, GSE216281 per stadi Braak; nessuna meta-analisi.
- Tranchevent et al. 2023 *NPJ Parkinsons Dis* 10.1038/s41531-023-00446-8: microarray + GSE110717; 0 in comune visibili; p combinate pesate (Marot); geni sesso-specifici.

**Pre-Eclampsia** (GSE114691, GSE143953, GSE148241, GSE155750, GSE186257, GSE218039, GSE234729, GSE262147, GSE79782)
- Gao et al. 2023 *Front Endocrinol* 10.3389/fendo.2023.1190012: **GSE148241, GSE114691 (2)** + GSE190971, GSE74341 (li chiama «microarray», ma GPL16791/GPL11154 sono Illumina HiSeq: RNA-seq); intersezione dei DEG dei 4 dataset (p<0,05 non corretto) → 60 DEG (Suppl. Table 1); hub PAPPA2, HTRA4, NTRK2, PHYHIP, INHBA, KCNF1, CADM3 (CADM3 giù, gli altri su).
- Xiong et al. 2025 *Sci Rep* 10.1038/s41598-025-89140-8: **GSE234729, GSE262147 (2)** + 2 microarray; ComBat + WGCNA + LASSO/SVM; geni RAG1, RBBP7, RFTN2, SPATA7, ZNF16 (plausibilità bassa).
- Han et al. 2025 *Front Cell Dev Biol* 10.3389/fcell.2025.1635878: **GSE234729 (1)** + GSE75010, GSE25906; WGCNA + limma, no meta-analisi; hub LEP, FLT1, HTRA4, FSTL3, ENG, SLC2A1, HK2, BHLHE40, ANKRD37, SIGLEC6, PLIN2, SCARB1, LPL, THY1, MME, P4HA1.
- He J et al. 2023 *Front Mol Biosci* 10.3389/fmolb.2023.1248771: 8 microarray uniti (ComBat), **GSE148241 (1)** solo validazione; glicolisi su HK2, SLC2A1, PFKP, ALDOA, TPI1, GAPDH.
- I geni «classici» (FLT1, LEP, ENG, HTRA4, PAPPA2, FSTL3, INHBA, HK2) ricorrono in tutti: buon controllo biologico anche senza meta-analisi formale.

**nash** (GSE115193, GSE126848, GSE134422, GSE147304, GSE162694, GSE173735, GSE212741) e **Non-alcoholic Fatty Liver Disease** (GSE115193, GSE126848, GSE135251, GSE160016, GSE185051)
- **Piras & DiStefano 2024 *Life Sci Alliance* 10.26508/lsa.202302517 (PMC10987979)**: 9 GEO (3 RNA-seq: **GSE135251, GSE126848 (2)**, GSE130970) + PRJNA512027 proprio; REM (GeneMeta/Choi, FDR per permutazione); MASLD vs ctrl 685 DEG (top P4HA1, RASSF4, ACADSB, C11orf54, TMEM45B), MASH vs ctrl 1.870 (P4HA1, PRAMEF10, PRKAA2, DTL, EXO1, MAT1A, IGFBP2; ITGBL1, LOXL1 su; TAT, CEBPD giù), MASH vs MASLD 3.284 (SMOC2, ITGBL1, LOXL1, SOD3 su). **Liste complete: Table S1/S3/S5.** Il miglior benchmark trovato.
- Maiers et al. 2026 *Hepatol Commun* 10.1097/hc9.0000000000000991: 8 RNA-seq fra cui **GSE135251, GSE162694, GSE185051 (3 fra i due gruppi)** + 4 microarray; p combinate (Edgington); **contrasto fibrosi F3-4 vs F0-1**, non malattia vs controllo; 846 DEG in Table S1 (su THBS2, ADAMTSL2, FBLN5, LUM, CXCL6, SOX9, SOX4, AKR1B10, FBN1, CCL19, CCL20, CCL21, IL32, C7; giù SLC16A10, AADAT, SLC13A5, ABCA6, NR5A2).
- Kamzolas et al. 2026 *Nat Metab* 10.1038/s42255-026-01543-7: GSE130970, E-MTAB-9815, coorte EPoS (= Govaere 2020, il cui GEO è GSE135251, ma non nominato); traiettoria di 145 geni (Table 3). 0 GSE nominati.
- Lan et al. 2025 *Sci Rep* 10.1038/s41598-025-90744-3: scoperta su 3 microarray uniti; GSE126848, GSE162694, GSE135251 solo validazione; CYP7A1, TNFRSF12A.
- 349 hit: il dominio è saturo di «hub gene / ML» su GSE135251+GSE126848; quasi tutti senza meta-analisi.

**Carcinoma, Hepatocellular** (GSE120663, GSE144269, GSE159220, GSE164359, GSE202853, GSE256235, GSE263134, GSE77509)
- Sucularli 2025 *PLoS One* 10.1371/journal.pone.0331118: TCGA-LIHC ∩ **GSE77509** (intersezione DEG con GOBP mitotic cell cycle), **GSE144269** validazione (2); geni CDKN3, TRIP13, RACGAP1, FBXO43, EZH2, SPDL1, E2F1, TUBE1, CDC6; nessuna lista supplementare. Il nostro gruppo contiene **GSE144269 con i bracci invertiti**: non confrontabile finché non corretto (S13).
- GepLiver 2023 *Sci Data* 10.1038/s41597-023-02257-1: atlante che include entrambi (risorsa, non meta-analisi). 219 hit generici: il dominio più inflazionato.

**idiopathic pulmonary fibrosis** (GSE185259, GSE231693, GSE248485, GSE73189, GSE79544, GSE92592, GSE99621)
- **He D et al. 2025 *Eur Respir J* 10.1183/13993003.01070-2024 (PMC12138033)**: revisione sistematica + integrazione di 35 studi polmone (16 RNA-seq); **GSE92592, GSE73189, GSE99621 (3)**; metodo MINT (mixOmics, dati uniti con ComBat, PLS-DA) + robust rank aggregation come confronto; IPF vs ctrl: su MMP7, COMP, DIO2, FHL2, COL17A1; giù CA4, FAM167A, MYRF, CRTAC1, FZD5, PLLP; IPF-specifici GPSM2, HSPA4L, COL16A1, ITGA7, VCAN; **Tabelle S5–S6**. Benchmark forte (rivista forte, 3 GSE), ma non è un pooling di effetti.
- Inkala et al. 2026 *BMC Bioinformatics* (MUUMI) 10.1186/s12859-026-06394-3: 17 dataset (11 RNA-seq) fra cui **GSE92592, GSE99621 (2)**; ensemble effect size + Fisher + rank product; top COL3A1, COL14A1, COL15A1, COL1A2; **rank completo su Zenodo 15019060**. Dataset curati: Inkala 2025 *Data Brief* 10.1016/j.dib.2025.112139.
- Kim SK et al. 2021 *BMC Pulm Med* 10.1186/s12890-021-01749-3: 13 dataset uniti (quasi tutti microarray), **GSE99621 (1)**; key driver CDK1, CDK2, CDKN1A, CDKN2A, MDM2; hub DSP, HSPA4, SPP1, VCAM1.
- Ritrattato: Qian 2021 *Biomed Res Int* 10.1155/2021/5545312.

**schizophrenia** (GSE107638, GSE112523, GSE118313, GSE121376, GSE132689, GSE182875, GSE184102, GSE191248, GSE228881, GSE263180, GSE78936, GSE80655, GSE86906; nostro n_sig = 0)
- Rebouças et al. 2025 *BMC Psychiatry* 10.1186/s12888-025-07524-6: 17 dataset (4 RNA-seq) fra cui **GSE263180, GSE112523, GSE107638 (3)**; dati uniti (SVA) + limma + random forest, cervello e sangue mescolati; geni HUWE1, PTGDS, RPL31.
- Carceller et al. 2024 *Biol Sex Differ* 10.1186/s13293-024-00635-x: **GSE80655, GSE78936 (2)** + GSE174407, GSE138082, GSE42546; REM metafor su logFC; **confronto = differenze di sesso**, non SCZ vs ctrl; Metafun-SCZ.
- Burrack et al. 2024 *Genes* (MDPI) 10.3390/genes15050609: **GSE80655 (1)** + microarray + CMC; REM Hedges g per i PDE4: PDE4B −0,25 [−0,47; −0,03]; stessa serie: GABA (Singer 2026), GRIA (Baumel 2026) in *Alpha Psychiatry*.
- Il nostro 0 significativi è coerente con effetti piccoli noti: il confronto possibile è solo sulla direzione di geni noti (PDE4B, GAD1, SST).

**multiple sclerosis** (GSE126427, GSE137619, GSE138614, GSE159225, GSE173789, GSE180760, GSE250037, GSE89843)
- Abbadessa et al. 2025 *Ann Neurol* 10.1002/ana.27216: vote-counting su 9 studi di sostanza bianca con Monte Carlo; **GSE138614 (1)** come universo di geni; hub PTPRC, HLA-B, MYC, MMP2, COL11A2, MAG; CASP1, VIM in 4/9 studi; Tabelle S6–S9 + GitHub.
- Ji et al. 2024 *Degener Neurol Neuromuscul Dis* (Dove) 10.2147/dnnd.s491211: sangue GSE17048, GSE190847, **GSE173789 (1)**; ComBat + clustering; FCRL1, BTG1, RPL38. Bassa.
- Jansen & Castorina 2023 *IJMS* 10.3390/ijms24119361: solo microarray (0). Il nostro gruppo mescola lesioni cerebrali (GSE138614) e sangue (GSE173789).

**endometriosis** (GSE118928, GSE130435, GSE135485, GSE153739, GSE153740, GSE188915, GSE212787, GSE232713, GSE87809)
- **Golinska et al. 2025 *Front Immunol* 10.3389/fimmu.2025.1619434**: network meta-analysis (netmeta su logFC/SE di limma) su 9 dataset (4 RNA-seq), fra cui **GSE153739, GSE153740, GSE232713 (3)**; PROSPERO CRD42024548098; eutopico-malate vs eutopico-sane: CCL21 su; BIRC3, CEL, LEFTY1 giù; lesione vs eutopico: C7 3,38, C3 2,40, C1QA, SERPINE1, SERPINE2, CPA3, KIT, MS4A6A, FCGR2B, S100A10, STAT5A, SERPINA5 giù; **Supplementary Dataset completo con I².** GSE153739/GSE153740 sono una coppia dello stesso gruppo (duplicato parziale anche da noi?).
- Bae et al. 2022 *Front Endocrinol* 10.3389/fendo.2022.942368: 3 microarray, **GSE135485 (1, validazione)** — uno dei nostri studi con i ruoli scambiati; geni C7, CFH, FZD7, LY96, PDLIM3, PTGIS.
- Gunther et al. 2025 *eLife* 10.7554/elife.103825: «l'eutopico non è l'endometriosi» — il contrasto va dichiarato (nostro n_sig = 62).

**SARS-CoV-2** (34 GSE, fra cui GSE147507, GSE148696/7, GSE150819, GSE151803, GSE155518, GSE164073)
- Chandrashekar et al. 2021 *Sci Rep* 10.1038/s41598-021-95733-w: **GSE147507 (NHBE), GSE150819 (organoidi, validazione) (2)** + GSE153970; DESeq2 per dataset + intersezione (73 su, 27 giù) + PPI; 43 hub: IL6, IL1B, CXCL8, MMP9, CXCL1, CSF2, CCL20, ICAM1, IL1A, CXCL2, CSF3, SAA1, NFKB2, PI3, TNFAIP3, CXCL3, CXCL5, CXCL6, EDN1, HBEGF, BCL2A1, NFKBIZ, S100A12, PLAUR, BIRC3, IL36G, LIF, SERPINB2, SPRR1A, SPRR1B, IVL, DDX58, SPRR2A, ZC3H12A, S100A9, PDGFB, IL7R, MAP3K8, IKBKE, ADAM8, GBP5 (su), MAF (giù); Table S1.
- Zhang X et al. 2023 *Front Genet* 10.3389/fgene.2023.1235927: solo **GSE147507 (1)**, 4 linee; 12 geni comuni: SAA2, BIRC3, TNFAIP2, IL32, CSF3, C1QTNF1, C3, KYNU, CXCL5, CXCL3, VNN1, SOD2.
- Nessuna meta-analisi a effetti su colture infettate trovata (161 hit, per lo più «bioinformatics and system biology» di bassa qualità; 1 ritrattato: Han 2022 *Comput Math Methods Med*).

**hypoxia** (27 studi; fra cui GSE78025, GSE104193, GSE120886, GSE149132)
- Di Giovannantonio et al. 2025 *Cell Genom* 10.1016/j.xgen.2025.100764: valuta **70 firme** su 73 serie GEO in vitro (767 campioni; fra i nostri **GSE120886, GSE104193, GSE149132**) e TCGA. Non dà DEG ma dice quale firma regge: in vitro Tardon 2020 (19 geni) con IQM ≈94%; nei tumori Buffa 2010 (51) e Ragnum 2015 (32); Buffa∩Ragnum = ADM, DDIT4, P4HA1, HILPDA.
- Shakir et al. 2026 *EMBO Rep* 10.1038/s44319-025-00651-x: riprocessa GSE153291, GSE186370, GSE81513, **GSE78025 (1)**, GSE132624 con una sola pipeline e confronta; CA9, EGLN3, JUNB, SAP30, TGFA, USP28, BCL3; dataset EV3.

**lipopolysaccharide / TNF / IFNG / TGFB1** — co-citazione dei nostri GSE: **nessuna meta-analisi** (5, 8, 4, 4 hit, tutti studi primari o fuori tema). Riferimenti utili: Chen et al. 2019 *Front Immunol* 10.3389/fimmu.2019.02887 (REM GeneMeta su 206 dataset di macrofagi, tutti microarray, 0 nostri; cDEG LPS precoce TNF, IL6, PTGS2, IL7R su; tardivo IL1B su, NOV giù; Suppl. Table 1 completa); Aybey et al. 2025 *J Transl Med* 10.1186/s12967-025-06628-7 (firme specifiche IFN tipo I vs tipo II da dati pubblici, cita uno dei nostri GSE).

## 2. Tabella riassuntiva

| entità | articoli utili (totale visti) | GSE in comune (max) | geni disponibili | nota |
|---|---|---|---|---|
| psoriasis | 3 (26) | 2 (Federico, nessuna DE) / 1 | no (on request / preprint bloccato) | — |
| Crohn Disease | 4 (116) | 3 (Metselaar, 2 geni) / 1 (Stemmer) | parziale | mega-analisi, non REM |
| Colitis, Ulcerative | 3 (67) | 2 (Rahman) | sì ma bassa qualità | Excel, p non corretto |
| Alzheimer Disease | 4 (40) | 1 | sì (ma 0 GSE nella meta-analisi seria) | riferimento di direzione |
| Parkinson Disease | 3 (13) | 1 | sì (hub PPI) | nessuna meta-analisi |
| Pre-Eclampsia | 4 (56) | 2 (Gao; Xiong) | sì (60 DEG; hub) | intersezione, p non corretto |
| nash / NAFLD | 4 (349) | 2 (Piras, REM) / 3 (Maiers, fibrosi) | **sì, liste complete** | **migliore** |
| Carcinoma, Hepatocellular | 1 (219) | 2 | 9 geni, no liste | GSE144269 invertito da noi |
| idiopathic pulmonary fibrosis | 3 (55) | **3 (He 2025)** / 2 (MUUMI) | **sì (S5–S6; Zenodo)** | **forte** |
| schizophrenia | 3 (51) | 3 (Rebouças) / 2 (sesso) | pochi | nostro n_sig = 0 |
| multiple sclerosis | 2 (43) | 1 | sì (vote-count) | tessuto ≠ sangue |
| endometriosis | 2 (24) | **3 (Golinska, netmeta)** | **sì, dataset completo** | contrasto da allineare |
| sepsis | — | — | — | non nel file |
| SARS-CoV-2 | 2 (161) | 2 (Chandrashekar) | sì (43 hub) | intersezione |
| hypoxia | 2 (26) | 3 (valutazione firme) / 1 | firme, non DEG | vedi §4 |
| LPS, TNF, IFNG, TGFB1 | 0 | 0 | — | vedi §4 |

## 3. Fattibilità del benchmark «replichiamo le meta-analisi pubblicate?»

- **Possibile in modo serio per 3 entità**: NAFLD/nash (Piras 2024: REM, 2 GSE, liste complete, contrasto malattia vs controllo), IPF (He 2025: 3 GSE, liste S5–S6; MUUMI: rank completo), endometriosi (Golinska 2025: 3 GSE, netmeta, dataset completo). **Parziale per 5**: Crohn/UC (Stemmer 2024 liste in figura; Metselaar 2 geni), PE (Gao 2023: 60 DEG), SARS-CoV-2 (43 hub), SCZ (direzione di PDE4B), HCC (dopo la correzione di GSE144269). **Non possibile per** AD, PD, MS, psoriasi (1 GSE e/o liste non pubblicate) e per i quattro stimoli (0 articoli).
- **Trappole misurate su questi articoli.** (a) Tecnologia dichiarata sbagliata: Gao 2023 e Xiong 2025 chiamano «microarray» dati HiSeq/NovaSeq (GPL11154, GPL16791, GPL24676). (b) «Hub gene» = grado in STRING, non effetto: IL6, IL1B, TNF, CXCL8 emergono per connettività a prescindere dal dato (Alghamdi, Chandrashekar, Huang). (c) Liste di 5–20 geni contro i nostri 2.000–8.000 significativi: l'intersezione non misura nulla; usare direzione concorde + posizione dei loro geni nella nostra graduatoria (AUC dello z nostro sul loro insieme, con un insieme casuale di pari numero come controllo). (d) Contrasti diversi: fibrosi F3-4 vs F0-1 (Maiers), eutopico vs sano vs lesione vs eutopico (Golinska), lesionale vs non-lesionale vs sano (psoriasi), differenze di sesso (Carceller, metafun-AD), stadi Braak (Zhang T). Prima di confrontare, dichiarare quale contrasto hanno i nostri bracci. (e) Tessuto vs sangue: MS (GSE173789 sangue, GSE138614 cervello), SCZ (Rebouças mescola), IBD (Metselaar separa, e il sangue dà SMD 5 volte più piccola). (f) Studi doppi trattati in modo diverso dagli autori: GSE93624 = GSE101794 (Stemmer esclude), GSE125583 ∩ GSE95587 89 soggetti (nessuno lo dichiara), GSE153739/GSE153740 (Golinska li tiene entrambi). (g) «Mega-analisi» (dati uniti) ≠ meta-analisi: nessun effect size per studio da confrontare con il nostro REM; solo liste. (h) Liste «on request» o solo in figura (Stemmer 2024/2026, Sucularli): non eseguibile. (i) Riviste a controllo variabile (MDPI, Frontiers, Dove, Hindawi, Sci Rep) dominano; 3 ritrattazioni incontrate (Qian 2021; Han 2022; Li 2022 EBCAM). (j) I nostri difetti noti vanno corretti prima: GSE144269 invertito, GSE135485/GSE208347 con ruoli scambiati. (k) Scelta del benchmark a posteriori: fissare articolo, contrasto, metrica e soglia PRIMA di guardare, come da regola del progetto.

## 4. Firme di consenso per gli stimoli: benchmark più solido degli «integrated analysis»

- **PROGENy** — Schubert et al. 2018 *Nat Commun* 10.1038/s41467-017-02391-6: footprint da esperimenti di perturbazione per 14 vie (TGFb, TNFa, Hypoxia, JAK-STAT, NFkB, Androgen, Estrogen, EGFR, MAPK, PI3K, p53, Trail, VEGF, WNT), pesi continui, top 100–500 geni per via. Copre TGFB1, TNF, ipossia, IFNG (JAK-STAT), DHT/R1881 (Androgen, atteso +) ed enzalutamide (Androgen, atteso −).
- **CytoSig** — Jiang et al. 2021 *Nat Methods* 10.1038/s41592-021-01274-5: matrice di risposta a 43 citochine da 20.591 profili (bulk, umano; TNFA, IFNG, IFN1, TGFB1, IL1B, IL6 inclusi secondo l'articolo; LPS non è una citochina e, per quanto ricordo, non c'è — da verificare su cytosig.ccr.cancer.gov, oggi 403 e PMC bloccato).
- **MSigDB Hallmark** — Liberzon et al. 2015 *Cell Syst* 10.1016/j.cels.2015.12.004: TNFA_SIGNALING_VIA_NFKB, INTERFERON_GAMMA_RESPONSE, INTERFERON_ALPHA_RESPONSE, HYPOXIA, EPITHELIAL_MESENCHYMAL_TRANSITION, TGF_BETA_SIGNALING, INFLAMMATORY_RESPONSE, ANDROGEN_RESPONSE (≈200 geni, quasi solo «su», senza controllo negativo interno).
- **Ipossia**: Buffa 2010 (51) 10.1038/sj.bjc.6605450; Winter 2007 (97) 10.1158/0008-5472.CAN-06-3322; Ragnum 2015 (32) 10.1038/bjc.2014.604; Lombardi 2022 (48 geni HIF conservati) 10.1016/j.celrep.2022.111652; valutazione indipendente Di Giovannantonio 2025 (sopra). Buffa/Winter sono firme *prognostiche su tumori*; per colture in vitro la stessa valutazione indica Tardon 2020 (19 geni) o Lombardi.
- **IFN**: Schoggins 2011 (≈380 ISG) 10.1038/nature09907; Interferome v2 (Rusinova 2013) 10.1093/nar/gks1215; Mostafavi 2016 10.1016/j.cell.2015.12.032; Aybey 2025 (tipo I vs tipo II specifiche) 10.1186/s12967-025-06628-7 — quest'ultima permette il controllo IFN-γ vs IFN-α.
- **LPS**: Xue 2014 *Immunity* 10.1016/j.immuni.2014.01.006 (spettro di attivazione dei macrofagi); Chen 2019 (cDEG REM, sopra); Hallmark INFLAMMATORY_RESPONSE. Immune Dictionary (Cui 2024 *Nature* 10.1038/s41586-023-06816-9) è topo e single-cell: non adatto direttamente.
- **TGF-β1 / EMT**: Padua 2008 TBRS 10.1016/j.cell.2008.01.046; Tan 2014 firma EMT generica 10.15252/emmm.201404208; Byers 2013 76 geni 10.1158/1078-0432.CCR-12-1558; Hallmark EMT; PROGENy TGFb.
- **Giudizio**: sì, sono un benchmark più solido — derivano da decine di esperimenti, hanno direzione e spesso pesi, e sono usate da migliaia di lavori — ma con tre avvertenze: (1) le firme tumorali (Buffa, Winter, EMT clinico) non sono risposte acute in vitro; (2) PROGENy/CytoSig vengono in gran parte da microarray; (3) il test giusto è specificità incrociata: la nostra IFNG deve caricare su JAK-STAT/IFNG più che su TGFb, TNF su NFkB più che su Androgen, DHT con segno + e enzalutamide con segno − sulla stessa firma androgenica. Questo controllo «positivo e negativo nello stesso tempo» nessun articolo di «integrated analysis» lo offre.

Tutti i DOI dei lavori di consenso (§4) sono stati verificati su Europe PMC il 2026-11-07; gli articoli del §1 sono letti dal testo pieno salvo dove indicato (Solvin, CytoSig).
