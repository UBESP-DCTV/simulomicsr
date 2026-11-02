# funzioni condivise di S3: accordo grezzo, kappa di Cohen, IC bootstrap
import math, random, collections
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
    vals = sorted(v for v in vals if v == v)
    return vals[int(0.025 * len(vals))], vals[int(0.975 * len(vals)) - 1]
def binom_coda_sup(k, n, p):
    return sum(math.comb(n, i) * p**i * (1 - p)**(n - i) for i in range(k, n + 1))
def ic_esatto(k, n, alfa=0.05):
    # Clopper-Pearson per bisezione: il bootstrap su meno di 20 gruppi e' troppo stretto
    def biseca(f):
        lo, hi = 0.0, 1.0
        for _ in range(60):
            m = (lo + hi) / 2
            if f(m): lo = m
            else: hi = m
        return lo
    inf = 0.0 if k == 0 else biseca(lambda p: binom_coda_sup(k, n, p) < alfa / 2)
    sup = 1.0 if k == n else biseca(lambda p: 1 - binom_coda_sup(k + 1, n, p) > alfa / 2)
    return inf, sup
def matrice(a, b, classi=CLASSI):
    m = {x: {y: 0 for y in classi} for x in classi}
    for x, y in zip(a, b): m[x][y] += 1
    return m
def stampa_matrice(m, nome_righe, nome_col, classi=CLASSI):
    print(f"  {nome_righe} \\ {nome_col:>10s}" + "".join(f"{c:>11s}" for c in classi) + "      tot")
    for x in classi:
        print(f"  {x:>21s}" + "".join(f"{m[x][y]:11d}" for y in classi) + f"{sum(m[x].values()):9d}")
    print(f"  {'tot':>21s}" + "".join(f"{sum(m[x][y] for x in classi):11d}" for y in classi))
