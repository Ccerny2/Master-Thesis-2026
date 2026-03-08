# robustness checks: alternative specifications

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
ivs<-filter(vrz,var%in%c("gas_exposure","gas_exposure_nominal","load_pct","load_delta","wind_solar_delta","btm_delta","saifi_delta","rps_sales_cost","ca","rate_delta_pre","rate_delta_nominal_pre",
                         "expected_loss_mwh","expected_loss_fire_mwh","pou_pct","ev_delta","coal_retirements_gen","iso","utility_owned_gen","switching_pct","ami_2yr_delta","dr_potential"))
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

tfz<-paste(c(2015:2019),c(2020:2024),sep="-")
# function takes the model as its input
rbCmplr<-function(MDL,tf) {
  m<-MDL
  l<-data.frame(var=names(m$coefficients),coeff=m$coefficients,se=m$std.error,pv=m$p.value) %>%
    mutate(ss=ifelse(pv<0.1,"*","")) %>%
    mutate(result=paste("R",round(coeff,2),ss," (",round(se,2),")",sep=""),timeframe=tf) %>% 
    select(var,result) %>% filter(var!="(Intercept)") %>%
    rbind(data.frame(var="R2",result=round(MDL$adj.r.squared,3)))
  colnames(l)<-c("var",paste('r',tf,sep=""))
  return(l)
}
bndr<-function(z) full_join(z[[1]],z[[2]]) %>% full_join(full_join(z[[3]],z[[4]])) %>% full_join(z[[5]])

# alternative DV specifications
pctd<-function(tf) lm_robust(rate_pct~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure+
                              st_saifi_delta+ca_rescale+st_rate_delta_pre, data = filter(rta,timeframe==tf), clusters = region)
pctR<-list()
for (j in 1:5) pctR[[j]]<-rbCmplr(pctd(tfz[j]),tfz[j])
write.csv(bndr(pctR),"Outputs/robust_rate_pct_change.csv",row.names=F)

#### compare RMSE of two possible DV definitions
library(caret)
train_control <- trainControl(method = "cv", number = 10)

# and compare RMSE
rmsePll<-function(dv,tf) {
  dd<-rta %>% mutate(DV=scale(dv)) %>% filter(timeframe==tf)
  m<-train(DV~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure+
               st_saifi_delta+ca_rescale+st_rate_delta_pre, data = dd,
             method='lm',trControl = train_control)
  return(data.frame(timeframe=tf,rmse=round(m$results$RMSE,2)))
  } 

real<-list()
for (j in 1:5) real[[j]]<-rmsePll(rta$rate_delta,tfz[j])
realR<-do.call(rbind,real)

pct<-list()
for (j in 1:5) pct[[j]]<-rmsePll(rta$rate_pct,tfz[j])
pctR<-do.call(rbind,pct)

cbind(realR,pctR)

# function takes the model as its input
rbCmplr<-function(MDL,tf) {
  m<-MDL
  l<-data.frame(var=names(m$coefficients),coeff=m$coefficients,se=m$std.error,pv=m$p.value) %>%
    mutate(ss=ifelse(pv<0.1,"*","")) %>%
    mutate(result=paste("R",round(coeff,2),ss," (",round(se,2),")",sep=""),timeframe=tf) %>% 
    select(var,result) %>% filter(var!="(Intercept)") %>%
    rbind(data.frame(var="R2",result=round(MDL$adj.r.squared,3)))
  colnames(l)<-c("var",paste('r',tf,sep=""))
  return(l)
}

# 1) no prior trend
notr<-function(tf) lm_robust(rate_delta~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure+
                              st_saifi_delta+ca_rescale, data = filter(rta,timeframe==tf), clusters = region)
notR<-list()
for (j in 1:5) notR[[j]]<-rbCmplr(notr(tfz[j]),tfz[j])
write.csv(bndr(notR),"Outputs/robust_no_pretrend.csv",row.names=F)

# 2) residential rates on LHS 
rsr<-function(tf) lm_robust(resi_rate_delta~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure+
                               st_saifi_delta+ca_rescale+st_rate_delta_pre, data = filter(rta,timeframe==tf), clusters = region)
rsR<-list()
for (j in 1:5) rsR[[j]]<-rbCmplr(rsr(tfz[j]),tfz[j])
write.csv(bndr(rsR),"Outputs/robust_resi_rates.csv",row.names=F)

# 3) exclude CA
noCa<-function(tf) lm_robust(rate_delta~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure+
                               st_saifi_delta+st_rate_delta_pre, data = filter(rta,state!="CA",timeframe==tf), clusters = region)
noCaR<-list()
for (j in 1:5) noCaR[[j]]<-rbCmplr(noCa(tfz[j]),tfz[j])
write.csv(bndr(noCaR),"Outputs/robust_no_ca.csv",row.names=F)

# 4) weighted
wta <- read.csv("Data/inputs.csv") %>%
  select(state,year,sales_mwh) %>% 
  mutate(timeframe=paste(year-5,year,sep="-")) %>% select(-year)
wda<-rta %>% inner_join(wta)
wtz<-function(tf) lm_robust(rate_delta~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure+
                              st_saifi_delta+ca_rescale+st_rate_delta_pre, data = filter(wda,timeframe==tf), clusters = region,weights=sales_mwh)

wtR<-list()
for (j in 1:5) wtR[[j]]<-rbCmplr(wtz(tfz[j]),tfz[j])
write.csv(bndr(wtR),"Outputs/robust_sales_weighted.csv",row.names=F)

# 5) nominal prices 
nml<-function(tf) lm_robust(rate_delta_nominal~st_wind_solar_delta+st_rps_sales_cost+st_btm_delta+st_load_pct+st_gas_exposure_nominal+
                              st_saifi_delta+ca_rescale+st_rate_delta_nominal_pre, data = filter(rta,timeframe==tf), clusters = region)

nmlR<-list()
for (j in 1:5) nmlR[[j]]<-rbCmplr(nml(tfz[j]),tfz[j])
write.csv(bndr(nmlR),"Outputs/robust_nominal_prices.csv",row.names=F)

# 6) exclude BTM
noBtm<-function(tf) lm_robust(rate_delta~st_wind_solar_delta+st_rps_sales_cost+st_load_pct+st_gas_exposure+
                               st_saifi_delta+ca_rescale+st_rate_delta_pre, data = filter(rta,timeframe==tf), clusters = region)
noBtmR<-list()
for (j in 1:5) noBtmR[[j]]<-rbCmplr(noBtm(tfz[j]),tfz[j])
write.csv(bndr(noBtmR),"Outputs/robust_no_btm.csv",row.names=F)

