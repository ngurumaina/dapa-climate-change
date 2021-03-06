#### LIBRARIES: raster, maptools, rgdal, sp
####

#functions to summarise

####################################################################################
####################################################################################
#function to summarise experiments
summariseExperiments <- function(bDir) {
  experiments <- createExperiments(bDir) #change when perturbed runs are ready
  for (i in 1:nrow(experiments)) {
    ty <- experiments$TYPE[i]; va <- experiments$VAR[i]; sc <- experiments$SCALE[i] #get data from matrix
    cat("\n")
    cat("processing",paste(ty),"/",paste(va),"/",paste(sc),"\n")
    #list folders and loop to get what we need
    sp_folder <- paste(bDir,"/shuffle-perturb/climate/",va,"_",ty,"_",sc,sep="")
    if (!file.exists(paste(sp_folder,"/performance.csv",sep=""))) {
      f_list <- list.files(sp_folder); f_list <- f_list[grep("s-",f_list)]
      
      #verify whether preliminary files exist
      nfil <- length(f_list)/1000
      pfc <- 1
      for (pf in 1:nfil) {
        per_file <- paste(sp_folder,"/performance_",pf,".csv",sep="")
        
        if (file.exists(per_file)) {
          cat("Block",pf,"was already analysed, skipping files \n")
          to_skip <- ((pf-1)*1000+1):((pf-1)*1000+1000)
          if (pfc==1) {
            cum_skipped <- to_skip
          } else {
            cum_skipped <- c(cum_skipped,to_skip)
          }
          pfc <- pfc+1
        }
      }
      
      #reducing f_list
      if (pfc>1) {
        f_list_red <- f_list[-cum_skipped]
      } else {
        f_list_red <- f_list
      }
      
      #reading individual model runs
      fcount <- 1
      scount <- pfc
      for (f_name in f_list) {
        if (ty == "s") { #get experimental details
          p <- NA
          s <- as.numeric(gsub(paste(va,"_s-",sep=""),"",f_name))
        } else {
          p <- as.numeric(gsub("p-","",strsplit(f_name,"_")[[1]][2]))
          s <- as.numeric(gsub("s-","",strsplit(f_name,"_")[[1]][3]))
        }
        cat("reading in experiment s =",s,"/ p =",p,"\n")
        PSDataFolder <- paste(sp_folder,"/",f_name,sep="") #data folder
        acc <- read.csv(paste(PSDataFolder,"/accuracy-metrics.csv",sep="")) #load optimisation curve
        eva <- read.csv(paste(PSDataFolder,"/evaluation.csv",sep="")) #load time series
        
        #get the performance row
        per_row <- data.frame(TYPE=ty,VAR=va,SCALE=sc,P=p,SEED=s,
                              RMSE.TEST=acc$TEST.ERROR,OR.TEST=acc$TEST.OMISSION.RATE,
                              RMSE.TRAIN=acc$TRAIN.ERROR,OR.TRAIN=acc$TRAIN.OMISSION.RATE,
                              TPR=eva$TPR,FPR=eva$FPR,TNR=eva$TNR)
        if (fcount==1) { #summarise
          performance <- per_row
        } else {
          performance <- rbind(performance,per_row)
        }
        
        #restart counter and write preliminary file to avoid heavy matrices, these will
        #be merged at the end
        if (fcount==1000) {
          write.csv(performance,paste(sp_folder,"/performance_",scount,".csv",sep=""),row.names=F,quote=F)
          scount <- scount+1
          fcount <- 1
          rm(performance); g=gc(); rm(g)
        } else {
          fcount <- fcount+1
        }
      }
      
      if (nfil>1) {
        cat("Concatenating ")
        for (sc in 1:nfil) {
          per_pre <- read.csv(paste(sp_folder,"/performance_",sc,".csv",sep=""))
          if (sc==1) {
            performance <- per_pre
          } else {
            performance <- rbind(performance,per_pre)
          }
        }
      }
      write.csv(performance,paste(sp_folder,"/performance.csv",sep=""),row.names=F,quote=F)
      rm(performance);g=gc();rm(g)
    }
  }
}

#function to get the summarised data and plot the results in boxplot
generalSummary <- function(bDir) {
  expList <- createExperiments(bDir)
  types <- unique(expList$TYPE)
  for (typ in types) {
    experiments <- expList[which(expList$TYPE==typ),]
    #define output names
    out_perf <- paste(bDir,"/shuffle-perturb/climate_results/",typ,"-performance.csv",sep="")
    #if not exists open and do process
    if (!file.exists(out_perf)) {
      for (i in 1:nrow(experiments)) {
        ty <- experiments$TYPE[i]; va <- experiments$VAR[i]; sc <- experiments$SCALE[i] #get data from matrix
        cat("processing",paste(ty),"/",paste(va),"/",paste(sc),"\n")
        sp_folder <- paste(bDir,"/shuffle-perturb/climate/",va,"_",ty,"_",sc,sep="")
        performance <- read.csv(paste(sp_folder,"/performance.csv",sep=""))
        if (i==1) {
          perf <- performance
        } else {
          perf <- rbind(perf,performance)
        }
      }
      write.csv(perf,out_perf,quote=F,row.names=F)
    }
  }
}




#sources dir
#src.dir <- "D:/_tools/dapa-climate-change/trunk/EcoCrop"
#src.dir.ps <- "D:/_tools/dapa-climate-change/trunk/PhD/0005-dqs/scripts"

#1. create experiment list
createExperiments <- function(bDir) {
  expList <- list.files(paste(bDir,"/shuffle-perturb/climate",sep="")) #list experiments
  for (exp in expList) { #loop through list
    expRow <- data.frame(TYPE=strsplit(exp,"_",fixed=T)[[1]][2],SCALE=strsplit(exp,"_",fixed=T)[[1]][3],VAR=strsplit(exp,"_",fixed=T)[[1]][1])
    if (exp == expList[1]) {
      experiments <- expRow
    } else {
      experiments <- rbind(experiments,expRow) #append data frame
    }
  }
  return(experiments)
}

#2. create control files
createControls <- function(bDir) {
  experiments <- createExperiments(bDir)
  for (x in 1:nrow(experiments)) {
    sp_dir <- paste(bDir,"/shuffle-perturb/climate",sep="") #base climate dir
    ty <- experiments$TYPE[x]; sc <- experiments$SCALE[x]; va <- experiments$VAR[x] #details of exp.
    SPDataDir <- paste(sp_dir,"/",va,"_",ty,"_",sc,sep="") #data storage dir
    cat("Process",paste(ty),"/",paste(va),"/",paste(sc),"\n")
    if (ty == "p") {
      pList <- c(0:299)
      runsList <- list.files(SPDataDir,pattern=paste(va,"_p-0_s-",sep="")) #list to get seeds
      sList <- as.numeric(gsub(paste(va,"_p-0_s-",sep=""),"",runsList)) #get seeds
    } else {
      pList <- NA
      runsList <- list.files(SPDataDir,pattern=paste(va)) #list to get seeds (shuffled)
      sList <- as.numeric(gsub(paste(va,"_s-",sep=""),"",runsList)) #get seeds
    }
    
    for (pval in pList) {
      for (seed in sList) {
        cRow <- data.frame(TYPE=ty,SCALE=sc,VAR=va,P=pval,SEED=seed)
        if (is.na(pval)) {
          if (seed==sList[1]) {
            controlList <- cRow
          } else {
            controlList <- rbind(controlList,cRow)
          }
        } else {
          if (pval==pList[1] & seed==sList[1]) {
            controlList <- cRow
          } else {
            controlList <- rbind(controlList,cRow)
          }
        }
      }
    }
    write.csv(controlList,paste(bDir,"/bin/control/",ty,"_",va,"_",sc,".csv",sep=""),row.names=F,quote=F)
  }
}


################## this is the perturb function
EcoCrop_ps <- function(bDir,ty,va,sc,s,p) {
  #check if model was run, if not, create lock file
  psDir <- paste(bDir,"/shuffle-perturb/climate/",va,"_",ty,"_",sc,sep="")
  if (is.na(p)) {
    psDataDir <- paste(psDir,"/",va,"_s-",s,sep="")
  } else {
    psDataDir <- paste(psDir,"/",va,"_p-",p,"_s-",s,sep="")
  }
  checkFile <- paste(psDataDir,"/proc.done",sep="")
  if (!file.exists(checkFile)) {
    zz <- file(paste(psDataDir,"/proc.lock",sep=""),open="w");close(zz)
    #add remaining chunk of code below here
  
    #create a run dir in the ./bin/ folder
    bin_dir <- paste(bDir,"/bin",sep="")
    runNumber <- round(runif(1,0,9999),0)
    run_dir <- paste(bin_dir,"/run-",runNumber,sep="")
    while (file.exists(run_dir)) {
      runNumber <- round(runif(1,0,9999),0)
      run_dir <- paste(bin_dir,"/run-",runNumber,sep="")
    }
    dir.create(run_dir)
    
    #copy data from perturbed folder to run folder
    ascList <- list.files(psDataDir,pattern=".asc")
    ascList <- lapply(ascList,function(x,idir,odir) {k<-file.copy(paste(idir,"/",x,sep=""),paste(odir,"/",x,sep=""))},psDataDir,run_dir)
    
    #copy the rest of data required for model runs
    cat("copying the remaining climate files \n")
    vaList <- c("prec","tmin","tmean")
    notPert <- vaList[which(vaList!=va)]
    iDir <- paste(bDir,"/climate/ind_coarse",sep="")
    for (vnp in notPert) {
      ascList <- paste(vnp,"_",1:12,".asc",sep="")
      ascList <- lapply(ascList,function(x,idir,odir) {k<-file.copy(paste(idir,"/",x,sep=""),paste(odir,"/",x,sep=""))},iDir,run_dir)
    }
    
    #Running the model
    gs <- 6
    parFile <- paste(bDir,"/analyses/data/calibration-parameters.csv",sep="")
    params <- read.csv(parFile); params <- params[which(params$GS==gs),] #select growing parameters
    vl <- "tmean"; rw=2
    if (!file.exists(paste(run_dir, "/gnut_suitability.asc",sep=""))) {
    	eco <- suitCalc(climPath=run_dir, 
                      Gmin=120,Gmax=120,Tkmp=params$KILL[rw],Tmin=params$MIN[rw],Topmin=params$OPMIN[rw],
                      Topmax=params$OPMAX[rw],Tmax=params$MAX[rw],Rmin=params$MIN[1],Ropmin=params$OPMIN[1],
                      Ropmax=params$OPMAX[1],Rmax=params$MAX[1], 
                      outfolder=run_dir, 
                      cropname="gnut")
    }
    rm(eco); g=gc(); rm(g)
    #move the output to required folder and remove unnecessary files, unlink run_dir
    status <- file.copy(paste(run_dir,"/gnut_suitability.asc",sep=""),paste(psDataDir,"/gnut_suitability.asc",sep=""))
    ascList <- list.files(run_dir)
    ascList <- lapply(ascList,function(x,idir) {k<-file.remove(paste(idir,"/",x,sep=""))},run_dir)
    unlink(run_dir,recursive=T)
    
    #Assess accuracy of each growing season and each parameter tuning
    test <- read.csv(paste(bDir,"/analyses/data/test.csv",sep="")); test <- cbind(test[,"longitude"], test[,"latitude"])
    train <- read.csv(paste(bDir,"/analyses/data/train.csv",sep="")); train <- cbind(train[,"longitude"], train[,"latitude"])
    parList <- read.csv(paste(bDir,"/analyses/data/calibration-parameters.csv",sep=""))
    pList <- parList[which(parList$GS==gs),][2,]
    vr <- pList$VARIABLE
    
    rs <- raster(paste(psDataDir,"/gnut_suitability.asc",sep=""))
    tem <- accMetrics(rs, test) #doing with test data
    trm <- accMetrics(rs, train) #doing with training data
    res_acc <- data.frame(GS=gs, VARIABLE=vr, TYPE="suitability", TEST.AV.SUIT=tem$METRICS$SUIT, 
                          TEST.SD.SUIT=tem$METRICS$SUITSD, TEST.MAX.SUIT=tem$METRICS$SUITX, 
                          TEST.MIN.SUIT=tem$METRICS$SUITN, TEST.OMISSION.RATE=tem$METRICS$OMISSION_RATE, 
                          TEST.ERROR=tem$METRICS$RMSQE, TEST.ERR.DIST=tem$METRICS$ERR_DIST, 
                          TEST.MXE=tem$METRICS$MAX_ENT, TEST.SLOPE=tem$METRICS$SLOPE, 
                          TRAIN.AV.SUIT=trm$METRICS$SUIT, TRAIN.SD.SUIT=trm$METRICS$SUITSD, 
                          TRAIN.MAX.SUIT=trm$METRICS$SUITX, TRAIN.MIN.SUIT=trm$METRICS$SUITN, 
                          TRAIN.OMISSION.RATE=trm$METRICS$OMISSION_RATE, TRAIN.ERROR=trm$METRICS$RMSQE, 
                          TRAIN.ERR.DIST=trm$METRICS$ERR_DIST, TRAIN.MXE=trm$METRICS$MAX_ENT, 
                          TRAIN.SLOPE=trm$METRICS$SLOPE)
    write.csv(res_acc, paste(psDataDir,"/accuracy-metrics.csv",sep=""), row.names=F)
    
    #Evaluation stuff
    ers <- raster(paste(bDir,"/shuffle-perturb/evaluation/pa_coarse.asc",sep=""))
    evMet <- eval_ps(rs,ers)
    write.csv(evMet,paste(psDataDir,"/evaluation.csv",sep=""),row.names=F)
    
    #write proc.done file
    zz <- file.remove(paste(psDataDir,"/proc.lock",sep=""))
    zz <- file(paste(psDataDir,"/proc.done",sep=""),open="w");close(zz)
  }
}

