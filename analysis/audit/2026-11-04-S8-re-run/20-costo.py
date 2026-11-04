#!/usr/bin/env python3
# Costo del re-run, dai tempi SLURM (20-sacct.txt) e dalla quota di uscita dello Stadio 2 (21-out.txt).
import datetime as dt
righe={l.split()[0]:l.split() for l in open("analysis/audit/2026-11-04-S8-re-run/20-sacct.txt")}
def sec(j):
    h,m,s=righe[j][3].split(":");return int(h)*3600+int(m)*60+int(s)
def t(j,c): return dt.datetime.fromisoformat(righe[j][c])
H=3600
chunk=["35609","35610","35611","35612","35619","35620","35621","35622","35623"]
wall_s1=(max(t(j,5) for j in chunk)-min(t(j,4) for j in chunk)).total_seconds()
rec_a3,rec_tot=86898,508037
s1_par=wall_s1*rec_tot/rec_a3/H
media=sum(sec(j) for j in chunk[:-1])/8
s1_ser=rec_tot/10000*media/H
s1_res=sum(sec(j) for j in ["35644","35645","35646"])*rec_tot/rec_a3/H
quota=13951208/84834478
s2_old=sec("24022")/H; s2_a3=sec("35647")/H
fatt_s1=sec("35589")/sec("35598")
fatt_s2=s2_a3/(s2_old*quota)
s2_basso=s2_old*fatt_s1; s2_alto=s2_a3/quota
s2_res=sec("35701")/quota/H
rc,rp,ric=133.6/60,71/60,23/60
prova=2.0
print(f"S1: 9 blocchi A3 in {wall_s1/60:.1f} min con due blocchi insieme -> {s1_par:.1f} h; un blocco alla volta {s1_ser:.1f} h; recupero {s1_res:.1f} h")
print(f"S2: vecchio senza flag {s2_old:.2f} h; A3 con flag {s2_a3:.2f} h; quota di uscita A3 {quota:.4f}")
print(f"fattore del flag: {fatt_s1:.2f} su S1 (5.000 record), {fatt_s2:.2f} implicito su S2")
print(f"S2 con flag sul corpus: {s2_basso:.1f} h (fattore S1) - {s2_alto:.1f} h (scala sui caratteri); recupero {s2_res:.1f} h")
print(f"locale: re-cluster {rc:.1f} h, re-pool {rp:.1f} h, ricomposizione {ric:.1f} h; prova di invarianza S2, stima {prova:.1f} h")
b=prova+s1_par+s1_res+s2_basso+s2_res+rc+rp+ric
c=prova+s1_par+s1_res+s2_alto+s2_res+rc+rp+ric
a=prova+s1_ser+s1_res+s2_alto+s2_res+rc+rp+ric
print(f"TOTALE macchina: basso {b:.0f} h, centrale {c:.0f} h, alto {a:.0f} h")
o=1-quota
print(f"senza rifare gli studi A3: S2 {s2_alto*o:.1f} h, S1 {s1_par*(rec_tot-rec_a3)/rec_tot:.1f} h")

# La prova: 2.000 studi a caso fra quelli mai rigenerati, piu' 300 studi gia' rigenerati nello stesso job.
n_prova,n_inv=2000,300
fuori=24394-2566
rec_st=(rec_tot-rec_a3)/fuori
ch_st=(84834478-13951208)/fuori
ch_a3=13951208/2566
s1p=wall_s1/rec_a3*n_prova*rec_st/H
s1r=sum(sec(j) for j in ["35644","35645","35646"])/rec_a3*n_prova*rec_st/H
ora_ch=s2_a3/13951208
s2p=n_prova*ch_st*ora_ch; s2i=n_inv*ch_a3*ora_ch; s2r=sec("35701")/H
tot_llm=s1p+s1r+s2p+s2i+s2r
print(f"PROVA: {n_prova*rec_st:.0f} record; S1 {s1p:.2f} h, recupero {s1r:.2f} h; S2 fuori {s2p:.2f} h, S2 ripetibilita' {s2i:.2f} h, recupero {s2r:.2f} h; modello {tot_llm:.1f} h; con re-cluster {tot_llm+rc:.1f} h")
