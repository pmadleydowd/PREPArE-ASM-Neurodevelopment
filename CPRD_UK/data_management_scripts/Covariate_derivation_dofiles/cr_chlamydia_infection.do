********************************************************************************
* do file author:	Harriet FOrbes
* Date: 			01 April 2022
* Description: 		Derive maternal physical conditions at preg start 
* Notes: 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************


*********************************************************************
*Identify most recent chlamydia diagnosis
*********************************************************************
*set trace on
*set tracedepth 1


*********************************************************************
*Identify asthma, diabetes and copd records at cohort entry
*********************************************************************
*Lift all events relating to ASD from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
compress
save "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta", replace


foreach var in  chlamydia  {
use "$Codelsdir\Diagnoses_READ_`var'.dta", clear 
gen `var'=1 
keep medcode `var'
duplicates drop
merge 1:m medcode using "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta", keep(match) nogen
rename eventdate `var'_dx_date
drop if `var'_dx_date==.
keep patid `var'_dx_date `var'
save "$Datadir\Derived_data\CPRD\_temp\codes_`var'_all", replace
}

foreach var in  chlamydia  {
forvalues x=1/14 {
use "$Datadir\Derived_data\CPRD\_temp\codes_`var'_all", clear
keep patid `var' `var'_dx_date
merge m:1 patid using "$Datadir\Derived_data\Cohorts/pregnancy_cohort_final_`x'", keep(match) nogen
keep patid `var' `var'_dx_date pregstart_num pregid
save "$Datadir\Derived_data\CPRD\_temp\codes_`var'_`x'", replace
}
}

foreach var in  chlamydia  {
use "$Datadir\Derived_data\CPRD\_temp\codes_`var'_1", clear
forvalues x=2/14 {
append using "$Datadir\Derived_data\CPRD\_temp\codes_`var'_`x'"
}
count


drop if `var'_dx_date>pregstart_num /*drop if Dx is after pregstart date*/
gen ever_chlamydia=1
gen chlam_1_yr=1 if pregstart_num-`var'_dx_date<=365
bysort pregid: egen chlam_prev_yr=max(chlam_1_yr)
keep patid pregid ever_chlamydia chlam_prev_yr
duplicates drop
count
save "$Datadir\Derived_data\CPRD\_temp\final_`var'", replace
}

