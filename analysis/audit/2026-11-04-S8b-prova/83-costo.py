#!/usr/bin/env python3
# S8b: quanto manca per completare il corpus, dai tempi registrati della prova. Solo poddgx02, due job alla volta.
fuori_rest=21828-6000
rec_st=(508037-86898)/21828
rec=fuori_rest*rec_st
blocchi=rec/10000; min_blocco=17.0
s1=blocchi*min_blocco/2/60; s1r=27.2/60*rec/134806
jobh=(5+33/60+47/3600)+(8+10/60+3/3600); a300=7.76*300/2566; nuovi=jobh-a300
s2j=nuovi/6000*fuori_rest; s2=s2j/2; s2r=46.7/60
loc={"input":27/60,"re-cluster":168.3/60,"re-pool":103/60,"altri":0.3}
tot=s1+s1r+s2+s2r+sum(loc.values())
print(f"studi da fare {fuori_rest}, record {rec:.0f}, blocchi {blocchi:.1f}")
print(f"Stadio 1 {s1:.1f} h + recupero {s1r:.1f} h; ore-job Stadio 2 della prova {jobh:.2f}, di cui 300 studi {a300:.2f}; Stadio 2 restante {s2j:.1f} ore-job = {s2:.1f} h con due job, recupero {s2r:.1f} h")
print(f"locale {sum(loc.values()):.1f} h; TOTALE {tot:.0f} h")
print(f"corpus intero da zero, due job: Stadio 2 {(nuovi/6000*21828+7.76)/2:.1f} h")
