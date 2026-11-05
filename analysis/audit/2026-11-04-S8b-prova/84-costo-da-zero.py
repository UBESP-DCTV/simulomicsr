#!/usr/bin/env python3
# S8b, dopo la scelta del PI: quanto costa rifare tutto il corpus da zero, in un solo run. Solo poddgx02, due job alla volta.
# Stessi tempi di 83-costo.py. Una correzione: 83 non scalava il recupero dello Stadio 2 (46,7 min misurati su 6.300 studi).
studi=24394; rec=508037; prova_studi=6300
blocchi=rec/10000; min_blocco=17.0
s1=blocchi*min_blocco/2/60; s1r=27.2/60*rec/134806
jobh=(5+33/60+47/3600)+(8+10/60+3/3600); a300=7.76*300/2566; nuovi=jobh-a300
s2j=nuovi/6000*21828+7.76; s2=s2j/2; s2r=46.7/60*studi/prova_studi
loc={"input":27/60,"re-cluster":168.3/60,"re-pool":103/60,"altri":0.3}
tot=s1+s1r+s2+s2r+sum(loc.values())
print(f"studi {studi}, record {rec}, blocchi {blocchi:.1f}")
print(f"Stadio 1 {s1:.1f} h + recupero {s1r:.1f} h; Stadio 2 {s2j:.1f} ore-job = {s2:.1f} h con due job, recupero {s2r:.1f} h")
print(f"locale {sum(loc.values()):.1f} h; TOTALE {tot:.1f} h; prova di invarianza esclusa, stima S8 2.0 h")
print(f"con il recupero scalato, i 15.828 studi di 83-out.txt passano da 28.3 a {28.3-46.7/60+46.7/60*15828/prova_studi:.1f} h")
