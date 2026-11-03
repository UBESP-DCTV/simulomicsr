# Sessione S5, il gate e i due insiemi (2026-11-03)

Finding: `docs/findings/2026-11-03-S5-gate-e-insiemi.md`. Opzioni e scelta del PI:
`analysis/audit/2026-08-21-decisioni/S5-opzioni.md`. Cancelli e previsioni: `00-previsioni.md`.

Solo misura: il deliverable, la copia su micron e la cache delle conte restano come sono.
I file pesanti stanno in `/mnt/micron/simulomicsr-dati/2026-11-03-S5-gate-e-insiemi/` e si rifanno con
gli script. Si lancia dalla radice del repository, con `Rscript` senza `--vanilla`, nell'ordine dei numeri.

| script | che cosa fa |
|---|---|
| `10-dispatch.R` | dispatch di produzione col gate a 3 e a 2, su deliverable e riferimento |
| `20-fit-bracci.R` | fit per nome dei 893 bracci; `catena.sh` lancia 20, 30, 35, 40, 42 |
| `30-rem-k2.R` | REM dei 282 gruppi a due studi, T0 e T1, e dominanza |
| `35-riproduzione-194.R` | cancello 3 sulle 194 |
| `40-incertezza.R`, `41-q-profile.R` | intervalli Q-profile, Knapp-Hartung, intervallo di predizione |
| `42-controllo-positivo.R`, `43-spiega.R` | cancello 5, 5-bis, spiegazione delle previsioni smentite |
| `45`, `46`, `47`, `48` | studi doppi: correlazione, impronta esatta (scartata), distanza L1, effetto |
| `50-insiemi.R` | setaccio, le 41 e le 173, seconda lettura |
| `60-movimento.R` | movimento fra le due esecuzioni con i due gate |
| `70-senza-dominante.R` | rimozione dello studio più pesante sulle 173 |
| `72`, `73`, `74` | controllo negativo con studi non collegati, poi appaiato per precisione |
| `80-tavole.R` | tavole dei due insiemi per il file delle opzioni |
