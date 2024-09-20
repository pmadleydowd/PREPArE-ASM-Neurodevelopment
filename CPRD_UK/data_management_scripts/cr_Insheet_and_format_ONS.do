log using "$Logdir\LOG_cr_Insheet_and_format_ONS.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		02 November 2021
* Description:  Insheet and format all linked ONS data
* Notes: 		
********************************************************************************
* Notes on major updates (Date - description):
* 
********************************************************************************
* Contents
********************************************************************************
* 1 - Set up environment 
* 2 - Read in and format ONS mortality data



********************************************************************************
* 1 - Set up environment 
********************************************************************************
global Rawlinked "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\data_linked\20_000228_request2\Results\GOLD_linked\Final"

global Statalinked "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Analysis\rawdatafiles\stata\data_linked" 

********************************************************************************
* 2 - Read in and format ONS mortality data
********************************************************************************
import delim using "$Rawlinked\death_patient_20_000228_request2_DM.txt", clear

* generate numeric version of variables 
gen dod_num = date(dod, "DMY")
format %td dod_num


*Label variables
label variable patid "Patient id"
label variable pracid "Practice ID"
label variable dod "Date of death"
label variable dod_num "Date of death (numeric)"
label variable cause "Underlying cause of death"
label variable cause1 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause2 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause3 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause4 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause5 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause6 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause7 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause8 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause9 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause10 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause11 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause12 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause13 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause14 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause15 "Cause of death mention ICD10 (non-neonatal deaths only)"
label variable cause_neonatal1 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal2 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal3 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal4 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal5 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal6 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal7 "Cause of death mention ICD10 for neonatal deaths only"
label variable cause_neonatal8 "Cause of death mention ICD10 for neonatal deaths only"


order patid pracid dod*

compress
save "$Statalinked\20_000228_ONS_death_patient", replace




********************************************************************************
log close