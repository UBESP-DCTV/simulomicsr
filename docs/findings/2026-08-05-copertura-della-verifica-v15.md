# Quanto delle 214 meta-analisi di v15 è davvero verificato

**Data:** 2026-08-05 · **Deliverable:**
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/deliverable-annotato.rds`

Nasce da una domanda dell'utente: *«queste meta-analisi sono state controllate una ad
una e ci fidiamo di tutte?»*. La risposta breve è **no**, e questo documento dice
esattamente quanto è coperto, come, e dove sta il residuo.

---

## 1. `coherent` è un DEFAULT, non una lettura

`.annotate_coherence()` (`R/stage4-coherence-annotation.R:56`) assegna:

```r
clusters$coherence_verdict <- ifelse(is.na(hit), "coherent", "incoherent")
```

Cioè **tutto ciò che non compare nella lista dei problemi noti esce `coherent`**. Sui
214: **11 hanno una lettura esplicita** (marcati incoerenti), **203 hanno un default**.

Non è un difetto del codice — la lista dei verdetti è per costruzione una lista di
*incoerenze* — ma il nome della colonna invita a leggerlo come un'approvazione. Per
questo il campo di provenienza è stato riscritto e ora dice, dentro il dato stesso:

> `incoerenze da censimento-2026-07-28 + D0ter-2026-08-02; 'coherent' e un DEFAULT
> (assenza di verdetto), non una lettura`

La versione precedente diceva `rilettura-D0ter-2026-08-02`, che attestava una lettura
riguardante i 49 gruppi nuovi come se coprisse tutti e 214: **più larga del vero**.

---

## 2. La composizione poolata non è quella letta

| misura | valore |
|---|---:|
| gruppi con composizione poolata identica alla censita (`stessi_membri`) | **57 / 214** |
| gruppi con composizione diversa | **157 / 214** |
| studi censiti | 1.879 |
| studi poolati | 1.338 |
| **studi che cadono al gate dei controlli interni** | **541** |

Nessuno dei nove case study ha `stessi_membri = TRUE`: IFN-γ ha 35 studi censiti e 20
poolati, JQ1 41 → 25, DHT 34 → 23. È lo stesso fenomeno già misurato su v13
(2026-07-30: «solo 45 su 191 hanno lo stesso insieme di studi censito»).

---

## 3. L'argomento che regge, e il suo limite esatto

**L'argomento (chiusura per sottoinsiemi):** se un gruppo è stato letto e giudicato
omogeneo, e il pooling ne *toglie* studi, il sottoinsieme resta omogeneo. Vale nella
direzione «meno studi», che è la direzione sicura.

**Dove cade:** se un gruppo *acquisisce* studi che il lettore non ha mai visto.

Misurato confrontando, gruppo per gruppo, gli studi effettivamente poolati in v15 con
quelli presenti quando il gruppo fu letto:

| | |
|---|---:|
| gruppi che poolano **solo** studi già letti | **212 / 214** |
| gruppi che poolano studi **mai letti da nessuno** | **2 / 214** |

I due sono esattamente i gruppi **de-frammentati**, ed è coerente: la fusione delle
scritture ha portato dentro studi che prima stavano altrove.

- **TGFB1** `HGNC:11766`: **+10 studi mai letti in quel gruppo** — ed è la figura 2 del paper;
- **IL17A** `HGNC:5981`: **+2 studi**.

---

## 4. I 12 studi scoperti, letti uno per uno (2026-08-05)

### TGF-β1 — nove su dieci puliti

`GSE125577` (HIBEC TGFb vs Vehicle Control), `GSE137779` (TGFB vs Control), `GSE178518`
(«Vehicle A + TGFb» vs «Vehicle A» — veicolo tenuto costante), `GSE199225` (PCOS tgfb vs
PCOS no treatment), `GSE215947`, `GSE225549` (tre confronti appaiati: Post-COVID
fibrosis, IPF, donatore sano, ciascuno TGFB vs il proprio Control), `GSE232640` (LX2
trattate vs non trattate), `GSE262398` (SAEC TGFb vs DMSO), `GSE88757` (PANC-1 + TGFb
72h vs PANC-1 + Vehicle 72h).

### Il difetto: `GSE178714`

Sei confronti, di cui **quattro su cellule SMAD2/SMAD3 knockout**: TGF-β somministrato a
cellule prive dei suoi due trasduttori principali. Il confronto è appaiato *dentro* il
genotipo (KO+TGFB vs KO+untreated), quindi formalmente misura «TGF-β contro non
trattato»; **biologicamente la risposta è abolita per costruzione**, e i bracci KO pesano
il doppio dei wild-type (4 contro 2).

**Impatto misurato: 0,6% del peso del pool, posizione 41 su 59.** Il metodo si difende da
solo — le cellule che non rispondono hanno varianza alta e la pesatura per varianza
inversa le declassa. I dieci studi nuovi insieme valgono il **23,9%** del pool, e i sei
bersagli attesi reggono tutti a k=59 (SMAD7 +1,41 FDR 2,5e−22; TGFBI +2,15 FDR 4,1e−24;
SERPINE1 +2,43; COL1A1 +1,72; CCN2 +1,69; JUNB +1,22).

**Va dichiarato lo stesso**: 0,6% è piccolo, ma è un difetto noto e taciuto sarebbe un
difetto nascosto.

### IL17A — entrambi puliti

`GSE198683` (IL-17 su tre donatori vs Control) e `GSE182957` (IL17 vs coltura non
trattata).

⚠️ **Errore di misura mio, corretto prima del verdetto.** La prima lettura stampava le
etichette **troncate a 58 caratteri** — la stessa classe di errore che il progetto ha già
pagato tre volte (alias corti, lettere greche, testo troncato). Rilette per intero,
`GSE182957` contiene anche i bracci `TNFa+IL17` e `TNFalpha`, che il troncamento non
mostrava. Nel gruppo IL17A c'è **solo** il braccio IL-17 puro, quindi il verdetto non
cambia — ma senza rileggere sarebbe stato dato su mezza frase.

---

## 5. Che cosa si può dire, e che cosa no

**Si può dire:**

- 11 gruppi sono dichiarati incoerenti e restano nel deliverable marcati come tali;
- 212 su 214 poolano solo studi già letti: il giudizio regge **per argomento**;
- i 2 scoperti sono stati letti a mano il 2026-08-05, con un difetto trovato e quantificato;
- nessuno dei 214 è entrato senza che il suo gruppo avesse una lettura alle spalle.

**Non si può dire** che ogni gruppo sia stato riletto sulla propria composizione poolata
vera. Sarebbe una fase di lettura a sé, su 214 gruppi, e oggi non esiste.

**Per i Methods:** la chiusura per sottoinsiemi è un **argomento**, non una misura, e va
scritta come tale — accanto al numero che la delimita (212 su 214, con i 2 residui letti
a parte).
