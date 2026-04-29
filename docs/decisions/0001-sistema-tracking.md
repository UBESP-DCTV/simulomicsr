# ADR-0001: Sistema di tracking decisioni

- **Status:** Accepted
- **Date:** 2026-04-29
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

Il progetto simulomicsr riparte come pipeline reale (RNAseq da repository pubblico → classificazione LLM → meta-analisi cross-studio) dopo essere stato scaffolding vuoto. La visione è ampia (almeno cinque sotto-sistemi indipendenti) e si svilupperà su molte sessioni. L'utente ha richiesto esplicitamente che ogni decisione e azione sia tracciata in modo strutturato, perché vuole derivarne in seguito il manuale utente del pacchetto/progetto.

Serve definire da subito il sistema di documentazione operativa, prima di scrivere codice o prendere altre decisioni architetturali, in modo che ogni scelta successiva si depositi nel formato concordato.

## Decision Drivers

- Ogni decisione deve essere ritrovabile, datata, motivata e correggibile in futuro senza perdere la storia
- L'output finale deve includere un manuale utente: il sistema di tracking deve produrre materiale riusabile in vignette/pkgdown
- Granularità tecnica (cosa è cambiato in un file) e granularità strategica (perché abbiamo scelto X invece di Y) sono esigenze diverse — vanno servite con artifact diversi
- Compatibilità con il workflow `superpowers` già in uso (skill `brainstorming` produce spec, skill `writing-plans` produce piani)
- Costo cognitivo basso: un sistema troppo pesante viene abbandonato

## Considered Options

1. **Sistema completo stratificato (ADR + Spec + Plan + Commit + Vignette)** — quattro artifact con ruoli distinti più l'output narrativo
2. **`JOURNAL.md` lineare** — un unico file cronologico con entry datate, niente file per decisione
3. **Solo commit atomici dettagliati** — il messaggio di commit è l'unico artifact di tracking

## Decision Outcome

Scelta: **Opzione 1 — Sistema completo stratificato**.

Motivazione: copre i due livelli (tecnico + strategico) senza confonderli, è compatibile con la skill `superpowers/brainstorming` e `superpowers/writing-plans` che già scriveranno in `docs/superpowers/specs/` e `docs/superpowers/plans/`, e produce materiale direttamente riusabile per il manuale (gli ADR sono leggibili in ordine cronologico, le spec descrivono i sotto-sistemi, le vignette ne sono la sintesi narrativa). I numeri ADR forniscono identificatori stabili da citare in commit, issue, codice.

### Stratificazione adottata

| Livello | Cosa cattura | Dove vive | Audience |
|---|---|---|---|
| **ADR** | Decisioni di scope, architettura, processo, tooling — una decisione per file | `docs/decisions/NNNN-<slug>.md` | Tu fra 6 mesi; collaboratori; base manuale |
| **Spec** | Design dettagliato di un sotto-sistema/feature | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` | Implementatore della feature |
| **Plan** | Piano d'esecuzione passo-passo derivato dalla spec | `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md` | Esecutore (anche LLM in sessione futura) |
| **Commit** | Cosa è cambiato e perché, atomico | `git log` | Archeologia tecnica (`git blame`, bisect) |
| **Vignette / pkgdown** | Manuale utente generato dagli artifact precedenti | `vignettes/`, sito pkgdown | Utenti finali del pacchetto |

### Convenzioni operative

- ADR numerati progressivamente a quattro cifre, slug kebab-case
- ADR immutabili una volta `Accepted`: per cambiare, si crea un nuovo ADR che marca il vecchio `Superseded by ADR-NNNN`
- Lingua italiana per ADR/spec/plan (allineata alla lingua di lavoro), commit message in italiano
- Ogni commit che riflette una decisione cita l'ADR rilevante (es. `Refs ADR-0001`)
- L'indice `docs/decisions/README.md` mantiene la tabella aggiornata di tutti gli ADR

### Consequences

- **Positive:**
  - Storia delle decisioni leggibile come narrativa numerata, riusabile per il manuale
  - Identificatori stabili (ADR-NNNN) da citare ovunque
  - Compatibilità nativa con superpowers (spec/plan già al posto giusto)
  - Reversibilità: una decisione cattiva si supersede senza perdere la traccia
- **Negative:**
  - Costo di disciplina: ogni decisione non banale richiede di scrivere un ADR prima di committare il codice corrispondente
  - Più file da mantenere allineati (indice + ADR singoli)
- **Neutral:**
  - La struttura di `docs/` cresce: ADR, specs, plans coesistono. Servirà tenere `docs/README.md` come mappa quando il numero di artifact diventa significativo

## Links

- Memoria progetto: feedback su tracciabilità decisioni
- Skill superpowers: `brainstorming`, `writing-plans`
- Template MADR (riferimento): https://adr.github.io/madr/
