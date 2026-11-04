# La ricerca di un errore, dopo H sopra 70%

Scritto il 2026-11-04, dopo il verdetto e prima di questi calcoli. Il disegno dice: «sopra 70% il valore supera quanto mi aspetto dal soffitto e va cercato un errore».
Il verdetto resta quello della regola depositata. Questi controlli non cambiano soglia, insiemi o statistica. **Se trovano un errore di calcolo, S7 si ferma e lo dice.** Se trovano un limite, il limite entra nei Methods.

Unità: la meta-analisi. Seme: 20261104. I margini sono un giudizio dell'agente, tranne T = 17%, che è la soglia del PI.

| # | controllo | che cosa escluderebbe | attesa | è un errore o un limite se |
|---|---|---|---|---|
| E1 | `rango()` del disegno, alla lettera, sui 72, con `cor(..., use = "pairwise.complete.obs")` | un errore della forma veloce | differenza massima di `P_e` sotto 1e-9 | errore se la differenza è maggiore |
| E2 | Firma dell'entità uguale alla colonna del fondo, per le entità con un solo `pert_id` misurabile | due vie di calcolo diverse | uguali | errore se diverse |
| E3 | 99 rimescolamenti dei geni sui 72 | un rango che premia il composto giusto a prescindere dalla query | `H` media 10%, in [7%; 13%] | errore se fuori |
| E4 | Firma giusta e firme sbagliate ricalcolate su 5 linee scelte a caso (20 estrazioni): i composti famosi hanno molte linee, quindi meno rumore del fondo | un vantaggio da numero di linee | `H` 19: 55% [17%; 74%]; `H_scambio`: 15% [10%; 24%] | limite se `H` scende sotto il proprio `H_scambio` o sotto 17% |
| E5 | Fondo ristretto ai composti con almeno 10 linee attive | lo stesso vantaggio, dal lato del fondo | `H` 19: 55% [17%; 74%] | limite se `H` scende sotto 17% |
| E6 | Tolta la prima componente principale del fondo da query e firme | la risposta generica, per esempio la proliferazione | `H` 19: 60% [17%; 74%]; `H_scambio`: 15% [10%; 24%] | limite se `H` scende sotto 17% |
| E7 | `H_fonti` sui soli composti che stanno anche nel deliverable (34), contro gli altri farmaci di Tahoe (108) | la selezione: nel deliverable entrano composti forti e molto studiati | sui 34 più alto che sui 108 | limite se la differenza spiega da sola il divario fra 74% e 37% |
| E8 | Correlazione di `P_e` con il numero di linee e con `tas` mediano | la dipendenza dalla forza del composto | Spearman 0,3 [0; 0,5] | limite se sopra 0,5 |
