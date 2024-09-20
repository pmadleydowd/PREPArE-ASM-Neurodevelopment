***********************************************************************
**************************SMOKING, BMI AND ALCOHOL DATA********************
**************************************************************************


cd  "$Dodir\Data management"

*There are X clinical files 

******************************************************************************************************************************
*Smoking: 
******************************************************************************************************************************

*During or pre-pregnancy
cap program drop pr_getsmok
forvalues n=1/14 {
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final_`n'", clear
keep patid pregstart_num gestdays pregid
run "$Dodir\Data management\Covariate_derivation_dofiles\pr_getsmok"
noi pr_getsmok, clinicalfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Clinical_Files_reduced") ///
 additionalfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Additional_Files") smokingcodelist("$Codelsdir\cr_smokingcodes_reduced") ///
 smokingstatusvar(smokstatus) index(pregstart_num)

*Recode smoking status
recode smokstatus 12=1
rename smokstatus smokstatus
save "$Datadir\Derived_data\CPRD\smoking_`n'_gold", replace
}
use "$Datadir\Derived_data\CPRD\smoking_1_gold", clear
forvalues n=2/14 {
append using "$Datadir\Derived_data\CPRD\smoking_`n'_gold"
}
keep patid pregid pregstart_num smokstatus
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
label variable smokstatus "Smoking status"
label define lb_smokstatus 0 "Non-smoker" 1 "Current smoker" 2 "Ex-smoker"
label values smokstatus lb_smokstatus
preserve
keep patid pregid smokstatus
save "$Datadir\Derived_data\covariates\smokingfinal", replace

*check: expect 99% to have ethnicity among those with live birth 2010-2016, plus eligible for HES linkage, with 85% White ethnicity
restore
*merge 1:m patid pregstart_num using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", keep(match) nogen keepusing(outcome)
*merge m:1 patid using "$Rawdatdir/stata\data_linked/linkage_eligibility_gold21", keep(match) nogen keepusing(hes_e)
*tab hes_e
*tab outcome
gen pregyear=year(pregstart_num)
tab smokstatus if pregyear>=2010 & pregyear<=2016, miss



******************************************************************************************************************************
*BMI
******************************************************************************************************************************

*Pre-pregnancy
forvalues n=1/14 {
	disp "n = `n'"
	use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final_`n'", clear
	keep patid pregid pregstart_num secondtrim_num pregend_num
	run "$Dodir\Data management\Covariate_derivation_dofiles\pr_getbmistatus"
	run "$Dodir\Data management\Covariate_derivation_dofiles\pr_getallbmirecords"
	run "$Dodir\Data management\Covariate_derivation_dofiles\pr_getheightstatus"
	noi pr_getbmistatus, index(pregstart_num) patientfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Patient_Files") ///
	 clinicalfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Clinical_Files") ///
	 additionalfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Additional_Files")

	egen bmi_cat=cut(bmi), at(0,18.5,25,30,1000) 
	recode bmi_cat 18.5=1
	recode bmi_cat 25=2
	recode bmi_cat 30=3

	label define bmi_cat 0 Underweight 1 "Normal Weight" 2 "Overweight" 3 "Obese"
	lab val bmi_cat bmi_cat
	tab bmi_cat
	save "$Datadir\Derived_data\CPRD\bmi_`n'", replace
}
use "$Datadir\Derived_data\CPRD\bmi_1", clear
forvalues n=2/14 {
	append using "$Datadir\Derived_data\CPRD\bmi_`n'"
}
keep patid pregid bmi bmi_cat
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
label variable bmi "BMI"
label variable bmi bmi_cat "BMI"
label define lb_bmi 0 "Underweight, <18 kg/m^2" 1 "Normal weight, 18-<25 kg/m^2" 2 "Overweight, 25-<30 kg/m^2" 3 "Obese, >= 35 kg/m^2" 
label values bmi_cat lb_bmi
save "$Datadir\Derived_data\covariates\bmi_final", replace

*Check overall distribution
use "$Datadir\Derived_data\covariates\bmi_final", clear
merge m:1 patid pregid using "$Rawdatdir/stata\data_linked/20_000228_pregnancy_register.dta", keep(match) nogen keepusing(pregstart_num)
gen pregyear=year(pregstart_num)
keep if pregyear>=2010 & pregyear<=2016
merge m:1 patid using "$Rawdatdir/stata\data_linked/linkage_eligibility_gold21", keep(match) nogen keepusing(hes_e)
keep if hes_e==1
bysort patid: keep if _n==1
merge 1:m patid pregstart_num using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", keep(match) nogen keepusing(outcome)
tab outcome
keep if outcome==1 /*keep live births*/
tab bmi_cat , miss
count if bmi_cat>=35 & pregyear>=2010 & pregyear<=2016

*****************************************************************************************************************************
*Alcohol
******************************************************************************************************************************

*Ever
forvalues n=1/14 {
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final_`n'", clear
keep patid pregid pregstart_num gestdays
run "$Dodir\Data management\Covariate_derivation_dofiles\pr_getalcoholstatus"
noi pr_getalcoholstatus,  clinicalfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Clinical_Files_reduced") ///
 additionalfile("$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Additional_Files") ///
alcoholcodelist("$Codelsdir\cr_alcoholcodes") alcoholstatusvar(alcstatus) ///
alcohollevelvar(alclevel) index(pregstart_num)
save "$Datadir\Derived_data\CPRD\_temp\alc_`n'", replace
}
use "$Datadir\Derived_data\CPRD\_temp\alc_1", clear
forvalues n=2/14 {
append using "$Datadir\Derived_data\CPRD\_temp\alc_`n'"
}
gen hazardous_drinking=1 if alclevel==3
replace hazardous_drinking=0 if alclevel!=3
keep patid pregid hazardous_drinking
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
label variable hazardous_drinking "Evidence of alcohol problems (binary)"
label define lb_hazardous_drinking 1 "Yes" 0 "No"
label values hazardous_drinking lb_hazardous_drinking
save "$Datadir\Derived_data\covariates\alc_final", replace

*Check overall distribution
use "$Datadir\Derived_data\covariates\alc_final", clear
merge m:1 patid pregid using "$Rawdatdir/stata\data_linked/20_000228_pregnancy_register.dta", keep(match) nogen keepusing(pregstart_num)
gen pregyear=year(pregstart_num)
keep if pregyear>=2010 & pregyear<=2016
merge m:1 patid using "$Rawdatdir/stata\data_linked/linkage_eligibility_gold21", keep(match) nogen keepusing(hes_e)
keep if hes_e==1
bysort patid: keep if _n==1
merge 1:m patid pregstart_num using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", keep(match) nogen keepusing(outcome)
tab outcome
keep if outcome==1 /*keep live births*/
tab hazardous_drinking , miss


*erase files we do not need
forvalues n=1/14 {
capture erase "$Datadir\Derived_data\CPRD\_temp\smoking_`n'_gold.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\alc_`n'.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\bmi_`n'.dta"
}
