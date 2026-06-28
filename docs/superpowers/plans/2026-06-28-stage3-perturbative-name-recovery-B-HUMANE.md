# HUMANE — Recupero nomi farmaci con ChEMBL → Stadio 3 v5 (Opzione B)

Versione leggibile del plan `2026-06-28-stage3-perturbative-name-recovery-B-plan.md`.

## Cosa fa, in due righe

Insegna alla pipeline a **dare un nome ai farmaci** che oggi non riconosce (perché non
stanno in ChEBI), usando ChEMBL come secondo dizionario — esattamente come MeSH ha risolto
le malattie. Poi ri-raggruppa (Stadio 3 v5) e ri-poola (Stadio 4 v5) per de-minestronare i
cluster `small_molecule`.

## Perché serviva un pezzo nuovo (non solo "cambia il DB")

Le malattie erano scritte pulite ("breast cancer"). I farmaci no: sono annegati nel rumore
(`osimertinib 2 um 9d`, `treated for 48 hours with 10 um ag1478`) o combinati
(`enzalutamide + onvansertib`). Misurato: l'**86%** dei nomi-farmaco non matcherebbe ChEMBL
"così com'è". Quindi aggiungiamo un estrattore che pesca il nome dal rumore — con un freno di
precisione: un nome conta solo se matcha **esattamente** un alias del dizionario (niente
indovinare, lezione del bug C1).

## Le 3 idee chiave

1. **ChEBI prima, ChEMBL poi.** Se ChEBI conosce già il farmaco, niente cambia. ChEMBL entra
   solo per chi ChEBI non conosce.
2. **De-frammentazione gratis.** Se ChEMBL risolve una sigla (`gdc0973`), prendiamo il nome
   canonico ChEMBL ("cobimetinib") e lo ri-cerchiamo in ChEBI → così la sigla finisce sullo
   **stesso** ID di chi ha scritto "cobimetinib". Niente doppioni.
3. **Combo = condizione a sé.** Due farmaci diversi insieme diventano un ID-combo ordinato
   (`CHEBI:a+CHEBI:b`): le combo identiche si raggruppano tra loro, ma restano separate dai
   singoli farmaci.

## Cosa NON fa (deciso con te)

- **Niente biologici** (citochine/patogeni: LPS, TNF, IFN, IL, TGF). Nessun dizionario di
  farmaci li nomina. Vanno in una **sessione futura**, con un brainstorming dedicato (insieme
  al fix-tipo K3 per i casi mal-etichettati). È dove `cytokine_stim` resta fermo a ~64%.
- Niente normalizzazione della grafia (già misurato: non aiuta, −0,1pp).

## Come procede

**Fase 1 (codice, ~mezza giornata).** 5 task TDD piccoli: dizionario ChEMBL + accessor →
estrattore → risoluzione+de-frag+combo → integrazione → script di build reale. Tutto testato
con mini-fixture, **nessun run pesante**.

**Fase 2 (run pesanti, con gate tuoi tra l'uno e l'altro).**
- Scarica ChEMBL (5.4G) e costruisci il dizionario (~min).
- **Smoke di copertura PRIMA del fullrun**: ti mostro quanti farmaci recupera e zero falsi,
  così non sprechiamo 6h se l'estrazione va rivista.
- Re-cluster Stadio 3 v5 (~6h).
- Re-pool Stadio 4 v5 (~11h, output sul disco grande).
- Re-gate: ti riporto la tabella v4→v5 (atteso: `small_molecule` giù dal 49%).

## Tempo stimato

Codice ~mezza giornata; poi ~17h di run distribuiti su gate separati (come per le malattie).

## Decisioni rinviate / rischi onesti

- La **copertura reale di ChEMBL** la sapremo solo dopo il download: lo smoke di copertura è
  il punto in cui decidiamo se procedere.
- La mini-fixture di test usa ID ChEMBL illustrativi (sintetici); opzionalmente, dopo il
  download, la rigeneriamo come sottoinsieme reale.
- L'estrattore tokenizza anche sugli spazi: il freno di precisione (match esatto, ≥3 caratteri,
  non numerico) tiene a bada i falsi, e lo smoke di copertura + i canary lo verificano.
