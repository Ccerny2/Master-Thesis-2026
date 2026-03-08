# script to run core regressions and generate figures 1 and 2


setwd("set your working directory")
source("prep.R")
library(estimatr)

dta<-read.csv("Outputs/rates_regression_set.csv") 

# standardize all the core variables
stdr<-function(vrl,vv) {
  a<-dta %>% mutate(vr=vv) %>% group_by(timeframe) %>% summarize(mv=mean(vr),sv=sd(vr))
  b<-dta %>% mutate(vrv=vv) %>% inner_join(a) %>% mutate(stv=(vrv-mv)/sv) %>%
    select(state,timeframe,stv)
  colnames(b)<-c("state","timeframe",paste("st",vrl,sep=""))
  return(b)
}
vrz<-data.frame(var=names(dta)) %>% mutate(indx=c(1:nrow(.)))
ivs<-filter(vrz,var%in%c("gas_exposure","load_pct","wind_solar_delta","btm_delta","saifi_delta","rps_sales_cost","ca","rate_delta_pre"))
stdr<-function(z) {
  a<-dta %>% mutate(vr=dta[,z]) %>% group_by(timeframe) %>% summarize(mv=mean(vr),sv=sd(vr))
  b<-dta %>% mutate(vrv=dta[,z]) %>% inner_join(a) %>% mutate(stv=(vrv-mv)/sv) %>%
    select(state,timeframe,stv)
  colnames(b)<-c("state","timeframe",paste("st",names(dta)[z],sep="_"))
  return(b)
}
stdz<-list()
for (j in 1:nrow(ivs)) stdz[[j]]<-stdr(ivs$indx[j])
stda<-do.call(cbind,stdz)
rta<-dta %>% inner_join(stda[,1:2] %>% cbind(select(stda,-state,-timeframe))) %>%
  mutate(ca_rescale=ca/sd(ca))

# run through every iteration, region-clustered SEs
clse<-function(tf) {
  m<-lm_robust(rate_delta~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+
                 st_gas_exposure+st_saifi_delta+ca_rescale+st_rate_delta_pre, data = filter(rta,timeframe==tf), clusters = region,alpha=0.1)
  rr<-list()
  rr[[1]]<-data.frame(var=names(m$coefficients),coeff=m$coefficients,se=m$std.error,pv=m$p.value,lo=m$conf.low,hi=m$conf.high) %>%
    mutate(ss=ifelse(pv<0.1,"*","")) %>%
    mutate(result=paste("R",round(coeff,2),ss," (",round(se,2),")",sep=""),timeframe=tf) %>% 
    select(timeframe,var,coeff,result,se,ss,lo,hi)
  rr[[2]]<-m$adj.r.squared
  return(rr)
}

tfz<-paste(c(2015:2019),c(2020:2024),sep="-")
rzl<-list()
for (j in 1:5) rzl[[j]]<-clse(tfz[j])[[1]]
rzcre<-do.call(rbind,rzl)

# export core results
write.csv(rzcre,"Outputs/reg_results_core.csv",row.names=F)
for (j in 1:5) print(clse(tfz[j])[[2]]) # R2



#### Shapley values (Figure 1)
library(gtools)
cpllr<-function(dd,cmbz,z) {
  cmbo<-cmbz[[z]] # pulls one of the ranges of combinations
  l<-list()
  for (i in 1:nrow(cmbo)) l[[i]]<-data.frame(r2a=summary(lm(rate_delta~.,data=as.data.frame(dd[,c(1,cmbo[i,])])))$r.squared, # regression without key var
                                             r2b=summary(lm(rate_delta~.,data=as.data.frame(dd[,c(1,2,cmbo[i,])])))$r.squared) # regression with key var
  return(do.call(rbind,l) %>% mutate(pls=r2b-r2a) %>% select(pls))
}
empty<-function(dt,z) {
  dd<-select(dt,rate_delta,names(dt)[z])
  return(data.frame(pls=summary(lm(rate_delta~.,data=dd))$r.squared))
}
shply<-function(zz,tf) {
  a<-rgd %>% filter(timeframe==tf)
  h<-a %>% select(rate_delta,names(rgd)[zz]) 
  j<-h %>% cbind(select(a,-names(h),-timeframe))
  N<-length(names(j)) # to chop off MD_STATE
  cmbs<-list()
  for (i in 1:(N-2)) cmbs[[i]]<-combinations(n=(N-2),r=i,v=c(3:N)) # all possible combinations
  ll<-list()
  for (k in 1:(N-2)) ll[[k]]<-cpllr(j,cmbs,k)
  xta<-do.call(rbind,ll) %>% rbind(empty(rgd,zz))
  return(mean(xta$pls))
}

rgd<-rta %>% select(rate_delta,st_gas_exposure,st_load_pct,st_wind_solar_delta,st_btm_delta,
                    st_saifi_delta,st_rps_sales_cost,ca_rescale,st_rate_delta_pre,timeframe)
names(rgd)
shpa<-data.frame(var=names(rgd)[2:9]) 
shpz<-list()
for (k in 1:5) shpz[[k]]<-shpa 
for (k in 1:5) for (ii in 1:nrow(shpa)) shpz[[k]]$shply[ii]<-shply(ii+1,tfz[k])
for (k in 1:5) shpz[[k]]$timeframe<-tfz[k]
shpl<-do.call(rbind,shpz)

shp24<-shpl %>% filter(timeframe=="2019-2024") %>% arrange(shply) %>% 
  mutate(fl=c("a","b","c","d","e","f","g","h"))

shpf<-shpl %>% inner_join(data.frame(timeframe=tfz,x=c(5:1))) %>% inner_join(select(shp24,var,fl))

ggsave("Figures/figure1.jpg",
       plot=base(shpf)+coord_flip()+
         geom_col(aes(x,shply,fill=fl))+
         scale_x_continuous(breaks=c(1:5),labels=rev(tfz))+ylab("Shapley Value")+
         scale_fill_manual(values=c("khaki","gray50","green2","lightblue3","darkcyan",
                                    "slateblue","tan1","firebrick4"),guide="none")+
         scale_y_continuous(breaks=c(0,0.35,0.7),labels=c("0","0.35","0.7"))+
         ant("CA",1,0.14,5,'white')+ant("BTM",1,0.38,5,'black')+
         ant("load",1,0.55,5,'black')+ant("RPS",1,0.665,5,'white')+
         ant("gas",1,0.733,3.5,'black')+ant("wind+solar",1.6,0.73,3,'gray50')+
         ant("reliability",2.02,0.758,3,"gray50")+ant("prior trend",1.8,0.74,3,'gray50')+
         geom_segment(x=1,xend=1.7,y=0.785,yend=0.785,color='gray50',linewidth=0.1)+
         geom_segment(x=1.45,xend=1.9,y=0.794,yend=0.794,color='gray50',linewidth=0.1)+
         theme(axis.title.y=element_blank()),width=6,height=4)

# effects figure (Figure 2)
mdl<-lm(rate_delta~gas_exposure+load_pct+wind_solar_delta+btm_delta+
          saifi_delta+rps_sales_cost+ca+rate_delta_pre, data = filter(rta,timeframe=="2019-2024"))

uja<-rta %>% filter(timeframe=="2019-2024") %>% mutate(prd1=predict(mdl)) %>%
  mutate(gas_eff=mdl$coefficients[2]*gas_exposure,
         load_eff=mdl$coefficients[3]*load_pct,
         ws_eff=mdl$coefficients[4]*wind_solar_delta,
         btm_eff=mdl$coefficients[5]*btm_delta,
         saifi_eff=mdl$coefficients[6]*saifi_delta,
         rps_eff=mdl$coefficients[7]*rps_sales_cost,
         ca_eff=mdl$coefficients[8]*ca) %>%
  mutate(others=prd1-gas_eff-load_eff-ws_eff-btm_eff-saifi_eff-rps_eff-ca_eff) %>%
  arrange(prd1) %>% mutate(x=c(1:48))
fja<-data.frame(state=rep(uja$state,times=8),x=rep(uja$x,times=8),
                eff=c(uja$gas_eff,uja$load_eff,uja$ws_eff,uja$btm_eff,uja$saifi_eff,uja$rps_eff,uja$ca_eff,uja$others),
                fl=rep(c("Gas","Load","Ws","aBTM","SAIFI","RPS","zCA","zzOther"),each=48))
actls<-select(uja,state,x) %>% inner_join(rta %>% filter(timeframe=="2019-2024") %>%
                                            select(state,rate_delta))
prdz<-rbind(select(uja,x,prd1) %>% rename(est=prd1) %>% mutate(typ="aPrd"),
            select(actls,x,rate_delta) %>% rename(est=rate_delta) %>% mutate(typ="bActual"))
ggsave("Figures/figure2.jpg",
       plot=base(fja)+geom_col(aes(x,eff,fill=fl),alpha=0.9)+
         geom_point(data=prdz,aes(x,est,color=typ,shape=typ),size=2)+
         scale_color_manual(values=c("navy","purple"),guide="none")+
         scale_shape_manual(values=c(16,18),guide="none")+
         geom_point(data=actls,aes(x,rate_delta),color='purple',shape=18,size=2)+
         scale_fill_manual(values=c('tan1',"lightblue3","slateblue","darkcyan","khaki","green2","firebrick4","gray70"),
                           labels=c("BTM","Gas","Load","RPS","Reliability","Wind/solar","CA","Other"),name="")+
         ylab("Predicted\nPrice Change\n(¢/kWh)")+scale_y_continuous(breaks=c(-3,0,3,6),labels=c('-3','0','3','6'))+
         theme(axis.title.x=element_blank(),axis.text.x=element_blank(),
               legend.position=c(0.24,0.76),legend.title=element_blank())+
         ant("ND",1,-3.2,4,'gray50')+ant("CA",48,7.2,4,'gray50')+
         geom_point(aes(x=27.5,y=-2.3),shape=16,color='navy',size=2)+ant("Net prediction",36.6,-2.3,4,'navy')+
         geom_point(aes(x=27.5,y=-2.8),shape=18,color='purple',size=2)+ant("Actual rate change",39,-2.8,4,'purple'),width=5,height=5)

