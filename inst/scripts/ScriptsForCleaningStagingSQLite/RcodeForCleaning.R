
library(RSQLite)
library(DBI)
con <- dbConnect(SQLite(), "spb_history.sqlite")
dbListTables(con)
pkgTbl = dbReadTable(con, "viewhistory_package")
jobTbl = dbReadTable(con, "viewhistory_job")
buildTbl = dbReadTable(con, "viewhistory_build")
messTbl = dbReadTable(con, "viewhistory_message")

delete_fun <- function(pkg, con){

if(pkg %in% pkgTbl$name){
       pkg_rm = which(pkgTbl$name == pkg)
       pkg_id = pkgTbl[pkg_rm, "id"]  
       job_rm = which(jobTbl$package_id == pkg_id)
       job_ids = jobTbl[job_rm, "id"]
       build_rm = buildTbl[(buildTbl$job_id %in% job_ids), "id"]
       mess_rm = messTbl[(messTbl$build_id %in% build_rm), "id"]

       sql_cmd = paste0("DELETE FROM viewhistory_package WHERE name = '", pkg, "'")
       sql = sql_cmd
       rs = dbSendStatement(con, sql)
       dbClearResult(rs)

       sql_cmd = paste0("DELETE FROM viewhistory_job WHERE id IN (", paste(job_rm,
       collapse=", "), ")")
       sql = sql_cmd
       rs = dbSendStatement(con, sql)
       dbClearResult(rs)

       sql_cmd = paste0("DELETE FROM viewhistory_build WHERE id IN (", paste(build_rm,
       collapse=", "), ")")
       sql = sql_cmd
       rs = dbSendStatement(con, sql)
       dbClearResult(rs)

       sql_cmd = paste0("DELETE FROM viewhistory_message WHERE id IN (", paste(mess_rm,
       collapse=", "), ")")
       sql = sql_cmd
       rs = dbSendStatement(con, sql)
       dbClearResult(rs)
       return(TRUE)
}
	return(NA)
}


# how to get pkgs??
# using manifest misses decline/experiment/annotaiton/workflow
#pkgs =
#as.character(read.table("/home/lori/b/masterManifests/manifest/all.txt")[,1])


# first time some manual that are old wokflows/annotation/etc
# deprecated
pkgs=c("spbtest", "spbtest2", "164", "51")
lapply(pkgs, FUN=delete_fun, con=con)

#pkgs = as.character(read.table("sqDel3.txt")[,1])
pkgs = read.table("sqDel.txt")[,1]
lapply(pkgs, FUN=delete_fun, con=con)

# some other manuals
pkgs=c('artMSexit', 'ATACpipe', 'brainimageRdata', 'HiCLegos',
    'methylGO', 'PCRSA', 'vistimeseq')
    

dbDisconnect(con)






pkgs = c("acorn", "APAlog", "ATACCoGAPS", "benchmark.data.scRNAseq",
         "best.friends", "BiocDeveloper ", "biocmask", "BiocUtils",
         "biodbExpasy", "biodbMirbase", "CAM3", "Cara1.0", "ceRNAR",
         "chihaya-R", "ChromENVEE", "cleanse", "CytoTalk", "deepCE", "DEPTH",
         "distSTRING", "DMEA", "DunedinPACE", "edgeCounter", "FEVV", "funomics",
         "Genefusiondiscover", "GenomicInteractionHub", "ggtranscript",
         "GRETTA", "HiTIMED", "iDA", "InSituType", "IntOMICS ", "Lheuristic",
         "LINEAGE", "LipidSigR", "MACARRoN", "Magellan", "MarZIC",
         "massconverter", "masstools", "mbOmic", "mhAnalysis", "MicroBioMap",
         "mnmer", "MobilityTransformR", "mulea", "NanoStringExperiment ",
         "OptiLCMS", "peakCombiner", "Pedigree", "poplin", "proteasy",
         "protlocassign", "protlocassigndoc", "prozor", "rd4",
         "RegionPropertiesFeatures", "RGraphSpace", "Rhisat", "SC.MEB",
         "scDesign3Workflow", "sciCNV", "SCIntRuler", "SignacSlim",
         "SparseSignaturesPlus", "spbtest3", "ssde", "surf", "SVseek",
         "TimeSeriesAnalysis", "tinytools", "Totem", "TSSr", "turboGliph",
         "VSOLassoBag", "Yeskit") 
lapply(pkgs, FUN=delete_fun, con=con)
