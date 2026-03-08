#

setwd("set your working directory")
library(estimatr)
source("prep.R")

dta<-read.csv("Outputs/rates_regression_set.csv") 

# standardize all the core and bench variables
stdr<-function(vrl,vv) {
  a<-dta %>% mutate(vr=vv) %>% group_by(timeframe) %>% summarize(mv=mean(vr),sv=sd(vr))
  b<-dta %>% mutate(vrv=vv) %>% inner_join(a) %>% mutate(stv=(vrv-mv)/sv) %>%
    select(state,timeframe,stv)
  colnames(b)<-c("state","timeframe",paste("st",vrl,sep=""))
  return(b)
}
vrz<-data.frame(var=names(dta)) %>% mutate(indx=c(1:nrow(.)))
ivs<-filter(vrz,var%in%c("gas_exposure","load_pct","load_delta","wind_solar_delta","btm_delta","saifi_delta","rps_sales_cost","ca","rate_delta_pre","rate_delta_nominal_pre",
                         "ee_delta","expected_loss_mwh","expected_loss_fire_mwh","pou_pct","ev_delta","coal_retirements_twh","iso","utility_owned_gen","switching_pct","ami_delta","dr_potential"))
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

rta<-dta %>% inner_join(stda[,1:2] %>% cbind(select(stda,-state,-timeframe))) %>% mutate(ca_rescale=ca/sd(ca))

# function takes the model as its input
cmplr<-function(vl,vr,tf) {
  dd<-rta %>% mutate(vv=vr) %>% filter(timeframe==tf)
  m<-lm_robust(rate_delta~vv+st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+
                 st_gas_exposure+st_saifi_delta+ca_rescale+st_rate_delta_pre, data = dd, clusters = region,alpha=0.1)
  
  rr<-data.frame(var=vl,coeff=m$coefficients[names(m$coefficients)=="vv"],se=m$std.error[names(m$coefficients)=="vv"],pv=m$p.value[names(m$coefficients)=="vv"]) %>%
    mutate(ss=ifelse(pv<0.1,"*","")) %>%
    mutate(result=paste("R",round(coeff,2),ss," (",round(se,2),")",sep=""),timeframe=tf) %>% 
    select(timeframe,var,coeff,result,se)
  return(rr)
}
tfcmpl<-function(vvl,vvr) {
  l<-list()
  for (j in 1:5) l[[j]]<-cmplr(vvl,vvr,tfz[j])
  rz<-do.call(rbind,l)
  return(rz)
}
tfz<-paste(c(2015:2019),c(2020:2024),sep="-")

# 
psr<-function(z) which(names(rta)==z)
rvars<-data.frame(vlb=c("AMI delta","coal retirements","DR potential","EE delta","EV delta","ISO","POU%","retail competition","risk: natural hazard","risk: wildfire","utility owned gen"),
                  pos=c(psr("ami_delta"),psr("st_coal_retirements_twh"),psr("st_dr_potential"),psr("st_ee_delta"),psr("st_ev_delta"),psr("st_iso"),psr("st_pou_pct"),psr("st_switching_pct"),psr("st_expected_loss_mwh"),psr("st_expected_loss_fire_mwh"),psr("st_utility_owned_gen")))
scvars<-list()
for (k in 1:nrow(rvars)) scvars[[k]]<-tfcmpl(rvars$vlb[k],rta[,rvars$pos[k]])
scnd<-do.call(rbind,scvars)

# one extra set of results, wildfire risk, no CA dummy
wfcmpl<-function(tf) {
  m<-lm_robust(rate_delta~st_expected_loss_fire_mwh+st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+
                 st_gas_exposure+st_saifi_delta+st_rate_delta_pre, data = filter(rta,timeframe==tf), clusters = region,alpha=0.1)
  rr<-data.frame(var="risk: wildfire (no CA dummy)",coeff=m$coefficients[names(m$coefficients)=="st_expected_loss_fire_mwh"],se=m$std.error[names(m$coefficients)=="st_expected_loss_fire_mwh"],pv=m$p.value[names(m$coefficients)=="st_expected_loss_fire_mwh"]) %>%
    mutate(ss=ifelse(pv<0.1,"*","")) %>%
    mutate(result=paste("R",round(coeff,2),ss," (",round(se,2),")",sep=""),timeframe=tf) %>% 
    select(timeframe,var,coeff,result,se)
  return(rr)
}
wfa<-list()
for (j in 1:5) wfa[[j]]<-wfcmpl(tfz[j])
wff<-do.call(rbind,wfa)
xpt<-scnd %>% rbind(wff) %>% arrange(var,timeframe)
write.csv(xpt,"Outputs/secondary_vars.csv",row.names=F)
