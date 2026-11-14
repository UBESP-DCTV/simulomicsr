## T1. Le 17 corse: chiusura e misure contro Atlas

`V-fable corsa 1` è la corsa fermata dal limite di spesa (3 studi senza chiamata); `V-fable corsa 1b` è la stessa corsa con i tre studi completati.

| corsa | chiusi su 47 | (a) gruppi identici su 47 | (b) ritrovati | (b) su 97 | (c) errori / giudicabili | non valide | valide non chiuse | rifiuti | dollari |
|---|---|---|---|---|---|---|---|---|---|
| T-haiku corsa 1 | 47 | 38 | 71/95 | 71/97 | 3/18 | 0 | 0 | 0 | 0,21 |
| T-haiku corsa 2 | 46 | 38 | 68/95 | 68/97 | 1/22 | 1 | 0 | 0 | 0,22 |
| T-sonnet corsa 1 | 46 | 39 | 72/95 | 72/97 | 1/21 | 0 | 1 | 0 | 1,79 |
| T-sonnet corsa 2 | 46 | 38 | 70/95 | 70/97 | 1/24 | 1 | 0 | 0 | 1,82 |
| T-opus corsa 1 | 45 | 37 | 69/95 | 69/97 | 2/22 | 1 | 1 | 0 | 3,72 |
| T-opus corsa 2 | 47 | 38 | 67/95 | 67/97 | 2/33 | 0 | 0 | 0 | 3,63 |
| T-fable corsa 1 | 44 | 35 | 60/95 | 62/97 | 2/34 | 0 | 1 | 2 | 8,65 |
| T-fable corsa 2 | 45 | 36 | 65/95 | 67/97 | 2/31 | 0 | 0 | 2 | 8,68 |
| V-haiku corsa 1 | 46 | 37 | 72/95 | 72/97 | 1/19 | 0 | 1 | 0 | 0,14 |
| V-haiku corsa 2 | 47 | 39 | 68/95 | 68/97 | 3/20 | 0 | 0 | 0 | 0,14 |
| V-sonnet corsa 1 | 47 | 39 | 72/95 | 72/97 | 2/25 | 0 | 0 | 0 | 1,36 |
| V-sonnet corsa 2 | 47 | 38 | 70/95 | 70/97 | 2/23 | 0 | 0 | 0 | 1,32 |
| V-opus corsa 1 | 47 | 38 | 72/95 | 72/97 | 2/32 | 0 | 0 | 0 | 2,70 |
| V-opus corsa 2 | 47 | 38 | 72/95 | 72/97 | 2/30 | 0 | 0 | 0 | 2,67 |
| V-fable corsa 1 | 43 | 36 | 69/95 | 71/97 | 2/26 | 0 | 0 | 1 | 6,48 |
| V-fable corsa 1b | 46 | 37 | 69/95 | 71/97 | 2/31 | 0 | 0 | 1 | 7,23 |
| V-fable corsa 2 | 46 | 37 | 69/95 | 71/97 | 2/38 | 0 | 0 | 1 | 7,18 |

Termini di paragone: metodo di oggi 14/47 e 13/95; Mistral-Small 3.2 forma `B0` 45 chiusi, 36/47, 68/95, 2/33; Mistral-Small 3.2 schema v1 34 chiusi, 31/47, 50/95, 0/4.

## T2. Differenza appaiata nei confronti ritrovati (b), punti percentuali, IC95 per studio

| corsa | Claude % | Mistral stessa forma % | Claude meno Mistral | esito | Claude meno oggi |
|---|---|---|---|---|---|
| T-haiku corsa 1 | 74,7 | 71,6 | +3,2 (-6,5, +12,5) | a cavallo di 0 | +61,1 (+44,9, +74,7) |
| T-haiku corsa 2 | 71,6 | 71,6 | +0,0 (-17,9, +18,0) | a cavallo di 0 | +57,9 (+39,8, +73,3) |
| T-sonnet corsa 1 | 75,8 | 71,6 | +4,2 (-11,8, +20,0) | a cavallo di 0 | +62,1 (+45,5, +75,3) |
| T-sonnet corsa 2 | 73,7 | 71,6 | +2,1 (-17,6, +20,4) | a cavallo di 0 | +60,0 (+42,7, +74,0) |
| T-opus corsa 1 | 72,6 | 71,6 | +1,1 (-16,9, +17,7) | a cavallo di 0 | +58,9 (+41,7, +73,3) |
| T-opus corsa 2 | 70,5 | 71,6 | -1,1 (-19,0, +16,0) | a cavallo di 0 | +56,8 (+39,3, +72,3) |
| T-fable corsa 1 | 63,2 | 71,6 | -8,4 (-29,6, +12,3) | a cavallo di 0 | +49,5 (+29,5, +67,3) |
| T-fable corsa 2 | 68,4 | 71,6 | -3,2 (-21,1, +14,7) | a cavallo di 0 | +54,7 (+35,5, +71,4) |
| V-haiku corsa 1 | 75,8 | 52,6 | +23,2 (+6,1, +41,0) | sopra 0 | +62,1 (+46,8, +74,0) |
| V-haiku corsa 2 | 71,6 | 52,6 | +18,9 (+2,6, +35,4) | sopra 0 | +57,9 (+40,3, +72,6) |
| V-sonnet corsa 1 | 75,8 | 52,6 | +23,2 (+8,5, +37,4) | sopra 0 | +62,1 (+45,5, +75,3) |
| V-sonnet corsa 2 | 73,7 | 52,6 | +21,1 (+4,2, +36,6) | sopra 0 | +60,0 (+42,9, +74,1) |
| V-opus corsa 1 | 75,8 | 52,6 | +23,2 (+6,6, +38,6) | sopra 0 | +62,1 (+45,3, +75,6) |
| V-opus corsa 2 | 75,8 | 52,6 | +23,2 (+6,6, +38,6) | sopra 0 | +62,1 (+45,3, +75,6) |
| V-fable corsa 1 | 72,6 | 52,6 | +20,0 (+3,1, +35,8) | sopra 0 | +58,9 (+41,7, +73,1) |
| V-fable corsa 1b | 72,6 | 52,6 | +20,0 (+3,1, +35,8) | sopra 0 | +58,9 (+41,7, +73,1) |
| V-fable corsa 2 | 72,6 | 52,6 | +20,0 (+3,1, +35,8) | sopra 0 | +58,9 (+41,7, +73,1) |

## T3. Errori di lettura del modello per corsa (studi su 47)

«Largo»: l'errore costa gruppi o confronti del lettore (regole R1-R4 scritte dopo la revisione). «Col precedente»: lo stesso conto se la base non scritta resta senza costo, come nella sessione sulle cause (S12r4). «Stretto»: l'errore cambia la misura contro Atlas.

| corsa | largo | col precedente | stretto | solo senza costo | errori di forma | rifiuti | fermati | studi (largo) | studi (stretto) | studi (forma) | studi (rifiuto) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T-haiku corsa 1 | 4 | 3 | 1 | 3 | 1 | 0 | 0 | GSE50760 GSE57945 GSE60340 GSE93624 | GSE57945 | GSE147507 |  |
| T-haiku corsa 2 | 6 | 5 | 3 | 3 | 2 | 0 | 0 | GSE50760 GSE57945 GSE58365 GSE60340 GSE69597 GSE71595 | GSE58365 GSE69597 GSE71595 | GSE147507 GSE67812 |  |
| T-sonnet corsa 1 | 4 | 3 | 1 | 0 | 2 | 0 | 0 | GSE50760 GSE57945 GSE60340 GSE69597 | GSE69597 | GSE147507 GSE93624 |  |
| T-sonnet corsa 2 | 4 | 3 | 1 | 0 | 2 | 0 | 0 | GSE50760 GSE57945 GSE60340 GSE69597 | GSE69597 | GSE147507 GSE66207 |  |
| T-opus corsa 1 | 2 | 1 | 1 | 3 | 3 | 0 | 0 | GSE57945 GSE69597 | GSE69597 | GSE147507 GSE83687 GSE93624 |  |
| T-opus corsa 2 | 3 | 3 | 3 | 2 | 1 | 0 | 0 | GSE65335 GSE69597 GSE71595 | GSE65335 GSE69597 GSE71595 | GSE147507 |  |
| T-fable corsa 1 | 3 | 3 | 3 | 4 | 1 | 2 | 0 | GSE46665 GSE69597 GSE71595 | GSE46665 GSE69597 GSE71595 | GSE112057 | GSE147507 GSE71421 |
| T-fable corsa 2 | 3 | 3 | 3 | 3 | 0 | 2 | 0 | GSE46665 GSE69597 GSE71595 | GSE46665 GSE69597 GSE71595 |  | GSE147507 GSE71421 |
| V-haiku corsa 1 | 4 | 3 | 2 | 3 | 1 | 0 | 0 | GSE50760 GSE57945 GSE65335 GSE93624 | GSE57945 GSE65335 | GSE68919 |  |
| V-haiku corsa 2 | 7 | 5 | 4 | 3 | 0 | 0 | 0 | GSE50760 GSE57945 GSE58365 GSE60340 GSE65335 GSE71595 GSE93624 | GSE57945 GSE58365 GSE65335 GSE71595 |  |  |
| V-sonnet corsa 1 | 4 | 2 | 1 | 0 | 0 | 0 | 0 | GSE57945 GSE60340 GSE69597 GSE93624 | GSE69597 |  |  |
| V-sonnet corsa 2 | 5 | 3 | 1 | 1 | 0 | 0 | 0 | GSE52778 GSE57945 GSE60340 GSE69597 GSE93624 | GSE69597 |  |  |
| V-opus corsa 1 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | GSE57945 GSE69597 | GSE69597 |  |  |
| V-opus corsa 2 | 3 | 2 | 1 | 2 | 0 | 0 | 0 | GSE57945 GSE60340 GSE69597 | GSE69597 |  |  |
| V-fable corsa 1 | 2 | 2 | 2 | 2 | 0 | 1 | 3 | GSE46665 GSE69597 | GSE46665 GSE69597 |  | GSE71421 |
| V-fable corsa 1b | 3 | 3 | 2 | 3 | 0 | 1 | 0 | GSE46665 GSE69597 GSE83687 | GSE46665 GSE69597 |  | GSE71421 |
| V-fable corsa 2 | 3 | 3 | 2 | 2 | 0 | 1 | 0 | GSE46665 GSE69597 GSE93624 | GSE46665 GSE69597 |  | GSE71421 |

## T4. Le due corse dello stesso modello e della stessa forma

| coppia | largo | largo, almeno una | largo, tutte e due | stretto | stretto, almeno una | stretto, tutte e due | ritrovati su 95 | uscita identica al carattere (P14) | stessa tabella, gruppi e confronti (P15) | stessi gruppi | stessi confronti |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T-haiku corsa 1 e 2 | 4 e 6 | 7 | 3 | 1 e 3 | 4 | 0 | 71 e 68 | 1 | 29 | 43 | 39 |
| T-sonnet corsa 1 e 2 | 4 e 4 | 4 | 4 | 1 e 1 | 1 | 1 | 72 e 70 | 18 | 39 | 44 | 41 |
| T-opus corsa 1 e 2 | 2 e 3 | 4 | 1 | 1 e 3 | 3 | 1 | 69 e 67 | 8 | 35 | 44 | 39 |
| T-fable corsa 1 e 2 | 3 e 3 | 3 | 3 | 3 e 3 | 3 | 3 | 60 e 65 | 9 | 40 | 46 | 45 |
| V-haiku corsa 1 e 2 | 4 e 7 | 7 | 4 | 2 e 4 | 4 | 2 | 72 e 68 | 0 | 25 | 43 | 39 |
| V-sonnet corsa 1 e 2 | 4 e 5 | 5 | 4 | 1 e 1 | 1 | 1 | 72 e 70 | 15 | 41 | 46 | 46 |
| V-opus corsa 1 e 2 | 2 e 3 | 3 | 2 | 1 e 1 | 1 | 1 | 72 e 72 | 11 | 36 | 47 | 45 |
| V-fable corsa 1b e 2 | 3 e 3 | 4 | 2 | 2 e 2 | 2 | 2 | 69 e 69 | - | - | - | - |
| V-fable corsa 1 e 2 | 2 e 3 | 3 | 2 | 2 e 2 | 2 | 2 | 69 e 69 | 7 | 38 | 44 | 43 |

La ripetibilità (ultime quattro colonne) è misurata dal programma depositato sulle 16 corse: per Fable con lo schema v1 confronta la corsa 1 fermata e la corsa 2.

## T5. Per studio: in quante delle 17 corse c'è un errore di lettura che costa (largo)

| studio | corse con l'errore (largo), su 17 | corse con l'errore (stretto), su 17 |
|---|---|---|
| GSE69597 | 14 | 14 |
| GSE57945 | 11 | 3 |
| GSE60340 | 8 | 0 |
| GSE50760 | 6 | 0 |
| GSE93624 | 6 | 0 |
| GSE46665 | 5 | 5 |
| GSE71595 | 5 | 5 |
| GSE65335 | 3 | 3 |
| GSE58365 | 2 | 2 |
| GSE52778 | 1 | 0 |
| GSE83687 | 1 | 0 |

Studi con un errore che costa in almeno una corsa: 11 su 47. Corse senza un errore di lettura che costa: 0 su 17.

## T6. Previsioni depositate, corsa 1 (ordine: Haiku / Sonnet / Opus / Fable)

|  | forma | quantità | atteso | misurato | esito |
|---|---|---|---|---|---|
| P1 | T | studi non chiusi | 9 / 5 / 4 / 3 | 0 / 1 / 2 / 3 | confermata |
| P1 | V | studi non chiusi | 6 / 3 / 2 / 2 | 1 / 0 / 0 / 4 | confermata |
| P2 | T | uscite non valide contro lo schema | 6 / 2 / 2 / 1 | 0 / 0 / 1 / 0 | confermata |
| P2 | V | uscite non valide contro lo schema | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P3 | T | rifiuti | 0 / 0 / 0 / 1 | 0 / 0 / 0 / 2 | confermata / confermata / confermata / smentita |
| P3 | V | rifiuti | 0 / 0 / 0 / 1 | 0 / 0 / 0 / 1 | confermata / confermata / confermata / smentita |
| P4 | T | uscite troncate | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P4 | V | uscite troncate | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P5 | T | uscite con un recinto di codice | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | confermata |
| P6 | T | (a) quota di studi con partizione identica | 31/47 / 36/47 / 38/47 / 39/47 | 38 / 39 / 37 / 35 | confermata |
| P6 | V | (a) quota di studi con partizione identica | 33/47 / 37/47 / 39/47 / 39/47 | 37 / 39 / 38 / 36 | confermata |
| P7 | T | (b) confronti ritrovati su 95 | 56 / 68 / 72 / 74 | 71 / 72 / 69 / 60 | - |
| P7 | V | (b) confronti ritrovati su 95 | 58 / 68 / 72 / 74 | 72 / 72 / 72 / 69 | - |
| P8 | T | Claude meno Mistral nella stessa forma, (b) | -13 punti / +0 punti / +4 punti / +6 punti | +3,2 / +4,2 / +1,1 / -8,4 | a cavallo di 0 |
| P8 | V | Claude meno Mistral nella stessa forma, (b) | +8 punti / +19 punti / +23 punti / +25 punti | +23,2 / +23,2 / +23,2 / +20,0 | sopra 0 |
| P9 | T | Claude meno oggi, (b) | sopra 0 / sopra 0 / sopra 0 / sopra 0 | +61,1 / +62,1 / +58,9 / +49,5 | sopra 0 |
| P9 | V | Claude meno oggi, (b) | sopra 0 / sopra 0 / sopra 0 / sopra 0 | +62,1 / +62,1 / +62,1 / +58,9 | sopra 0 |
| P10 | T | (c) errori fra i non elencati | 3% / 3% / 3% / 3% | 16,7% / 4,8% / 9,1% / 5,9% | indeterminata |
| P10 | V | (c) errori fra i non elencati | 3% / 3% / 3% / 3% | 5,3% / 8,0% / 6,2% / 7,7% | indeterminata |
| P11 | T | dei 4 errori di B0 che costano, presenti | 2 / 1 / 1 / 1 | 0 / 0 / 0 / 0 | confermata |
| P12 | T | dei 5 errori di B0 che non costano, presenti | 2 / 1 / 0 / 0 | 1 / 0 / 0 / 0 | smentita / confermata / confermata / confermata |
| P13 | T | studi con un errore di lettura che costa (largo; stretto) | 6 / 3 / 2 / 2 | 4; 1 / 4; 1 / 2; 1 / 3; 3 | smentita per i quattro (intervallo: 0) |
| P13 | V | studi con un errore di lettura che costa (largo; stretto) | 5 / 3 / 2 / 2 | 4; 2 / 4; 1 / 2; 1 / 2; 2 | smentita per i quattro (intervallo: 0) |
| P14 | T | studi con l'uscita identica al carattere fra le due corse | 15 / 15 / 15 / 15 | 1 / 18 / 8 / 9 | smentita |
| P14 | V | studi con l'uscita identica al carattere fra le due corse | 15 / 15 / 15 / 15 | 0 / 15 / 11 / 7 | smentita |
| P15 | T | studi con la stessa tabella, gli stessi gruppi e gli stessi confronti fra le due corse | 38 / 41 / 42 / 42 | 29 / 39 / 35 / 40 | smentita |
| P15 | V | studi con la stessa tabella, gli stessi gruppi e gli stessi confronti fra le due corse | 38 / 41 / 42 / 42 | 25 / 41 / 36 / 38 | smentita |

