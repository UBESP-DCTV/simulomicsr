# C in parole semplici — Stadio 2 senza spezzare gli studi

Companion leggibile di ADR-0020 + spec 2026-06-02. Niente sigle.

## Il problema, in una frase

Lo Stadio 2 deve guardare uno studio **intero** per capire il disegno (chi è
trattato, chi è controllo, chi è replicato di chi). Ma quando uno studio ha
tanti campioni, il modello non li tiene tutti in testa insieme, così oggi lo
tagliamo a fette da 50. Vedendo solo una fetta, il modello non capisce il
disegno completo e fa errori che a valle rovinano l'analisi.

## L'idea della soluzione

Uno studio da 5.000 campioni in realtà ha pochissime **situazioni diverse** —
in media **13** (es. "trattato 24h", "controllo", "trattato 48h"...). Tutto il
resto sono **repliche** della stessa situazione.

Quindi invece di dare al modello 5.000 campioni a fette, gli diamo **le 13
situazioni distinte, tutte insieme**, una volta sola. Ci stanno comodamente nel
contesto. Il modello capisce il disegno intero in un colpo, senza spezzarlo.
Poi noi "ri-gonfiamo": l'etichetta che il modello ha dato a una situazione la
applichiamo a tutti i campioni che ne fanno parte.

Bonus: raggruppare per situazione fa già metà del lavoro (le repliche sono già
insieme), quindi il modello ha un compito più piccolo e più affidabile.

## Cosa NON cambia

- Lo **Stadio 1** (un campione alla volta) resta identico. Il lavoro fatto sui
  508.037 campioni è ancora buono.
- Lo schema dei risultati Stadio 2 resta lo stesso.

## Cosa cambia

- Come prepariamo l'input dello Stadio 2 (situazioni invece di fette).
- Una piccola modifica al prompt dello Stadio 2 (ti chiedo l'OK prima, come
  abbiamo fatto per lo Stadio 1).
- Va **ri-eseguito** lo Stadio 2 (= si rifà F3), poi F4.

## La domanda delicata — DECISA (2026-06-04)

Cosa fa "situazione diversa"? La firma è la **sola condizione sperimentale**:
tessuto, malattia, farmaco/dose/tempo, e la condizione clinica/risposta/stadio/
visita del paziente. **Escludiamo** donatore, età, sesso, etnia: sono identità
individuale, non disegno. (Se in futuro emergesse uno studio disegnato apposta
su sesso/età come fattore, lo gestiremo come eccezione — vedi rischi.)

## Rischi onesti

- Se la "situazione" è troppo grossolana → fondo cose diverse → disegno
  sbagliato. Lo verifichiamo sul gold dei 72 studi prima di lanciare.
- Se è troppo fine → non comprimo abbastanza per una manciata di studi enormi
  (~9 studi su 1.659). Per quelli decidiamo una gestione a parte.

## Costo

Ri-fare lo Stadio 2, ma su record compatti (13 situazioni invece di migliaia di
campioni a fette): atteso **più veloce** del run F3 attuale, non più lento.
