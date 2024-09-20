********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			11 March 2022
* Description: 		Derivation of covariates for vomiting in pregnancy and prescriptions for anti-emetics 
* Notes:			Called in cr_Covariates_derivation.do 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Datasets output
********************************************************************************
* 1 - "$Datadir\Derived_data\CPRD\_temp\vomit_or_antiemetics_preg.dta" - patient id, pregnancy ID and binary indicators for vomiting in pregnancy, anti-emetics during pregnancy

 
********************************************************************************
* Contents
********************************************************************************
* 1 - Vomiting during pregnancy 
* 2 - Anti-emetics during pregnancy 

********************************************************************************
* * 1 - Vomiting during pregnancy 
********************************************************************************
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num
joinby medcode using "$Codelsdir\ReadCode_vomiting_signed_off_DR.dta", _merge(mergevar) 
rename eventdate_num clinical_date
keep patid clinical_date 
save "$Datadir\Derived_data\CPRD\_temp\all_vomiting_CPRD.dta", replace


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
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\all_vomiting_CPRD.dta", keep(3) nogen	
	gen vomit_pregnancy = 1 if pregstart_num <= clinical_date & clinical_date <= pregend_num 
	keep if vomit_pregnancy == 1
	if _N >0 {
		duplicates drop patid pregid , force
	}
	keep patid pregid vomit_pregnancy
	save "$Datadir\Derived_data\CPRD\_temp\vomiting_preg_`x'.dta", replace
	restore
}

use "$Datadir\Derived_data\CPRD\_temp\vomiting_preg_1.dta", clear
forvalues x = 2/`maxpreg' {
	append using "$Datadir\Derived_data\CPRD\_temp\vomiting_preg_`x'.dta"
}


merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", keep(2 3) nogen
replace vomit_pregnancy = 0 if vomit_pregnancy==. 
keep patid pregid vomit_pregnancy

sort patid
compress
save "$Datadir\Derived_data\CPRD\_temp\vomiting_preg.dta", replace




********************************************************************************
* 2 - Anti-emetics during pregnancy 
********************************************************************************
use "$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Therapy_Files", clear
merge m:1 prodcode using "$Codelsdir/Prescription_Antiemetics_signed_off_DR.dta", keepusing(prodcode) keep(3) 
keep patid eventdate_num
rename eventdate_num clinical_date
save "$Datadir\Derived_data\CPRD\_temp\all_antiemetics_CPRD.dta", replace


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
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\all_antiemetics_CPRD.dta", keep(3) nogen	
	gen antiemetics_pregnancy = 1 if pregstart_num <= clinical_date & clinical_date <= pregend_num 
	keep if antiemetics_pregnancy == 1
	if _N >0 {
		duplicates drop patid pregid , force
	}
	keep patid pregid antiemetics_pregnancy
	save "$Datadir\Derived_data\CPRD\_temp\antiemetics_preg_`x'.dta", replace
	restore
}

use "$Datadir\Derived_data\CPRD\_temp\antiemetics_preg_1.dta", clear
forvalues x = 2/`maxpreg' {
	append using "$Datadir\Derived_data\CPRD\_temp\antiemetics_preg_`x'.dta"
}


merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", keep(2 3) nogen
replace antiemetics_pregnancy = 0 if antiemetics_pregnancy==. 
keep patid pregid antiemetics_pregnancy

sort patid
compress
save "$Datadir\Derived_data\CPRD\_temp\antiemetics_preg.dta", replace




********************************************************************************
* 3 - Merge together and output 
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\vomiting_preg.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\antiemetics_preg.dta", nogen 
egen vom_antiemet_preg = rowmax(vomit antiemetics)
keep patid pregid vomit_pregnancy antiemetics_preg  vom_antiemet_preg

save "$Datadir\Derived_data\covariates\vomit_or_antiemetics_preg.dta", replace


********************************************************************************
