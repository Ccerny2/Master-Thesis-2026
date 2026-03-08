# prep script

library(tidyverse)
library(lubridate)
library(cowplot)

# functions
base<-function(z) {
  ggplot(data=z)+theme_light()+theme(axis.text=element_text(size=14,color='gray50'),axis.title=element_text(size=14,color='gray50',angle=0),axis.title.y=element_text(size=14,color='gray50',angle=0),axis.ticks=element_blank(),
                                     panel.grid.major = element_blank(),panel.grid.minor = element_blank(),plot.title=element_text(size=14,face='bold',color='gray50',hjust=0.5),
                                     panel.border = element_blank(), axis.line=element_line(color='gray50'),legend.title=element_text(size=14,face='bold',color='gray50'),legend.text=element_text(size=14,color='gray50'))
}
lblblu<-rgb(8/255,48/255,106/255)
noX<-theme(axis.title.x=element_blank(),axis.text.x=element_blank())
noY<-theme(axis.title.y=element_blank(),axis.text.y=element_blank())
p25<-function(z) quantile(z,.25,na.rm=T)
p75<-function(z) quantile(z,.75,na.rm=T)
ant<-function(lb,x,y,sz,cl) annotate('text',x=x,y=y,label=lb,size=sz,color=cl)
gs<-function(x1,x2,y1,y2,cl,sz=0.3) geom_segment(x=x1,xend=x2,y=y1,yend=y2,color=cl,size=sz)


