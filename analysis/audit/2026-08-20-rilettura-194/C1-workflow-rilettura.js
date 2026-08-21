export const meta = {
  name: 'rilettura-194-correttezza',
  description: 'Legge tutte e 194 le meta-analisi e da un verdetto di correttezza a ciascuna, con due critici simmetrici e un arbitro',
  phases: [
    { title: 'Lettura', detail: 'un lettore per blocco: verdetto per gruppo, citando l\'etichetta' },
    { title: 'Critica', detail: 'due critici simmetrici: ha accusato troppo / troppo poco' },
    { title: 'Arbitrato', detail: 'decide sull\'etichetta, dichiara cio\' che l\'etichetta non chiude' },
  ],
}

const DIR = 'analysis/audit/2026-08-20-rilettura-194'
const BLOCCHI = Array.from({length: 15}, (_, i) => String(i + 1).padStart(2, '0'))

// --- le regole, identiche per tutti e tre i ruoli ---------------------------
const REGOLE = `
REGOLE DEL GIUDIZIO (valgono per tutti, senza eccezioni):

1. Una meta-analisi e' CORRETTA quando tutti i confronti che raggruppa misurano
   lo stesso contrasto: stessa entita', stessa direzione, contro un controllo
   dello stesso tipo. Non e' un giudizio sul risultato biologico: e' un giudizio
   sull'APPAIAMENTO, e si legge sulle etichette dei bracci.

2. UN DIFETTO SI DICHIARA SOLO SE E' LEGGIBILE NELL'ETICHETTA CHE CITI. Devi
   riportare l'etichetta testuale. Un sospetto non provabile dall'etichetta e'
   un sospetto, e va scritto come sospetto, non come difetto.

3. NEI CASO-CONTROLLO DI MALATTIA I SOGGETTI DIVERSI SONO OBBLIGATORI, NON UN
   DIFETTO. Se il gruppo confronta malati contro sani, il fatto che il malato e
   il sano siano persone diverse e' il disegno, non un errore. Questo da solo
   fu il 52% dei falsi allarmi del primo rilevatore di questo progetto.
   Analogamente: dosi diverse, tempi diversi e linee cellulari diverse fra
   STUDI diversi sono normali in una meta-analisi; il problema e' quando i due
   BRACCI DELLO STESSO CONFRONTO non sono appaiati.

4. Esempi di difetto VERO, tutti leggibili sull'etichetta:
   - secondo agente solo nel trattato: "TGF-beta1 + 3C" contro "TGF-beta1 + DMSO"
     va bene (3C isolato), ma "LPS + IFN-gamma" contro "untreated" misura due
     cose insieme;
   - materiale diverso fra i bracci: trattato "MSC da iPSC" contro controllo
     "MSC primarie";
   - sede anatomica diversa: trattato "pons" contro controllo "brain";
   - donatore / sesso / etnia diversi nel trattamento: "Dexamethasone (Donor 3)"
     contro "Control (Donor 1)";
   - passaggio di coltura diverso: trattato "passage 27" contro controllo
     "passage 6";
   - tempo non appaiato: trattato "24h" contro controllo "0h" quando lo stesso
     studio ha il controllo a 24h;
   - direzione opposta sotto lo stesso verso: un agonista e un antagonista nello
     stesso gruppo;
   - l'entita' del gruppo non e' quella che il confronto isola.

5. SI CONTA PER STUDIO, NON PER DESTINAZIONE. Uno studio di screening con
   duecento composti domina da solo qualunque conteggio fatto per destinazione.

6. Nel dubbio si sceglie la lettura che NON SOVRASTIMA la qualita' del dato, e
   la scelta si dichiara. La regola vale in tutte e due le direzioni: dove
   l'etichetta DECIDE che il confronto e' pulito, resta pulito.
`

const DOMANDA_COMPARATIVA = `
LA DOMANDA COMPARATIVA. Esistono due esecuzioni della stessa catena che
differiscono SOLO per gli stadi LLM. Nel materiale, le righe sotto
"CONFRONTO CON L'ALTRA ESECUZIONE" dicono, studio per studio, se lo studio e'
STABILE, se i suoi confronti sono cambiati, se e' ENTRATO (prima non era
poolato) o se e' SPOSTATO (prima stava sotto un'altra chiave di contrasto).

Dove c'e' divergenza la domanda NON e' "questo gruppo e' corretto?" ma
"di queste due assegnazioni dello stesso studio, quale e' quella giusta?".
Rispondi scegliendo uno di tre casi, che portano a tre conclusioni diverse:
  A = il run NUOVO sbaglia dove il vecchio azzeccava;
  B = il run NUOVO azzecca dove il vecchio sbagliava;
  C = sono ENTRAMBE difendibili, l'etichetta sorgente e' ambigua.
Se l'etichetta non basta per scegliere, e' C, e va detto.
`

const SCHEMA_LETTURA = {
  type: 'object',
  required: ['gruppi'],
  properties: {
    gruppi: {
      type: 'array',
      items: {
        type: 'object',
        required: ['cluster_id', 'verdetto', 'motivo', 'studi_difettosi', 'divergenze'],
        properties: {
          cluster_id: { type: 'string' },
          verdetto: { type: 'string', enum: ['corretta', 'difettosa', 'incerta'] },
          motivo: { type: 'string', description: 'Deve CITARE le etichette testuali su cui si basa il verdetto.' },
          studi_difettosi: {
            type: 'array',
            items: {
              type: 'object',
              required: ['study_id', 'categoria', 'etichetta_citata'],
              properties: {
                study_id: { type: 'string' },
                categoria: { type: 'string', description: 'categoria breve del difetto, in italiano' },
                etichetta_citata: { type: 'string', description: 'il testo esatto trattato vs controllo' },
              },
            },
          },
          sospetti_non_provabili: { type: 'array', items: { type: 'string' } },
          divergenze: {
            type: 'array',
            description: 'una voce per ogni studio che diverge fra le due esecuzioni',
            items: {
              type: 'object',
              required: ['study_id', 'caso', 'motivo'],
              properties: {
                study_id: { type: 'string' },
                caso: { type: 'string', enum: ['A', 'B', 'C'] },
                motivo: { type: 'string' },
              },
            },
          },
        },
      },
    },
  },
}

const SCHEMA_CRITICA = {
  type: 'object',
  required: ['rilievi'],
  properties: {
    rilievi: {
      type: 'array',
      items: {
        type: 'object',
        required: ['cluster_id', 'rilievo', 'verdetto_proposto', 'etichetta_citata'],
        properties: {
          cluster_id: { type: 'string' },
          rilievo: { type: 'string' },
          verdetto_proposto: { type: 'string', enum: ['corretta', 'difettosa', 'incerta'] },
          etichetta_citata: { type: 'string' },
        },
      },
    },
  },
}

const SCHEMA_ARBITRO = {
  type: 'object',
  required: ['gruppi'],
  properties: {
    gruppi: {
      type: 'array',
      items: {
        type: 'object',
        required: ['cluster_id', 'verdetto_finale', 'motivo', 'studi_difettosi', 'divergenze', 'etichetta_non_chiude'],
        properties: {
          cluster_id: { type: 'string' },
          verdetto_finale: { type: 'string', enum: ['corretta', 'difettosa', 'incerta'] },
          motivo: { type: 'string' },
          studi_difettosi: {
            type: 'array',
            items: {
              type: 'object',
              required: ['study_id', 'categoria', 'etichetta_citata'],
              properties: {
                study_id: { type: 'string' },
                categoria: { type: 'string' },
                etichetta_citata: { type: 'string' },
              },
            },
          },
          divergenze: {
            type: 'array',
            items: {
              type: 'object',
              required: ['study_id', 'caso', 'motivo'],
              properties: {
                study_id: { type: 'string' },
                caso: { type: 'string', enum: ['A', 'B', 'C'] },
                motivo: { type: 'string' },
              },
            },
          },
          etichetta_non_chiude: {
            type: 'boolean',
            description: 'true se il verdetto NON e\' deciso dall\'etichetta e resta una scelta dichiarata',
          },
          rilievi_accettati: { type: 'integer' },
          rilievi_respinti: { type: 'integer' },
        },
      },
    },
  },
}

log(`Leggo tutte e 194 le meta-analisi in ${BLOCCHI.length} blocchi da 13.`)

const risultati = await pipeline(
  BLOCCHI,

  // --- STADIO 1: il lettore ------------------------------------------------
  (b) => agent(
    `Sei il LETTORE. Leggi il file ${DIR}/blocco-${b}.txt per intero (usa Read; e' un file
di testo, leggilo tutto, non a pezzi) e dai un verdetto di CORRETTEZZA a OGNI
meta-analisi che contiene. Sono 13 gruppi (12 nell'ultimo blocco): non saltarne
nessuno, nemmeno quelli piccoli a k=3-4, che sono la maggioranza del deliverable.

${REGOLE}

${DOMANDA_COMPARATIVA}

COME SI SCEGLIE IL VERDETTO DEL GRUPPO:
- "corretta"  = nessun confronto poolato ha un difetto leggibile sull'etichetta;
- "difettosa" = almeno un confronto poolato ha un difetto leggibile, e tu lo citi;
- "incerta"   = le etichette non bastano a decidere (per esempio sono sigle mute
                come "C1" contro "T1", o non dicono cosa distingue i due bracci).

Non gonfiare e non sminuire: il tuo compito e' descrivere quello che l'etichetta
dice. Per ogni difetto riporta lo study_id, una categoria breve, e il testo
esatto dell'etichetta trattato contro controllo.`,
    { label: `lettore:blocco-${b}`, phase: 'Lettura', schema: SCHEMA_LETTURA }
  ),

  // --- STADIO 2: i due critici simmetrici ----------------------------------
  (lettura, b) => parallel([
    () => agent(
      `Sei il CRITICO A. Il tuo compito e' sostenere che il lettore HA ACCUSATO TROPPO.
Leggi il file ${DIR}/blocco-${b}.txt per intero e i verdetti del lettore qui sotto.
Cerca le accuse che NON reggono sull'etichetta: difetti dichiarati che l'etichetta
non prova, casi in cui i soggetti diversi sono obbligatori perche' il disegno e'
caso-controllo di malattia, differenze fra STUDI diversi scambiate per difetti di
appaiamento, sospetti presentati come fatti.

${REGOLE}

Non gonfiare: se un'accusa regge, lasciala stare e non scrivere nulla su quel
gruppo. Segnala solo i casi in cui puoi citare l'etichetta che smentisce
l'accusa. Un rilievo senza etichetta citata non vale.

VERDETTI DEL LETTORE:
${JSON.stringify(lettura, null, 1)}`,
      { label: `critico-A:blocco-${b}`, phase: 'Critica', schema: SCHEMA_CRITICA }
    ),
    () => agent(
      `Sei il CRITICO B. Il tuo compito e' sostenere che il lettore HA ACCUSATO TROPPO POCO.
Leggi il file ${DIR}/blocco-${b}.txt per intero e i verdetti del lettore qui sotto.
Cerca i difetti che il lettore NON ha visto: confronti dichiarati puliti che
sull'etichetta non lo sono, secondi agenti presenti solo nel trattato, materiale o
sede o donatore diversi fra i due bracci, tempi non appaiati, entita' del gruppo
che il confronto non isola, gruppi dati per corretti che andrebbero detti incerti.

${REGOLE}

Non gonfiare: se un gruppo e' davvero pulito, lascialo stare e non scrivere nulla
su quel gruppo. Segnala solo i casi in cui puoi citare l'etichetta che prova il
difetto. Un rilievo senza etichetta citata non vale.

VERDETTI DEL LETTORE:
${JSON.stringify(lettura, null, 1)}`,
      { label: `critico-B:blocco-${b}`, phase: 'Critica', schema: SCHEMA_CRITICA }
    ),
  ]).then((critiche) => ({ lettura, critiche })),

  // --- STADIO 3: l'arbitro -------------------------------------------------
  (x, b) => agent(
    `Sei l'ARBITRO. Leggi il file ${DIR}/blocco-${b}.txt per intero, poi i verdetti del
lettore e i rilievi dei due critici, e fissa il verdetto finale di OGNI gruppo del
blocco. Devono esserci tutti: 13 gruppi (12 nell'ultimo blocco).

DECIDI SULL'ETICHETTA, NON SULL'AUTOREVOLEZZA. I due critici hanno per costruzione
tesi opposte: uno sostiene che si e' accusato troppo, l'altro troppo poco. Non
contare quanti sono d'accordo, e non fare la media. Vai a vedere l'etichetta citata
nel file e decidi su quella. Un rilievo la cui etichetta non dice quello che il
critico sostiene va respinto, da qualunque dei due venga.

${REGOLE}

${DOMANDA_COMPARATIVA}

QUANDO L'ETICHETTA NON CHIUDE LA QUESTIONE: non inventare una decisione. Metti
etichetta_non_chiude = true, scegli la lettura che NON sovrastima la qualita' del
dato, e dichiara nel motivo perche' l'etichetta non basta. Ma attenzione: la regola
vale in tutte e due le direzioni. Se l'etichetta DECIDE che il confronto e' pulito,
il gruppo resta "corretta" e etichetta_non_chiude = false.

Per ogni gruppo riporta anche quanti rilievi hai accettato e quanti respinti.

VERDETTI DEL LETTORE:
${JSON.stringify(x.lettura, null, 1)}

RILIEVI DEL CRITICO A (sostiene: accusato troppo):
${JSON.stringify(x.critiche[0], null, 1)}

RILIEVI DEL CRITICO B (sostiene: accusato troppo poco):
${JSON.stringify(x.critiche[1], null, 1)}`,
    { label: `arbitro:blocco-${b}`, phase: 'Arbitrato', schema: SCHEMA_ARBITRO }
  )
)

const gruppi = risultati.filter(Boolean).flatMap((r) => r.gruppi || [])
log(`Verdetti finali raccolti: ${gruppi.length} (attesi 194)`)
return { gruppi }
