log using "$Logdir\LOG_cr_Insheet_and_format_IMD.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		02 November 2021
* Description:  Insheet and format all linked IMD data
* Notes: 		
********************************************************************************
* Notes on major updates (Date - description):
* 
********************************************************************************
* Contents
********************************************************************************
* 1 - Set up environment 
* 2 - Read in and format patient IMD data
* 3 - Read in and format practice IMD data


********************************************************************************
* 1 - Set up environment 
********************************************************************************
global Statalinked "$Rawdatdir\stata\data_linked" 

********************************************************************************
* 2 - Read in and format patient IMD data
********************************************************************************
import delim using "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\data_linked\20_000228_request2\Results\GOLD_linked\Final\patient_imd2015_20_000228_request2.txt", clear

*Label variables
label variable patid "Patient id"
label variable pracid "Practice ID"
label variable imd2015_5 "IMD2015: quintile (1=LEAST deprived)"

compress
save "$Statalinked\20_000228_imd2015_patient", replace




********************************************************************************
* 3 - Read in and format practice IMD data
********************************************************************************
import delim using "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\data_linked\20_000228_request2\Results\GOLD_linked\Final\practice_imd_20_000228_request2.txt", clear
save "$Statalinked\20_000228_imd2015_practice", replace

import delim using "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\data_linked\20_000228_IMD_redelivery\Results\GOLD_linked\Final\practice_imd_20_000228_redelivery.txt", clear
save "$Statalinked\20_000228_imd_practice_redelivery", replace // all practices that were missing from the first delivery

use "$Statalinked\20_000228_imd2015_practice", clear
append using "$Statalinked\20_000228_imd_practice_redelivery"


gen imd_practice = .
foreach var in e2015_imd_5 ni2017_imd_5 s2016_imd_5 w2014_imd_5 {
	replace imd_practice = `var' if `var' !=.
}


*Label variables
label variable pracid "Practice ID"
label variable country "1=England, 2=Northern Ireland, 3=Scotland, 4=Wales"
label variable e2015_imd_5 "England: IMD2015: quintile (1=LEAST deprived)"
label variable ni2017_imd_5 "Northern Ireland: MDM2017: quintile (1=LEAST deprived)"
label variable s2016_imd_5 "Scotland: IMD2016: quintile (1=LEAST deprived)"
label variable w2014_imd_5 "Wales: IMD2014: quintile (1=LEAST deprived)"
label variable imd_practice "IMD quintile for practice (1=LEAST deprived)"


compress
save "$Statalinked\20_000228_imd_practice", replace


********************************************************************************
log close