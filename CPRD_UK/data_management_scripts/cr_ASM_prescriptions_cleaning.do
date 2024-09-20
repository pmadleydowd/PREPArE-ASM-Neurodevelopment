cap log close
log using "$Logdir\LOG_cr_ASM_presciptions_cleaning.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			07 October 2021
* Description: 		Extract and clean individual ASM prescriptions (define length, dose, ASM type) for all women in the pregnancy register
* Notes: 			1) Uses the file "Stata syntax for CPRD analyses\Stata syntax for CPRD analyses\1_create pregnancy and mother cohorts\1_Using data from CPRD Gold\5_Estimate antidepressant prescription lengths and identify treatment groups.do" written by Hein Heuvelman in order to run data cleaning checks on prescriptions in CPRD 


********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************
* 06/01/2022 - removed exposure derivations section and created new .do file for this (cr_ASM_presciptions_exposure_derivations.do). Updated title of current .do file from cr_ASM_prescriptions.do to cr_ASM_prescriptions_cleaning.do


********************************************************************************	
* Output datasets 	
********************************************************************************
*	1 - "$Datadir\Derived_data\CPRD\ASM_therapy.dta" - a dataset of all ASM prescriptions (3,865,538 prescriptions)
* 	2 - "$Datadir\Derived_data\CPRD\ASM_therapy_365days_prior_to_first_pregnancy.dta" - a dataset of all ASM prescriptions occuring after the time point 365 days before the first preganncy in the cohort (1,268,940 prescriptions)
* 	3 - "$Datadir\Derived_data\CPRD\ASM_prescriptions_cleaned.dta" - a dataset of cleaned prescription information including daily dose and quantity, and length of prescription derived (1,256,739 prescriptions for 44,282 unique patient IDs)	


********************************************************************************
* Contents
********************************************************************************
* 1 - Identify all ASM prescriptions and label variables
* 2 - Restrict to ASM prescriptions in year prior to or anytime following first pregnancy in study period
* 3 - Data cleaning
* 	3.1 - Identify all missing and implausible values of quantity and daily dose prescribed 
* 	3.2 - Set all implausible values to missing
* 	3.3 - Use the hotdecking procedure to impute missing values for quantity and daily dose prescribed
* 4 - Define length of prescription
* 5 - Define daily dose of prescription
* 6 - Estimate prescription end dates and output prescription data


********************************************************************************
* Load packages 
********************************************************************************
ssc install unique 

********************************************************************************
* 1 - Identify all ASM prescriptions and label variables
********************************************************************************
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Therapy_Files.dta", clear
count
joinby prodcode using "$Codelsdir\Prescription_AEDs_signed_off_DR.dta", _merge(mergevar)
tab mergevar
drop mergevar _merge 
count
sort patid eventdate

* attach labels to variables in codelists
label variable productname "Name of product"
label variable aed "Flag to indicate ASM therapy"
label variable aed_class "ASM class"
label variable epilepsy_only "ASM is epilepsy only flag"
label variable bipolar_only "ASM is bipolar only flag"
label variable dosemg "Dosage (mg)"
label variable ddd_who "WHO Defined Daily Dose"

duplicates drop
compress
save "$Datadir\Derived_data\CPRD\ASM_therapy.dta", replace


********************************************************************************
* 2 - Restrict to ASM prescriptions in year prior to or anytime following first pregnancy in study period
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear // take pregnancy cohort mothers
joinby patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", unmatched(master) // merge on pregnancy register info
drop _merge
sort patid pregstart_num
by patid: egen seq=seq() // generate sequence of pregnancies in cohort for each mother
order patid pregstart_num pregnumber totalpregs seq
keep if seq==1 // keep the first pregnancy 
keep patid pregstart_num
gen pregstart_num_minus365 = pregstart_num - 365 // date of one year prior to start of first pregnancy in cohort for a given mother
format %d pregstart_num_minus365 


* Merge on ASM therapies
merge 1:m patid using "$Datadir\Derived_data\CPRD\ASM_therapy.dta" 
keep if _merge==3 // retain if mother received any ASM therapies
drop _merge 
count // 1,570,691 prescriptions for ASMs at any time point 
unique patid // 49,738 mothers with any prescription of an ASM

* Retain only ASM prescriptions that occur in the year prior to or anytime following first pregnancy in study period - all prescriptions for later pregnancies will also be kept 
sort patid eventdate_num
order patid pregstart_num pregstart_num_minus365 eventdate_num
keep if eventdate_num >= pregstart_num_minus365
count //1,282,121 prescriptions 
unique patid // 44,738 mothers with any prescription of an ASM after the time point 1 year before the start date of their first pregnancy


compress
save "$Datadir\Derived_data\CPRD\ASM_therapy_365days_prior_to_first_pregnancy.dta", replace 



********************************************************************************
* 3 - Data cleaning
********************************************************************************	
use "$Datadir\Derived_data\CPRD\ASM_therapy_365days_prior_to_first_pregnancy.dta", clear	

***Drop unnecessary variables to make dataset as small as possible
drop sysdate eventdate /*string variables*/
drop consid drugdmd bnfcode numdays numpacks issueseq prn sysdate_num

***DAILY DOSE
*Merge in numeric daily dose variable (contains number of tablets taken per day) for those with common dosage information
merge m:1 dosageid using "$Rawdatdir/documentation\Lookups_2021_09\common_dosages.dta", keep(master match) nogen
* 985,132 matched
* 296,989 not matched - no data in common dosage dataset
*Request data from CPRD on other dosageids (HF to investigate)

* Merge on packtype information
merge m:1 packtype using "$Rawdatdir/documentation\Lookups_2021_09\packtype.dta", keep(master match) nogen 


***QUANTITY
*Summarise quantity variable (QTY)
tab qty, sort freq miss
* 813 - 0.1% are missing QTY


*** DAILY DOSE 
*Summarise daily dose variable (daily_dose)
tab daily_dose, sort freq miss
tab daily_dose, mis
* 296,989 - 23.2% are missing daily_dose information


*DOSE IN MG PER TABLET
*Summarise dose variable (derived from product name when generating code list)
tab dosemg, sort freq miss
* 6 - <0.000001% missing dosage in mg



* Check dose units and impute from productname if missing ********************************************************************************
tab dose_unit, mis
* 1,090,133 - 85.0% missing dosage units

* Scan 
tab productname if dose_unit==""
gen flag_tab = regexs(0) if (regexm(productname, "tab")) & dose_unit==""
gen flag_Tab = regexs(0) if (regexm(productname, "Tab")) & dose_unit==""
gen flag_cap = regexs(0) if (regexm(productname, "cap")) & dose_unit==""
gen flag_Cap = regexs(0) if (regexm(productname, "Cap")) & dose_unit==""
replace dose_unit = "TAB" if flag_tab=="tab" | flag_Tab=="Tab"
replace dose_unit = "CAP" if flag_cap=="cap" | flag_Cap=="Cap"
drop flag_tab flag_Tab flag_cap flag_Cap

tab productname if dose_unit==""
gen flag_ml = strpos(productname, "ml ") if dose_unit==""
replace dose_unit="ML" if flag_ml!=. & flag_ml!=0
drop flag_ml

tab productname if dose_unit==""
gen flag_sachet = strpos(productname, "sachet") if dose_unit==""
replace dose_unit="SACHET" if flag_sachet!=. & flag_sachet!=0
drop flag_sachet

tab productname if dose_unit==""
gen flag_supp = strpos(productname, "suppositories") if dose_unit==""
replace dose_unit="SUPPOSITORIES" if flag_supp!=. & flag_supp!=0
drop flag_supp

tab productname if dose_unit==""


tab dose_unit, mis
/*
Notes: 
1) 	Dose units now assigned for all but four observations (titration pack).

2) 	The majority of units are capsules (42.3%) and tablets (57.0%).
	Milligrams make up 0.3% (n=3,325) of dose units. 
	Milliliters make up 0.4% (n=5,133) of dose units. 
	Puffs make up 0.0% (n=6) of dose units. 
*/		


* set those with dose unit in grams to mg
gen daily_dose_original = daily_dose
tab daily_dose if dose_unit=="GRAM"
replace daily_dose = daily_dose*1000 if dose_unit=="GRAM"
tab daily_dose if dose_unit=="GRAM"
replace dose_unit="MG" if dose_unit=="GRAM"

/* Data cleaning process
********************************************************************************
- 1 Identify all implausible values of quantity and daily dose prescribed 
	- 1.1 Daily dose
		- 0 tablets/capsules a day
		- > 10 tablets/capsules a day
	- 1.2 Quantity
		- < 7 tablets/capsules
		- > 280 capsules = 10 capsules a day (maximum daily dose) for 4 weeks
- 2 Set all implausible values to missing
- 3 Use the hotdecking procedure to impute missing values for quantity and daily dose prescribed
*********************************************************************************/

* 3.1 - Identify all missing and implausible values of quantity and daily dose prescribed 
********************************************************************************
gen dose_tab = 1 if inlist(dose_unit, "TAB", "CAP")
replace dose_tab = 2 if inlist(dose_unit, "GRAM", "MG", "ML", "PUFF", "SACHET", "SUPPOSITORIES")

tab dose_tab, matcell(tabcaps) mis
scalar n_tabcap = tabcaps[1,1]
scalar n_otherdose = tabcaps[2,1] // used to calculate percentages manually


* Daily dose
**************
* Daily dose == . 
count if inlist(dose_unit, "TAB", "CAP") & missing(daily_dose) // 294,225 (23.1%) who take tablets or capsules with a missing daily dose
count if !inlist(dose_unit, "TAB", "CAP") & missing(daily_dose) // 2,764 (29.8%) who do not take tablets or capsules with a missing daily dose

tab dosage_text if inlist(dose_unit, "TAB", "CAP") & missing(daily_dose) , miss sort freq // all missing dosage text (didn't merge with common dosages file)
tab dosage_text if !inlist(dose_unit, "TAB", "CAP") & missing(daily_dose) , miss sort freq 


* Daily dose == 0 
count if inlist(dose_unit, "TAB", "CAP") & daily_dose==0 // 90,123 (7.1%) who take tablets or capsules with a daily dose of 0
count if !inlist(dose_unit, "TAB", "CAP") & daily_dose==0 // 490 (5.3%) who do not take tablets or capsules with a daily dose of 0 

tab dosage_text if inlist(dose_unit, "TAB", "CAP") & daily_dose==0 , miss sort freq // most with insufficient information in dosage text (i.e. "as directed")
tab dosage_text if !inlist(dose_unit, "TAB", "CAP") & daily_dose==0 , miss sort freq 


* Daily dose > 10 // 
count if inlist(dose_unit, "TAB", "CAP") & daily_dose>10 & daily_dose!=.  // 1,447 (.11%) who take tablets or capsules with a daily dose > 10 
count if !inlist(dose_unit, "TAB", "CAP") & daily_dose>10  & daily_dose!=. //  4,703 (50.7%) who do not take tablets or capsules with a daily dose > 10 

tab dosage_text if inlist(dose_unit, "TAB", "CAP") & daily_dose>10 & daily_dose!=., miss sort freq 
tab daily_dose if inlist(dose_unit, "TAB", "CAP") & daily_dose>10 & daily_dose!=. , miss sort freq // most seem accurate but a few problematic dosage texts (e.g. "ONE TO BE TAKEN AT 8AM AND 10PM", corresponding to 2 tablets a day and 27% of these with >10)

tab dosage_text if !inlist(dose_unit, "TAB", "CAP") & daily_dose>10 & daily_dose!=., miss sort freq
tab daily_dose if !inlist(dose_unit, "TAB", "CAP") & daily_dose>10 & daily_dose!=., miss sort freq // most seem plausible and in line with dosage text



* Quantity
**************
* Missing quantity 
count if inlist(dose_unit, "TAB", "CAP") & missing(qty) // 813 (.06%) who take tablets or capsules with missing quantity  
count if !inlist(dose_unit, "TAB", "CAP") & missing(qty) //  0 (0%) who do not take tablets or capsules with missing quantity  

tab packtype_desc if inlist(dose_unit, "TAB", "CAP") & missing(qty), miss sort freq
tab packtype_desc if !inlist(dose_unit, "TAB", "CAP") & missing(qty), miss sort freq


* Quantity < 7 
count if inlist(dose_unit, "TAB", "CAP") & qty<7 // 9997 (.79%) who take tablets or capsules with a quantity <7 
count if !inlist(dose_unit, "TAB", "CAP") & qty<7 //   86 (.94%) who do not take tablets or capsules with a quantity <7 

tab packtype_desc if inlist(dose_unit, "TAB", "CAP")  & qty<7 , miss sort freq // Need to check whether prescription for single tablet/capsule is likely
tab packtype_desc if !inlist(dose_unit, "TAB", "CAP")  & qty<7 , miss sort freq


* Quantity > 280 
count if inlist(dose_unit, "TAB", "CAP") & qty>280  & qty!=. //  19,188 (1.5%) who take tablets or capsuleswith a quantity > 280 
count if !inlist(dose_unit, "TAB", "CAP") & qty>280 & qty!=. //  4,112 (44.3%) who do not take tablets or capsules with a quantity > 280 

tab packtype_desc if inlist(dose_unit, "TAB", "CAP") & qty>280 & qty!=., miss sort freq
tab qty if inlist(dose_unit, "TAB", "CAP") & qty>280 & qty!=., miss sort freq

tab packtype_desc if !inlist(dose_unit, "TAB", "CAP") & qty>280 & qty!=., miss sort freq
tab qty if !inlist(dose_unit, "TAB", "CAP") & qty>280 & qty!=., miss sort freq


* 3.2 - Set all implausible values to missing
********************************************************************************
* Daily dose - CHECK THESE WITH HF
**************
replace daily_dose = . if daily_dose==0 // 90,613 set to missing 
replace daily_dose = . if daily_dose>10 & daily_dose!=. & inlist(dose_unit, "TAB", "CAP") //  1447 set to missing 

 
* Quantity - CHECK THESE WITH HF
**************
replace qty = . if qty <7 //  10,084 set to missing 

	

* 3.3 - Use the hotdecking procedure to impute missing values for quantity and daily dose prescribed
********************************************************************************
count
count if qty==.
count if daily_dose==.

*Create a flag to indicate imputed values

gen flag_imputed_daily_dose = 1 if daily_dose==.
gen flag_imputed_qty = 1 if qty==.

gen dose_unit2 = .
replace dose_unit2=1 if inlist(dose_unit, "CAP", "TAB")
replace dose_unit2=2 if inlist(dose_unit, "MG")
replace dose_unit2=3 if inlist(dose_unit, "ML")
replace dose_unit2=4 if inlist(dose_unit, "PUFF")
replace dose_unit2=5 if inlist(dose_unit, "SACHET")
replace dose_unit2=6 if inlist(dose_unit, "SUPPOSITORIES")

tab dose_unit dose_unit2, miss

*If daily_dose missing, impute modal daily dose within dose_unit2/patient/prodcode/qty

bysort dose_unit2 patid prodcode qty: egen modal_daily_dose = mode(daily_dose) 
replace daily_dose = modal_daily_dose if daily_dose==. 
count if daily_dose==. 

*If daily_dose still missing, impute modal daily_dose for dose_unit2/prodcode/qty in any patient

bysort dose_unit2 prodcode qty: egen modal_daily_dose2 = mode(daily_dose) 
replace daily_dose = modal_daily_dose2 if daily_dose==. & modal_daily_dose==. 
count if daily_dose==.

*If daily_dose still missing, impute modal daily_dose for dose_unit2/prodcode in any patient

bysort dose_unit2 prodcode: egen modal_daily_dose3 = mode(daily_dose) 
replace daily_dose = modal_daily_dose3 if daily_dose==. & modal_daily_dose==. & modal_daily_dose2==. 
count if daily_dose==. 

*If daily_dose then still missing, impute modal daily_dose for dose_unit2/prodname in any patient

bysort dose_unit2 productname: egen modal_daily_dose4 = mode(daily_dose) 
replace daily_dose = modal_daily_dose4 if daily_dose==. & modal_daily_dose==. & modal_daily_dose2==. & modal_daily_dose3==.
count if daily_dose==. 

*If daily_dose then still missing, impute modal daily_dose for dose_unit2/aedclass in any patient

bysort dose_unit2 aed_class: egen modal_daily_dose5 = mode(daily_dose) 
replace daily_dose = modal_daily_dose5 if daily_dose==. & modal_daily_dose==. & modal_daily_dose2==. & modal_daily_dose3==. & modal_daily_dose4==. 
count if daily_dose==.

count
count if qty==.
count if daily_dose==.	

*If qty missing, impute modal qty within dose_unit2/patient/prodcode/daily_dose

bysort dose_unit2 patid prodcode daily_dose: egen modal_qty = mode(qty) 
replace qty = modal_qty if qty==. 
count if qty==. 

*If qty still missing, impute modal qty for dose_unit2/prodcode/daily_dose in any patient

bysort dose_unit2 prodcode daily_dose: egen modal_qty2 = mode(qty) 
replace qty = modal_qty2 if qty==. & modal_qty==. 
count if qty==.

*If qtyq still missing, impute modal qty for dose_unit2/prodcode in any patient

bysort dose_unit2 prodcode: egen modal_qty3 = mode(qty) 
replace qty = modal_qty3 if qty==. & modal_qty==. & modal_qty2==. 
count if qty==. 

*If qty then still missing, impute modal qty for dose_unit2/prodname in any patient

bysort dose_unit2 productname: egen modal_qty4 = mode(qty) 
replace qty = modal_qty4 if qty==. & modal_qty==. & modal_qty2==. & modal_qty3==.
count if qty==. 

*If qty then still missing, impute modal qty for dose_unit2/aedclass in any patient

bysort dose_unit2 aed_class: egen modal_qty5 = mode(qty) 
replace qty = modal_qty5 if qty==. & modal_qty==. & modal_qty2==. & modal_qty3==. & modal_qty4==. 
count if qty==.

count // 1,282,121
count if qty==. // 5 with qty still missing
count if daily_dose==. // 26 with daily dose still missing		 

*Update flag to indicate imputed values

replace flag_imputed_daily_dose = . if daily_dose==.
replace flag_imputed_qty = . if qty==.

tab flag_imputed_daily_dose, miss // 389,023 (30.34%) with daily dose imputed
tab flag_imputed_qty, miss // 10,892 (0.85%) with quantity imputed


*Drop any unneeded variables

drop /*
*/ dose_unit2 /*
*/ modal_daily_dose modal_daily_dose2 modal_daily_dose3 modal_daily_dose4 modal_daily_dose5 /*
*/ modal_qty modal_qty2 modal_qty3 modal_qty4 modal_qty5


/*
preserve
count // 1,282,121
duplicates drop patid, force
count // 44,738 women 
restore
*/
	
 
 
 * summary statistics for daily dose 
summ daily_dose, de
summ daily_dose if flag_imputed_daily_dose==., de
summ daily_dose if flag_imputed_daily_dose==1, de

twoway /*
*/ histogram daily_dose if flag_imputed_daily_dose==., width(2) blcolor(red) bfcolor(none) fraction || /*
*/ histogram daily_dose if flag_imputed_daily_dose==1, width(2) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))

 twoway /*
*/ histogram daily_dose if flag_imputed_daily_dose==. & daily_dose<=10, width(1) blcolor(red) bfcolor(none) fraction || /*
*/ histogram daily_dose if flag_imputed_daily_dose==1 & daily_dose<=10, width(1) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))

 
* summary statistics for quantity
summ qty, de
summ qty if flag_imputed_qty==., de
summ qty if flag_imputed_qty==1, de

twoway /*
*/ histogram qty if flag_imputed_qty==., width(2) blcolor(red) bfcolor(none) fraction || /*
*/ histogram qty if flag_imputed_qty==1, width(2) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))

twoway /*
*/ histogram qty if flag_imputed_qty==. & qty<=336, width(2) blcolor(red) bfcolor(none) fraction || /*
*/ histogram qty if flag_imputed_qty==1 & qty<=336, width(2) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))

 
save "$Datadir\Derived_data\CPRD\_temp\temp_prescr.dta", replace

	
********************************************************************************
* 4 - Define length of prescription
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\temp_prescr.dta", clear

*Create flag to indicate prescription lenght based on imputed data

gen flag_imputed_prescr_length = .
replace flag_imputed_prescr_length = 1 if flag_imputed_daily_dose==1 | flag_imputed_qty==1


*Generate new prescription length and quality check the imputed data
* prescription duration: QTY (total number tablets) / Daily_dose (tablets per day)

gen prescr_length = ceil(qty / daily_dose) // rounding up to the next whole number
label var prescr_length "Prescription duration in days"

tab prescr_length, miss // 26 (<0.0001%) missing
summ prescr_length, de
summ prescr_length if flag_imputed_prescr_length==., de
summ prescr_length if flag_imputed_prescr_length==1, de

*Censor at a lowest value of 2 days and highest value of 360 days

replace prescr_length = 2 if prescr_length<2
replace prescr_length = 360 if prescr_length>360 & prescr_length!=.

summ prescr_length, de
summ prescr_length if flag_imputed_prescr_length==., de
summ prescr_length if flag_imputed_prescr_length==1, de		

twoway /*
*/ histogram prescr_length if flag_imputed_prescr_length==., width(4) blcolor(red) bfcolor(none) fraction || /*
*/ histogram prescr_length if flag_imputed_prescr_length==1, width(2) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))


save "$Datadir\Derived_data\CPRD\_temp\temp_prescr_length.dta", replace		



********************************************************************************
* 5 - Define daily dose of prescription
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\temp_prescr_length.dta", clear	

*Create flag to indicate daily dose based on imputed data

gen flag_imputed_dd_mg = .
replace flag_imputed_dd_mg = 1 if flag_imputed_daily_dose==1 

* Calculate daily dose

gen dd_mg=daily_dose*dosemg
sum dd_mg, detail
sum dd_mg if flag_imputed_dd_mg==., de
sum dd_mg if flag_imputed_dd_mg==1, de  // imputed values lower on average than observed

twoway /*
*/ histogram dd_mg if flag_imputed_dd_mg==., width(4) blcolor(red) bfcolor(none) fraction || /*
*/ histogram dd_mg if flag_imputed_dd_mg==1, width(2) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))

twoway /*
*/ histogram dd_mg if flag_imputed_dd_mg==. & dd_mg<3200 , width(4) blcolor(red) bfcolor(none) fraction || /*
*/ histogram dd_mg if flag_imputed_dd_mg==1 & dd_mg<3200, width(2) bfcolor(none) blcolor(blue) fraction legend(order(1 "Actual" 2 "Imputed"))


tab dd_mg, miss // 24 (<0.0001%) missing
label var dd_mg "Daily dose (mg) taken per day"

save "$Datadir\Derived_data\CPRD\_temp\temp_prescr_length_dd.dta", replace


********************************************************************************
* 6 - Estimate prescription end dates and output prescription data
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\temp_prescr_length_dd.dta", replace

gen presc_startdate_num = eventdate_num
gen presc_enddate_num = eventdate_num + prescr_length
format %td presc_startdate_num presc_enddate_num 

keep patid presc_startdate_num presc_enddate_num prodcode aed_class qty daily_dose dose_unit prescr_length dd_mg flag_imputed* ddd_who
order patid presc_startdate_num presc_enddate_num prodcode aed_class qty daily_dose dose_unit prescr_length dd_mg flag_imputed* ddd_who

label variable daily_dose	"Daily dose"
label variable dose_unit	"Units for daily dose"
label variable prescr_length "Length of prescription in days"
label variable flag_imputed_daily_dose "Imputed daily dose"
label variable flag_imputed_qty "Imputed quantity"
label variable flag_imputed_prescr_length "Imputed length of prescription (either daily dose or quantity)"
label variable flag_imputed_dd_mg "Imputed daily dose in mg (daily dose imputed)"
label variable presc_startdate_num "Prescription start date (numeric)"
label variable presc_enddate_num "Prescription end date (numeric)"

compress
duplicates drop // potentially move this to earlier or repeat throughout

drop if presc_enddate_num ==. // remove all those with a missing end date of prescription (23 observations)

save "$Datadir\Derived_data\Exposure\ASM_prescriptions_cleaned.dta", replace	


	

********************************************************************************
* Clear temporary datasets
********************************************************************************
capture erase "$Datadir\Derived_data\CPRD\_temp\temp_prescr.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\temp_prescr_length.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\temp_prescr_length_dd.dta"



********************************************************************************
log close