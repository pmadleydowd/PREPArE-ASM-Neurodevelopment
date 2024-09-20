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
*Identify asthma, CKD, diabetes, autoimmune disease and hypertension at pregnancy start
*********************************************************************
*set trace on
*set tracedepth 1


*append code lists
use "$Codelsdir\ReadCode_asthma_signed_off_DR.dta", replace
gen asthma=1
merge 1:1 medcode using "$Codelsdir\READCode_CKD_signed_off_HF"
gen ckd=1 if _m==3 | _m==2
drop _m
merge 1:1 medcode using "$Codelsdir\READCode_diabetes_signed_off_DR"
gen diab=1 if _m==3 | _m==2
drop _m
*hypertension and autoimmune not signed off


duplicates list medcode readterm

keep medcode asthma ckd diab
save "$Datadir\Derived_data\CPRD\_temp\all_codes_physical_health.dta", replace

*********************************************************************
*Identify asthma, diabetes and copd records at cohort entry
*********************************************************************

*Lift all events relating to ASD from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
compress
drop if medcode<78
save "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta", replace


foreach var in  asthma ckd  diab  {
use "$Datadir\Derived_data\CPRD\_temp\all_codes_physical_health.dta", clear 
keep if `var'==1 
keep medcode `var'
duplicates drop
merge 1:m medcode using "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta", keep(match) nogen
rename eventdate `var'_dx_date
drop if `var'_dx_date==.
keep patid `var'_dx_date `var'
bysort patid (`var'_dx_date): keep if _n==1 /*keeps earliest diagnosis: create 1 record per patient*/
save "$Datadir\Derived_data\CPRD\_temp\codes_`var'_all", replace
}

foreach var in  asthma ckd  diab  {
forvalues x=1/14 {
use "$Datadir\Derived_data\CPRD\_temp\codes_`var'_all", clear
keep patid `var' `var'_dx_date
merge 1:1 patid using "$Datadir\Derived_data\Cohorts/pregnancy_cohort_final_`x'", keep(match) nogen
keep patid `var' `var'_dx_date pregstart_num pregid
save "$Datadir\Derived_data\CPRD\_temp\codes_`var'_`x'", replace
}
}

foreach var in  asthma ckd  diab  {
use "$Datadir\Derived_data\CPRD\_temp\codes_`var'_1", clear
forvalues x=2/14 {
append using "$Datadir\Derived_data\CPRD\_temp\codes_`var'_`x'"
}
count


drop if `var'_dx_date>pregstart_num /*drop if 1st Dx is after pregstart date*/
keep patid pregid `var' `var'_dx_date

count
save "$Datadir\Derived_data\CPRD\_temp\final_`var'", replace
}

use "$Datadir\Derived_data\CPRD\_temp\final_asthma", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\final_ckd", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\final_diab", nogen
keep patid pregid asthma ckd diab
replace ckd = 0 if ckd == . 
replace diab = 0 if diab == .
save "$Datadir\Derived_data\Covariates\long_term_health_con_final", replace

forvalues x=1/14{
foreach var in  asthma ckd  diab  {
cap erase "$Datadir\Derived_data\CPRD\_temp\codes_`var'_`x'.dta" 
}
}
erase "$Datadir\Derived_data\CPRD\_temp\all_codes_physical_health.dta"
erase "$Datadir\Derived_data\CPRD\_temp\clinical_reduced.dta"
foreach var in  asthma ckd  diab  {
*erase "$Datadir\Derived_data\CPRD\_temp\final_`var'.dta"
*erase "$Datadir\Derived_data\CPRD\_temp\final`var'.dta"
erase "$Datadir\Derived_data\CPRD\_temp\codes_`var'_all.dta"
}

