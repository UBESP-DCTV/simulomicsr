import csv, collections
D="/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/"
rd=lambda f:list(csv.DictReader(open(D+f,encoding="utf-8")))
PF=rd("27-per-forma.csv"); PG=rd("27-peggioramenti.csv"); ST=rd("27-stati.csv"); CB=rd("24-contro-la-base.csv"); FO=rd("24-forme.csv")
E29=rd("29-errori-presenti-per-forma.csv"); EB=rd("26-errori-nelle-basi.csv")
LATO_A={"A0C","A0A1","A0A3","A0A2","A0A2A3","A0A2A3A4","A0A2A3A4R","A0pl1","A0pl2"}
st={(r["errore"],r["corsa"]):r["stato"] for r in ST}
errs=sorted({r["errore"] for r in ST})
T=lambda s:s=="TRUE"
diff=0
for r in PF:
    k=r["corsa"]; b=r["base"]
    cb=[x for x in CB if x["corsa"]==k]
    pg=[x for x in PG if x["corsa"]==k]
    exp={}
    exp["migliorati"]=sum(T(x["migliorato"]) for x in cb)
    exp["peggiorati"]=sum(T(x["peggiorato"]) for x in cb)
    exp["migliorati_e_peggiorati"]=sum(T(x["migliorato"]) and T(x["peggiorato"]) for x in cb)
    exp["peggiorati_lettura"]=sum(x["causa"]=="lettura del modello" for x in pg)
    exp["peggiorati_forma"]=sum(x["causa"]=="forma" for x in pg)
    exp["peggiorati_non_errore"]=sum(x["causa"]=="non errore" for x in pg)
    exp["studi_con_errore_nuovo"]=sum(T(x["errore_nuovo"]) for x in pg)
    exp["studi_con_errore_nuovo_stretto"]=sum(T(x["errore_nuovo_stretto"]) for x in pg)
    inb=[e for e in errs if st.get((e,b))=="presente"]
    exp["errori_di_lettura_nella_base"]=len(inb)
    exp["errori_di_lettura_tolti"]=sum(st.get((e,k))=="assente" for e in inb)
    bad=[(c,r[c],v) for c,v in exp.items() if str(r[c])!=str(v)]
    npg=len(pg)
    if bad or npg!=exp["peggiorati"]:
        diff+=1; print(k,b,"DIFF",bad,"righe peggioramenti",npg,"peggiorati",exp["peggiorati"])
    fo=[x for x in FO if x["corsa"]==k]
    if fo:
        f=fo[0]
        if (f["migliorati"],f["peggiorati"],f["migliorati_e_peggiorati"])!=(r["migliorati"],r["peggiorati"],r["migliorati_e_peggiorati"]):
            print("  24-forme vs 27-per-forma",k,(f["migliorati"],f["peggiorati"],f["migliorati_e_peggiorati"]),(r["migliorati"],r["peggiorati"],r["migliorati_e_peggiorati"]))
print("per-forma righe",len(PF),"diverse",diff)
# causa vuota?
print("cause:",collections.Counter(x["causa"] for x in PG))
# errore_nuovo coerenza
print("errore_nuovo != (causa==lettura):",sum(T(x["errore_nuovo"])!=(x["causa"]=="lettura del modello") for x in PG))
# 29
costa={r["errore"]:r["costa"] for r in EB}
d29=0
for r in E29:
    k=r["corsa"]; rk=[x for x in ST if x["corsa"]==k]; pres=[x for x in rk if x["stato"]=="presente"]
    c=[x for x in pres if costa.get(x["errore"],"si")=="si"]
    exp=[len(pres),len({x["studio"] for x in pres}),len(c),len({x["studio"] for x in c}),len({x["studio"] for x in rk if x["stato"]=="non valutabile"})]
    got=[int(r[c2]) for c2 in ["errori_presenti","studi_con_errore","errori_che_costano","studi_con_errore_che_costa","studi_non_valutabili"]]
    if exp!=got: d29+=1; print("29 DIFF",k,exp,got)
print("29 righe",len(E29),"diverse",d29)
# etichette presenti nella forma e non nella base, contro errore nuovo contato
print("\ncorsa base | etichette presenti in corsa e non in base | di cui in studi con riga errore_nuovo | studi_con_errore_nuovo")
for r in PF:
    k=r["corsa"]; b=r["base"]
    nuove=[e for e in errs if st.get((e,k))=="presente" and st.get((e,b))!="presente"]
    studi_nuovo={x["studio"] for x in PG if x["corsa"]==k and T(x["errore_nuovo"])}
    fuori=[e for e in nuove if e.split(":")[0] not in studi_nuovo]
    print(k,b,len(nuove),len(nuove)-len(fuori),r["studi_con_errore_nuovo"],"| fuori:",fuori)
