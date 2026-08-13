# La regola che deve vedere «la genetica su un braccio solo» e' cieca quando il marcatore e' incollato

**Data:** 2026-08-13 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessuna modifica al codice di produzione · nessun run**

Nasce da una domanda dell'utente: *una manipolazione genetica e un trattamento con
una molecola non sono la stessa cosa e non vanno nello stesso mucchio — succede?*

---

## 1. La domanda, e la risposta breve

**Nel deliverable non esiste una meta-analisi che mescoli «abbiamo aggiunto la
proteina» con «abbiamo manipolato il gene».** Il verso (`gain`/`block`) sta nella
chiave di raggruppamento e separa per costruzione stimolazione e knockout.

**Ma cercando la risposta e' venuto fuori un difetto diverso**, in una regola di
produzione che esiste apposta per questo: `.rp_genetic_asymmetry()` deve scartare i
confronti in cui la modifica genetica c'e' su **un braccio solo** (e' un contrasto
rotto: cambiano due cose insieme). Quella regola, sui dati veri del deliverable,
segnala **zero** casi. Ce ne sono almeno **23**.

## 2. Il caso TNF: una mia affermazione, ritrattata

Avevo descritto la fusione proposta `HGNC:11892` + `CHEMBL:CHEMBL265582` come «il
TNF come gene e il TNF come proteina ricombinante». **E' falso**, e lo dico avendo
letto le etichette: **entrambi i lati sono proteina TNF-α aggiunta al terreno**
(`treatment=TNF-α`, `perturbation=TNFa stimulation`, «Monocytes treated with TNF»
da un lato; `treatment=TNF-alpha`, «Neutrophils stimulated with TNF-alpha»
dall'altro). Stesso verso `gain`, stesso controllo `vehicle_untreated`, stesso
`kind` `cytokine_stim`. La differenza e' **il registro che dà il codice**, non
l'esperimento. Avevo ripreso una scorciatoia scritta in un messaggio di commit
senza aprire i dati.

Nel corpus esiste anche un gruppo TNF con verso `block` (`cgroup_L5_51cb597b`):
**non puo' fondersi** con quelli di stimolazione, perche' il verso e' nella chiave.

## 3. Il criterio giusto era gia' quello applicato

La rilettura del 2026-08-05 aveva usato esattamente il criterio dell'utente — *la
modifica genetica deve essere identica sui due bracci* — e lo aveva applicato caso
per caso:

- `cgroup_L5_12228932` (EGF): «EGF vs PBS/controllo/starvation in ogni braccio,
  **con background genetico (SYK-KO/WT) e siRNA** [tenuti costanti]» → **coerente**;
- `cgroup_L5_8958b27a`: «il secondo fattore (siRNA, genotipo P53KO/WT) e' **sempre
  tenuto identico** fra trattato e controllo» → **coerente**;
- `cgroup_L5_35d1be10`: «`MCF10A_p63shRNA_Nutlin3A_5uM` ha controllo
  `MCF10A_DMSO`» → **incoerente**;
- `cgroup_L5_37942548`: «il caso KO38 (controllo `Engineered HeLa S3 cells (KO38)`
  senza equivalente esplicito nel trattato)» → segnalato.

Anche delle 8 fusioni candidate della de-frammentazione, **3 sono state respinte**
con lo stesso criterio: IL-10 e GM-CSF («5 membri su 13 misurano DIFFERENZIAZIONE
non stimolazione»), e «Compound 4» («**NON E' LA STESSA MOLECOLA**: il ponte fra i
due ID e' l'alias generico `compound4`»).

## 4. Quanto materiale geneticamente modificato c'e' nel deliverable

Misurato su tutti i 4.726 confronti delle 214, col rilevatore di produzione
`.rp_has_genetic_marker()`:

| | confronti | gruppi |
|---|---:|---:|
| marcatore genetico su **entrambi** i bracci (contesto costante) | 280 | 54 |
| marcatore su **un braccio solo** (contrasto rotto) | **0 secondo la produzione** | 0 |
| nessun marcatore | 4.446 | — |

**52 gruppi su 214 contengono sia confronti con materiale geneticamente modificato
sia confronti su cellule normali** — fra questi TGF-β1, TNF, EGF, JQ1, IFN-γ,
SARS-CoV-2, DHT, enzalutamide, LPS. **Non e' di per se' un difetto**: se la
modifica e' identica sui due bracci, cio' che cambia resta il farmaco, e la
variabilita' di contesto e' quello che τ² deve misurare. E' un fatto da dichiarare
nei Methods, non un errore da correggere.

## 5. Il difetto: `\b` non vede il confine quando il marcatore e' incollato

`.RP_GENETIC_CS_RX` e' `\\b(sh|si|sg)[A-Z][A-Za-z0-9]{1,}\\b`. Il `\b` pretende un
confine di parola **prima** di `sh`. In `p63shRNA` prima di `sh` c'e' una cifra:
niente confine, **nessun match**. Idem per `\bko\b` contro `KO2`.

| etichetta | produzione | dovrebbe |
|---|---|---|
| `shRNA p63` | TRUE | TRUE |
| **`p63shRNA`** | **FALSE** | TRUE |
| **`MCF10A_p63shRNA_Nutlin3A_5uM`** | **FALSE** | TRUE |
| **`A549siEGFR`** | **FALSE** | TRUE |
| **`MCF7 RELA KO2 + Fulvestrant`** | **FALSE** | TRUE |
| `simvastatin`, `sirolimus`, `single cell`, `shear stress` | FALSE | FALSE |

**I due casi che i lettori umani avevano trovato a occhio il 5 agosto sono
esattamente di questa forma.** La regola automatica non poteva vederli.

E' la stessa famiglia della trappola gia' pagata tre volte dal progetto (`\b` e il
carattere `_`), in una variante nuova: qui il confine manca perche' prima del
marcatore c'e' una **cifra**, non un separatore.

### La misura del costo

Con il confine allargato — `(^|[^A-Za-z])(sh|si|sg)[A-Z]…` piu' `(^|[^a-z])(ko|kd)[0-9]?` —
e con gli stessi 16 casi negativi di controllo (`simvastatin`, `sirolimus`,
`single cell`, `serum depletion`, `shear stress`, `sitagliptin`, `silica`,
`sigmoid`, `Tokyo`, `washing`, `KOH buffer`…) tutti ancora negativi:

> **23 confronti su 4.726 (0,49%), in 11 gruppi**, hanno un marcatore genetico su
> un braccio solo. La produzione ne vede **zero**.

Alcuni, letti: `MCF10A_p63shRNA_Nutlin3A_5uM` vs `MCF10A_DMSO`; `Engineered HeLa S3
cells + acido retinoico` vs `Engineered HeLa S3 cells (KO38) + DMSO`; `MDA-MB-231
Doxorubicin (overexpr…)` vs `MDA-MB-231 Untreated (overexpr…)`.

## 6. Limiti, dichiarati

1. **23 e' un limite superiore che chiede lettura umana.** Alcuni possono essere
   asimmetrie di *etichetta* e non di sostanza (il campo c'e' su entrambi i bracci
   ma scritto diversamente). Nessuno dei 23 e' stato giudicato.
2. **Il pattern allargato ha gia' un falso positivo noto**: `Kd measurement`
   (costante di dissociazione) viene preso per un knockdown. Va chiuso prima di
   metterlo in produzione.
3. **Non ho misurato la regola intera**, solo il marcatore.
   `.rp_genetic_asymmetry()` ha due esenzioni (quando il contrasto E' genetico e
   quando l'entita' del gruppo e' genetica): quante delle 23 sopravvivrebbero alla
   regola completa non e' misurato.
4. **Un primo rilevatore, scartato.** Il primo tentativo classificava il delta con
   `.ca_delta()`/`.ca_classify_key()` e dava **zero delta genetici in tutto il
   deliverable** — mentre sei gruppi delle 214 hanno un `kind` genetico. Causa:
   quelle funzioni classificano il **nome del campo**, non il contenuto, e
   `perturbation=shTP53` finisce in classe **`drug`** perche' «perturbation» sta
   nella lista dei nomi di campo del farmaco. Il caso di accettazione ha smascherato
   lo strumento prima che producesse un numero.

## 7. Materiale

`analysis/audit/2026-08-13-genetica-su-un-braccio/`: `G1-…` (il rilevatore cieco,
tenuto come cicatrice), `G2-genetica-v2.R` (quello di produzione, coi 20 casi di
accettazione), `G2-gruppi.csv`, `G2-membri.csv`, `G3-un-braccio-solo.csv` (i 23).
