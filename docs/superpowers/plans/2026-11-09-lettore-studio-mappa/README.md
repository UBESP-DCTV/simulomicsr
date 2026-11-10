# Mappa del piano «lettore dello studio»

Due infografiche seguono il piano `../2026-11-09-lettore-studio-tabella-dei-fattori-plan.md` (ADR-0029).

| file | per chi | che cosa è |
|---|---|---|
| `mappa-per-il-PI.pdf` | il PI | Tre pagine A4 da stampare: il percorso dei quattro piani, gli undici passi del Piano 1 con le caselle da segnare a mano, le previsioni e la regola di esito. Non dipende dallo stato. |
| `stato-del-piano.pdf` | l'agente e il PI | Lo stato di oggi: passi, cancelli, previsioni con i risultati, dubbi, registro. L'agente lo rigenera a ogni passo. |
| `stato.json` | l'agente | La fonte dello stato. È il solo file che si modifica a mano. |
| `genera.py` | l'agente | Scrive i due PDF da `stato.json`. Usa solo la libreria standard di Python e `google-chrome` in modalità headless. |

## Che cosa fa l'agente a ogni passo (Task) del piano

1. Fai il commit del passo, come dice il piano.
2. Modifica `stato.json`:
   - nel passo: `stato`, `commit` (hash corto), `data`, `nota` (una riga, solo se serve);
   - nei cancelli valutati dal passo: `stato` e `nota`;
   - nelle previsioni misurate: `risultato`, `ic95` (due numeri, oppure `null`), `esito`, `nota`;
   - `prossimo_passo`, `sessione`, `aggiornato`;
   - una riga nuova in `registro`. Non cancellare le righe vecchie;
   - un dubbio nuovo in `dubbi`, se il passo ne ha aperto uno. Un dubbio chiuso vuole `chiusura`.
3. Esegui dalla radice del repository:
   `python3 docs/superpowers/plans/2026-11-09-lettore-studio-mappa/genera.py`
4. Fai un commit con `stato.json` e `stato-del-piano.pdf`.
5. Se il PI lavora da remoto, mandagli `stato-del-piano.pdf`.

Lo script si ferma con un errore se lo stato non è coerente. Per esempio: un passo «fatto» senza commit, un esito
senza risultato, un cancello fallito senza nota. Se un cancello è fallito, il PDF lo scrive in testa.

## Valori ammessi

| campo | valori |
|---|---|
| `task[].stato` | `da_fare`, `in_corso`, `fatto`, `bloccato` |
| `cancelli[].stato` | `da_valutare`, `passato`, `fallito` |
| `previsioni[].esito` | `da_misurare`, `confermata`, `smentita`, `indeterminata` |
| `piani[].stato` | `da_scrivere`, `scritto`, `in_corso`, `chiuso` |
| `fermate[].stato` | `da_raggiungere`, `in_attesa_del_pi`, `decisa` (con `esito`) |
| `dubbi[].stato` | `aperto`, `chiuso` (con `chiusura`: spiegato, corretto, deciso, rinviato) |

`previsioni[].risultato` usa l'unità del pannello: percento per `quota`, punti percentuali per `punti`, numero di
studi per `studi`.

## Regole

- **Le previsioni non cambiano.** `atteso` e `intervallo` copiano `analysis/audit/2026-11-09-lettore-studio/00-previsioni.md`,
  che il passo 1 committa prima di ogni calcolo. Se il passo 1 scrive valori diversi da quelli di questa tabella,
  correggi `stato.json` nello stesso commit del passo 1 e scrivilo nel registro. Dopo il passo 1 quei due campi non
  si toccano più.
- **Niente contenuto degli studi di giudizio.** Nessuna nota, nessun dubbio e nessuna riga del registro contiene
  fattori, livelli, confronti o uscite del modello degli 82 studi di giudizio. Sono ammessi identificativi e conteggi.
- **La mappa del PI si rigenera solo se cambia il piano**: `genera.py --mappa-pi`. Lo script rifiuta di scriverla se
  il contenuto non sta in tre pagine. Dopo la rigenerazione guarda le pagine (`pdftoppm -r 80 -png`).
- **Piani 2, 3 e 4.** Quando un piano nuovo è scritto, aggiungi i suoi passi a `stato.json` e adatta `genera.py`
  (oggi controlla che i passi siano undici e i cancelli cinque).
- Prova di impaginazione senza toccare i file veri: `genera.py --stato <file> --uscita <cartella>`.
