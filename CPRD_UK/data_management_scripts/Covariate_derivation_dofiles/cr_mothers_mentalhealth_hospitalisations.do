********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			24 Feb 2023
* Description: 		Derive maternal hospitalisaton for mental health during pregnancy
* Notes: 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************

*********************************************************************
*Identify occurrences of sectioning 
*********************************************************************
*Lift all events relating to sectioning from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
compress
drop if medcode<78
save "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta", replace


use "$Datadir\codelists\READ_MentalHealthHosp_codelist_draft.dta", clear 
keep medcode
duplicates drop
merge 1:m medcode using "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta", keep(match) nogen
drop if eventdate==.
drop medcode 
save "$Datadir\Derived_data\CPRD\_temp\codes_MH_hosp_all", replace

forvalues x=1/14 {
	use "$Datadir\Derived_data\CPRD\_temp\codes_MH_hosp_all", clear
	merge m:1 patid using "$Datadir\Derived_data\Cohorts/pregnancy_cohort_final_`x'", keep(match) nogen
	keep if pregstart_num <= eventdate & eventdate <= pregend_num	
	bysort patid: egen _seq=seq()
	keep if _seq == 1
	keep patid pregid
	save "$Datadir\Derived_data\CPRD\_temp\codes_MH_hosp_`x'", replace
}


use "$Datadir\Derived_data\CPRD\_temp\codes_MH_hosp_1", clear
forvalues x=2/14 {
	append using "$Datadir\Derived_data\CPRD\_temp\codes_MH_hosp_`x'"
}
count
gen MH_hosp_preg = 1
save "$Datadir\Derived_data\CPRD\_temp\final_MH_hosp", replace
