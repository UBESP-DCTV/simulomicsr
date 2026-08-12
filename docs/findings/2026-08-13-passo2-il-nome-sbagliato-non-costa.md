# PASSO 2 — il `canonical_name` sbagliato NON costa potenza: 9 cluster su 10.521, zero nel deliverable

**Data:** 2026-08-13 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun push · nessuna modifica al codice di produzione**

Chiude il PASSO 2 del programma di correttezza
(`docs/superpowers/specs/2026-08-10-correttezza-passo-passo-HANDOUT.md` §4) — e lo
chiude **senza toccare il resolver**, che era l'intervento piu' invasivo previsto.

---

## 1. La domanda, e perche' era rimasta aperta

Il PASSO 1 aveva stabilito che l'ID emesso dal modello **non entra** nell'identita'
delle 214: ogni ID esce da un dizionario. Restava un'ipotesi, formulata leggendo il
codice e **mai misurata**:

> Il ramo `anchor` (`R/stage3-contrast-anchor.R:700-702`) adotta l'ID dell'anchor
> **solo se tutti i token distintivi del suo `canonical_name`** compaiono nei
> valori del delta trattato (`.cg_matches_all_words`). Il `canonical_name` e'
> sbagliato su **111 righe su 214** del deliverable. Un nome sbagliato dovrebbe
> quindi **spegnere il ramo**, e l'identita' ripiegare sul testo: un errore di
> **omissione** — potenza persa, frammentazione — invece che di sostituzione.

## 2. La risposta

Sui **10.521 cluster `cgroup` non-COMBO** (l'universo dove il ramo `anchor` puo'
scattare):

| | cluster | quota | nel deliverable |
|---|---:|---:|---:|
| il nome del modello **spegne** il ramo, quello vero lo accenderebbe | **9** | 0,09% | **0** |
| il nome del modello **accende** il ramo, quello vero lo spegnerebbe | 26 | 0,25% | 2 |
| esito identico coi due nomi | 10.486 | 99,7% | — |

*(le quote su 10.521; sul sottoinsieme dei 6.866 cluster il cui ID ha un nome
ontologico risolvibile sono 0,13% e 0,38%. I due denominatori sono dichiarati
perche' danno numeri diversi, non per sceglierne uno.)*

**L'ipotesi e' misurata e cade.** Il nome sbagliato non toglie identita': i due
nomi portano allo stesso esito nel 99,7% dei casi, e dove differiscono la
differenza e' **di grafia o di sinonimo**, non di identita':

```
PLX4720          contro  PLX-4720                 (trattino)
SB431542         contro  SB 431542                (spazio)
Monosomy X       contro  Turner Syndrome          (sinonimo)
antibiotics      contro  antimicrobial agent      (sinonimo)
type 1 diabetes  contro  Diabetes Mellitus, Type 1  (forma MeSH)
2,4-Pentanedione contro  acetylacetone            (sinonimo)
```

## 3. Che cosa succederebbe davvero, se si "aggiustasse"

Dei 9 cluster che cambierebbero entita', **3** finirebbero in una chiave che
esiste gia', cioe' si fonderebbero:

| cluster (k) | confluirebbe in | k | nel deliverable |
|---|---|---:|---|
| `STR:cholangiocarcinoma` (2) | `cgroup_L5_5524cba9` | 1 | no |
| `STR:b_glucan` (1) | `cgroup_L5_3154709e` | 1 | no |
| `CHEBI:15698` (1) | `cgroup_L5_a32e5eaa` | 31 | **si** |

**Il guadagno totale sul deliverable e' UN membro in UNA meta-analisi su 214**, e
per giunta e' un caso di de-frammentazione (`CHEBI:15698` e `CHEBI:50131` sono due
schede ChEBI della decitabina), non di nome sbagliato.

**Il costo del "fix" sarebbe piu' alto del guadagno**: sostituire il nome del
modello con quello ontologico spegnerebbe il ramo su **26 cluster** dove oggi
scatta, per guadagnarlo su 9. Netto negativo, prima ancora di contare le ~9 ore di
re-cluster e le ~31 di re-pool.

> **Conclusione: il PASSO 2 si chiude senza modifiche.** L'intervento piu' invasivo
> del programma di correttezza e' stato tolto dal tavolo da una misura, non da un
> giudizio.

## 4. Lo strumento, e il suo primo tentativo sbagliato

La misura rifa' la sola prova `.cg_matches_all_words` con il nome vero dell'ID al
posto di `canonical_name`, sul primo membro di ogni cluster (che e' quello che
`ct_chr()` porta al cluster).

**⚠️ La prima versione usava il testo sbagliato**, e si e' visto da un numero che
non tornava: 173 cluster passavano la prova col nome del modello pur non avendo
`src == "anchor"`. In produzione la prova gira su `d$treated_values` — i valori del
**delta** — non su tutti i `factor_levels` del braccio trattato. Il mio testo era un
**sovrainsieme**: piu' facile da far combaciare. Ricostruito `.ca_delta` di
produzione, il disaccordo e' sparito.

> **Caso di accettazione, superato prima di riportare qualunque cifra:** sui 10.521
> cluster non-COMBO la prova rifatta coincide con il ramo scelto in produzione
> **10.521 volte su 10.521, accordo 100,000%**.
>
> Gli 81 disaccordi residui sono **tutti** `src == "COMBO"`, ed e' il codice a
> spiegarli: il ramo COMBO ritorna a `R/stage3-contrast-anchor.R:682-688`, **prima**
> del ramo `anchor`. Su quei cluster l'anchor non puo' scattare, col nome giusto o
> sbagliato — per questo sono esclusi dal denominatore.

**Un secondo artefatto, corretto prima di pubblicarlo.** Il mio risolutore copre
HGNC, ChEBI e MeSH; per `STR:`, `NCBITaxon:`, `CHEMBL:` e `UNK` (3.655 cluster,
il 34,7%) il nome vero e' `NA` e la prova fallisce **per costruzione**. Contarli
come «guadagno del nome del modello» avrebbe dato **486 invece di 26**, e sarebbe
stato falso.

## 5. Limiti

1. **Misura sui cluster che ESISTONO.** Se il ramo non scatta, l'entita' ripiega
   sul testo e il cluster nasce con un'altra chiave: si misura quale sarebbe la
   chiave corretta e se collide con una esistente. **Non** si misura un
   contro-fattuale completo — per quello servirebbe un re-cluster.
2. **Primo membro.** L'entita' e' nella chiave del cluster, quindi identica per
   tutti i membri; ma la prova `.cg_matches_all_words` dipende dai valori del
   singolo membro, e membri diversi potrebbero dare esiti diversi. Il numero e'
   quindi una stima, non un censimento.
3. **Il nome «vero» e' quello del dizionario**, che a sua volta puo' essere una
   forma poco usata (`β-<small>D</small>-glucan` per il beta-glucano, con le
   marcature HTML dentro). Dove i due nomi divergono non e' sempre il dizionario ad
   avere ragione.

## 6. Materiale

| | |
|---|---|
| misura esatta | `analysis/audit/2026-08-13-passo2/P2b-anchor-mancato-esatto.R` |
| primo tentativo, col testo sbagliato | `P2-anchor-mancato.R` (tenuto: e' la cicatrice) |
| tabella per cluster | `P2b-anchor-mancato.csv` |
| codice letto | `R/stage3-contrast-anchor.R:682-702`, `R/stage3-build.R:575-620`, `R/stage3-contrast-gate.R:343` |
