# robustness checks: alternative timeframes

setwd("set your working directory")
library(estimatr)
source("prep.R")

dta<-read.csv("Outputs/rates_regression_set_alt_tfs.csv") 

# standardize all the core and bench variables
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

# run through every iteration
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

tfz<-paste(c(2015:2023),2024,sep="-")
rzl<-list()
for (j in 1:9) rzl[[j]]<-clse(tfz[j])[[1]]
rzl[[10]]<-clse("2021-2023")[[1]]
rzcre<-do.call(rbind,rzl)
write.csv(rzcre,"Outputs/reg_results_alt_spans.csv",row.names=F)
for (j in 1:9) print(clse(tfz[j])[[2]]) # R2
clse("2021-2023")[[2]] # R2

