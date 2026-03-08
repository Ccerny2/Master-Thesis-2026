# script to generate data in format for regressions

library(tidyverse)

# set working directory
setwd("set your working directory")
dta <- read.csv("Data/inputs.csv")

# certain transformations prior to calculating trends
dda<-dta %>% 
  mutate(solar=ifelse(is.na(gen_gwh_solar),0,gen_gwh_solar),wind=ifelse(is.na(gen_gwh_wind),0,gen_gwh_wind),
         saifi=ifelse(is.na(saifi),NA,ifelse(saifi<0,0,saifi))) %>%
  mutate(gas_hub_price_real=gas_hub_price_real/10, # convert all gas $/MWh to ¢/kWh
         ws=(solar+wind)/gen_gwh_total,gas_share=(gen_gwh_gas/gen_gwh_total)) %>%
  mutate(gas_exposure=gas_share*gas_hub_price_real,
         gas_exposure_nominal=gas_share*gas_hub_price,
         iso=ifelse(state%in%c('AR','CA','CT','DE','IL','IN','IA','KS','KY','LA','ME','MD',
                               'MA','MI','MN','MS','MO','NE','NH','NJ','NY','ND','OH','OK','PA',
                               'RI','SD','TX','VT','VA','WV','WI'),1,0)) 
  

# stack data sets to derive changes and pct. changes for vars that require them
stkr<-function(yy,pt) {
  a<-dda %>% filter(year==yy) %>% 
    select(state,rate_real_2024,rate_nominal,resi_rate_real,sales_mwh,ws,btm,ee,ev_pct)
  names(a)<-c("state",paste(names(a)[2:9],"_",pt,sep=""))
  return(a)
}
# SAIFI (reliability) and AMI on 2-year deltas
lgVars<-function(y1,y2) {
  dda %>% filter(year%in%c(y1-1,y1)) %>% group_by(state) %>%
    summarize(saifi_ys=mean(saifi,na.rm=T),ami_ys=mean(ami_pct,na.rm=T)) %>%
    inner_join(dda %>% filter(year%in%c(y2-1,y2)) %>% group_by(state) %>%
                 summarize(saifi_ye=mean(saifi,na.rm=T),ami_ye=mean(ami_pct,na.rm=T))) %>%
    mutate(saifi_delta=saifi_ye-saifi_ys,
           ami_delta=ami_ye-ami_ys) %>% select(state,saifi_delta,ami_delta)
}

# function to generate regression data sets across timeframes
rgSet<-function(y1,y2) {
  dlts<-inner_join(stkr(y1,"ys"),stkr(y2,"ye")) %>% 
    mutate(rate_delta=rate_real_2024_ye-rate_real_2024_ys,rate_delta_nominal=rate_nominal_ye-rate_nominal_ys,
           resi_rate_delta=resi_rate_real_ye-resi_rate_real_ys,
           rate_pct=(rate_real_2024_ye-rate_real_2024_ys)/rate_real_2024_ys,
           wind_solar_delta=(ws_ye-ws_ys)*100,wind_solar_pct=(ws_ye-ws_ys)/ws_ys,
           load_delta=sales_mwh_ye-sales_mwh_ys,load_pct=(sales_mwh_ye-sales_mwh_ys)/sales_mwh_ys,
           btm_delta=(btm_ye-btm_ys)*100,ee_delta=(ee_ye-ee_ys)*100,ev_delta=ev_pct_ye-ev_pct_ys) 
  
  # sums and averages
  avgs<-dda %>% filter(year%in%c(y1:y2)) %>% group_by(state) %>%
    summarize(gas_share=mean(gas_share),gas_exposure=mean(gas_exposure),gas_exposure_nominal=mean(gas_exposure_nominal),
              coal_retirements_twh=sum(coal_retirements_twh),utility_owned_gen=mean(utility_owned_gen),
              pou_pct=mean(pou_pct,na.rm=T),switching_pct=mean(switching_pct,na.rm=T),
              dr_potential=mean(dr_mw_per_twh_potential,na.rm=T)) 
  
  
  # prior trend change for rate
  rdlts<-inner_join(stkr(y1-5,"ys"),stkr(y1,"ye")) %>% 
    mutate(rate_delta_pre=rate_real_2024_ye-rate_real_2024_ys,
           rate_delta_nominal_pre=rate_nominal_ye-rate_nominal_ys,
           rate_pct_pre=(rate_real_2024_ye-rate_real_2024_ys)/rate_real_2024_ys) %>%
    select(state,rate_delta_pre,rate_delta_nominal_pre,rate_pct_pre)
  
  # RPS increments generated in inputs, selection varies based on timeframe
  if (y2==2024) dda$rps<-dda$rps_2024
  else {
    if (y1==2021 & y2==2023) dda$rps<-dda$rps_2021_2023
    else dda$rps<-dda$rps_5year
  } 
    
  # bring everything together
  rga<-dlts %>% select(state,names(dlts)[18:28]) %>% inner_join(avgs) %>%
    inner_join(filter(dda,year==y2) %>% select(state,region,iso,expected_loss_mwh,expected_loss_fire_mwh)) %>%
    inner_join(rdlts) %>% inner_join(lgVars(y1,y2)) %>% 
    mutate(ca=ifelse(state=="CA",1,0))
  
  rgx<-data.frame(timeframe=paste(y1,y2,sep="-")) %>% cbind(rga)
  return(rgx)
}

# tag on RPS to each output file
rps<-read.csv("Data/rps_incremental_gen.csv") %>% # incremental need
  inner_join(read.csv("Data/rps_costs.csv")) %>% # proxy REC price
  mutate(rps_sales_cost=rps*multiplier) %>% select(timeframe,state,rps_sales_cost)

rgxpt<-rgSet(2019,2024) %>% rbind(rgSet(2018,2023)) %>% rbind(rgSet(2017,2022)) %>% 
  rbind(rgSet(2016,2021)) %>% rbind(rgSet(2015,2020)) %>%
  left_join(rps) %>% mutate(rps_sales_cost=ifelse(is.na(rps_sales_cost),0,rps_sales_cost))
write.csv(rgxpt,"Outputs/rates_regression_set.csv",row.names=F)

# alternative timeframes, ending in 2024
rgxptAltTfs<-rgSet(2023,2024) %>% rbind(rgSet(2022,2024)) %>% rbind(rgSet(2021,2024)) %>% rbind(rgSet(2020,2024)) %>% rbind(rgSet(2019,2024)) %>% rbind(rgSet(2018,2024)) %>% rbind(rgSet(2017,2024)) %>% 
  rbind(rgSet(2016,2024)) %>% rbind(rgSet(2015,2024)) %>% rbind(rgSet(2021,2023)) %>%
  left_join(rps) %>% mutate(rps_sales_cost=ifelse(is.na(rps_sales_cost),0,rps_sales_cost))
write.csv(rgxptAltTfs,"Outputs/rates_regression_set_alt_tfs.csv",row.names=F)




