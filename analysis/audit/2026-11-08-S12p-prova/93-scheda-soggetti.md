# Scheda di lettura mirata: i soggetti (simulomicsr, verifica S12p, 2026-11-08)

Leggi **solo** questa scheda e i pacchetti del tuo lotto in `/home/user/S12p-soggetti-20261108/pacchetti/`. Non aprire
altri file, non cercare nel disco, non usare la rete. Ogni pacchetto descrive un confronto fra un braccio trattato
(campioni T1, T2, …) e un braccio di controllo (C1, C2, …), con i metadati GEO dei campioni.

**Una sola domanda.** Guarda i donatori, pazienti o soggetti (o le linee primarie, lotti di cellule primarie, cloni di
origine), il sesso e l'età dei campioni dei due bracci. Per ciascuno di questi tre assi, dove il testo li riporta, decidi:

- **disgiunti**: nessun valore in comune fra i due bracci (per esempio: il trattato viene solo dal paziente A, il
  controllo solo dal paziente B; oppure i malati hanno 9-17 anni e i sani 41 e 68);
- **parziali**: almeno un valore in comune, ma insiemi diversi (per esempio: i donatori P e V stanno in tutti e due i
  bracci, il donatore S solo nel trattato);
- **uguali**: gli stessi valori nei due bracci;
- **non_detto**: il testo non lo riporta per almeno un braccio.

Scrivi nel file `/home/user/S12p-soggetti-20261108/risposte/lotto-XX.jsonl` una riga JSON per pacchetto:

```
{"id": "V0123", "donatori": "parziali", "sesso": "uguali", "eta": "non_detto", "citazione": "testo esatto che decide", "nota": "al massimo 25 parole"}
```

Valori ammessi per `donatori`, `sesso`, `eta`: "disgiunti", "parziali", "uguali", "non_detto". La citazione è una copia
esatta dal pacchetto. Alla fine controlla che il file abbia una riga valida per ogni pacchetto del lotto.
