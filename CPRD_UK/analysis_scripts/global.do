******************************************************************************
* Author: 	Paul Madley-Dowd
* Date: 	21 April 2021
* Description:  Runs all global macros for the CPRD PREPArE project. To be run at the start of all stata sessions. 
******************************************************************************
clear 

global Projectdir 	"PROJECTDIRECTORY"

global Dodir 		"$Gitdir\dofiles"
global Logdir 		"$Projectdir\logfiles"
global Datadir 		"$Projectdir\datafiles"
global Rawdatdir 	"$Projectdir\rawdatafiles"
global Rawtextdir	"RAWTEXTDIRECTORY"
global Graphdir 	"$Projectdir\graphfiles"
global Codelsdir	"$Projectdir\datafiles\codelists"

cd "$Projectdir"

