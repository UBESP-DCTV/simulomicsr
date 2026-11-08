# S12, seconda parte — i campi GEO nell'ingresso: cancelli e previsioni

**Depositate:** 2026-11-08, dopo le quattro decisioni del PI e prima di scaricare qualunque testo da GEO.
Le previsioni della prima parte (`00-previsioni.md`, commit `f8228f5`) restano come sono.

**Decisioni del PI (2026-11-08), tutte come raccomandato nel finding:**
1. l'ingresso dello Stadio 2b contiene anche `description`, `treatment_protocol_ch1` e `growth_protocol_ch1`
   di ogni campione, presi da GEO e congelati con data e SHA-256;
2. nei confronti malati contro sani i donatori diversi sono un avviso (`DONATORI_DIVERSI_CONDIZIONE`); sesso o
   età senza valori in comune restano errore;
3. i dati non detti e i casi incerti sono un avviso (`NON_DETTO_*`, `TEMPO_NON_DETTO`, `PARZIALE_` di donatore,
   sesso ed età, `AGENTE_NON_DETTO_CONTROLLO`, `ENTITA_INCERTA`);
4. la voce aperta «altre differenze» è un errore (`ALTRA_DIFFERENZA`).

Le decisioni 2-4 coincidono con la tabella `stage2b_esiti_default()` già committata (`efa44ac`): non cambia
nessun esito, cambia solo lo stato da «proposta» a «decisa». La decisione 1 cambia l'ingresso.

**Oggetto:** gli stessi 1.903 confronti, 993 studi e 15.559 campioni dei bracci della prima parte
(`20-ingressi-1903.jsonl.gz`). **Fonte nuova:** GEO, una richiesta per studio
(`acc.cgi?acc=<GSE>&targ=gsm&form=text&view=brief`, lo stesso formato verificato su 40 studi in `24-out.txt`);
per un campione che la risposta dello studio non contiene, una richiesta per campione (`targ=self`).
Testo grezzo salvato per intero, una risposta per file, con data, URL e SHA-256 in un manifesto.
**Più righe dello stesso campo** si uniscono con «,», come fa l'H5 di ARCHS4 per `characteristics_ch1` ed
`extract_protocol_ch1`. **Unità:** il confronto (P7, P8), lo studio (P9), il campione (P10).
**Seme:** 20261108 (nessuna estrazione casuale). **Cecità:** come nella prima parte; non apro i file dei 193.

## Cancelli (binari: se uno fallisce la seconda parte non vale)

| # | cancello | come si verifica |
|---|---|---|
| G1 | GEO ha risposto per 993 studi su 993; ogni risposta è salvata con SHA-256 nel manifesto | script di scaricamento, manifesto |
| G2 | Ogni campione dei bracci (15.559 su 15.559) ha il suo blocco nel testo scaricato | script di estrazione |
| G3 | Controllo positivo dell'estrazione: sui 40 studi già scaricati il 2026-11-07 (`24-studi-scelti.json`), i conteggi «presente» e «cambia fra i campioni» di `description`, `treatment_protocol_ch1` e `growth_protocol_ch1` coincidono con `24-out.txt` | script di estrazione |
| G4 | L'ingresso nuovo non perde testo: per 1.903 confronti su 1.903, ogni valore non vuoto di ogni campo (H5 e GEO) di ogni campione compare per intero | script dell'ingresso |
| G5 | Test dello Stadio 2b verdi, compresi i test nuovi sui campi GEO; nessun accession GEO nel prompt, nello schema e nei test | `testthat`, `grep` |

## Previsioni

**P7 — Confronti oltre il limite di token, con i campi GEO.** Quantità: confronti su 1.903 il cui ingresso
(prompt di sistema + testo) supera 26.624 token stimati (caratteri / 3). **Atteso: da 1 a 4.** Oggi è 1 (117
campioni). I protocolli si scrivono una volta per studio; la descrizione per campione aggiunge poco a ogni riga.
**Intervallo di rilevanza: da 0 a 19.** Motivo: lo stesso di P1; ogni confronto oltre il limite è scartato senza
lettura, e 19 confronti consumerebbero metà del margine di 40 falsi allarmi della prova.

**P8 — Token d'ingresso per confronto, con i campi GEO.** Quantità: mediana della stima dei token sui 1.903.
**Atteso: da 3.700 a 5.500** (oggi 3.603). **Intervallo di rilevanza: mediana sopra 10.000.** Motivo: lo stesso
di P3; sopra 10.000 la prova con tre modelli non sta in una notte su `poddgx02`.

**P9 — Studi in cui la descrizione cambia fra i campioni dei bracci.** Quantità: quota dei 993 studi in cui
`description` non è uguale in tutti i campioni dei bracci dei suoi confronti. **Atteso: 55%** (22 su 40 in
`24-out.txt`). **Intervallo di rilevanza: da 40% a 70%.** Motivo: è l'intervallo di Wilson al 95% della stima
su 40 studi (variabilità misurata, da 39,8% a 69,3%, arrotondato). Fuori dall'intervallo, la frase del finding
«in più di metà degli studi la descrizione porta dati per campione» va corretta, e con essa la ragione della
decisione 1.

**P10 — Titoli uguali fra GEO e H5.** Quantità: quota dei 15.559 campioni il cui `title` scaricato da GEO
coincide con il `title` dell'H5 (entrambi con la riparazione della codifica e la normalizzazione degli spazi).
**Atteso: almeno 99%.** **Intervallo di rilevanza: da 98% a 100%.** Motivo (giudizio, da dire al PI): il titolo
serve qui da controllo che il blocco GEO è quello del campione giusto, e che GEO non è cambiato dopo la copia di
ARCHS4. Sotto 98%, per più di un campione su 50 l'ingresso mescola due versioni dello stesso campione; allora i
Methods lo dicono, e i titoli diversi si leggono tutti prima della prova.
