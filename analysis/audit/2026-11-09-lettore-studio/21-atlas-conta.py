# Misura esplorativa (2026-11-09): quanti confronti, gruppi e campioni scrivono i curatori di Expression Atlas
# negli esperimenti umani RNA-seq differenziali che corrispondono a uno studio nostro (20-atlas-studi-nostri.txt).
# Scarica i file <accession>-configuration.xml dall'FTP di EBI in una cartella vuota e li conta.
# Uso: python3 -I 21-atlas-conta.py 20-atlas-studi-nostri.txt <cartella_xml> > 21-out.txt
import os, re, sys, urllib.request
acc = [l.split()[0] for l in open(sys.argv[1])]; D = sys.argv[2]; os.makedirs(D, exist_ok=True)
nc = ng = na = 0; per = []
for a in acc:
    f = os.path.join(D, a + "-configuration.xml")
    if not os.path.exists(f) or os.path.getsize(f) == 0:
        urllib.request.urlretrieve("https://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/experiments/%s/%s-configuration.xml" % (a, a), f)
    t = open(f, encoding="utf-8", errors="replace").read()
    c = len(re.findall(r"<contrast id=", t)); nc += c; per.append(c)
    ng += len(re.findall(r"<assay_group id=", t)); na += len(re.findall(r"<assay[ >]", t))
per.sort()
print("studi %d; confronti %d; gruppi %d; campioni nei gruppi %d; confronti per studio: mediana %d, massimo %d; studi senza confronti %d"
      % (len(per), nc, ng, na, per[len(per) // 2], per[-1], sum(1 for x in per if x == 0)))
