capture log close
log using "$Logdir\LOG_cr_Covariates_derivation.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			05 January 2022
* Description: 		Derivation of covariates for use in all studies 
* Notes:			1) Makes use of the following .do files	contained in $Dodir\Data management\Covariate_derivation_dofiles
* 						- cr_alc_smok_BMI.do
* 						- cr_clean_ethnicity_codes_in_CPRD.do
* 						- cr_clean_ethnicity_codes_in_HES.do
* 						- cr_Extract_CPRD_Rx_codelists.do
* 						- pr_getalcoholstatus.do
* 						- pr_getallbmirecords.do
* 						- pr_getbmistatus.do
* 						- pr_getheightstatus.do
* 						- pr_getsmok.do
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Install required packages
********************************************************************************
ssc install datacheck

********************************************************************************
* Datasets output
********************************************************************************
* 1 - "$Datadir\Derived_data\CPRD\pregnancy_cohort_covariates.dta" - dataset of mother ID, pregnancy ID and all covariates  

 
********************************************************************************
* Contents
********************************************************************************
* 1 -  Maternal age at the start of pregnancy 
* 2 -  Marital status 
* 3 -  Ethnicity 
* 4 -  Area of residence 
* 5 -  Socioeconomic position (Index of Multiple Deprivation score for area of residence)
* 6 -  Maternal smoking, alcohol intake and body mass index
* 7 -  Prior health care utilization in the year before pregnancy
* 8 -  Number of incident seizures in the year before pregnancy 
* 9 -  Medications taken during the periconceptional period 
* 10 - Vomiting or prescription of antiemetics during pregnancy 
* 11 - Calendar year of start of pregnancy
* 12 - Parity 
* 13 - Illicit drug use 
* 14 - Maternal physical health coniditons at pregnancy start
* 15 - Collate all covariates into a single dataset  
* Delete all temporary datasets

********************************************************************************
* 1 -  Maternal age at the start of pregnancy 
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers

* merge on pregnancy register information 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid pregstart_num 

* merge on mothers patient information 
merge m:1 patid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", keep(3)


* derive estimated DOB as the mid point of the year (1st July) of their year of birth 
gen eDOB = mdy(7,1,yob)
gen matage_at_pregstart_days = pregstart_num - eDOB  
gen matage_at_pregstart_years = floor(matage_at_pregstart_days / 365.25)

* clean variable for implausible maternal ages 
replace matage_at_pregstart_years = . if (matage_at_pregstart_years>100) // 11 individuals with ages >100 

* Derive categorical measure for descriptive statistics 
recode matage_at_pregstart_years (0/17 = 1) (18/24 = 2) (25/29 = 3) (30/34 = 4) (35/100 = 5), gen(matage_cat)

* create labels 
label variable matage_at_pregstart_years "Maternal age in years at pregnancy start (assumes DOB was 1 July)"
label variable matage_cat "Maternal age (years)"
label define lb_matage_cat 1 "<18" 2 "18-24" 3 "25-29" 4 "30-34"  5 ">=35"
label values matage_cat lb_matage_cat

* save dataset 
rename matage_at_pregstart_years matage		
keep patid pregid matage matage_cat yob
save "$Datadir\Derived_data\covariates\matage.dta", replace  



********************************************************************************
* 2 -  Marital status 
********************************************************************************
* prepare lookup MAR 
use "$Rawdatdir\documentation\Lookups_2021_09\TXTFILES\MAR.dta", clear
rename code marital 
save "$Datadir\Derived_data\CPRD\_temp\marital_lookup.dta", replace 

* load patient data 
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers
merge m:1 patid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", keep(3) nogen 

* merge on marital status lookup
merge m:1 marital using "$Datadir\Derived_data\CPRD\_temp\marital_lookup.dta", nogen  

* regroup marital groups - Single, married or civil partnered (including cohabiting and in stable relationship), separated or widowed or divorced, unkown 

gen marital_derv = maritalstatus
replace marital_derv = "Unknown" if maritalstatus == "Data Not Entered" 
replace marital_derv = "In a partnership" if inlist(maritalstatus,"Civil Partnership", "Co-habiting", "Engaged", "Married", "Remarried", "Stable relationship") 
replace marital_derv = "Previosuly in a partnership" if inlist(maritalstatus, "Divorced", "Separated", "Widowed") 
tab marital_derv
encode marital_derv, gen(marital_derived)
drop marital_derv

* create labels 
label variable marital_derived "Marital status"

* save dataset 
keep patid pregid marital_derived
save "$Datadir\Derived_data\covariates\marital.dta" , replace 



********************************************************************************
* 3 -  Ethnicity 
********************************************************************************
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_clean_ethnicity_codes_in_HES.do"
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_clean_ethnicity_codes_in_CPRD.do"
* outputs "$Datadir\Derived_data\CPRD\_temp\ethnicity_final.dta"

* update formatting of variable 
use "$Datadir\Derived_data\CPRD\ethnicity_final.dta", clear
label variable eth5 "Ethnicity"
label define lb_eth5 0 "White" 1 "South Asian" 2 "Black" 3 "Other" 4 "Mixed" 5 "Missing or not Stated"
label values eth5 lb_eth5
replace eth5 = 5 if eth5 == . 

save "$Datadir\Derived_data\covariates\ethnicity_final.dta", replace

********************************************************************************
* 4 -  Area of residence 
********************************************************************************
* prepare lookup PRG 
use "$Rawdatdir\documentation\Lookups_2021_09\TXTFILES\PRG.dta", clear
rename code region
save "$Datadir\Derived_data\CPRD\_temp\region_lookup.dta", replace 

* load pregnancy cohort
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers

* derive practice ID
tostring patid, gen(patid_str) format(%12.0f) force
gen pracid_str = substr(patid_str, -5,5)
destring pracid_str, gen(pracid)

* merge on practice information 
merge m:1 pracid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Practice_Files.dta", keep(3) nogen 

* merge on region lookup
merge m:1 region using "$Datadir\Derived_data\CPRD\_temp\region_lookup.dta", nogen  

* turn into numeric variable
encode practiceregion, gen(AreaOfResidence)

keep patid pregid AreaOfResidence	
save "$Datadir\Derived_data\covariates\area_of_residence.dta" , replace 



********************************************************************************
* 5 -  Socioeconomic position (Index of Multiple Deprivation score for area of residence)
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers

* derive practice ID
tostring patid, gen(patid_str) format(%12.0f) force
gen pracid_str = substr(patid_str, -5,5)
destring pracid_str, gen(pracid)

* merge on IMD by practice ID 
merge m:1 pracid using "$Rawdatdir\stata\data_linked\20_000228_imd_practice.dta", nogen keep(1 3)

* merge on IMD by patient ID 
merge m:1 patid using "$Rawdatdir\stata\data_linked\20_000228_imd2015_patient.dta", nogen keep(1 3)

* check missing data 
count if !missing(imd_practice) // 1,949,089 with practice level IMD information
count if !missing(imd2015_5)   // 570,941 with patient level IMD information

* rename variables 
rename imd2015_5 IMD5_2015_patient

* label variables 
label variable IMD5_2015_patient "Patient level IMD 2015 quintiles - 1 = Least deprived"

* define variable for use in analyses - patient level or practice level if patient level missing
gen imd5 = IMD5_2015_patient
replace imd5 = imd_practice if missing(IMD5_2015_patient)

gen imd5_source = "Patient" if !missing(IMD5_2015_patient)
replace imd5_source = "Practice" if missing(IMD5_2015_patient) & !missing(imd_practice)

* label new variables 
label variable imd5 "Maternal IMD status"
label variable imd5_source "Source of IMD information"
label define lb_imd5 1 "1 - Least deprived" 5 "5 - Most deprived"
label values imd5 lb_imd5


* save file 
keep patid pregid imd5*
save "$Datadir\Derived_data\covariates\SEP.dta" , replace 

********************************************************************************
* 6 -  Maternal smoking, alcohol intake and body mass index
* This information will be collected from clinical records closest to the start of pregnancy
********************************************************************************
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_alc_smok_BMI.do"

* Update missing values  
use "$Datadir\Derived_data\covariates\smokingfinal.dta", clear
replace smokstatus = 3 if smokstatus == . 
label define lb_smokstatus 3 "No information", modify
save "$Datadir\Derived_data\covariates\smokingfinal.dta", replace

use "$Datadir\Derived_data\covariates\bmi_final.dta", clear
replace bmi_cat = 4 if bmi_cat == . 
label define lb_bmi 4 "No information", modify
save "$Datadir\Derived_data\covariates\bmi_final.dta", replace

use "$Datadir\Derived_data\covariates\alc_final.dta", clear
replace hazardous_drinking = 0 if hazardous_drinking == . 
save "$Datadir\Derived_data\covariates\alc_final.dta", replace


********************************************************************************
* 7 -  Prior health care utilization in the year before pregnancy
* Prior health care utilization will be assessed using the number of GP consultation in the year before pregnancy
********************************************************************************
* load consultation files 
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Consultation_Files.dta", clear
* remove all consultations that do not involve an interaction with a health care professional
foreach x in 5 12 13 14 15 16 17 19 23 24 25 26 29 41 42 43 44 45 47 48 49 51 52 53 54 56 57 58 59 60 {
    tab constype if constype == `x'
	drop if constype ==`x'
}
* remove all consultations from before the date of 1 year before the first pregnancy in cohort (1Jan1995)
keep if eventdate_num >= date("1Jan1994","DMY") // 7 million consultations removed
duplicates drop patid eventdate_num, force // keep consultations on different days only
save "$Datadir\Derived_data\CPRD\_temp\Consultation_f2f.dta", replace 


* load pregnancy cohort IDs
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers
* merge on pregnancy register information 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid pregstart_num 
* create a sequence variable for pregnancies 
sort patid 
egen _seq=seq(), by(patid)


* merge on consultation information 
summ _seq
local maxpreg = r(max)
forvalues x = 1(1)`maxpreg' {
	disp "x = " `x'
	preserve 
	keep if _seq==`x' 
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\Consultation_f2f.dta", keep(3) nogen 
	keep if eventdate_num < pregstart_num & eventdate_num > pregstart_num - 365  // retain only events in the year before pregnancy

	if _N > 0 { // some groups may have no events in year before pregnancy
		egen CPRD_consultation_events = count(eventdate_num), by(patid) // count number of events for each patient
		duplicates drop patid, force // keep only first instance of each patient
		keep patid pregid CPRD_consultation_events	
	}
	if _N == 0 {
		keep patid pregid 
	}
	
	save "$Datadir\Derived_data\CPRD\_temp\CPRD_consultation_events_preg`x'.dta", replace 
	restore 
}

* append all CPRD consultation datasets together 
use "$Datadir\Derived_data\CPRD\_temp\CPRD_consultation_events_preg1.dta", clear
forvalues x = 2(1) `maxpreg' {
	append using "$Datadir\Derived_data\CPRD\_temp\CPRD_consultation_events_preg`x'.dta"
}

* merge back onto pregnancy register
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen 

* set missing values to 0
replace CPRD_consultation_events = 0 if CPRD_consultation_events == . 

* create categorical variable 
recode CPRD_consultation_events (0 = 0) (1/3 = 1) (4/10 = 2) (11/1000 = 3), gen(CPRD_consultation_events_cat)

* label variables
label variable CPRD_consultation_events "Number of CPRD consultation events in year before pregnancy"
label variable CPRD_consultation_events_cat "Number of CPRD consultation events in year before pregnancy"
label define lb_CPRD_consultation_events 0 "0" 1 "1-3" 2 "4-10" 3 ">10"
label values CPRD_consultation_events_cat lb_CPRD_consultation_events

* Save CPRD information 
save "$Datadir\Derived_data\covariates\CPRD_consultation_events.dta" , replace 



**# Adding CPRD consultations during pregnancy
********************************************************************************
* 7b -  Health care utilization during pregnancy
* Health care utilization will be assessed using the number of GP consultations during pregnancy
********************************************************************************
* load consultation files 
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Consultation_Files.dta", clear
* remove all consultations that do not involve an interaction with a health care professional
foreach x in 5 12 13 14 15 16 17 19 23 24 25 26 29 41 42 43 44 45 47 48 49 51 52 53 54 56 57 58 59 60 {
    tab constype if constype == `x'
	drop if constype ==`x'
}
* remove all consultations from before the date of the first pregnancy in cohort (1Jan1995)
keep if eventdate_num >= date("1Jan1995","DMY") // 7 million consultations removed
duplicates drop patid eventdate_num, force // keep consultations on different days only
save "$Datadir\Derived_data\CPRD\_temp\Consultation_preg.dta", replace 


* load pregnancy cohort IDs
use "$Datadir\Derived_data\cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers
* merge on pregnancy register information 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid pregstart_num pregend_num
* create a sequence variable for pregnancies 
sort patid
egen _seq=seq(), by(patid)


* merge on consultation information 
forvalues x = 1(1)17 {
	disp "x = " `x'
	preserve 
	keep if _seq==`x' 
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\Consultation_preg.dta", keep(3) nogen 
	keep if eventdate_num < pregend_num & eventdate_num > pregstart_num   // retain only events in  pregnancy

	if _N > 0 { // some groups may have no events  pregnancy
		egen CPRD_consult_events_preg = count(eventdate_num), by(patid) // count number of events for each patient
		duplicates drop patid, force // keep only first instance of each patient
		keep patid pregid CPRD_consult_events_preg	
	}
	if _N == 0 {
		keep patid pregid 
	}
	
	save "$Datadir\Derived_data\CPRD\_temp\CPRD_consult_events_preg`x'.dta", replace 
	restore 
}

* append all CPRD consultation datasets together 
use "$Datadir\Derived_data\CPRD\_temp\CPRD_consult_events_preg1.dta", clear
forvalues x = 2(1)17 {
	append using "$Datadir\Derived_data\CPRD\_temp\CPRD_consult_events_preg`x'.dta"
}

* merge back onto pregnancy register
merge 1:1 patid pregid using "$Datadir\Derived_data\cohorts\pregnancy_cohort_matids_pregids.dta", nogen 

* set missing values to 0
replace CPRD_consult_events_preg = 0 if CPRD_consult_events_preg == . 

* create categorical variable 
recode CPRD_consult_events_preg (0 = 0) (1/3 = 1) (4/10 = 2) (11/1000 = 3), gen(CPRD_consult_events_preg_cat)

* label variables
label variable CPRD_consult_events_preg "Number of CPRD consultation events during pregnancy"
label variable CPRD_consult_events_preg_cat "Number of CPRD consultation events during pregnancy"
label define lb_CPRD_consult_events_preg 0 "0" 1 "1-3" 2 "4-10" 3 ">10"
label values CPRD_consult_events_preg_cat lb_CPRD_consult_events_preg

* Save CPRD information 
save "$Datadir\Derived_data\covariates\CPRD_consult_events_preg.dta" , replace 


**# End



********************************************************************************
* 8 -  Number of incident seizures in the year before pregnancy 
* The number of incident seizures in the year before pregnancy was used as a marker of activity or severity of epilepsy. Incident seizures were identified by a Read code in the clinical or referral CPRD files, an ICD-10 code in the first diagnostic position in the HES APC linked dataset, or a Read code, ICD-10 code or an A&E diagnosis of an epilepsy related central nervous system condition in the HES A&E linked dataset. Incidents had to occur on separate days to be counted 
********************************************************************************
* Obtain info on CPRD seizures 
********************************
* Lift all events relating to seizures from Clinical and referral files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num
joinby medcode using "$Codelsdir\READ_epilepsy_incident_seizures_signed_off.dta", _merge(mergevar) 
rename eventdate_num clinical_date
keep patid clinical_date 
duplicates drop // keeping only events on different days
sort patid
compress
save "$Datadir\Derived_data\CPRD\_temp\seizures.dta"



* Obtain info on HES seizures
********************************
* Lift all events relating to seizures from HES admitted patients
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear
count
rename icd code
merge m:1 code using "$Datadir\codelists\ICDCode_epilepsy_incident_seizures_signed_off.dta"
list code description if _merge ==2 // G41 and R56 not merged but subclassifications have been  
keep if _merge == 3 
drop _merge 
count
rename epistart_num clinical_date
keep patid clinical_date 
duplicates drop // keeping only events on different days
sort patid
compress
save "$Datadir\Derived_data\HES\_temp\APC_seizures.dta", replace


*Lift all events relating to seizures from HES A&E attendances
	* Prepare code list for use in outpatient files
use "$Codelsdir\ICDCode_epilepsy_incident_seizures_signed_off.dta", clear 
gen altcode = subinstr(code, ".", "",.)
save "$Datadir\Derived_data\HES\_temp\ICDCode_epilepsy_incident_seizures_signed_off.dta", replace
	* load data
use "$Rawdatdir\stata\data_linked\20_000228_hesae_diagnosis.dta", clear
	* merge on ICD 10 diagnoses in HES A&E
rename diag altcode
merge m:1 altcode using "$Datadir\Derived_data\HES\_temp\ICDCode_epilepsy_incident_seizures_signed_off.dta", keep(1 3) 
gen seizure=1 if _merge == 3
drop _merge 
	* merge on Read code diagnoses in HES A&E
rename altcode readcode
merge m:1 readcode using "$Codelsdir\READ_epilepsy_incident_seizures_signed_off.dta", keep(1 3) // no readcodes in HES A&E for seizures 
replace seizure=1 if _merge == 3
drop _merge 
	* identify A&E diagnosis codes for epilepsy events 
replace seizure=1 if diag3 == "241" & diagscheme == 1
	* keep seizure events
keep if seizure ==1 
	* merge on date information 
keep patid aekey 
duplicates drop 
count
merge 1:1 patid aekey using "$Rawdatdir\stata\data_linked\20_000228_hesae_attendance.dta", keep(3) 
rename arrivaldate_num clinical_date 
keep patid clinical_date 
compress
save "$Datadir\Derived_data\HES\_temp\AE_seizures.dta", replace


* join HES lists together
use "$Datadir\Derived_data\HES\_temp\APC_seizures.dta", clear
append using "$Datadir\Derived_data\HES\_temp\AE_seizures.dta"
duplicates drop // keeping only events on different days
sort patid clinical_date
compress
save "$Datadir\Derived_data\HES\_temp\seizures.dta", replace



* Merge info onto pregnancy register and determine if seizure was in the year before pregnancy 
************************************************************************************************
foreach source in "CPRD" "HES" { 
	* Set local macros
	if "`source'" == "CPRD" {
		local indata = "$Datadir\Derived_data\CPRD\_temp\seizures.dta"
		local outdata = "$Datadir\Derived_data\CPRD\_temp\seizures_preg"
	}
	else if "`source'" == "HES" {
		local indata = "$Datadir\Derived_data\HES\_temp\seizures.dta"
		local outdata = "$Datadir\Derived_data\HES\_temp\seizures_preg"
	}	
	
	* load pregnancy cohort IDs and pregnancy start 
	use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear
	merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
	keep patid pregid pregstart_num 
		* create a sequence variable for pregnancies 
	sort patid 
	egen _seq=seq(), by(patid)

	
	* merge on seizure info from CPRD for each pregnancy and count number of events
	summ _seq 
	local maxpreg = r(max)
	forvalues x = 1(1)`maxpreg' {
		disp "x = " `x'
		preserve 
		keep if _seq==`x' 
		merge 1:m patid using "`indata'", keep(3) nogen // merge on seizure event info 
		keep if clinical_date < pregstart_num & clinical_date > pregstart_num - 365  // retain only events in the year before pregnancy

		if _N > 0 { // some groups with no events in year before pregnancy
			egen `source'_seizure_events = count(clinical_date), by(patid) // count number of events for each patient
			duplicates drop patid, force // keep only first instance of each patient
			keep patid pregid `source'_seizure_events	
		}
		if _N == 0 {
			keep patid pregid 
		}
		
		save "`outdata'_`x'.dta", replace 
		restore 
	}
	  
		* append all seizure datasets together 
	use "`outdata'_1.dta", clear
	forvalues x = 2(1)`maxpreg' {
		append using "`outdata'_`x'.dta"
	}

		* merge back onto pregnancy register
	merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen 

		* set missing values to 0
	replace `source'_seizure_events = 0 if `source'_seizure_events == . 

		* Save information 
	save "$Datadir\Derived_data/`source'\_temp\seizure_events.dta" , replace 	
	
}


* Collate all information 
************************************
* merge CPRD and HES information 
use "$Datadir\Derived_data\CPRD\_temp\seizure_events.dta", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\HES\_temp\seizure_events.dta", nogen 

* count total number of events across CPRD and HES 
gen seizure_events_CPRD_HES = CPRD_seizure_events + HES_seizure_events 

* create categorical variables 
foreach var in CPRD_seizure_events HES_seizure_events seizure_events_CPRD_HES {
	recode `var' (0 = 0) (1 = 1) (2 = 2) (3/100 = 3), gen(`var'_cat)
}

* create variable labels 
label variable CPRD_seizure_events "Number of CPRD seizure events in year before pregnancy"
label variable CPRD_seizure_events_cat "Number of CPRD seizure events in year before pregnancy"
label variable HES_seizure_events "Number of HES seizure events in year before pregnancy"
label variable HES_seizure_events_cat "Number of HES seizure events in year before pregnancy"
label variable seizure_events_CPRD_HES "Number of seizure events in CPRD and HES in the year before pregnancy"
label variable seizure_events_CPRD_HES_cat "Number of seizure events in CPRD and HES in the year before pregnancy"

label define lb_seizure_events 0 "0" 1 "1" 2 "2" 3 "3+"
label values CPRD_seizure_events_cat HES_seizure_events_cat seizure_events_CPRD_HES_cat lb_seizure_events

* save data 
save "$Datadir\Derived_data\covariates\seizure_events_final.dta" , replace 


********************************************************************************
* 9 -  Medications taken during the periconceptional period 
* Medications taken during the periconceptional period such as folic acid, multivitamins, antidepressants, and antipsychotics will be considered as potential confounders.
********************************************************************************
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_Extract_CPRD_Rx_codelists.do"

* Outputs the following files
* 	- "$Datadir\Derived_data\Covariates\antipsychotics_Rx_365_pre_preg.dta"
* 	- "$Datadir\Derived_data\Covariates\antidepressants_Rx_365_pre_preg.dta"
* 	- "$Datadir\Derived_data\Covariates\multivitamin_Rx_365_pre_preg.dta"
* 	- "$Datadir\Derived_data\Covariates\folic_acid_Rx_365_pre_preg.dta"


********************************************************************************
* 10 - Vomiting or prescription of antiemetics during pregnancy 
* As drug levels may be influenced by vomiting in pregnancy we will also include vomiting or prescription of antiemetics during pregnancy as potential covariates
********************************************************************************
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_vomiting_antiemetics.do"

********************************************************************************
* 11 - Calendar year of start of pregnancy will always be included as a control variable.
* Time trends are necessary to evaluate given the length of the study and how both neurodevelopmental outcomes and AEDs have changed over time, therefore calendar year of start of pregnancy will always be included as a control variable.
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers

* merge on pregnancy register information 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid pregstart_num 

* generate year of pregnancy start 
gen pregstart_year = year(pregstart_num)

* recode into categories 
recode pregstart_year (1995/1999 = 1) (2000/2004 = 2) (2005/2009 = 3) (2010/2014 = 4) (2015/2018 = 5), gen(pregstart_year_cat)
label define lb_yearcat 1 "1995-1999" 2 "2000-2004" 3 "2005-2009" 4 "2010-2014" 5 "2015-2018"
label values pregstart_year_cat lb_yearcat

* create label 
label variable pregstart_year "Year of pregnancy start"
label variable pregstart_year_cat "Year of pregnancy start"

* save file 
keep patid pregid pregstart_year*
save "$Datadir\Derived_data\covariates\year_of_pregnancy.dta" , replace 


********************************************************************************
* 12 - Parity and gravidity
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_conflicts_outcome_update.dta", clear // take pregnancy cohort mothers
keep patid pregid updated_outcome

* merge on pregnancy register information 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) 
keep patid pregid updated_outcome pregstart_num // taking the pregnancy number as gravidity 

* generate gravidty as order among pregnancies (updated after cleaning algorithms)
sort patid pregstart_num 
by patid: egen gravidity = seq()
label variable gravidity "Gravidity"

* generate parity variable as order among live born children 
gen viable = 1 if inlist(updated_outcome, 1,2,3,11,12) 
sort patid viable gravidity
by patid: egen parity = seq() if viable == 1
label variable parity "Parity"

* generate categorical variables
recode gravidity (1 = 0) (2 = 1) (3 = 2) (4/100 = 3), gen(gravidity_cat)
label variable gravidity_cat "Gravidity"
label define lb_graviditycat 0 "0" 1 "1" 2 "2" 3 "3+"
label values gravidity_cat lb_graviditycat

recode parity (1 = 0) (2 = 1) (3 = 2) (4/100 = 3), gen(parity_cat)
label variable parity_cat "Parity"
label define lb_paritycat 0 "0" 1 "1" 2 "2" 3 "3+"
label values parity_cat lb_paritycat

keep patid pregid gravidity parity gravidity_cat parity_cat

save "$Datadir\Derived_data\covariates\parity.dta" , replace 



********************************************************************************
* 13 - Illicit drug use 
********************************************************************************
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_illicit_drug_use.do"

********************************************************************************
* 14 - Maternal physical health coniditons at pregnancy start
********************************************************************************
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_mothers_physical_conditions.do"
do "$Dodir\Data management\Covariate_derivation_dofiles\cr_chlamydia_infection.do"

********************************************************************************
* 15 - Collate all covariates into a single dataset  
********************************************************************************
* take pregnancy cohort mothers
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear 

* merge all files together 
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\matage.dta", nogen keep(1 3) // section 1 - maternal age
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\marital.dta" , nogen keep(1 3) // section 2 - marital status
merge 1:1 patid pregid using  "$Datadir\Derived_data\covariates\ethnicity_final", nogen keep(1 3) // section 3 - ethnicity 
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\area_of_residence.dta" , nogen keep(1 3) // section 4 - area of residence
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\SEP.dta" , nogen keep(1 3) // section 5 - IMD5 

* merge files from section 6 - maternal smoking, bmi and alcohol  
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\smokingfinal", nogen keep(1 3) // smoking 
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\bmi_final", nogen keep(1 3) // bmi
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\alc_final", nogen keep(1 3) // alcohol use

merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\CPRD_consultation_events.dta" , nogen keep(1 3) // section 7 - health care utilization
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\CPRD_consult_events_preg.dta" , nogen keep(1 3) //section 7b- healht care utilization during pregnancy 

merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\seizure_events_final.dta", nogen keep(1 3) // section 8 - epilepsy severity

* merge files from section 9 - medications taken during the periconceptional period 
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\antipsychotics_Rx_365_pre_preg.dta", nogen keep(1 3) // antipsychotics
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\antidepressants_Rx_365_pre_preg.dta", nogen keep(1 3) // antidepressants
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\multivitamin_Rx_365_pre_preg.dta", nogen keep(1 3) // multivitamin
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\folic_acid_Rx_365_pre_preg.dta", nogen keep(1 3) // folic acid 

merge 1:1 patid pregid using  "$Datadir\Derived_data\covariates\vomit_or_antiemetics_preg.dta", nogen keep(1 3) // section 10 - vomiting or prescription of antiemetics during pregnancy
 
merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\year_of_pregnancy.dta", nogen keep(1 3) // section 11 - year of pregnancy start 

merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\parity.dta", nogen keep(1 3) // section 12 - parity 

merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\illicitdruguse.dta", nogen keep(1 3) // section 13 - illicit drug use 

merge 1:1 patid pregid using "$Datadir\Derived_data\covariates\long_term_health_con_final.dta", nogen keep(1 3) // section 13 - maternal physical health conditions 
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\final_chlamydia.dta", nogen keep(1 3) // section 13 - maternal physical health conditions 


* save covariate information
save "$Datadir\Derived_data\covariates\pregnancy_cohort_covariates.dta", replace


********************************************************************************
* Delete all temporary datasets
********************************************************************************
capture erase "$Datadir\Derived_data\CPRD\_temp\matage.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\marital.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\marital_lookup.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\area_of_residence.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\region_lookup.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\SEP.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\prior_healthcare_utilization.dta"

capture erase "$Datadir\Derived_data\CPRD\_temp\seizures.dta"
capture erase "$Datadir\Derived_data\HES\_temp\APC_seizures.dta"
capture erase "$Datadir\Derived_data\HES\_temp\AE_seizures.dta"
capture erase "$Datadir\Derived_data\HES\_temp\seizures.dta"

capture erase  "$Datadir\Derived_data\CPRD\_temp\seizure_events.dta"
capture erase  "$Datadir\Derived_data\HES\_temp\seizure_events.dta"

forvalues x = 1(1)17 {
	capture erase "$Datadir\Derived_data\CPRD\_temp\seizure_events_preg`x'.dta", replace 
	capture erase "$Datadir\Derived_data\HES\_temp\seizure_events_preg`x'.dta", replace 	
}

capture erase "$Datadir\Derived_data\CPRD\_temp\parity.dta"

********************************************************************************
log close 