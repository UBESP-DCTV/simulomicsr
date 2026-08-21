# funzioni condivise di S3: accordo grezzo, kappa di Cohen, IC bootstrap
import random, collections
CLASSI = ['corretta', 'difettosa', 'incerta']
def accordo(a, b):
    return sum(x == y for x, y in zip(a, b)) / len(a)
def kappa(a, b):
    n = len(a); po = accordo(a, b)
    ca, cb = collections.Counter(a), collections.Counter(b)
    pe = sum(ca[k] * cb[k] for k in set(ca) | set(cb)) / (n * n)
    return (po - pe) / (1 - pe) if pe < 1 else float('nan')
def ic_bootstrap(a, b, f, B=2000, seme=20260821):
    rng = random.Random(seme); n = len(a); vals = []
    for _ in range(B):
        idx = [rng.randrange(n) for _ in range(n)]
        vals.append(f([a[i] for i in idx], [b[i] for i in idx]))
    vals.sort(); return vals[int(0.025 * B)], vals[int(0.975 * B) - 1]
def matrice(a, b, classi=CLASSI):
    m = {x: {y: 0 for y in classi} for x in classi}
    for x, y in zip(a, b): m[x][y] += 1
    return m
def stampa_matrice(m, nome_righe, nome_col, classi=CLASSI):
    print(f"  {nome_righe} \\ {nome_col:>10s}" + "".join(f"{c:>11s}" for c in classi) + "      tot")
    for x in classi:
        print(f"  {x:>21s}" + "".join(f"{m[x][y]:11d}" for y in classi) + f"{sum(m[x].values()):9d}")
    print(f"  {'tot':>21s}" + "".join(f"{sum(m[x][y] for x in classi):11d}" for y in classi))
