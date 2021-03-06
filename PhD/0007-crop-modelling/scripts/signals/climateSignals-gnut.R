#Julian Ramirez-Villegas
#CIAT/CCAFS/UoL
#March 2012
stop("Do not runt the whole thing")

#local
#src.dir <- "D:/_tools/dapa-climate-change/trunk/PhD/0006-weather-data/scripts"
#src.dir2 <- "D:/_tools/dapa-climate-change/trunk/PhD/0007-crop-modelling/scripts"

#eljefe
#src.dir <- "~/PhD-work/_tools/dapa-climate-change/trunk/PhD/0006-weather-data/scripts"
#src.dir2 <- "~/PhD-work/_tools/dapa-climate-change/trunk/PhD/0007-crop-modelling/scripts"

#sourcing needed functions
source(paste(src.dir,"/GHCND-GSOD-functions.R",sep=""))
source(paste(src.dir,"/watbal.R",sep=""))
#source(paste(src.dir2,"/climateSignals-functions.R",sep=""))
source(paste(src.dir2,"/climateSignals-functions.v2.R",sep="")) #improved version!

library(raster)

#Climate signals on yield for Indian Groundnuts
#local
#bDir <- "F:/PhD-work/crop-modelling"

#eljefe
#bDir <- "~/PhD-work/crop-modelling"

# sradDir <- paste(bDir,"/climate-data/CRU_CL_v1-1_data",sep="")
# tempDir <- paste(bDir,"/climate-data/CRU_TS_v3-1_data",sep="")
# era40Dir <- paste(bDir,"/climate-data/ERA-40",sep="")

sradDir <- paste(bDir,"/climate-data/gridcell-data/IND/cru_srad",sep="")
tempDir <- paste(bDir,"/climate-data/gridcell-data/IND",sep="")
era40Dir <- paste(bDir,"/climate-data/gridcell-data/IND/srad_e40",sep="")

y_iyr <- 1966
y_eyr <- 1995

#Planting dates as in literature
#summer (only separated in Sardana and Kandhola 2007):
#         1. End of April to early May
#khariff: summer rainfed. 
#         1. From first week of June to last week of July (Talawar 2004) (regular and late monsoon)
#         2. From end of May to early June (Sardana and Kandhola 2007) (pre-monsoon)
#         3. Third week of June (Singh and Oswalt 1995)
#         4. First half of July (Singh et al. 1986)
#         5. 20th April (normal summer) (Harinath and Vasanthi 1998 http://www.indianjournals.com/ijor.aspx?target=ijor:ijpp1&volume=26&issue=2&article=001)
#rabi: winter irrigated
#         1. From mid December to mid January (Ramadoss and Myers 2004 http://www.regional.org.au/au/asa/2004/poster/4/1/2/1243_ramadoss.htm)
#         2. Mid September to first of November
#         3. Early rabi: 5-20 October (Harinath and Vasanthi 1998 http://www.indianjournals.com/ijor.aspx?target=ijor:ijpp1&volume=26&issue=2&article=001)
#         4. Normal rabi: 5 November (Harinath and Vasanthi 1998 http://www.indianjournals.com/ijor.aspx?target=ijor:ijpp1&volume=26&issue=2&article=001)

ncFile <- paste(bDir,"/climate-data/IND-TropMet/0_input_data/india_data.nc",sep="")
#mthRainAsc <- paste(bDir,"/climate-data/IND-TropMet",sep="")
mthRainAsc <- paste(bDir,"/climate-data/gridcell-data/IND/rain",sep="")

cropDir <- paste(bDir,"/GLAM/climate-signals-yield/GNUT",sep="")
ydDir <- paste(bDir,"/GLAM/climate-signals-yield/GNUT/raster/gridded",sep="")
oDir <- paste(bDir,"/GLAM/climate-signals-yield/GNUT/signals",sep="")
if (!file.exists(oDir)) {dir.create(oDir)}

#create mask
metFile <- raster(ncFile,band=0)
yldFile <- raster(paste(ydDir,"/raw/raw-66.asc",sep=""))
msk <- maskCreate(metFile,yldFile)

############
#determine planting date using pjones algorithm?

if (!file.exists(paste(oDir,"/cells-process.csv",sep=""))) {
  pCells <- data.frame(CELL=1:ncell(msk))
  pCells$X <- xFromCell(msk,pCells$CELL); pCells$Y <- yFromCell(msk,pCells$CELL)
  pCells$Z <- extract(msk,cbind(X=pCells$X,Y=pCells$Y))
  pCells <- pCells[which(!is.na(pCells$Z)),]
  write.csv(pCells,paste(oDir,"/cells-process.csv",sep=""),quote=F,row.names=F)
} else {
  pCells <- read.csv(paste(oDir,"/cells-process.csv",sep=""))
}

# plot(msk)
# text(x=pCells$X,y=pCells$Y,labels=pCells$CELL,cex=0.35)

pday <- raster(paste(cropDir,"/calendar/gnut/plant_lr.tif",sep="")) #planting date
hday <- raster(paste(cropDir,"/calendar/gnut/harvest_lr.tif",sep="")) #harvest date

#calculate growing season duration
hdaym <- hday
hdaym[which(hday[] < pday[])] <- hdaym[which(hday[] < pday[])] + 365
gdur <- hdaym-pday

############################################################################
############################################################################
################### Using ea/ep ratio to estimate when the crop was planted
############################################################################
############################################################################
###Parameters
sd_default=165; ed_default=225; thresh=0.5
tbase=10; topt=28; tmax=50
tcrit=34; tlim=40

oDir <- paste(bDir,"/GLAM/climate-signals-yield/GNUT/signals/ea_ep_ratio",sep="")
if (!file.exists(oDir)) {dir.create(oDir)}

#parallelisation
library(snowfall)
sfInit(parallel=T,cpus=12) #initiate cluster

#export functions and data
sfExport("sd_default"); sfExport("ed_default"); sfExport("thresh")
sfExport("tbase"); sfExport("topt"); sfExport("tmax"); sfExport("tcrit"); sfExport("tlim")
sfExport("pday"); sfExport("hday")
sfExport("pCells")
sfExport("oDir")
sfExport("ncFile")
sfExport("mthRainAsc")
sfExport("ydDir")
sfExport("bDir")
sfExport("sradDir")
sfExport("tempDir")
sfExport("era40Dir")
sfExport("y_iyr")
sfExport("y_eyr")
sfExport("src.dir")
sfExport("src.dir2")

#remove all those cells in the list that do not exist
cellList <- NULL
for (cell in pCells$CELL) {
  if (!file.exists(paste(oDir,"/climate_cell-",cell,".csv",sep=""))) {
    cellList <- c(cellList,cell)
  }
}

#run the control function
system.time(sfSapply(as.vector(cellList), cell_wrapper))

#stop the cluster
sfStop()


################### get the signals into a grid
#important fields
iyr <- 66; fyr <- 95
if (fyr < iyr) {
  tser <- (1900+iyr):(2000+fyr)
} else {
  tser <- 1900+(iyr:fyr)
}
tser <- substr(tser,3,4)


#for a given cell extract the yield data and make the correlation for each detrending technique
x <- calcSignals(techn="lin",ydDir=ydDir,oDir=oDir,tser)
x <- calcSignals(techn="loe",ydDir=ydDir,oDir=oDir,tser)
x <- calcSignals(techn="fou",ydDir=ydDir,oDir=oDir,tser)
x <- calcSignals(techn="qua",ydDir=ydDir,oDir=oDir,tser)

#plot all the rasters (correlations and p values)
x <- plotSignals(techn="lin",oDir,pval=0.1)
x <- plotSignals(techn="loe",oDir,pval=0.1)
x <- plotSignals(techn="fou",oDir,pval=0.1)
x <- plotSignals(techn="qua",oDir,pval=0.1)



############################################################################
############################################################################
############################# With planting dates from Sacks et al. (2010)
############################################################################
############################################################################
###Parameters
tbase=10; topt=28; tmax=50; tcrit=34; tlim=40

oDir <- paste(bDir,"/GLAM/climate-signals-yield/GNUT/signals/sacks_pdate",sep="")
if (!file.exists(oDir)) {dir.create(oDir)}

#parallelisation
library(snowfall)
sfInit(parallel=T,cpus=12) #initiate cluster

#export functions and data
sfExport("tbase"); sfExport("topt"); sfExport("tmax"); sfExport("tcrit"); sfExport("tlim")
sfExport("pday"); sfExport("hday")
sfExport("pCells")
sfExport("oDir")
sfExport("ncFile")
sfExport("mthRainAsc")
sfExport("ydDir")
sfExport("bDir")
sfExport("sradDir")
sfExport("tempDir")
sfExport("era40Dir")
sfExport("y_iyr")
sfExport("y_eyr")
sfExport("src.dir")
sfExport("src.dir2")

#remove all those cells in the list that do not exist
cellList <- NULL
for (cell in pCells$CELL) {
  if (!file.exists(paste(oDir,"/climate_cell-",cell,".csv",sep=""))) {
    cellList <- c(cellList,cell)
  }
}

#run the control function
system.time(sfSapply(as.vector(cellList), cell_wrapper_irr))

#stop the cluster
sfStop()


################### get the signals into a grid
#important fields
iyr <- 66; fyr <- 95
if (fyr < iyr) {
  tser <- (1900+iyr):(2000+fyr)
} else {
  tser <- 1900+(iyr:fyr)
}
tser <- substr(tser,3,4)


#for a given cell extract the yield data and make the correlation for each detrending technique
x <- calcSignals(techn="lin",ydDir=ydDir,oDir=oDir,tser)
x <- calcSignals(techn="loe",ydDir=ydDir,oDir=oDir,tser)
x <- calcSignals(techn="fou",ydDir=ydDir,oDir=oDir,tser)
x <- calcSignals(techn="qua",ydDir=ydDir,oDir=oDir,tser)


#plot all the rasters (correlations and p values)
x <- plotSignals(techn="lin",oDir,pval=0.1)
x <- plotSignals(techn="loe",oDir,pval=0.1)
x <- plotSignals(techn="fou",oDir,pval=0.1)
x <- plotSignals(techn="qua",oDir,pval=0.1)

