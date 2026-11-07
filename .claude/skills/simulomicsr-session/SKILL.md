---
name: simulomicsr-session
description: "Protocollo di sessione del progetto simulomicsr (pipeline R di meta-analisi RNA-seq dai metadati GEO, deliverable A3 v16 con 194 meta-analisi, handout dei difetti aperti). Caricare all'inizio di OGNI sessione del progetto e per ogni altro lavoro in questo repository: quando l'utente dice sessione simulomicsr, nomina una sessione S4-S17, S12p, S7b o S7c degli handout, nomina le 194 meta-analisi, il deliverable, le 37 o le 173, oppure chiede di riprendere / continuare / andare avanti con il progetto."
type: Playbook
title: "simulomicsr: come si lavora una sessione"
status: stable
version: 1
tags:
- simulomicsr
- meta-analisi
- protocollo
- ste100
- okf
generated:
  by: simulomicsr-agent/skill-v1
  at: '2026-11-02T14:21:54+01:00'
sources:
- id: mmm-v4
  resource: "skill mmm-session v4, catalogo delle skill del PI"
  title: "Protocollo di sessione MMM v4, da cui vengono struttura e principi"
- id: ste100
  resource: https://en.wikipedia.org/wiki/Simplified_Technical_English
  title: "Simplified Technical English: sintesi delle regole. Il testo ufficiale di ASD-STE100 (Issue 9, gennaio 2025) si chiede ad asd-ste100.org e non è stato letto"
- id: okf
  resource: https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/main/SPEC.md
  title: "Open Knowledge Format v0.2"
---

# Scopo

Questo protocollo fissa come si lavora una sessione di simulomicsr. PI: Luca Vedovelli. Ogni regola esiste per un errore già pagato. Il lavoro da fare sta nell'handout. Questo file dice come farlo.[^mmm-v4]

# Da quando vale

Il protocollo vale dalla prima sessione dopo il 2026-11-02. Non è retroattivo.

- Non riscrivere finding, handout, ADR, commit e riassunti già scritti.
- Non aggiungere frontmatter o «In breve» ai documenti vecchi.
- Il prompt di una sessione nell'handout resta valido: dice che cosa fare.

# Dove sta tutto

- **Stato e regole di metodo:** `CLAUDE.md`. Non sono ripetuti qui.
- **Ordine delle sessioni e S12, S12p, S13, S15, S7c, S7b:** `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md` (comanda l'ordine). **Sessioni chiuse S1-S11 e prompt di S12b, S12c, S12d, S16, S17:** `docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md`.
- **Deliverable:** `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`. Scrivi sempre il percorso per esteso.
- **Finding:** `docs/findings/<data>-<tema>.md`. **Evidenza:** `analysis/audit/<data>-<tema>/`.

# Regole scientifiche

1. **Numeri dai file.** Rileggi ogni numero dal file che lo ha prodotto. Scrivi «tutti», «nessuno» o «solo» dopo il calcolo sull'intera tabella.
2. **Oggetto vero.** Misura il deliverable, non un proxy. Il peso è il peso REM dopo il collasso dei bracci (`.compute_study_gene_weights`), non 1/SE².
3. **Tutti i gruppi.** Non verificare a campione. Una lettura umana a campione si dichiara come tale.
4. **Riproduci prima di cambiare.** Riproduci il numero del deliverable. Poi cambia una sola cosa.
5. **Controllo positivo.** Ogni strumento ha un caso noto che deve vedere. Se non lo vede, fermati.
6. **Sensibilità.** Dichiara che cosa lo strumento vede e che cosa non vede. Un risultato nullo non prova l'assenza.
7. **Deliverable intatto.** Non modificare il deliverable, la copia su `/mnt/micron/` e i master. Non cambiare un verdetto senza una decisione del PI.
8. **La coerenza è il gate.** Non scrivere «finale» o «publication-grade» senza il gate.

# Attese: cancelli e previsioni

Scrivi le attese in `analysis/audit/<data>-<tema>/00-previsioni.md`. Committale prima del calcolo. Dopo il risultato non cambiarle. Non cambiare l'analisi per far tornare un numero.

**Cancelli** (al massimo 5). Sono controlli binari. Se un cancello fallisce, la sessione non vale. Esempi:

- il manifesto SHA-256 del deliverable passa;
- lo script riproduce il numero noto del deliverable;
- il calcolo copre 194 gruppi su 194;
- il controllo positivo risulta visto.

**Previsioni con intervallo di rilevanza.** Ogni previsione dichiara la quantità, il valore atteso e l'intervallo di rilevanza. L'intervallo è lo scarto oltre il quale cambia una scelta dell'handout o una frase dell'articolo. Giudica la stima con il suo intervallo di confidenza al 95%:

- tutta dentro l'intervallo: **confermata**, anche se lo scarto è significativo;
- tutta fuori: **smentita**. Lo scarto è un risultato e apre un dubbio;
- a cavallo di un estremo: **indeterminata**. Apre un dubbio solo se tocca una conclusione.

**Da dove viene l'intervallo.** Non esistono margini di default. Motiva ogni margine, in questo ordine:

1. una soglia del progetto (per esempio FDR < 0,05, `k_eff` ≥ 3, quota del primo studio 0,50);
2. una variabilità misurata (il test-retest delle letture, un nullo empirico);
3. un giudizio motivato. In questo caso dillo al PI.

**Incertezza.** L'unità è il gruppo o lo studio, non il gene o il campione. Dichiara unità, B e seme nelle previsioni. Il seme è la data della sessione.

# Chi decide

Il PI decide i verdetti, il gate, quali meta-analisi entrano nell'articolo, il re-run, le correzioni al deliverable e il testo dell'articolo. Il PI decide anche ogni lavoro oltre circa 4 ore di calcolo e il passaggio alla sessione successiva.

Per una decisione del PI:

1. spiega il problema in parole semplici;
2. porta tutte le opzioni reali, ognuna con la conseguenza;
3. dichiara la tua raccomandazione;
4. aspetta la risposta.

L'agente prende le decisioni tecniche e le scrive nel finding.

- **Una sessione, un obiettivo.** Se trovi altro, scrivilo nell'handout e rimandalo.
- **«Perché X?» è una domanda.** Rispondi con il motivo. Non cambiare niente.
- **I file che il PI carica sono il dato.** Controlla il contenuto del file. Non commentare come, in quanto tempo o con quale strumento il PI ha lavorato.

# Chiusura della sessione

Il verdetto è **chiusa** o **non chiusa**. «Chiusa con riserve» non esiste.

La sessione è chiusa quando non resta nessun dubbio aperto e il PI ha letto il riassunto senza aprirne di nuovi. Un dubbio è un cancello fallito, una previsione smentita, una previsione indeterminata che tocca una conclusione, un'anomalia vista durante il lavoro o una scelta del PI.

L'agente prova per primo a chiudere ogni dubbio. Porta al PI solo le scelte del PI. Un dubbio è chiuso in uno di questi quattro modi:

- **spiegato**, con il calcolo nel finding;
- **corretto**;
- **deciso** dal PI;
- **rinviato**, come ultima opzione.

Scrivi il rinvio nella sezione dell'handout della sessione che lo riceve: che cosa, perché, che cosa serve per chiuderlo. Quella sessione lo legge per primo.

# Linguaggio: stile STE in italiano, all'80%

Questo stile vale per ogni messaggio in chat al PI e per il riassunto «In breve». Non vale per codice, commit e corpo dei finding. Le regole adattano ASD-STE100 all'italiano.[^ste100]

**Che cosa vuol dire 80%.** Circa 4 frasi su 5 rispettano tutte le regole di frase. Circa una frase su 5 può uscire dalle regole, quando serve alla precisione o al legame fra due fatti. Non spezzare causa ed effetto in due frasi senza legame: scrivi «Il verdetto non vede le inversioni, perché legge solo le etichette». Un testo con sole frasi da 8 parole è troppo rigido. Se la media scende sotto 11 parole per frase, riunisci le frasi legate.

**Regole di frase**

| regola | esempio |
|---|---|
| Scrivi una sola idea per frase. Non usare il punto e virgola dentro una frase. | «Il calcolo copre 194 gruppi. Lo strumento vede il 52% degli studi.» |
| Scrivi al massimo 25 parole per frase. In un'istruzione, al massimo 20. | |
| Usa la forma attiva. Nomina chi fa l'azione. | «Il modello ha riletto i gruppi», non «i gruppi sono stati riletti» |
| Per un'istruzione usa l'imperativo. | «Apri il file.» |
| Usa presente, passato prossimo, futuro. Per un'ipotesi usa «se» e il presente. | «Se il tasso vale per tutti gli studi, sono una decina.» |
| Metti al massimo due complementi con «di» in fila. | «il peso del primo studio», non «la quota del peso dello studio del gruppo» |
| Scrivi frasi complete, con verbo e articoli. | «La sessione è chiusa», non «sessione chiusa» |

**Regole sempre valide** (lo 80% non si applica)

- Scrivi prima la conclusione, poi il dettaglio.
- Nomina sempre oggetto, numero e unità.
- Usa sempre la stessa parola per la stessa cosa. Non usare sinonimi per variare.
- Non usare metafore, modi di dire ed enfasi. Non scrivere «spegne», «il metro», «il setaccio», «il nocciolo».
- Non usare lineette come punteggiatura.
- Per un avviso, scrivi prima il comando e poi il rischio. «Non usare `--vanilla`. Senza la libreria del progetto mancano `arrow` e `devtools`.»
- Scrivi un codice interno sempre con il suo significato: «la sessione sul controllo condiviso (S4)», mai «S4» da solo.

**Paragrafi e liste.** Scrivi un argomento per paragrafo e al massimo 6 frasi. La prima frase dice l'argomento. Usa una lista verticale per tre o più elementi.

**Prima e dopo**

| prima | dopo |
|---|---|
| «Quella da sola spegne quasi tutta la meta-analisi.» | «Con quello studio invertito la meta-analisi ha 105 geni significativi. Con il segno corretto ne ha 6.590.» |
| «I 18 coerenti non sono assolti.» | «In 18 studi il metadato concorda con l'etichetta. La loro discordanza resta senza spiegazione.» |
| «Lo strumento ne avrebbe vista una solo nel 52% degli studi.» | «Lo strumento vede un'inversione nel 52% degli studi. Nel resto non la vede.» |
| «Il deliverable si riproduce esattamente prima di toccare il segno.» | «Prima ho riprodotto il deliverable: 105 geni. Poi ho cambiato il segno.» |

**Le parole**

| parola | significato | non scrivere |
|---|---|---|
| meta-analisi | il risultato di una entità nel deliverable | cluster, entry, voce |
| gruppo | gli studi che entrano in una meta-analisi | cgroup, cluster |
| studio | una serie GEO (`GSE...`) | dataset, serie |
| confronto | un trattato contro un controllo dentro uno studio | comparison, contrasto |
| braccio | un lato del confronto: il trattato o il controllo | arm |
| etichetta | il nome del braccio scritto dallo Stadio 2 | label |
| metadato | titolo, sorgente e caratteristiche del campione in GEO | stringhe grezze |
| verdetto | corretta, difettosa o incerta | giudizio |
| difetto | un errore scritto in `difetti.csv` | problema, bug |
| peso | il peso REM dello studio, dopo il collasso dei bracci | quota, contributo |

«Collasso dei bracci» e `quota_top1` restano nomi tecnici.

**Controllo.** Prima di inviare un riassunto, misura il testo. La soglia minima è 80%. Lo script vede lunghezza, passivi con agente, punto e virgola, connettivi e lineette. Non vede il significato.

```bash
python3 .claude/skills/simulomicsr-session/scripts/controlla_stile.py <file>
```

# Il riassunto «In breve»

Il riassunto è la prima cosa che il PI legge di una sessione. Deve bastare per capire e decidere. Scrivilo per ultimo, a numeri verificati, in testa al finding (sezione `# In breve`). Riportalo in chat così com'è. La forma sta in `esempi/in_breve_inversioni.md`: copia la forma, non i fatti.

**Lettore.** Il lettore conosce la statistica e la genomica. Non ricorda codici, file, sessioni e scelte passate. Scrivi il contesto che manca.

**Struttura**, sempre questa:

1. Titolo: `## In breve: <la domanda della sessione, in parole semplici>?`
2. **A cosa serviva.** Due o tre frasi: che cosa abbiamo controllato e perché conta per l'articolo.
3. **Cosa abbiamo trovato.** Al massimo 5 punti numerati. Ogni punto si apre con una frase in grassetto che dice il risultato. Chi legge solo i grassetti ha il messaggio.
4. **Cosa devi decidere.** Un punto per decisione. Il punto si apre con domanda e raccomandazione in grassetto. Poi vengono i motivi e le alternative, ognuna con la conseguenza.
5. **Comunque.** Che cosa faremo in ogni caso. Nomina il lavoro futuro per quello che fa, non con il suo codice.
6. Riga di chiusura: «Appena decidi questi N punti, la sessione è chiusa.» Senza decisioni: «Non c'è nulla da decidere: se non hai dubbi, la sessione è chiusa.» Se un cancello è fallito, il primo risultato lo dice e la riga dice che cosa serve.
7. Solo se ci sono stime di tempo: **Sui tempi di calcolo.** Chi ha fatto la stima, da quali tempi misurati, con quanti processori.

**Lingua**, più stretta che nel resto:

- Non scrivere codici: niente S4, commit, file, script, colonne, Stadio 3. Descrivi il passo per quello che fa.
- Descrivi le misure interne. Per esempio: «un solo studio porta più di metà del peso», «le 37 meta-analisi che passano tutti i controlli», «le 173 che restano valide senza gli studi difettosi».
- Tieni un numero `GSE` solo se il PI deve ritrovare quello studio.
- Scrivi un numero solo se serve a decidere o a dare la misura di un effetto. Niente intervalli e p-value: stanno nel finding.
- Se una cosa è cambiata, di' perché in una frase.

**Fuori dal riassunto**, nel finding: cancelli superati, controlli di integrità, correzioni di strumenti, durate. Un cancello fallito invece è un risultato.

**Verifica prima di inviarlo.** Controlla ogni frase sulle tabelle del finding. Rileggi ogni numero dal file. In fondo al finding metti la tabella «Da dove vengono i numeri del riassunto»: frase, file con la riga, valore letto. Un numero senza fonte non entra.

# Documentazione OKF, solo per il nuovo

Ogni finding nuovo ha un frontmatter nel formato Open Knowledge Format.[^okf] I documenti vecchi restano come sono. ADR e handout restano nel loro formato.

```yaml
---
type: Finding
title: "<in parole semplici>"
description: "<una frase>"
status: draft        # draft, stable, deprecated
generated: {by: simulomicsr-agent/skill-v1, at: <ISO 8601 con fuso>}
sources:
- {id: <id>, resource: "<percorso o URL>", title: "<titolo>"}
---
```

- Scrivi `verified: {by: human:luca-vedovelli, at: ...}` solo quando il PI ha riletto il testo. Senza questa riga il documento non è verificato. Chi lo cita lo dice.
- Rimanda una affermazione alla sua fonte con una nota `[^id]`.
- Non creare indici, registri o strumenti OKF senza una decisione del PI.

# Come si lavora una sessione

Una sessione per chat. Una sola chat alla volta sul repository.

1. **Apri.** Esegui `git status -sb && git log --oneline -n 5`. Se trovi lavoro non committato, fermati e chiedi. Fanno eccezione `renv/settings.json` e `analysis/audit/2026-08-21-S3-test-retest/umano/ISTRUZIONI.html`, un file del PI.
2. **Leggi.** Leggi la mappa dell'handout e la sezione della sessione, prima i dubbi ricevuti. Poi leggi il riassunto dell'ultimo finding.
3. **Verifica i dati.** Se la sessione legge il deliverable, esegui `analysis/audit/2026-08-21-S2-deliverable-in-salvo/10-manifesto-e-copia.sh verifica`.
4. **Di' dove siamo.** Scrivi in chat, in 5 righe, lo stato e il lavoro di questa sessione.
5. **Deposita le attese.** Scrivi cancelli e previsioni. Fai un commit separato.
6. **Calcola.** I comandi stanno in `CLAUDE.md` §3. Per un run di ore, manda un aggiornamento ogni ora.
7. **Chiudi i dubbi**, come dice la sezione sulla chiusura.
8. **Scrivi.** Scrivi il finding e l'evidenza. Scrivi il riassunto per ultimo e misuralo.
9. **Aggiorna.** Aggiorna `CLAUDE.md` §1 e il riquadro della sessione nell'handout.
10. **Committa.** Fai commit atomici in italiano. Non fare mai `git push`: lo fa il PI.
11. **Riferisci.** Manda il riassunto così com'è. Se il PI lavora da remoto, manda i file in chat. Se la sessione è chiusa, l'ultima riga è: «La sessione è chiusa. Apri la sessione S<n> e scrivi «sessione simulomicsr S<n>, leggi prima la skill di progetto».» S<n> è la sessione seguente nella mappa dell'handout. Questa riga è il segnale che il PI può andare avanti. Se la sessione non è chiusa, non scrivere questa riga: scrivi che cosa manca per chiuderla. Non aprire la sessione successiva.

# Skill collegate

`dataviz` (figure, sessione sulle figure dell'articolo), `manuscript-style-review` e `zotero-library` (Methods e limitazioni), `revisione-e-piano-implementazione` (revisione del manoscritto).

[^mmm-v4]: Protocollo di sessione MMM v4.
[^ste100]: Simplified Technical English, sintesi delle regole. Il testo ufficiale non è stato letto.
[^okf]: Open Knowledge Format v0.2.
