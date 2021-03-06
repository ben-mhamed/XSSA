require(TMB)
compile("xssams.cpp",flags="-O0 -g",safebounds=TRUE,safeunload=TRUE)
dyn.load(dynlib("xssams"))

field.counter <<- 0

   get.field = function()
   {
     field.counter <<- field.counter + 1
     field = sca[field.counter]
   # print(paste(field.counter,field))
     return(field)
   }
   
   get.numeric.field<-function()
   {
      ret = as.numeric(get.field())
      return(ret)
   }

logit<-function(p)
{
   return(log(p/(1-p)))
}

alogit<-function(alpha)
{
   return(1/(1+exp(-alpha)))
}


dat.file = "./xssams.dat"
sca = scan(file=dat.file,comment.char="#",what="raw",quiet=TRUE)
print(paste("Read",length(sca),"items from ",dat.file))

data = list()
phases = list()

data$ngear = get.numeric.field()
ngear=data$ngear
data$ntime = get.numeric.field()
ntime=data$ntime
data$dt = get.numeric.field()
data$obs.catch=matrix(nrow=ngear,ncol=ntime)
for (g in 1:ngear)
{
   for (t in 1:ntime)
   {
      data$obs.catch[g,t] = get.numeric.field()
   }
}
nzero = ntime;
ziter = 0;
while (nzero > 0)
{
   ziter = ziter + 1
   nzero = 0;
   for (g in 1:ngear)
      for (t in 2:ntime)
         if ( (data$obs.catch[g,t] <= 0.0) 
              && (data$obs.catch[g,t-1] > 0.0) && (data$obs.catch[g,t+1] > 0.0) )
         {
            nzero = nzero + 1 
            print(paste(nzero,ziter))
            data$obs.catch[g,t] = 0.5*(data$obs.catch[g,t-1] + data$obs.catch[f,t+1])
            print(paste(nzero, " catch for gear ", g ," at time ", t,
                  " set to ", data$obs.catch[g,t],sep=""))
         }
}
print(paste("Zero catch bridging instances:", nzero))
ZeroCatch = 1.0
data$obs_catch = log(data$obs.catch+ZeroCatch);


forcing.matrix=matrix(nrow=9,ncol=data$ntime)
for (r in 1:9)
{
   for (y in 1:ntime)
   {
      forcing.matrix[r,y] = get.numeric.field()
   }
}
data$fr = get.numeric.field()
data$immigrant_biomass = forcing.matrix[data$fr,]

data$use_mean_forcing = get.numeric.field()
mean.immigrant.biomass = mean(forcing.matrix[data$fr]);
maximum.immigrant.biomass = max(forcing.matrix[data$fr]);
if (data$use_mean_forcing)
   data$immigrant_biomass = mean.immigrant.biomass;
#print(data$immigrant.biomass)

data$phase_T12 = get.numeric.field()
phases = c(phases,data$phase_T12)
data$init_T12 = get.numeric.field()

data$phase_T21 = get.numeric.field() 
phases = c(phases,data$phase_T21)
data$init_T21 = get.numeric.field()

data$phase_r = get.numeric.field()
phases = c(phases,data$phase_r)
data$init_r = get.numeric.field()

data$phase_K = get.numeric.field()
phases = c(phases,data$phase_K)
data$init_K = get.numeric.field()

data$phase_sdlogF = get.numeric.field()
phases = c(phases,data$phase_sdlogF)
data$init_sdlogF = get.numeric.field()

data$phase_sdlogPop = get.numeric.field()
phases = c(phases,data$phase_sdlogPop)
data$init_sdlogPop = get.numeric.field()

data$phase_sdlogYield = get.numeric.field()
phases = c(phases,data$phase_sdlogYield)
data$init_sdlogYield = get.numeric.field()

data$phase_meanProportion_local = get.numeric.field()
phases = c(phases,data$phase_meanProportion_local)
data$init_meanProportion_local =  get.numeric.field()

data$phase_sdProportion_local = get.numeric.field()
phases = c(phases,data$phase_sdProportion_local)
data$init_sdProportion_local = get.numeric.field()

data$phase_qProp = get.numeric.field()
phases = c(phases,data$phase_qProp)
data$init_qProp = get.numeric.field()

data$use_robustY = get.numeric.field()
data$phase_pfat = get.numeric.field()
phases = c(phases,data$phase_pfat)
data$init_pfat = vector(length=ngear)

for (g in 1:ngear)
{
#  print(g)
   data$init_pfat[g] = get.numeric.field()
}
print(paste(field.counter,"input fields processed"))

data$maxtime = ntime
data$lengthU = ntime*(ngear+2)
# set up U indexing starting at 0
data$Fndxl = seq(0,(ntime-1)*(ngear),ngear)
data$Fndxu = data$Fndxl+(ngear-1) 
data$utPop1 = ngear*ntime - 1
data$utPop2 = data$utPop1 + ntime


parameters = list(
  logT12 = log(data$init_T12+1e-10),
  logT21 = log(data$init_T21+1e-10),
  logr = log(data$init_r),
  logK = log(data$init_K),
  logsdlogF = log(data$init_sdlogF),
  logsdlogPop = log(data$init_sdlogPop),
  logsdlogYield = log(data$init_sdlogYield),
  LmeanProportion_local = logit(data$init_meanProportion_local),
  logsdLProportion_local = log(logit(data$init_sdProportion_local)),
  qProp = data$init_qProp
)

if (!data$use_robustY)
{
   data$phase_pfat = -1;
   data$init_pfat = 1e-25
}
parameters$Lpfat = logit(data$init_pfat)


parameters$U=rep(0.0,data$lengthU)

phases=unlist(phases) # phase flag for each parameter
nap = length(phases)  # number of parameters
print(paste("number of parameters:",nap))
nphase = max(phases)  # number of phases
print(paste("number of phases",nphase))
fit.par=vector(length=nphase) # parameters estimates from each fit

for (p in 1:nphase) # loop through phases
{
   map = list() # name list of factors
   nip = 0
   for (n in 1:nap) # loop through parameters
   {
      # check phase flag for this parameter
      if ((phases[n] == -1) || (phases[n] > p))
      {
         map.entry = parameters[n]
         map = c(map,map.entry)
         nip = nip+1
	 map[[nip]]=rep(factor(NA),length(parameters[[n]]))
      }
   }
   print(paste("----------phase",p))
#  print(map)
#  build model for active parameters, omiting thos in map
   if (p == 1)
   {
      obj = MakeADFun(data,parameters,map=map,random=c("U"),DLL="xssams")
   }
   else
   {
      obj = MakeADFun(data,opt.par[p-1],map=map,random=c("U"),DLL="xssams")
   }
   lower <- obj$par*0-Inf
   upper <- obj$par*0+Inf
   opt = nlminb(obj$par,obj$fn,obj$gr,lower=lower,upper=upper)
   # save parameter estimates for use in next fit
   opt.par[p] = obj$env$parList(opt$par) 
}

#system.time(opt<-nlminb(obj$par,obj$fn,obj$gr,lower=lower,upper=upper))
rep<-sdreport(obj)
rep
