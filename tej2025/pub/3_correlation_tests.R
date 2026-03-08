# correlation tests

setwd("set your working directory")
source("prep.R")
library(estimatr)

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

vfa<-rta %>% select(timeframe,st_wind_solar_delta,st_rps_sales_cost,st_btm_delta,st_load_pct,
                    st_gas_exposure,st_saifi_delta,ca_rescale,st_rate_delta_pre)
# vif
vif<-function(tf,z) {
  dd<-filter(vfa,timeframe==tf)
  dda<-cbind(dd[,c(z)],dd[,c(2:9)[c(2:9)!=z]])
  names(dda)<-c("x",names(dd)[c(2:9)[c(2:9)!=z]])
  mdl<-lm(x~.,data=dda)
  dta<-dda %>% mutate(xhat=x-mdl$residuals)
  unadjR2<-(sum((dta$xhat-mean(dta$x))^2))/ # unadjusted R2
    (sum((dta$x-mean(dta$x))^2))
  return(data.frame(var=names(dd)[z],timeframe=tf,vif=(1/(1-unadjR2)))) # VIF
}
vcmpl<-function(tf){
  l<-list()
  for (j in 2:9) l[[j]]<-vif(tf,j)
  return(do.call(rbind,l))
}
vfs<-vcmpl("2015-2020") %>% rbind(vcmpl("2016-2021")) %>% rbind(vcmpl("2017-2022")) %>%
  rbind(vcmpl("2018-2023")) %>% rbind(vcmpl("2019-2024"))
write.csv(vfs,"Outputs/vifs.csv",row.names=F)

# correlogram
cra<-rta %>% filter(timeframe=="2019-2024") %>% select(wind_solar_delta,rps_sales_cost,btm_delta,load_pct,
                    gas_exposure,saifi_delta,ca_rescale,rate_delta_pre)

# 
crrl <- cor(cra, use = "pairwise.complete.obs")
crm<-data.frame(x=rep(c(1:8),times=8),y=rep(c(1:8),each=8),
                val=c(as.vector(as.matrix(crrl)))) %>%
  mutate(cl=ifelse(val>0.3,"b","a"),lab=round(val,2))
lbz<-c("wind+solar delta","RPS growth","BTM delta","load delta","gas exposure",
       "reliability delta","California","prior trend")
ggsave("Figures/correlogram.jpg",
       plot=base(filter(crm,x<y))+geom_tile(aes(x,y,fill=val))+
         geom_text(aes(x,y,label=lab,color=cl))+
         scale_color_manual(values=c("black","white"),guide="none")+
         scale_fill_gradient2(low='firebrick4',mid='white',high="navy",midpoint=0,guide="none")+
         scale_x_continuous(breaks=c(1:8),labels=lbz)+
         scale_y_continuous(breaks=c(1:8),labels=lbz)+
         theme(axis.text.x=element_text(angle=45,hjust=1),
               axis.line.y=element_blank(),axis.line.x=element_blank(),
               axis.title.y=element_blank(),axis.title.x=element_blank()),width=6,height=6)


