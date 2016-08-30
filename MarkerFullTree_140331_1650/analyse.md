Evaluation des performances de Sofa-Flexible
============================================

Tout d'abord un petit script R pour lire les fichiers d'expérience et créer
les courbes (je peux mettre les logs a disposition, à la demande). Cette
partie du code n'est pas très intéressante sauf si vous voulez voir ce qui se
passe quand on débute en R ...


```r
require(methods)
require(ggplot2)
```

```
## Loading required package: ggplot2
```

```r
MyPlotter<-function(datas, Metric=NULL, Title=NULL)
{
    #Todo: Commenter
    if( length(datas$Config)>2 )
    {
        p <-ggplot(datas,aes(x=Region,y=mean,fill=Config, group=Config))
        #p <- p + geom_errorbar(aes(ymin=mean-se,ymax=mean+se, width=.2,
        #                           position="dodge"))
        p <- p + scale_fill_discrete(name="Runtime",
                         labels=c("Openmp", "Sequential"))
        p <- p + theme(legend.position="bottom", 
                   axis.text.y=element_text(size=12, colour="#000000"))
    }
    else
    {
        p <-ggplot(datas,aes(x=Config,y=mean,fill=Config))
        p <- p + geom_errorbar(aes(ymin=mean-se,ymax=mean+se,width=.2))
        p <- p + theme(legend.position="none",
                       axis.text.y=element_text(size=12, colour="#000000"))
        p <- p + scale_x_discrete(labels=c("Openmp", "Sequential"))
    }
    p <- p + geom_bar(stat="identity", position="dodge")
    p <- p + coord_flip()
    p <- p + ylab(Metric)
    p <- p + xlab(Title)
    #ggsave(file=paste(basedir,"/figure/",Title,".png",sep=""))
    return(p)
}
# This script must be run from the root directory of the experiment output
# The experiment output files are organised in a tree similar to the
# following:
# Scene 1
#   . Group (likwid) 1
#   .   Config (seq, openmp, seq-perfmon ...) 1
#   .     run1.Metric1.csv
#   .     run2.Metric1.csv
#   .     run1.Metric2.csv
#   .       .
#   .   Config 2
#   .     .
#   .   .
#   . Group 2
#   . .
# Scene 2
library(ggplot2)
library(plyr)
#library(reshape2)
#palete for colorblind from
#http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/#a-colorblind-friendly-palette
# The palette with grey:
# TODO: Use cbPalette
#cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442",
#"#0072B2", "#D55E00", "#CC79A7")

basedir<-getwd()

#Initialize an empty plot list in 3D 
plots<-list(c())
plotTitles<-list(c())
groupNames<-c()
nplots<-0
scnNum<-1
setwd(basedir)
#
#parse all results by scenes, groups (likwid sets), config (seq, openmp etc.) 
#and create one plot by config
#
for (scndir in dir(pattern=".*.scn", path=basedir, no..=T,full.names=T))
{
    plots[[scnNum]]<-list(c())
    plotTitles[[scnNum]]<-list(c())
    setwd(scndir)
    #show(scndir)
    grpNum<-1
    for (grpdir in dir(path=scndir, no..=T,full.names=T))
    {
        plots[[scnNum]][[grpNum]]<-list(c())
        plotTitles[[scnNum]][[grpNum]]<-list(c())
        if(!file.info(grpdir)$isdir)
        {
            next
        }
        setwd(grpdir)
        #show(grpdir)
        if (scnNum == 1)
        {
            groupNames<-c(groupNames,basename(grpdir))
        }
        results <- NULL;
        ndir <-0
        for (dir in dir(path=grpdir, no..=T,full.names=T))
        {
            if(!file.info(dir)$isdir)
            {
                next
            }
            #show(dir)
            nrun<-0
            setwd(dir)
            for(file in list.files(path=dir, pattern="run.*.Metric.csv"))
            {
                #read the csv file
                curdata<-data.frame(read.csv(file,sep=",",
                                            quote="\"",dec=".", header=T,
                                            stringsAsFactors=F,as.is=T))
                expe<-basename(dir)

                if(NCOL(curdata) > 4)
                {
                    tmp<-(curdata[,1:3])
                    # For most metric, the average between the cores is the
                    # interesting one
                    tmp$Value<-curdata$Avg
                    # However for the metric matched by the following grep,
                    # we are interested by the sum amoung the processors
                    resgrep<-grep("Simulation time|Througput|Memory|bandwidth|data volume",
                                  curdata$Metric)
                    tmp$Value[resgrep]<-curdata$Sum[resgrep]
                    resgrep<-grep("miss ratio | request rate | CPI|Runtime",curdata$Metric)
                    tmp$Value[resgrep]<-curdata$Max[resgrep]
                    curdata<-tmp
                    remove(tmp)
                }
                curdata$runId<-nrun;
                colnames(curdata)<-c("Config","Region" ,"Metric","Value", "runId")
                if(grpNum > 1)
                {
                    #All the following metrics are interesting only once per scene
                    #Hence we remove them from all groups execpt the first
                    curdata<-curdata[-grep('Runtime|CPI|Clock|Execution time|FPS',curdata$Metric),]
                }
                else
                {
                    #Compute the idle time ratio
                    resgrep <- grep("unhalted", curdata$Metric)
                    resgrep1 <- grep("RDTSC", curdata$Metric)
                    for( i in 1:NROW(resgrep))
                    {
                        val  <-  100*(1-as.numeric(curdata$Value[resgrep[i]])/
                                      as.numeric(curdata$Value[resgrep1[i]]))
                        curdata <- rbind(curdata,
                                       c(curdata$Config[resgrep[i]],curdata$Region[resgrep[i]],"Idle time ratio [%]",val ,nrun))
                    }
                    #Change the Load to store ratio into Store to Load ratio
                    #Not used in the presentation : not very interesting
                    resgrep <- grep("Load to Store ratio",curdata$Metric)
                    for(i in 1:NROW(resgrep))
                    {
                        curdata$Value[resgrep[i]]<- 
                            1/as.numeric(curdata$Value[resgrep[i]])
                        curdata$Metric[resgrep[i]]<- "Store to Load ratio"

                    }

                }
                #Because for R integer and numeric are two different things ...
                curdata$Value <- as.numeric(curdata$Value)
                results<-rbind(results,curdata)

                nrun<-nrun+1

                remove(curdata)  
            }
            setwd("..")
        }
        remove(dir)
        remove(file)
        remove(expe)
        remove(ndir)
        remove(nrun)
        
            #Add statisticall stuffs
            stat<-ddply(results,c("Config", "Region", "Metric"),summarise,
                        N=length(Value),mean=mean(Value),sd=sd(Value),se=sd/sqrt(N))
        if(grpNum==1)
        {

            rdtsc <- grep("RDTSC", stat$Metric) 
            rdtscRes<-stat[rdtsc,]
            #Reduce to the openmp-perfmon lines
            openmpperfrdtsc<- grep("openmp-perfmon",rdtscRes$Config)
            omprdtscRes<-rdtscRes[openmpperfrdtsc,]
            #Same for seq-perfmon
            seqperfrdtsc<- grep("seq-perfmon",rdtscRes$Config)
            seqrdtscRes<-rdtscRes[seqperfrdtsc,]
            #Compute the sum
            rdtscSimu <- rdtscRes[rdtscRes$Region=="Simu",]
            TotOmpRuntime<-rdtscSimu[rdtscSimu$Config=="openmp-perfmon",]$mean
            TotSeqRuntime<-rdtscSimu[rdtscSimu$Config=="seq-perfmon",]$mean
            
            for(i in 1:NROW(omprdtscRes))
            {
                #Insert the Runrime ratio Row for omp runs
                val<-100*as.numeric(omprdtscRes[i,]$mean)/TotOmpRuntime
                myline<- c(omprdtscRes[i,]$Config,omprdtscRes[i,]$Region, "Runtime ratio [%]",omprdtscRes[i,]$N,val,0,0)
                stat <- rbind(stat,myline)
            
            }
            for(i in 1:NROW(seqrdtscRes))
            {
                #The same for seq runs
                val<-100*as.numeric(seqrdtscRes[i,]$mean)/TotSeqRuntime
                myline<- c(seqrdtscRes[i,]$Config,seqrdtscRes[i,]$Region, "Runtime ratio [%]", seqrdtscRes[i,]$N,val,0,0)
                stat <- rbind(stat,myline)

            }
            stat$N<-as.numeric(stat$N)
            stat$mean<-as.numeric(stat$mean)
            stat$se<-as.numeric(stat$se)
            stat$sd<-as.numeric(stat$sd)
            #show(stat)

            remove(rdtsc)
            remove(rdtscRes)
            remove(openmpperfrdtsc)
            remove(omprdtscRes)
            remove(TotOmpRuntime)
            remove(seqperfrdtsc)
            remove(seqrdtscRes)
            remove(TotSeqRuntime)
            remove(myline)
        }

        remove(results)

        #create the plots
        met<-unique(stat$Metric)

        for(mtr in 1:NROW(met))
        {
           
            plots[[scnNum]][[grpNum]][[mtr]]<-list(c())
            #Create two plots one for experiments on full code, on for experiments
            #  on part of the code
            set<-subset(stat,Metric==unique(stat$Metric)[mtr])
            resgrep<-grep("Full", set$Region)
            #TODO: some code simplification / factorization should be done here
            #If the first grep is false, we can't use -resgrep, so we use a
            #second grep which is a negation of the first. this is a dirty fix
            resgrep1<-grep("Full", set$Region, invert=T)
            miniset <- set[resgrep1,]
            resgrep2 <- grep("Simu", miniset$Region, invert=T)
            resgrep3 <- grep("Simu", miniset$Region)
            nplots<-nplots+1
            #Create the plot, 3 different groups : Full, perfmon Simu, perfmon
            #function some metrics are not available for each groups
            if(NROW(set[resgrep,]) > 0)
            {
                plots[[scnNum]][[grpNum]][[mtr]][[1]]<-MyPlotter(set[resgrep,],
                                        Metric=met[mtr],Title=basename(scndir))
            }
            if(NROW(set[resgrep2,]) > 0 )
            {
                plots[[scnNum]][[grpNum]][[mtr]][[2]]<-MyPlotter(miniset[resgrep2,],
                                        Metric=met[mtr],Title=basename(scndir))
            }
            if(NROW(set[resgrep3,]) > 0 )
            {
                plots[[scnNum]][[grpNum]][[mtr]][[3]]<-MyPlotter(miniset[resgrep3,],
                                        Metric=met[mtr],Title=basename(scndir))
            }
            plotTitles[[scnNum]][[grpNum]][[mtr]]<-met[mtr]
        }
        #show(plotTitles)
        remove(mtr)
        remove(met)
        remove(set)
        remove(miniset)
        remove(stat)
        setwd("..")
        grpNum<-grpNum+1
    }
    remove(grpdir)
    setwd("..")
    scnNum<-scnNum+1
}
remove(scndir)
#remove(cbPalette)
remove(basedir)
remove(resgrep2)
remove(resgrep3)
```

Nous avons testé 4 scènes (tirée des exemples flexible /types), pour chaque
scène seul le(s) objet(s) utilisant(s) flexible sont simulés.

Nous avons utilisé la librairie likwid pour relever les compteurs de
performances (hardware) et les grouper par catégorie. Cette analyse focalise
sur l'utilisation de la mémoire.

## Metriques indépendantes des groupes likwid

Pour commencer quelques métriques qui sont relevés par tous les groupes likwid
mais qui ne dépendent que de la scène :

<!--
### Cycles Per Intruction

Cette métrique montre les fonctions les plus gourmandes en calcul. La
comparaison entre les deux exécutions complètes (séquentielle et openmp) n'a
pas d'intérêt particulier.

Pour la partie openmp nous travaillons sur le nombre moyen de cycles par
instruction entre les cœurs.


```r
SceneNumbers<-c(1,3,5,2,4)
#All the following metrics are recorded only for the first group
group<-1
p<-list(c())
for(sn in SceneNumbers)
{
    show(plots[[sn]][[group]][[grep("CPI", plotTitles[[1]][[group]])]][[2]])
}
```

![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-2-1.png)![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-2-2.png)![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-2-3.png)![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-2-4.png)![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-2-5.png)

Au vu de ces courbes, il semble que pour toutes les scènes, les fonctions
applyJT et applyJ sont les plus gourmandes en calcul. 
-->

### Idle time ratio

Les courbes présentées ici correspondent au ratio de temps inactif (la
métrique Runtime unhalted semble trop imprécises pour un calcul de cette
métrique par fonctions). 
Formule :  
<code>
    100\*(1-Runtime unhalted / Runtime RDTSC)  
    Runtime unhalted correspond au temps d'execution actif (nbcycle\*clockfreq)  
    Runtime RDTSC est le temps d'execution mesuré par le time stamp counter  
</code>
Pour les run openmp, nous travaillons sur le Max.


```r
for(sn in SceneNumbers)
{
  # show(plots[[sn]][[group]][[grep("Idle",
  #                              plotTitles[[sn]][[group]])]][[1]])
   show(plots[[sn]][[group]][[grep("Idle",
                                plotTitles[[sn]][[group]])]][[3]])
}                                                                       
```

![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-3-1.png)![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-3-2.png)![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-3-3.png)![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-3-4.png)![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-3-5.png)
15 a 50% de temps perdu en séquentiel, 35-60 en parallèle, mais tous les
threads ne sont pas toujours utilisés (seulement quelques zones
parallèles).Attention fiabilité de la métrique  

### Runtime ratio
Cette métrique est dérivée des Runtime RDTSC globale et par fonction, elle
montre le ratio de temps passé dans chaque fonction observée.


```r
group<-1
for(sn in SceneNumbers)
{
   #show(plots[[sn]][[group]][[grep("Idle",
   #                             plotTitles[[sn]][[group]])]][[2]])
   #show(plots[[sn]][[group]][[grep("unhalted",
   #                             plotTitles[[sn]][[group]])]][[2]])
   #show(plots[[sn]][[group]][[grep("RDTSC",
   #                             plotTitles[[sn]][[group]])]][[1]])
   #show(plots[[sn]][[group]][[grep("RDTSC",
   #                             plotTitles[[sn]][[group]])]][[2]])
   show(plots[[sn]][[group]][[grep("Runtime ratio",
                                plotTitles[[sn]][[group]])]][[2]])
}                                                                       
```

![plot of chunk unnamed-chunk-4](figure/unnamed-chunk-4-1.png)![plot of chunk unnamed-chunk-4](figure/unnamed-chunk-4-2.png)![plot of chunk unnamed-chunk-4](figure/unnamed-chunk-4-3.png)![plot of chunk unnamed-chunk-4](figure/unnamed-chunk-4-4.png)![plot of chunk unnamed-chunk-4](figure/unnamed-chunk-4-5.png)

ApplyJ et applyJT vec ressortent, cependant la majorité du temps de
simu n'est pas capturé ici ...

### Temps de simulation



```r
group<-1
for(sn in SceneNumbers)
{
show(plots[[sn]][[group]][[grep("Simulation",
                                plotTitles[[sn]][[group]])]][[1]])
#show(plots[[sn]][[group]][[grep("RDTSC",
#                                plotTitles[[sn]][[group]])]][[3]])
#show(plots[[sn]][[group]][[grep("FPS",
#                                plotTitles[[sn]][[group]])]][[1]])
}
```

![plot of chunk unnamed-chunk-5](figure/unnamed-chunk-5-1.png)![plot of chunk unnamed-chunk-5](figure/unnamed-chunk-5-2.png)![plot of chunk unnamed-chunk-5](figure/unnamed-chunk-5-3.png)![plot of chunk unnamed-chunk-5](figure/unnamed-chunk-5-4.png)![plot of chunk unnamed-chunk-5](figure/unnamed-chunk-5-5.png)

L'utilisation d'openmp semble efficace néanmoins les gains sont inégaux selon
les scènes, et négatif pour la scène "linearRigidAffineFrame".

## Groupes Likwid


### Groupes mesurés


Les courbes suivantes présentent les résultat de métriques extraites des
groupes likwid. Leurs descriptions peuvent être obtenues par la commande :

    likwid-perfct -H -g <group>


1. L2

   Pour Les métriques des deux prochains groupes, nous utilisons la somme sur
   les cœurs pour les exécutions parallèles, car chaque cœur mesure uniquement
   des défauts de caches.

   >Formulas:
   >
   >L2 Load [MBytes/s] = 1.0E-06*L1D_REPLACEMENT*64/time
   >
   >L2 Evict [MBytes/s] = 1.0E-06*L1D_M_EVICT*64/time
   >
   > **L2 bandwidth [MBytes/s] = 1.0E-06*64*(L1D_REPLACEMENT+L1D_M_EVICT)/time**
   >
   >**L2 data volume [GBytes] = 1.0E-09*64*(L1D_REPLACEMENT+L1D_M_EVICT)**
   >
   >---
   >
   >Profiling group to measure L2 cache bandwidth. The bandwidth is computed by the
   number of cacheline allocated in the L1 and the number of modified cachelines
   evicted from the L1. The group also output total data volume transfered between
   L2 and L1. Note that this bandwidth also includes data transfers due to a write
   allocate load on a store miss in L1.
    

3. L3
   >Formulas:
   >
   >L3 Load [MBytes/s]  1.0E-06*L2_LINES_IN_ALL*64/time
   >
   >L3 Evict [MBytes/s]  1.0E-06*L2_LINES_OUT_DIRTY_ALL*64/time
   >
   >**L3 bandwidth [MBytes/s] 1.0E-06&#42;(L2_LINES_IN_ALL+L2_LINES_OUT_DIRTY_ALL)&#42;64/time**
   >
   >**L3 data volume [GBytes] 1.0E-09&#42;(L2_LINES_IN_ALL+L2_LINES_OUT_DIRTY_ALL)&#42;64**
   >
   >---
   >Profiling group to measure L3 cache bandwidth. The bandwidth is computed by the
   number of cacheline allocated in the L2 and the number of modified cachelines
   evicted from the L2. This group also outputs data volume transfered between the
   L3 and  measured cores L2 caches. Note that this bandwidth also includes data
   transfers due to a write allocate load on a store miss in L2.
<!--

4. L2CACHE
   >Formulas:
   >  
   >L2 request rate = L2_TRANS_ALL_REQUESTS / INSTR_RETIRED_ANY
   >  
   >L2 miss rate  = L2_RQSTS_MISS / INSTR_RETIRED_ANY
   >  
   >**L2 miss ratio = L2_RQSTS_MISS / L2_TRANS_ALL_REQUESTS**
   >  
   >---
   >This group measures the locality of your data accesses with regard to the
   L2 Cache. L2 request rate tells you how data intensive your code is
   or how many Data accesses you have in average per instruction.
   The L2 miss rate gives a measure how often it was necessary to get
   cachelines from memory. And finally L2 miss ratio tells you how many of your
   memory references required a cacheline to be loaded from a higher level.
   While the Data cache miss rate might be given by your algorithm you should
   try to get Data cache miss ratio as low as possible by increasing your cache reuse.
   Note: This group might need to be revised!

   Pour cette métrique, nous utilisons la moyenne exécutions 
   parallèles (il s'agit d'un ratio).-->

5. MEM
    >Group MEM:
    >
    >Profiling group to measure main memory bandwidth drawn by all cores of
    a socket.  Since this group is based on uncore events it is only possible to
    measure on the granularity of a socket.  If a thread group contains multiple
    threads only one thread per socket will show the results.  Also outputs total
    data volume transfered from main memory.
    
    Metrics:  
    > Memory Read BW [MBytes/s]  
    > Memory Write BW [MBytes/s]  
    > **Memory BW [MBytes/s]**   
    > **Memory data volume [GBytes]**

    Pour toutes les métriques de ce groupe, nous utilisons une somme car
    likwid ne les mesures que pour 1 cœur par socket, et la machine
    utilisée n'en contient qu'une.

Code pour afficher un groupe complet :
    
    ```r
    #group<-grep("GROUP",groupNames)
    #for(mtr in 1:4)
    #{
    #   for(sn in SceneNumbers)
    #   {
    #       show(plots[[sn]][[group]][[mtr]][[1]])
    #       show(plots[[sn]][[group]][[mtr]][[2]])
    #   }
    #}
    ```

### Résultats d'analyse

Pour plus de lisibilité on se restreint a quelques métriques (celle
précédemment mise en gras).  

<!--
Le ratio écriture/lecture nous montre que les fonctions que nous avons repérée
comme importante écrivent plus de données qu'elles n'en lisent.


```r
for(sn in SceneNumbers)
{
    group<-grep("DATA",groupNames)
    mtr<-grep("Load",plotTitles[[sn]][[group]])
    show(plots[[sn]][[group]][[mtr]][[2]])
}
```

![plot of chunk unnamed-chunk-7](figure/unnamed-chunk-7-1.png)![plot of chunk unnamed-chunk-7](figure/unnamed-chunk-7-2.png)![plot of chunk unnamed-chunk-7](figure/unnamed-chunk-7-3.png)![plot of chunk unnamed-chunk-7](figure/unnamed-chunk-7-4.png)![plot of chunk unnamed-chunk-7](figure/unnamed-chunk-7-5.png)
-->
#### Trafic mémoire

Analysons le trafic mémoire entre le depuis le cache L1 jusqu'à la RAM.
+ Par fonctions

    
    ```r
    SceneNumbers  <-  c(1,2,3,4)
    for(sn in SceneNumbers)
    {
        group<-grep("L2$",groupNames)
        mtr<-grep("bandwidth",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
        group<-grep("L3",groupNames)
        mtr<-grep("bandwidth",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
        group<-grep("MEM",groupNames)
        mtr<-grep("Memory BW",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
    }
    ```
    
    ![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-1.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-2.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-3.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-4.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-5.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-6.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-7.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-8.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-9.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-10.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-11.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-12.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-13.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-14.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-15.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-16.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-17.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-18.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-19.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-20.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-21.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-22.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-23.png)![plot of chunk unnamed-chunk-8](figure/unnamed-chunk-8-24.png)

On observe un legère agumentation de bande passe pour applyJT vec a tous les
niveau ainsi qu'une forte hause du volume de donnée. Alors que pour les autres
fonctions l'utilisation de la mémoire semble dimnuer (partage efficace).  
Il semble y avoir des problèmes de faux/ d'absence de partage mémoire entre les threads.


+ Au global 

    
    ```r
    for(sn in SceneNumbers)
    {
        group<-grep("L2$",groupNames)
        mtr<-grep("bandwidth",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[1]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[1]])
        group<-grep("L3",groupNames)
        mtr<-grep("bandwidth",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[1]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[1]])
        group<-grep("MEM",groupNames)
        mtr<-grep("Memory BW",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[1]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[1]])
    }
    ```
    
    ![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-1.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-2.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-3.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-4.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-5.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-6.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-7.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-8.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-9.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-10.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-11.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-12.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-13.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-14.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-15.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-16.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-17.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-18.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-19.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-20.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-21.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-22.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-23.png)![plot of chunk unnamed-chunk-9](figure/unnamed-chunk-9-24.png)
+ Au niveau de la simulation 

    
    ```r
    for(sn in SceneNumbers)
    {
        group<-grep("L2$",groupNames)
        mtr<-grep("bandwidth",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[3]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[3]])
        group<-grep("L3",groupNames)
        mtr<-grep("bandwidth",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[3]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[3]])
        group<-grep("MEM",groupNames)
        mtr<-grep("Memory BW",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[3]])
        mtr<-grep("data volume",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[3]])
    }
    ```
    
    ![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-1.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-2.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-3.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-4.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-5.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-6.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-7.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-8.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-9.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-10.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-11.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-12.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-13.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-14.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-15.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-16.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-17.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-18.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-19.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-20.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-21.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-22.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-23.png)![plot of chunk unnamed-chunk-10](figure/unnamed-chunk-10-24.png)
Au global l'utilisation mémoire s'intensifie en parallèle, mais pas si l'on se
restreint à la partie simulation.  

<!--
Ensuite nous nous intéressons a pourcentage de miss en L2

+ L'analyse sur le global 

    
    ```r
    for(sn in SceneNumbers)
    {
        group<-grep("L2CACHE",groupNames)
        mtr<-grep("miss ratio",plotTitles[[sn]][[group]])
        #show(plots[[sn]][[group]][[mtr]][[1]])
        show(plots[[sn]][[group]][[mtr]][[3]])
        mtr<-grep("request",plotTitles[[sn]][[group]])
        #show(plots[[sn]][[group]][[mtr]][[1]])
        show(plots[[sn]][[group]][[mtr]][[3]])
    }
    ```
    
    ![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-1.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-2.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-3.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-4.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-5.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-6.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-7.png)![plot of chunk unnamed-chunk-11](figure/unnamed-chunk-11-8.png)
Au global, on accède plus souvent au L2 mais en gardant le même ratio de
"miss", pas de gros impact du partage.

+ Par fonction

    
    ```r
    for(sn in SceneNumbers)
    {
        group<-grep("L2CACHE",groupNames)
        mtr<-grep("miss ratio",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
        mtr<-grep("request",plotTitles[[sn]][[group]])
        show(plots[[sn]][[group]][[mtr]][[2]])
    }
    ```
    
    ![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-1.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-2.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-3.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-4.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-5.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-6.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-7.png)![plot of chunk unnamed-chunk-12](figure/unnamed-chunk-12-8.png)
On retrouve la même tendance, excepté pour la zone applyJT vec qui semble poser
problème (beaucoup plus d'accès au L2, beaucoup plus de défauts de cache).

-->


```r
#Clean the environment
remove(sn)
remove(scnNum)
remove(grpNum)
remove(mtr)
remove(plots)
remove(nplots)
remove(plotTitles)
remove(group)
remove(p)
remove(SceneNumbers)
remove(groupNames)
remove(resgrep)
remove(MyPlotter)
remove(resgrep1)
remove(val)
remove(i)
```

## Conclusions

+ Comme prévu des fonctions clés ressortent (applyJ et applyJT de
  BaseDeformationMapping).
+ La parallélisation openmp est déjà rentable mais elle semble limitée par la
mémoire.
+ Des problèmes mémoire sur la zone applyJT vec
+ Potentiellement des choses à voir côté initialisation

Il faudrait observer la forme des accès mémoire, essayer de déclencher plus de
partage entre les threads en parallélisant à un niveau plus global ?
