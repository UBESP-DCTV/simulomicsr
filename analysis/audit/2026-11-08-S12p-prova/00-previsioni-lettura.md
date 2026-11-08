# S12p, seconda parte — la lettura dei falsi allarmi: cancelli e previsioni

**Depositate:** 2026-11-08, dopo il conto (commit `126a282`, `042c2e7`) e prima che un lettore apra un pacchetto.
**Decisione del PI (2026-11-08):** si leggono i falsi allarmi di Gemma **e** di Mistral (handout S12p, punto 5).

**Che cosa si legge.** 1.236 pacchetti, costruiti da `60-pacchetti.R` in `/home/user/S12p-lettura-20261108/`
(fuori dal repository; impronte in `61-manifesto-pacchetti.sha256`):

| gruppo | n | perché |
|---|---|---|
| confronti puliti accusati da Mistral o da Gemma, con almeno un'affermazione | 988 | la misura (338 accusati da tutti e due; i 3 accusati solo per ingresso oltre il limite non hanno nulla da leggere) |
| difetti del riferimento presi da Mistral o da Gemma | 188 | controllo positivo dei lettori |
| confronti puliti che nessuno dei tre modelli accusa, 60 a caso (seme 20261108) | 60 | quanto sono severi i lettori dove nessuno accusa (campione, dichiarato) |

**Cecità.** I pacchetti hanno un identificativo opaco e un ordine mescolato; non contengono l'accession del
confronto; le affermazioni dei due modelli sono anonime («Source 1», «Source 2», assegnate a caso per pacchetto).
I lettori non sanno quali confronti sono difettosi nel riferimento. La chiave sta fuori dalla cartella dei lettori e
entra nel repository dopo la lettura.

**I lettori.** Agenti di revisione interna (Claude, stesso modello della sessione), 42 lotti da circa 30 pacchetti,
uno per agente, con la scheda `SCHEDA.md` (copia in `61-scheda-lettura.md`). Nessun Claude entra nella pipeline o
nella validazione pubblicata: la lettura serve a scegliere la strada.

**Come si classifica un falso allarme del modello M** (dalla lettura, dopo, senza cambi):

- **riferimento**: il lettore dice «non confrontabile» (il confronto ha un difetto che il riferimento non contiene);
- **modello**: il lettore dice «confrontabile» e almeno un'affermazione di M è «falso»;
- **regola**: il lettore dice «confrontabile» e tutte le affermazioni di M sono «vero» o «non verificabile», nessuna
  con «conta = si» (la regola accusa per un fatto vero che non è un difetto);
- **incerto**: il lettore dice «incerto», oppure dice «confrontabile» ma un'affermazione vera «conta = si».

**Unità:** il confronto; per le quote di affermazioni, bootstrap sui confronti (B = 2.000, seme 20261108);
intervallo di Wilson al 95% sulle frazioni di confronti.

## Cancelli

| # | cancello | come si verifica |
|---|---|---|
| L1 | 1.236 pacchetti su 1.236 hanno una risposta valida (forma della scheda, una voce per ogni affermazione) | script di aggregazione |
| L2 | Controllo positivo: sui difetti del riferimento letti (esclusi i difetti «non provati»), i lettori rispondono «no» in almeno l'80% | script di aggregazione |
| L3 | Ambiente: ogni lettore apre solo la scheda, il suo lotto e i suoi pacchetti, e scrive solo il suo file di risposta | i transcript degli agenti, dopo |

Motivo della soglia di L2 (giudizio, da dire al PI): la rilettura delle 194 ha misurato un accordo test-retest con
kappa 0,78 e un accordo con il PI di 18 su 19. Se i lettori riconoscono meno di 4 difetti noti su 5, la loro risposta
«confrontabile» sui falsi allarmi non basta a dire chi sbaglia.

## Previsioni

**R1 — Difetti veri fra i falsi allarmi di Gemma.** Quantità: quota dei 360 falsi allarmi di Gemma con affermazioni
che i lettori giudicano «non confrontabili». **Atteso: 20%.** **Intervallo di rilevanza: da 10% a 100%.** Motivo
(giudizio): sopra il 10% il riferimento manca una parte non piccola dei difetti, e va rivisto prima di misurare
qualunque versione nuova; sotto, il riferimento regge e i falsi allarmi sono errori del passo.

**R2 — Difetti veri fra i falsi allarmi di Mistral.** Quantità: la stessa quota sui 962 falsi allarmi di Mistral
con affermazioni. **Atteso: 12%.** **Intervallo di rilevanza: da 10% a 100%.** Motivo: lo stesso di R1.

**R3 — La malattia scritta come agente.** Quantità: fra le affermazioni `CONDIZIONE_CON_AGENTE` dei falsi allarmi di
Mistral, quota giudicata «falso». **Atteso: 85%.** **Intervallo di rilevanza: da 70% a 100%.** Motivo (giudizio):
sopra il 70% l'errore è del modello, che scrive la condizione del donatore come un agente applicato, e la correzione
riguarda il prompt o la regola su questo caso; sotto, la causa è un'altra.

**R4 — La voce aperta «altre differenze».** Quantità: fra le affermazioni `ALTRA_DIFFERENZA` dei falsi allarmi di
Mistral, quota con «fatto = vero» e «conta = no». **Atteso: 50%.** **Intervallo di rilevanza: da 40% a 100%.** Motivo
(giudizio): sopra il 40% la voce aperta trattata come errore (decisione 4 del PI in S12) produce soprattutto accuse su
fatti veri che non sono difetti, e quella decisione va riconsiderata per primo.

**R5 — Severità dei lettori dove nessuno accusa (campione).** Quantità: quota dei 60 puliti non accusati che i
lettori giudicano «non confrontabili». **Atteso: 5%.** **Intervallo di rilevanza: da 0% a 10%.** Motivo: sopra il 10%
i lettori trovano difetti anche dove nessun modello accusa; allora R1 e R2 vanno letti contro questa base.
