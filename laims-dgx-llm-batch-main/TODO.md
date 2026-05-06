# TODO / backlog breve

## Da verificare sul cluster reale

- path e policy del runtime di inferenza finale dentro la `.sif`
- disponibilità reale di `apptainer`, `squeue` e `sacct`
- strategia cache/modelli open-weight
- tempi reali e risorse consigliate per `20B` e `120B`

## Hardening applicativo

- writer remoto più ricco per `status.json`
- validazione schema record-level
- retry di record/chunk falliti
- test di integrazione con cluster reale

## Documentazione / UX

- vignetta R end-to-end per utenti non bash
- esempio realistico di estrazione strutturata
- linee guida operative per scegliere `20B` vs `120B`
