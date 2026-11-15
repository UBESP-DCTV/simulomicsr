<!-- Rapporto di un agente di ricerca («Letteratura LLM curazione metadati»), 2026-11-15. Testo dell'agente come consegnato: i numeri e le fonti vanno riletti alla fonte prima di citarli. -->

# Rapporto: letteratura 2025-2026 sui modelli a pesi aperti per la curazione dei metadati genomici

Data della ricerca: 2026-11-15. Non ho scritto file nel repository.

**Come leggere le marche.** «Verificato» vuol dire che ho aperto la pagina, l'abstract o il testo. Uno strumento automatico ha letto le pagine fino a 100.000 caratteri e non legge le figure. «Non verificato» vuol dire che ho solo il riassunto di un motore di ricerca. Gli articoli con PMID vengono da PubMed («Secondo PubMed»), con il DOI accanto.

## In sintesi

- Nessun lavoro misura l'estrazione dei confronti o del livello di base contro una curazione umana. Il lavoro più vicino è un preprint del laboratorio Pavlidis (agosto 2026) sui fattori sperimentali di Gemma.
- I modelli a pesi aperti con numeri nel dominio sono cinque famiglie: gpt-oss, Qwen3 con ragionamento, GLM, Gemma, Llama 3.x da 70B.
- L'accordo fra famiglie diverse alza la precisione nella letteratura generale. Gli errori restano correlati anche fra aziende diverse, quindi l'accordo riduce gli errori comuni e non li toglie.
- Nessun benchmark misura la decodifica vincolata su modelli aperti da 20 a 130B nell'estrazione da documenti lunghi.

## Domanda 1. Modelli a pesi aperti misurati sulla curazione dei metadati genomici

1. **Pavlidis, Mancarci, Maximo, Yan, Schwartz, «Detailed curation of biological samples and experimental designs for genomics using LLM-supported agentic workflows»**, bioRxiv, 2026-08-02. https://www.biorxiv.org/content/10.64898/2026.07.30.741874v1.full. **Verificato** (testo, non le figure).
   - Compito: fattori sperimentali, valori dei fattori legati a termini di ontologia, etichette dello studio. Base e confronti non hanno una misura separata.
   - Riferimento: curazione manuale di Gemma, 400 studi di sviluppo (9.859 campioni) più 100 di prova. Gli autori dicono che non è un gold standard.
   - Modelli: Claude Haiku 4.5, Sonnet 5, Opus 4.8. Modello aperto: **GLM 5.2** (Together.ai), «strong performer on the factor task, but weaker on tags», prova dichiarata preliminare, senza numeri per modello.
   - Numeri: riproduzione esatta 30/400 (7,5%). Recall dei fattori 0,98. F1 dei valori sull'ontologia 0,62. F1 delle etichette 0,45 contro un tetto dei curatori di circa 0,55. Accordo fra curatori circa 60-90%.
   - La confidenza dichiarata dal modello non separa gli errori (AUC 0,38). Un classificatore esterno arriva ad AUC 0,86 (IC95 0,74-0,90). Le omissioni sono circa il 70% delle differenze pesate. Nessun insieme di modelli. Da 1 a 3 corse per configurazione.

2. **Shintani, Andrade, Bono, «Supporting Metadata Curation from Public Life Science Databases Using Open-Weight Large Language Models»**, bioRxiv, 2026-02-18. https://www.biorxiv.org/content/10.64898/2026.02.16.706241v1. **Verificato** (testo, tabelle lette in parte).
   - Compito: 150 progetti RNA-seq di Arabidopsis, trattato con ABA contro controllo. 17 configurazioni per 2 prompt, modelli locali in LM Studio, temperatura 0.
   - Aperti: gpt-oss-120b, gpt-oss-20b, gpt-oss-safeguard-120b, Qwen3-30B-A3B e Qwen3-Next-80B-A3B (instruct e thinking), Llama 3.3, Gemma 3 27B.
   - F1 col prompt migliore: gemini-2.5-pro 1,00. gpt-5.1 0,98. **gpt-oss-120b 0,99 (migliore aperto)**. Qwen3-Next-80B thinking 0,984 (altro prompt 0,894). Qwen3-30B thinking 0,968 (0,932). Qwen3-30B instruct 0,841 e 0,712. Qwen3-Next-80B instruct 0,882 e 0,704. Ricerca per parole chiave 0,59.
   - Il risultato dipende molto dal prompt. Nessuna statistica di accordo fra modelli.

3. **Szczepaniak, Wren, «Context-aware LLM extraction and controlled-vocabulary normalization of GEO transcriptomic sample metadata»**, Research Square, 2026-08-31. Secondo PubMed, PMID 42922702, https://doi.org/10.21203/rs.3.rs-10844781/v1. **Verificato** (abstract e testo PMC). È l'unico lavoro che cita Rogic et al. (Europe PMC, **verificato**).
   - Modelli locali: **gemma-4-12B-it** e gemma-4-E2B-it su vLLM. Nessun confronto fra modelli. 804.427 campioni umani di GEO.
   - Riferimento manuale di 1.500 campioni: tessuto F1 0,997. Condizione 0,957. **Trattamento: precisione 0,976, recall 0,847, F1 0,907**. Sesso: recall 0,623.
   - Lo stesso ingresso senza contesto dà un trattamento diverso nel 16,96% dei casi. Non estrae confronti.

4. **Hak, Marchet, Gautheret, Gallopin, «Metappuccino»**, Bioinformatics 2026;42(5). Secondo PubMed, PMID 42057294, https://doi.org/10.1093/bioinformatics/btag166. **Verificato** (testo, non la figura coi numeri per modello).
   - Mistral-7B-Instruct con LoRA, 19 classi di metadati SRA. Confronto con Mistral-7B-v0.3, Llama-3.1-8B, **Llama-3.1-70B**, DeepSeek-V2, Gemma-3n-E4B, Qwen3-30B-A3B.
   - Riferimento: 400 record SRA umani più 100 di melanoma, annotati a mano. Trattamento fuori distribuzione: 0,2725 per tutti i modelli. Sulle classi esplicite i modelli forti sono pari.

5. **Ikeda et al.**, GigaScience 2025;14. Secondo PubMed, PMID 40549542, https://doi.org/10.1093/gigascience/giaf070. **Verificato**. Solo **Llama 3.1 70B** (q4_0, Ollama). 600 campioni umani di ChIP-Atlas. Linee cellulari: accuratezza 0,923, copertura 0,930 (MetaSRA 0,903 e 0,721). Altri campioni: precisione 0,940, recall 0,934.

6. **Rogic et al., Database 2026, baag041** (già noto). Secondo PubMed, PMID 42483875, https://doi.org/10.1093/database/baag041. **Verificato**. Unico modello aperto: **Llama 3.3 70B Instruct**, solo sui ceppi murini, numeri solo nelle figure (non letti).

7. **Sundaram, Gonçalves, Musen**, GigaScience 2026;15. Secondo PubMed, PMID 41773962, https://doi.org/10.1093/gigascience/giag019. **Verificato solo l'abstract**. GPT-4 con i modelli CEDAR: recall medio da 17,65% a 62,87%. LLaMA-3 e MedLLaMA2 fanno peggio, numeri non letti.

8. Lavori **senza modelli aperti** (tutti **verificati**):
   - Elucidata, sistema a più agenti con GPT-4.1, recall medio 93% su 23 campi (https://doi.org/10.1101/2025.06.10.658658).
   - MetaMuse, trattamento normalizzato al 62% (https://doi.org/10.64898/2026.04.12.718044).
   - CistromeMeta (secondo PubMed, PMID 42287723, https://doi.org/10.1093/bioinformatics/btag380).
   - Kaier et al.: Gemini 2.5 Pro 97,1%, Claude Sonnet 4 88,6%, GPT-4.1 81,9% di precisione (secondo PubMed, PMID 41527010, https://doi.org/10.1186/s13104-026-07632-w).

9. **Non verificati**: MetaHQ (arXiv 2602.07805) è un database armonizzato, non un metodo con LLM. scBaseCount e SRAgent (https://doi.org/10.1101/2025.02.27.640494): un confronto di terzi dà recall 0,80 e precisione 0,73.

**Ricerche senza risultati.** Non ho trovato:
- un benchmark di LLM contro la curazione di Expression Atlas;
- un benchmark sull'estrazione dei confronti o sull'identificazione del livello di base;
- lavori con LLM su RummaGEO, ARCHS4, GEOmetadb o GEOfetch («ALE» compare solo come riferimento in Szczepaniak e Wren);
- un benchmark di armonizzazione CELLxGENE con modelli aperti grandi.

## Domanda 2. L'accordo fra modelli diversi come filtro

1. **Kim, Garg, Peng, Garg, «Correlated Errors in Large Language Models»**, ICML 2025. https://arxiv.org/abs/2506.07962. **Verificato**.
   - Più di 350 modelli. Quando due modelli sbagliano, danno la stessa risposta sbagliata nel 60% dei casi su HELM (caso 33%) e nel 42,3% sulla classifica HuggingFace (caso circa 12%).
   - Stessa azienda: +0,066 (HuggingFace), +0,022 (HELM). Stessa architettura: +0,076.
   - «Larger and more accurate models have highly correlated errors, even with distinct architectures and providers».

2. **Romanov, Bax, Niederer**, arXiv 2608.19025, 2026-08-19. https://arxiv.org/abs/2608.19025. **Verificato** (testo del PDF).
   - Sette modelli: GPT-5.5, Opus 4.7, Gemini 3.1 Pro, Qwen3.7-Plus, Kimi K2.6, GLM-5.1, DeepSeek V4. Estrazione da 18 articoli: GPT-5.5 95,7%. I tre migliori 92,6%, gli altri quattro 86,4%. **GLM-5.1 è il migliore aperto.**
   - Lo stesso modello ripetuto cinque volte arriva a 89,2%. Il voto fra modelli diversi dà 92,1% con tre corse e 93,3% con cinque.
   - Accordo 5 a 0: 93,2% di concordanza con i revisori umani. 4 a 1: 65,0%. 3 a 2: 55,2%.
   - Nella ricerca bibliografica Qwen3.7-Plus inventa il 45% delle citazioni (27/60) e GLM-5.2 il 29% (20/69).

3. **Liu, «LLMs as a Jury»**, arXiv 2607.10139 v3, 2026-08-17. https://arxiv.org/html/2607.10139. **Verificato** (primi 100.000 caratteri).
   - Correlazione media degli errori: 0,68 con lo stesso modello ricampionato, 0,52 nella stessa famiglia (Qwen3-32B, Qwen3-Next-80B, Qwen3-235B), 0,47 fra famiglie (Qwen3-235B, DeepSeek-V3.2, Claude Sonnet 4.6, Kimi-K2.5).
   - Quota di errori comuni a tutti: da 0,000 a 0,040 in matematica, 0,143 su MMLU-Pro. Compiti di ragionamento, non di estrazione.

4. **Goel et al., «Great Models Think Alike and this Undermines AI Oversight»**, arXiv 2502.04313. https://arxiv.org/abs/2502.04313. **Verificato solo l'abstract**, senza numeri. Gli errori dei modelli diventano più simili al crescere della capacità. I giudici LLM favoriscono i modelli simili a sé.

5. **Nel dominio.** Rogic et al. (**verificato**): fra i modelli forti kappa 0,68-0,85 sui ceppi e 55-67% di predizioni identiche sulle linee cellulari. Un insieme di tre modelli per intersezione «trades coverage for precision», valori solo in figura.

6. **Non verificati**: arXiv 2411.06535 (precisione da 73,1% a 93,9% con due modelli e 95,6% con tre, su 78 casi). arXiv 2603.17111 (correlazione 0,67 dentro la famiglia, modelli visione-linguaggio).

**Vuoto.** Nessuno studio isola «stessa famiglia» contro «famiglie diverse» sull'estrazione strutturata di metadati genomici. La misura del progetto (34 studi su 47 tenuti, 0 con errore) non ha un confronto diretto in letteratura.

## Domanda 3. Conformità allo schema JSON e uscite strutturate

1. **JSONSchemaBench**, arXiv 2501.10868. https://arxiv.org/abs/2501.10868. **Verificato**.
   - Circa 10.000 schemi reali, ma solo Llama-3.1-8B e Llama-3.2-1B. Schemi difficili di GitHub: senza vincolo 0,13 di copertura. Guidance 0,41. Llamacpp 0,39. XGrammar 0,28. Outlines 0,03.
   - Qualità con e senza vincolo: 50,7 / 52,6 / 80,1% senza. Guidance 54,0 / 55,9 / 83,8%. Il vincolo non peggiora e migliora fino a 3-4 punti. Sono compiti di ragionamento breve su un modello piccolo.

2. **SOB, Structured Output Benchmark**, arXiv 2604.25359. https://arxiv.org/abs/2604.25359. **Verificato**.
   - 21 modelli, 5.000 casi di testo, contesto medio 919 token, schema nel prompt. Aperti su vLLM a temperatura 0.
   - JSON valido e accuratezza dei valori: **GLM-4.7 0,972 e 0,830 (primo)**. **Qwen3.5-35B 0,974 e 0,828**. GPT-5.4 0,999 e 0,825. Qwen3-235B 0,982 e 0,811. Claude Sonnet 4.6 0,984 e 0,809. Gemma-3-27B 0,975 e 0,803. Gemma-4-31B 0,945 e 0,798. Qwen3-30B 0,988 e 0,778. Nemotron-3-Nano-30B 0,991 e 0,774. Ministral-3-14B 0,909 e 0,724. **gpt-oss-20b 0,858 e 0,693 (ultimo)**.
   - Decodifica vincolata provata solo sull'audio con tre modelli chiusi: accuratezza da −0,007 a +0,033. L'accuratezza cala coi contesti lunghi (0,830 sul testo, 0,237 sull'audio da 7.373 token, confronto confuso dal mezzo).

3. **IFStruct v1.0**, Liquid AI, 2026-06-30. https://www.liquid.ai/blog/ifstruct-v1.0. **Verificato**, fonte di un produttore. Misura solo la struttura: gemma-4-31B-it 95,90. gpt-oss-20b 91,95. Nemotron-3-Nano-30B 86,80. Qwen3-8B 79,75.

4. **StructEval**, arXiv 2505.20139. https://arxiv.org/abs/2505.20139. **Verificato l'abstract**: migliore o1-mini a 75,58, modelli aperti circa 10 punti sotto. Nomi dei modelli aperti non verificati.

5. **«Let Me Speak Freely?»**, Tam et al., arXiv 2408.02442. https://arxiv.org/abs/2408.02442. **Verificato l'abstract**: i vincoli di formato peggiorano il ragionamento, e di più se sono stretti. La replica di dottxt è **non verificata**.

**Vuoto.** Nessun benchmark misura la decodifica vincolata contro l'uscita libera su modelli aperti da 20 a 130B nell'estrazione da documenti o tabelle. Non ho trovato numeri per Mistral Small 3.2. La letteratura non spiega l'osservazione del progetto, cioè che l'errore di lettura si sposta con la forma dell'uscita.

## Domanda 4. Lettura di tabelle e documenti lunghi

1. **Classifica Vectara delle allucinazioni**, aggiornata il 2026-10-22. https://github.com/vectara/hallucination-leaderboard/. **Verificato**. Misura riassunti di documenti brevi.
   - Tasso di allucinazione: Llama-3.3-70B 4,1%. DeepSeek-V4.1-Flash 4,2%. Mistral-Large-2411 4,5%. Mistral-Small-2501 5,1%. Gemma-4-26b-a4b 5,2%. Granite-4.0-h-small 5,2%. Qwen3-32b 5,9%. Gemma-3-27b 7,4%. Gemma-4-31b 7,4%. DeepSeek-V4-Pro 8,6%. Qwen3-235b 9,3%. Qwen3-next-80b thinking 9,3%. Nemotron-3-Nano-30B 9,6%. GLM-5 10,1%. Qwen3.5-35b 10,5%. Kimi-k2.6 10,8%. Qwen3.5-122b 11,2%. GLM-4.7 11,7%. Qwen3.5-27b 12,1%. **gpt-oss-120b 14,2%**. Mistral-3-large-2512 14,5%. Ministral-3-14b 19,4%.
   - Non ho letto una riga per Mistral Small 3.2. I modelli più nuovi e con ragionamento fanno peggio dei precedenti in questa misura.

2. **MMTU**, NeurIPS 2025, arXiv 2506.05587 v3. https://arxiv.org/html/2506.05587v3. **Verificato**. 25 compiti su tabelle.
   - GPT-5 0,696. DeepSeek-R1 0,579 (migliore aperto). DeepSeek-V3 0,555. gpt-oss-120b 0,543. Qwen3-235B thinking 0,529. Qwen3-32B thinking 0,506 (senza ragionamento 0,379). gpt-oss-20b 0,478. Llama-3.3-70B 0,454. Mistral-Large-2411 0,446. **Mistral-Small-2503 0,417**. Nessun Gemma.
   - «Performance consistently declines as the table context length increases».

3. **TeleTables**, arXiv 2601.04202. https://arxiv.org/html/2601.04202. **Verificato**. 500 domande a scelta multipla su tabelle tecniche.
   - Qwen3-32B 91,18 (migliore). SeedOSS-36B 90,91. gpt-oss-120b 90,90. gpt-oss-20b 88,04. Qwen2.5-32B 82,53. Gemma-27B 80,45. Llama-3.3-70B 80,16.
   - I modelli con ragionamento battono quelli specializzati per tabelle. Il formato HTML dà il risultato migliore per la maggior parte dei modelli.

4. **RealHiTBench**, arXiv 2506.13405. https://arxiv.org/html/2506.13405. **Verificato**. Tabelle gerarchiche. DeepSeek-R1 migliore in assoluto (82,71 sulla comprensione della struttura). Llama-3.3-70B 55,81. Qwen2.5-72B 54,55. Mistral-7B 21,21. Modelli vecchi.

5. **Non verificati o non trovati**: classifica FACTS Grounding (nessun numero per i modelli aperti). WildTableBench (arXiv 2605.01018). TABVERSE (arXiv 2606.09578). L-CiteEval (arXiv 2410.02115). Numeri MRCR v2 da aggregatori. LongBench v2 e Loong: niente.

## Che cosa ne segue per la scelta del secondo lettore

- **GLM (4.7, 5.x)** ha l'evidenza più ampia a favore: forte sui fattori nella catena di Gemma (preliminare), primo nell'accuratezza dei valori in SOB, migliore aperto in Romanov et al. Contro: 10-12% nella classifica Vectara, e servono molte GPU.
- **gpt-oss-120b** ha l'unico F1 di 0,99 su trattato contro controllo, e legge bene le tabelle (90,9 e 0,543). Contro: 14,2% nella classifica Vectara. gpt-oss-20b è ultimo in SOB.
- **Qwen3 e Qwen3.5** sono buoni solo con il ragionamento acceso (0,97-0,98 contro 0,70-0,88, tabelle 0,506 contro 0,379). Dipendono molto dal prompt. Qwen3.5-35B è secondo in SOB.
- **Gemma (3-27B, 4-12B, 4-31B)** è usato a scala su GEO, con recall del trattamento 0,847, e sta a metà classifica in SOB. Il progetto ha già misurato che Gemma-4-31B non è ripetibile al carattere.
- **Llama 3.3 70B** ha il tasso di allucinazione più basso fra i grandi aperti (4,1%) e tre usi nel dominio. Sulle tabelle è debole (0,454) ed è di una generazione vecchia.
- Evidenza contro: i Ministral, Qwen senza ragionamento, gpt-oss-20b.
- Nessun lavoro misura i confronti o il livello di base, quindi nessuna di queste evidenze sostituisce una misura sui 47 studi.
- L'accordo fra famiglie diverse ha sostegno (Kim, Liu, Romanov, Rogic), ma gli errori dei modelli più accurati restano correlati.

## Fonti

- Pavlidis et al. 2026: https://www.biorxiv.org/content/10.64898/2026.07.30.741874v1.full
- Shintani et al. 2026: https://www.biorxiv.org/content/10.64898/2026.02.16.706241v1
- Szczepaniak e Wren 2026: https://doi.org/10.21203/rs.3.rs-10844781/v1
- Hak et al. 2026: https://doi.org/10.1093/bioinformatics/btag166
- Ikeda et al. 2025: https://doi.org/10.1093/gigascience/giaf070
- Rogic et al. 2026: https://doi.org/10.1093/database/baag041
- Sundaram et al. 2026: https://doi.org/10.1093/gigascience/giag019
- Elucidata 2025: https://doi.org/10.1101/2025.06.10.658658
- MetaMuse 2026: https://doi.org/10.64898/2026.04.12.718044
- CistromeMeta 2026: https://doi.org/10.1093/bioinformatics/btag380
- Kaier et al. 2026: https://doi.org/10.1186/s13104-026-07632-w
- MetaHQ: https://arxiv.org/abs/2602.07805
- scBaseCount: https://doi.org/10.1101/2025.02.27.640494
- Kim et al. 2025: https://arxiv.org/abs/2506.07962
- Romanov et al. 2026: https://arxiv.org/abs/2608.19025
- Liu 2026: https://arxiv.org/html/2607.10139
- Goel et al. 2025: https://arxiv.org/abs/2502.04313
- Ensemble Validation 2024: https://arxiv.org/abs/2411.06535
- Hidden Clones 2026: https://arxiv.org/abs/2603.17111
- JSONSchemaBench: https://arxiv.org/abs/2501.10868
- SOB: https://arxiv.org/abs/2604.25359
- IFStruct: https://www.liquid.ai/blog/ifstruct-v1.0
- StructEval: https://arxiv.org/abs/2505.20139
- Let Me Speak Freely: https://arxiv.org/abs/2408.02442
- Classifica Vectara: https://github.com/vectara/hallucination-leaderboard/
- MMTU: https://arxiv.org/html/2506.05587v3
- TeleTables: https://arxiv.org/html/2601.04202
- RealHiTBench: https://arxiv.org/html/2506.13405
- FACTS: https://www.kaggle.com/benchmarks/google/facts (non aperto)
- Citazioni di Rogic et al.: API Europe PMC, `/MED/42483875/citations`
