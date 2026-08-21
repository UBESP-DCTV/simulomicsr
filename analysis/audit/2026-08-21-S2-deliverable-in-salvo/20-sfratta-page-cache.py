#!/usr/bin/env python3
# 20-sfratta-page-cache.py — S2 dell'handout 2026-08-21: verifica della copia A FREDDO.
#
# Una verifica SHA-256 fatta subito dopo la copia legge dalla page cache, non dal
# disco: passa anche se il supporto ha scritto male. Questo script misura quante
# pagine dei file sotto ROOT sono residenti in RAM (mincore) e, con "sfratta", le
# espelle con posix_fadvise(DONTNEED) — senza root — così che la verifica
# successiva legga davvero dal disco. Equivale a un riavvio per questi file.
#
# Uso:
#   20-sfratta-page-cache.py <ROOT> misura     quante pagine sono in cache
#   20-sfratta-page-cache.py <ROOT> sfratta    espelle e rimisura (attesa: 0%)
#   poi: 10-manifesto-e-copia.sh verifica <ROOT>
#
# Fatto il 2026-08-21 su /mnt/micron/simulomicsr-salvataggio: prima 100% residenti
# (9,35 GiB), dopo 0%; verifica 73/73 OK in 10,9 s (5,4 s quando era in cache).
import os, sys, mmap, ctypes
libc = ctypes.CDLL("libc.so.6", use_errno=True)
PAGE = os.sysconf("SC_PAGE_SIZE")
def libc_mmap_addr(m, sz):
    # mmap supporta il buffer protocol in sola lettura: l'indirizzo si prende da Py_buffer
    import ctypes as C
    class Py_buffer(C.Structure):
        _fields_ = [("buf", C.c_void_p), ("obj", C.py_object), ("len", C.c_ssize_t), ("itemsize", C.c_ssize_t),
                    ("readonly", C.c_int), ("ndim", C.c_int), ("format", C.c_char_p), ("shape", C.c_void_p),
                    ("strides", C.c_void_p), ("suboffsets", C.c_void_p), ("internal", C.c_void_p)]
    pb = Py_buffer()
    C.pythonapi.PyObject_GetBuffer(C.py_object(m), C.byref(pb), C.c_int(0))
    a = pb.buf
    C.pythonapi.PyBuffer_Release(C.byref(pb))
    return a
def residenti(path):
    sz = os.path.getsize(path)
    if sz == 0: return 0, 0
    fd = os.open(path, os.O_RDONLY)
    try:
        m = mmap.mmap(fd, sz, prot=mmap.PROT_READ)
        n = (sz + PAGE - 1) // PAGE
        vec = (ctypes.c_ubyte * n)()
        addr = ctypes.c_void_p(libc_mmap_addr(m, sz))
        r = libc.mincore(addr, ctypes.c_size_t(sz), vec)
        if r != 0: raise OSError(ctypes.get_errno())
        res = sum(1 for b in vec if b & 1)
        del vec; m.close()
        return res, n
    finally:
        os.close(fd)
def sfratta(path):
    fd = os.open(path, os.O_RDONLY)
    try: os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
    finally: os.close(fd)
root = sys.argv[1]; azione = sys.argv[2]
tot_r = tot_n = 0
for d, _, fs in os.walk(root):
    for f in fs:
        p = os.path.join(d, f)
        if azione == "sfratta": sfratta(p)
        r, n = residenti(p); tot_r += r; tot_n += n
print(f"{azione}: pagine residenti {tot_r}/{tot_n} ({100*tot_r/max(tot_n,1):.1f}%) = {tot_r*PAGE/2**30:.2f} GiB su {tot_n*PAGE/2**30:.2f} GiB")
