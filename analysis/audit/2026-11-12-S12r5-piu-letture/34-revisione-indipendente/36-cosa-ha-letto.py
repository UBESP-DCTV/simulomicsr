#!/usr/bin/env python3
"""S12r5 - che cosa ha letto il revisore indipendente, contato sul suo transcript DOPO la revisione (audit interno).
Uso: python3 36-cosa-ha-letto.py <transcript.jsonl del subagente> <cartella congelata> > 36-cosa-ha-letto.txt
Conta gli strumenti usati, i file aperti con Read, i comandi Bash; ferma con un elenco se un comando non lavora nella
cartella congelata, nomina un percorso assoluto fuori dalla cartella, sale con «..» o usa la rete."""
import json, re, sys, collections
p, base = sys.argv[1], sys.argv[2].rstrip("/")
strumenti, letti, comandi = collections.Counter(), set(), []
for l in open(p, encoding="utf-8"):
    c = json.loads(l).get("message", {}).get("content")
    if not isinstance(c, list): continue
    for b in c:
        if b.get("type") != "tool_use": continue
        strumenti[b["name"]] += 1; i = b.get("input", {})
        if "file_path" in i: letti.add(i["file_path"])
        if "command" in i: comandi.append(i["command"])
fuori = sorted(f for f in letti if not f.startswith(base))
senza = [c for c in comandi if base not in c]
assoluti = sorted({m for c in comandi for m in re.findall(r"(?<![\w.])/(?:home|mnt|tmp|etc|usr|var)[\w./-]*", c) if not m.startswith(base)})
sale = [c for c in comandi if ".." in c]
rete = [c for c in comandi if re.search(r"curl|wget|https?:|\bgit\b|\bssh\b", c)]
print("strumenti: %s" % ", ".join("%s %d" % kv for kv in sorted(strumenti.items())))
print("file aperti con Read: %d; fuori dalla cartella: %d" % (len(letti), len(fuori)))
print("comandi Bash: %d; senza la cartella nel comando: %d; percorsi assoluti fuori: %d; con «..»: %d; con rete, git o ssh: %d" % (
      len(comandi), len(senza), len(assoluti), len(sale), len(rete)))
if fuori or senza or assoluti or sale or rete: sys.exit("FUORI DALLA CARTELLA: %s" % (fuori + senza + assoluti + sale + rete)[:5])
print("esito: il revisore ha lavorato solo nella cartella congelata")
