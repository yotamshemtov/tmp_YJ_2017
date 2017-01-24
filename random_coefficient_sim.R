
rm(list = ls())

library(ggplot2)
library(tidyr)
library(dplyr)

library(estCI)

#dirFigures = "~/Dropbox/att_CI/figures"

set.seed(12345)

############################################ 
# Simulation 
############################################

# Parameters
n=1000
num.simulations.finite = 1000
num.draws.super = 1000
sigma0 = 1
beta.var = seq(0,5,by = 0.5)

### Generating the data function
f.finite.sample = function(k){
  y0 = rnorm(n,mean=10,sd=sigma0)
  beta = rnorm(n,mean=3,sd=k)
  y1 = beta+y0
  tau = y1-y0
  
  sate = mean((y1-y0))
  
  gain.satt.vec <- gain.sharp.vec <- gain.satt.sharp.vec  <- rep(NA,num.simulations.finite)
  type1.error.satt.vec <- type1.error.satc.vec <- rep(NA,num.simulations.finite)
  error.sate.in.satt.vec <- error.satt.in.sate.vec <- rep(NA,num.simulations.finite)
  
  for (i in c(1:num.simulations.finite)){
    tr = rep(0,n)
    tr.index = sample(c(1:n),size=n/2,replace=FALSE)
    tr[tr.index]=1
    
    y = tr*y1 + y0*(1-tr)
    
    result = aveCI(y,tr, print=FALSE)
    
    length.satt.ci = result$sattCI[[2]]-result$sattCI[[1]]
    length.sharp.ci = result$sharpCI[[2]]-result$sharpCI[[1]]
    length.neyman.ci = result$neymanCI[[2]]-result$neymanCI[[1]]
    
    satt = mean((y1-y0)[tr==1])
    satc = mean((y1-y0)[tr==0])
    
    type1.error.satt.vec[i] = satt> result$sattCI[[2]] | satt< result$sattCI[[1]]
    type1.error.satc.vec[i] = satc> result$satcCI[[2]] | satc< result$satcCI[[1]]
    
    gain.satt.vec[i] = 1-length.satt.ci/length.neyman.ci
    gain.sharp.vec[i] = 1-length.sharp.ci/length.neyman.ci
    gain.satt.sharp.vec[i] = 1-length.satt.ci/length.sharp.ci
    
    error.sate.in.satt.vec[i] = sate> result$sattCI[[2]] | sate< result$sattCI[[1]]
    error.satt.in.sate.vec[i] = satt > result$neymanCI[[2]] | satt< result$neymanCI[[1]]
  }
  
  r = data.frame(
    type1.error.satt.ave = mean(type1.error.satt.vec),
    type1.error.satc.ave = mean(type1.error.satc.vec),
    gain.satt.ave = mean(gain.satt.vec),
    gain.sharp.ave = mean(gain.sharp.vec),
    gain.satt.sharp.ave = mean(gain.satt.sharp.vec),
    error.sate.in.satt.ave = mean(error.sate.in.satt.vec),
    error.satt.in.sate.ave = mean(error.satt.in.sate.vec),
    var.tau = var(tau)
  )
  
  return(r)
}

# check
print(f.finite.sample(4))

d = data.frame(
  gain.satt.ci = rep(NA,num.draws.super * length(beta.var)),
  gain.satt.sharp.ci =  rep(NA,num.draws.super * length(beta.var)),
  gain.sharp.ci = rep(NA,num.draws.super * length(beta.var)),
  beta.var = rep(beta.var,each= num.draws.super),
  size.indicator.satt = rep(NA,num.draws.super * length(beta.var)),
  size.indicator.sate.in.satt = rep(NA,num.draws.super * length(beta.var)),
  size.indicator.satc = rep(NA,num.draws.super * length(beta.var)),
  size.indicator.satt.in.sate = rep(NA,num.draws.super * length(beta.var))
)
dim(d)

### Simulation 
for (i in c(1:length(beta.var))){
  for (s in c(1:num.draws.super)){
    if(s%%10==0){cat("Variance random coefficient: ",beta.var[i],", Iteration: ",s,"\n")}
    
    result = f.finite.sample(beta.var[i])
    d$gain.satt.ci[(i-1)*num.draws.super + s] = result$gain.satt.ave
    d$gain.sharp.ci[(i-1)*num.draws.super + s] = result$gain.sharp.ave
    d$gain.satt.sharp.ci[(i-1)*num.draws.super + s] = result$gain.satt.sharp.ave
    d$size.indicator.satt[(i-1)*num.draws.super + s] = result$type1.error.satt.ave
    d$size.indicator.satc[(i-1)*num.draws.super + s] = result$type1.error.satc.ave
    d$size.indicator.sate.in.satt[(i-1)*num.draws.super + s] = result$error.sate.in.satt.ave
    d$size.indicator.satt.in.sate[(i-1)*num.draws.super + s] = result$error.satt.in.sate.ave
  }
}

d$beta.var = factor(d$beta.var)

############################################################
# Gains Figure --- comparison to sharp bound and Neyman
############################################################

dp <- d %>%
  group_by(beta.var) %>%
  summarise(
    gain.satt.ci = mean(gain.satt.ci),
    gain.satt.sharp.ci = mean(gain.satt.sharp.ci),
    gain.sharp.ci = mean(gain.sharp.ci),
    #
    size.indicator.satt = 1 - mean(size.indicator.satt),
    size.indicator.sate.in.satt = 1 - mean(size.indicator.sate.in.satt)
  ) %>% ungroup %>% data.frame() %>%
  gather( 2:3, key = "type", value = "gain"  )

dp$type = as.factor(dp$type)
levels(dp$type) = c("Gains from Neyman's", "Gains from sharp bound")

p <- ggplot(dp, aes(y=gain*100 ,x = beta.var, col = type, shape = type))+
  geom_point(size=3)+
  geom_line(aes(group=type), alpha = 0.7, lty=1)+
  labs(
    x = "Variance of treatment effect",
    y = "Percentage length gains \n"
  )+
  scale_colour_grey( start = 0, end = 0.5 )+
  theme_bw()+
  theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank() )+
  theme(panel.border = element_blank(), 
        axis.line.x = element_line(colour = "black"),
        axis.line.y = element_line(colour = "black"))+
  theme( axis.title.x = element_text(size = 15),
         axis.title.y = element_text(size = 15))+
  theme( legend.position = "bottom", 
         legend.text = element_text(size=11))

p <- p + guides(col=guide_legend(title=""),
                shape=guide_legend(title=""))

#setwd(dirFigures)
ggsave(file="random_coefficient_gain_sim_jan2017.pdf", plot = p)


############################################################
# Type-I Figure --- comparison of SATE and SATT cover 
#                      by SATT prediction interval
############################################################

dp <- d %>%
  group_by(beta.var) %>%
  summarise(
    gain.satt.ci = mean(gain.satt.ci),
    gain.satt.sharp.ci = mean(gain.satt.sharp.ci),
    gain.sharp.ci = mean(gain.sharp.ci),
    #
    size.indicator.satt = 1 - mean(size.indicator.satt),
    size.indicator.sate.in.satt = 1 - mean(size.indicator.sate.in.satt)
  ) %>% ungroup %>% data.frame() %>%
  gather( 5:6, key = "estimand", value = "size"  )

dp$estimand = as.factor(dp$estimand)
levels(dp$estimand) = c("Coverage SATE", "Coverage SATT")

### Simulation results - need to improve figure

p <- ggplot(dp, aes(y=size ,x = beta.var, col = estimand, shape = estimand))+
  geom_point(size=3)+
  geom_line(aes(group=estimand), alpha = 0.7, lty=1)+
  labs(
    x = "Variance of treatment effect",
    y = "Average estimand coverage \n"
  )+
  scale_colour_grey( start = 0, end = 0.5 )+
  theme_bw()+
  theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank() )+
  theme(panel.border = element_blank(), 
        axis.line.x = element_line(colour = "black"),
        axis.line.y = element_line(colour = "black"))+
  theme( axis.title.x = element_text(size = 15),
         axis.title.y = element_text(size = 15))+
  theme( legend.position = "bottom", 
         legend.text = element_text(size=11))+
  ylim(0,1)

p <- p + guides(col=guide_legend(title=""),
                shape=guide_legend(title=""))

#setwd(dirFigures)
ggsave(file="random_coefficient_error_sim_jan2017.pdf", plot = p)




