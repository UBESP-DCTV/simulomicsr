#!/usr/bin/env python3
"""Scarica i due file Level 5 di LINCS a pezzi da 64 MiB, con piu' connessioni: ogni connessione da S3 va a circa
100 KB/s (misurato 2026-11-04). Controlla l'integrita' con l'ETag di S3. Uso: 11-scarica-lincs-a-pezzi.py <connessioni>"""
import concurrent.futures as cf, hashlib, os, subprocess, sys, time
DEST = "/mnt/wwn-0x5000039d58caca35/lincs-meta/level5"
BASE = "https://s3.amazonaws.com/macchiato.clue.io/builds/LINCS2020/level5/"
FILE = [("level5_beta_trt_misc_n8283x12328.gctx", 408533814, "b58bcaa628f9f2afeadbb815b49a7684"),
        ("level5_beta_trt_cp_n720216x12328.gctx", 35518405386, "d342ab7f3fa6ece699099bc2d8fc94b8-2118")]
PEZZO = 64 * 1024 * 1024
PARTE = 16 * 1024 * 1024   # la parte del caricamento multipart su S3: 35518405386 / 16 MiB = 2118 parti
conn = int(sys.argv[1])

def pezzo(url, cartella, i, a, b):
    out = os.path.join(cartella, f"{i:05d}")
    if os.path.exists(out) and os.path.getsize(out) == b - a + 1:
        return 0
    tmp = out + ".tmp"
    for t in range(30):
        r = subprocess.run(["curl", "-fsS", "--retry", "5", "--retry-all-errors", "--speed-time", "120", "--speed-limit", "1000", "-r", f"{a}-{b}", "-o", tmp, url])
        if r.returncode == 0 and os.path.getsize(tmp) == b - a + 1:
            os.rename(tmp, out); return 1
        time.sleep(20)
    raise RuntimeError(f"pezzo {i} non scaricato")

for nome, taglia, etag in FILE:
    finale = os.path.join(DEST, nome)
    if os.path.exists(finale) and os.path.getsize(finale) == taglia:
        print("gia' presente", nome, flush=True); continue
    c = finale + ".pezzi"; os.makedirs(c, exist_ok=True)
    rg = [(i, s, min(s + PEZZO, taglia) - 1) for i, s in enumerate(range(0, taglia, PEZZO))]
    t0 = time.time(); fatti = 0
    with cf.ThreadPoolExecutor(conn) as ex:
        fut = [ex.submit(pezzo, BASE + nome, c, i, a, b) for i, a, b in rg]
        for f in cf.as_completed(fut):
            f.result(); fatti += 1
            if fatti % 20 == 0:
                print(f"{nome}: {fatti}/{len(rg)} pezzi, {(time.time()-t0)/60:.1f} min, {fatti*PEZZO/1e6/(time.time()-t0):.1f} MB/s", flush=True)
    # ricompone calcolando l'ETag di S3
    tot = hashlib.md5(); parti = []; cur = hashlib.md5(); nel = 0
    with open(finale + ".tmp", "wb") as w:
        for i, _, _ in rg:
            with open(os.path.join(c, f"{i:05d}"), "rb") as r:
                while True:
                    buf = r.read(1 << 20)
                    if not buf: break
                    w.write(buf); tot.update(buf)
                    pos = 0
                    while pos < len(buf):
                        q = min(PARTE - nel, len(buf) - pos); cur.update(buf[pos:pos+q]); nel += q; pos += q
                        if nel == PARTE: parti.append(cur.digest()); cur = hashlib.md5(); nel = 0
    if nel: parti.append(cur.digest())
    calc = tot.hexdigest() if "-" not in etag else hashlib.md5(b"".join(parti)).hexdigest() + f"-{len(parti)}"
    print(nome, "ETag atteso", etag, "calcolato", calc, flush=True)
    if calc != etag or os.path.getsize(finale + ".tmp") != taglia:
        print("ERRORE integrita'", nome, flush=True); sys.exit(1)
    os.rename(finale + ".tmp", finale)
    subprocess.run(["rm", "-rf", c])
    print("fatto", nome, time.strftime("%FT%T"), flush=True)
print("fatto lincs", time.strftime("%FT%T"), flush=True)
