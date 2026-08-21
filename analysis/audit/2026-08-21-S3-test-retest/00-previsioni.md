# S3 — Previsioni depositate PRIMA del run (2026-08-21, 23:40)

**Run:** `C3-workflow-retest.js` su **tutti e 15 i blocchi** (194 meta-analisi),
modello `claude-opus-5` (lo stesso del run originale `wf_40052108-a99`,
2026-08-19), stesso materiale (`SHA256-blocchi-letti.txt`), stessi prompt
(C1 verificato byte-identico allo script persistito del run originale).

**Che cosa si misura:** l'accordo fra il verdetto finale del run originale
(`2026-08-20-rilettura-194/verdetti-194.csv`) e quello del retest, gruppo per
gruppo, sulle 194. È il **test-retest del metodo** (lettore + due critici +
arbitro), non un confronto con un umano: quello è il punto 2 di S3, su 20 schede
cieche.

## Le previsioni, falsificabili

- **P1.** Accordo grezzo a tre classi (corretta / difettosa / incerta) fra **78% e 90%**; kappa di Cohen fra **0,55 e 0,80**.
- **P2.** Accordo binario (difettosa contro non-difettosa) **≥ 85%**.
- **P3.** «incerta» è la classe meno stabile: **meno della metà** delle 16 incerte originali resta incerta.
- **P4.** I tre totali si spostano di al più **±12** ciascuno: corrette 104–128, difettose 50–74, incerte 4–28.
- **P5.** Le coppie gruppo-studio accusate (`difetti.csv`, 97) si ritrovano nel retest per **almeno il 60%** (Jaccard ≥ 0,45).
- **P6.** Il disaccordo non è simmetrico: più gruppi passano da *corretta* a *difettosa/incerta* che il contrario (nel run originale il critico «troppo poco» ha prodotto 183 rilievi contro 69).

## La soglia di decisione, fissata ora

Dall'handout: *accordo alto* → ogni numero acquista una barra d'errore; *accordo
basso* → la rilettura va rifatta prima di tutto il resto, e l'handout va riscritto.

- **Alto:** kappa a tre classi **≥ 0,60** e accordo binario ≥ 85%.
- **Basso:** kappa **< 0,40** o accordo binario < 75%.
- **Fra 0,40 e 0,60:** zona grigia — si riporta con l'intervallo e si lascia decidere all'utente.

## Che cosa NON si fa

Nessun verdetto delle 194 viene cambiato. Il retest produce un secondo insieme
di verdetti che serve a misurare, non a sostituire.
