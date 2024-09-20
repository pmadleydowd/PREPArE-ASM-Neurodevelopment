********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			11 March 2022
* Description: 		Derivation of covariates for illicit drug use 
* Notes:			Called in cr_Covariates_derivation.do 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Datasets output
********************************************************************************
* 1 - 

 
********************************************************************************
* Contents
********************************************************************************
* 1 - Read codes for illicit drug use 
* 2 - Prescriptions for illicit drug use (e.g. methadone)


********************************************************************************
* 1 - Read codes for illicit drug use 
********************************************************************************
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num
joinby medcode using "$Codelsdir\Readcode_Illicitdruguse_signed_off_DR.dta", _merge(mergevar) 
rename eventdate_num clinical_date
keep patid clinical_date 
save "$Datadir\Derived_data\CPRD\_temp\all_illicit_drug_Read.dta", replace


use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid pregstart_num pregend_num
	* create a sequence variable for pregnancies 
sort patid 
egen _seq=seq(), by(patid)
sum _seq
local maxpreg = r(max)
forvalues x = 1/`maxpreg' {
	preserve
	keep if _seq == `x'
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\all_illicit_drug_Read.dta", keep(3) nogen	
	gen illicitdrug_pregnancy = 1 if pregstart_num <= clinical_date & clinical_date <= pregend_num 
	keep if illicitdrug_pregnancy == 1
	if _N >0 {
		duplicates drop patid pregid , force
	}
	keep patid pregid illicitdrug_pregnancy
	save "$Datadir\Derived_data\CPRD\_temp\illicitdrug_preg_`x'.dta", replace
	restore
}

use "$Datadir\Derived_data\CPRD\_temp\illicitdrug_preg_1.dta", clear
forvalues x = 2/`maxpreg' {
	append using "$Datadir\Derived_data\CPRD\_temp\illicitdrug_preg_`x'.dta"
}


merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", keep(2 3) nogen
replace illicitdrug_pregnancy = 0 if illicitdrug_pregnancy==. 
keep patid pregid illicitdrug_pregnancy

sort patid
compress
save "$Datadir\Derived_data\CPRD\_temp\illicitdrug_preg_read.dta", replace

********************************************************************************
* 2 - Prescriptions for illicit drug use (e.g. methadone)
********************************************************************************
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Therapy_Files.dta", clear
keep patid prodcode eventdate_num
joinby prodcode using "$Codelsdir\Prescriptions_OST_reviewed_DR.dta", _merge(mergevar) 
rename eventdate_num clinical_date
keep patid clinical_date 
save "$Datadir\Derived_data\CPRD\_temp\all_OST_prescription.dta", replace


use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid pregstart_num pregend_num
	* create a sequence variable for pregnancies 
sort patid 
egen _seq=seq(), by(patid)
sum _seq
local maxpreg = r(max)
forvalues x = 1/`maxpreg' {
	preserve
	keep if _seq == `x'
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\all_OST_prescription.dta", keep(3) nogen	
	gen OSTpresc_pregnancy = 1 if pregstart_num <= clinical_date & clinical_date <= pregend_num 
	keep if OSTpresc_pregnancy == 1
	if _N >0 {
		duplicates drop patid pregid , force
	}
	keep patid pregid OSTpresc_pregnancy
	save "$Datadir\Derived_data\CPRD\_temp\OSTpresc_preg_`x'.dta", replace
	restore
}

use "$Datadir\Derived_data\CPRD\_temp\OSTpresc_preg_1.dta", clear
forvalues x = 2/`maxpreg' {
	append using "$Datadir\Derived_data\CPRD\_temp\OSTpresc_preg_`x'.dta"
}


merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", keep(2 3) nogen
replace OSTpresc_pregnancy = 0 if OSTpresc_pregnancy==. 
keep patid pregid OSTpresc_pregnancy

sort patid
compress
save "$Datadir\Derived_data\CPRD\_temp\OSTpresc_preg.dta", replace

********************************************************************************
* 3 - join datasets 
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\illicitdrug_preg_read.dta", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\OSTpresc_preg.dta", nogen

egen illicitdrug_preg = rowmax(illicitdrug_pregnancy OSTpresc_pregnancy) 
keep patid pregid illicitdrug_preg

label variable illicitdrug_preg "Evidence of illicit drug use in pregnancy"

save "$Datadir\Derived_data\covariates\illicitdruguse.dta", replace



********************************************************************************
