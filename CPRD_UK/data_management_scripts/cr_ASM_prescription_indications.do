cap log close 
log using "$Logdir\LOG_cr_ASM_presciption_indications.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd / Jess / Harriet 
* Date: 			08 October 2021
* Description: 		Identify indications for ASMs from CPRD and HES data
*					1) Extracts codes from inidvidual datasets, then combine
*					2) merge in pregnancy dates, keep pre-preg information
*					3) deal with multiple indications
* Notes: 				
/*
*MAJOR CHANGE 29/1/22 by Jess Rast/HArriet Forbes
Bring in the pregnancy information as described here:
	1) re-run the pregnancy cohort data, but include the start and end date of pregnancy
	2)  make a new variable that identifies when the indication occured
			1) before pregnancy 
			2) during pregnancy 
			3) after pregnancy end
	3) each indication file now includes only one row per pregid with informaiton about first indication occurance
	4) make a new indication file, not replacing the current one without pregnancy info
*/
* Dataset outputs: "$Datadir\Derived_data\CPRD\_temp\ASM_indications_pre_preg_final.dta"

********************************************************************************
* Contents
********************************************************************************
/****Epilepsy: One of the following: 
1) Diagnosis of epilepsy according to the pres-specified algorithm , OR; 
2) Epilepsy-specific AEDs: Epilim, Brivaracetam, Brivaracetam, Eslicarbazepine, 
Ethosuximide, Felbamate, Fenfluramine, Lacosamide, Levetiracetam, Mesuximide, 
Oxcarbazepine, Perampanel, Phenobarbital, Phenytoin, Retigabine, Rufinamide, 
Stiripentol, Sulthiame, Tiagabine, Vigabatrin, Zonisamide, OR; 
3) Epilepsy-specific co-prescribing same day: i) Clobazam and an AED or ii) 
rectal administration of diazepam and an AED or 3) intranasal administration 
of Midazolamand AED 

***Bipolar disorder: One of the following: 
1) Read code in CPRD or ICD-10 code in HES (any diagnostic field) 
for bipolar, anytime prior to pregnancy start date OR; 
2) Mood-disorder specific co-prescribing (1-Quetiapine and [valproate or 
lamotrigine or carbamazepine] or 2-lithium and [valproate or lamotrigine 
or carbamazepine]) OR; 
3) The mood disorder-specific AED Depakote. 

***Generalised anxiety disorder 
An ASM used in psychiatry (valproate or lamotrigine or carbamazepine) along 
with a Read code in CPRD or ICD-10 code in HES for anxiety (any diagnostic field), 
anytime prior to pregnancy start date. 

***Neuropathic pain (including diabetic neuropathy) and fibromyalgia 
An ASM used in neuropathic pain management (carbamazepine, barbexaclone,  gabapentin, pregabalin) alongside either 1) a READ code in CPRD or ICD-10 code in HES (any diagnostic field) for a neuropathic pain disorder, anytime prior to pregnancy start or 2) evidence of codeine co-prescribing.  

***Migraine prophylaxis 
An ASM used for prevention of recurrent migraine (topiramate or valproate) 
along with a READ code in CPRD or ICD-10 code in HES (any diagnostic field) 
for recurrent migraine, anytime prior to pregnancy start. 

*following codelists not signed off: restless_leg tremors oth_mood_affective_dis treatresistant_schiz

***Restless legs syndrome   
The ASM cenobamate used for the treatment of restless leg syndrome along with a 
READ code in CPRD or ICD-10 code in HES (any diagnostic field) for restless leg 
syndrome, anytime prior to pregnancy start. 

***Essential tremors:The ASM primidone used for the treatment of essential tremors 
along with a READ code in CPRD or ICD-10 code (any diagnostic field)  in HES for 
essential tremors, anytime prior to pregnancy start. 

***Depression:An ASM used in psychiatry (valproate or lamotrigine or 
carbamazepine) along with a READ code in CPRD or ICD-10 code in HES (any 
diagnostic field) for  depression, anytime prior to pregnancy start. 

***Treatment resistant schizophrenia:An ASM used in psychiatry (valproate or 
lamotrigine or carbamazepine) along with READ code in CPRD or ICD-10 code (any 
diagnostic field) in HES for schizophrenia, anytime prior to pregnancy start. 

***Other off-label psychiatric use:Where none of the above indications were 
identified, yet there was co-prescription of antipsychotics, lithium, or 
antidepressants, alongside an ASM used in psychiatry (valproate or lamotrigine 
or carbamazepine) in CPRD. 

*/
*------------------------------------------------------------------------------*
********************************************************************************
* 1.1 - CPRD
********************************************************************************
**********************Diagnoses

*Combine code lists into one file
use "$Codelsdir\READ_epilespy_signed_off.dta", clear
gen asm_indication="epilepsy"
foreach var in bipolar anxiety neuropathicpain fibromyalgia migraine  {
append using "$Codelsdir\READ_`var'_signed_off.dta"
replace asm_indication="`var'" if asm_indication==""
}
append using  "$Codelsdir\ReadCode_psychosis_schizophrenia_signed_off_DR.dta"
replace asm_indication="psychosis" if asm_indication==""
append using  "$Codelsdir\ReadCode_mood_affective_disorders_signed_off_DR.dta"
replace asm_indication="oth_mood_affective_dis" if asm_indication==""
*drop if asm=="oth_mood_affective_dis" & severity!="high" /*only keep depression codes indicating severe depression*/ REMOVE
append using "$Codelsdir\ReadCode_restlessleg_signed_off_DR.dta"

replace asm_indication="restless_leg" if asm_indication==""
append using "$Codelsdir\ReadCode_essential_tremor_signed_off_DR.dta"
replace asm_indication="essential_tremor" if asm_indication==""
keep medcode asm 
save "$Codelsdir\READ_asm_indications_all_signed_off.dta", replace

*Lift all diagnoses relating to indications from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
joinby medcode using "$Codelsdir\READ_asm_indications_all_signed_off.dta", _merge(mergevar) /*keeps matches only*/
save "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta", replace
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
keep patid medcode eventdate_num  asm_indication
save "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_first_Dx.dta", replace
keep if asm_indication=="epilepsy" | asm_indication=="bipolar"
save "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_first_Dx_bipolar_epilepsy.dta", replace


*Seizures - 2 within 24 hours, take last seizure as event date
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
merge m:1 medcode using "$Codelsdir\READ_epilepsy_incident_seizures_signed_off", keep(match) nogen
keep patid eventdate_num
duplicates drop
drop if eventdate_num==.
bysort patid: drop if _N==1

*Group siezures
gen toassign = -1
gen group = 0
local g = 1
qui count if toassign

qui while r(N) > 0 {
    bysort patid (toassign eventdate_num) : replace group = `g' if (eventdate_num - eventdate_num[1]) <= 1 & toassign
      replace toassign = 0 if group == `g'
      local ++g
      count if toassign
}
bysort patid group: gen bign=_N
keep if bign>1
gen asm_indication="epilepsy"
keep patid asm_indication eventdate_num
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
save "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_seizure.dta", replace

********************************************************************************
***********************Prescriptions
********************************************************************************

*Extract all prescriptions for AEDS
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Therapy_Files.dta", clear
keep patid prodcode eventdate_num /*to reduce dataset size*/
joinby prodcode using "$Codelsdir\Prescription_AEDs_signed_off_DR.dta", _merge(mergevar) /*keeps matches only*/
save "$Datadir\Derived_data\CPRD\all_AED_prescriptions", replace


*Identify epilepsy or bipolar specific meds, which are equivalent to a diagnoses:
gen asm_indication="epilepsy" if epilepsy==1
replace asm_indication="bipolar" if bipolar==1
keep if epilepsy==1 | bipolar==1 
keep patid eventdate_num asm_indication 
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
save "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_meds.dta", replace


*Flag if patient has ever had medication for indication-specific meds, and keep earliest date
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear
gen psych_aed=1 if aed_class==22 | aed_clas==8 | aed_class==2
*valproate or lamotrigine or carbamazepine

gen neuropathicpain_aed=1 if aed_class==2 | aed_clas==6 | aed_class==14
*(carbamazepine, barbexaclone,  gabapentin, pregabalin)

gen migraine_aed=1 if aed_class==21 | aed_class==22

keep if psych==1 | neuropathicpain_aed==1 | migraine==1
rename eventdate_num first_Rx_date
keep patid first_Rx_date migraine neuro psych 
foreach var in psych neuro migraine {
	preserve
	keep if `var' ==1
bysort patid (first_Rx_date): keep if _n==1 /*keep earliest diagnosis*/
save "$Datadir\Derived_data\CPRD\ASM_specificflags_`var'_CPRD_meds.dta", replace
restore
}
********************************************************************************
*Prescription and Diagnosis same day
********************************************************************************

*Bipolar and Other psychiatric conditions
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear /*load in Rx*/
gen psych_aed=1 if aed_class==22 | aed_clas==8 | aed_class==2
*valproate or lamotrigine or carbamazepine
keep if psych_aed==1
keep patid eventdate_num psych_aed
duplicates drop
merge 1:m patid eventdate_num using   "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta", keep(match) /*merge in Dx*/
keep if asm_indication=="anxiety" | asm_indication=="oth_mood_affective_dis" ///
| asm_indication=="psychosis"
keep patid eventdate_num asm_indication
bysort patid asm_indication (eventdate): keep if _n==1 /*keeps first Dx*/
save "$Datadir\Derived_data\CPRD\Dx_Rx_psych_indications.dta", replace


*Neuropathic pain
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear /*load in Rx*/
gen neuropathicpain_aed=1 if aed_class==2 | aed_clas==6 | aed_class==14
*(carbamazepine, barbexaclone,  gabapentin, pregabalin)
keep if neuropathicpain_aed==1
keep patid eventdate_num neuropathicpain_aed
duplicates drop
merge 1:m patid eventdate_num using   "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta", keep(match) /*merge in Dx*/
keep if asm_indication=="neuropathicpain" | asm_indication=="fibromyalgia" 
keep patid eventdate_num asm_indication
bysort patid asm_indication (eventdate): keep if _n==1 /*keeps first Dx*/
save "$Datadir\Derived_data\CPRD\Dx_Rx_pain_indications.dta", replace


*Migrine prophylaxis
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear /*load in Rx*/
gen migraine_aed=1 if aed_class==21 | aed_class==22
*valproate and topiramate
keep if migraine_aed==1
keep patid eventdate_num migraine_aed
duplicates drop
merge 1:m patid eventdate_num using   "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta", keep(match) /*merge in Dx*/
keep if asm_indication=="migraine"
keep patid eventdate_num asm_indication
bysort patid asm_indication (eventdate): keep if _n==1 /*keeps first Dx*/
save "$Datadir\Derived_data\CPRD\Dx_Rx_migraine_indications.dta", replace

/*Essential tremors: none
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear /*load in Rx*/
gen essential_tremor_aed=1 if aed_class==15
*primidone
keep if essential_tremor_aed==1
keep patid eventdate_num essential_tremor_aed
duplicates drop
merge 1:m patid eventdate_num using   "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta", keep(match) /*merge in Dx*/
keep if asm_indication=="essential_tremor"
keep patid eventdate_num asm_indication
bysort patid asm_indication (eventdate): keep if _n==1 /*keeps first Dx*/
save "$Datadir\Derived_data\CPRD\Dx_Rx_essential_tremor_aed_indications.dta", replace
*/

/*Restless leg syndrome
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear /*load in Rx*/
gen restless_leg_aed=1 if aed_class==40
*cenobamate /*no cenobamate*/
keep if restless_leg_aed==1
keep patid eventdate_num restless_leg_aed
duplicates drop
merge 1:m patid eventdate_num using   "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta", keep(match) /*merge in Dx*/
keep if asm_indication=="migraine"
keep patid eventdate_num asm_indication
bysort patid asm_indication (eventdate): keep if _n==1 /*keeps first Dx*/
save "$Datadir\Derived_data\CPRD\Dx_Rx_rest_indications.dta", replace*/





********************************************************************************
*Co-prescriptions
********************************************************************************

use "$Codelsdir\Prescription_antidepressants_signed_off_DR", clear
gen presc=1
append using "$Codelsdir\Prescription_antipsychotics_signed_off_DR"
recode presc .=2
append using "$Codelsdir\Prescription_lithium_sign_off_DR"
recode presc .=3
append using "$Codelsdir\Prescription_clobazam_signed_off_DR"
recode presc .=4
append using "$Codelsdir\Prescription_diazepam_signed_off_DR"
recode presc .=5
append using "$Codelsdir\Prescription_quetiapine_signed_off_DR"
recode presc .=6
append using "$Codelsdir\Prescription_midazolam_signed_off_DR.dta"
recode presc .=7

lab define presc 1 antidepressants 2 antipsychotics 3 lithium ///
4 clobazam 5 diazepam 6 quetiapine 7  midazolam
keep prodcode presc
duplicates drop
save "$Codelsdir\Prescription_indications_all.dta", replace


*Flag if patient has ever had medication for specific meds, and keep earliest date
use"$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Therapy_Files.dta", clear
*drop women not in the preg register
joinby patid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids", _merge(mergevar) /*keeps matches only*/
keep patid prodcode eventdate_num /*to reduce dataset size*/
duplicates drop
drop if prodcode<22
drop if prodcode>82911
keep patid prodcode eventdate_num /*to reduce dataset size*/
joinby prodcode using "$Codelsdir\Prescription_indications_all.dta", _merge(mergevar) /*keeps matches only*/
drop mergevar
duplicates drop
save "$Datadir\Derived_data\CPRD\Prescription_indications_all.dta", replace



*******************************************************************************
**Co-prescribing: AED and another Rx on same day
*******************************************************************************
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear
keep patid eventdate_num 
duplicates drop
merge 1:m patid eventdate_num using  "$Datadir\Derived_data\CPRD\Prescription_indications_all.dta", keep(match)

*Epilepsy
gen asm_indication="epilepsy" if presc==4 /*Clobazam and an AED*/
replace asm_indication="epilepsy" if presc==5 /*Diazepam and an AED*/
replace asm_indication="epilepsy" if presc==7 /*Midazolamand and an AED*/
tab asm_indication
keep if asm_indication=="epilepsy"
save "$Datadir\Derived_data\CPRD\Co_prescribing_epilepsy.dta", replace

*Bipolar and Other psychiatric conditions
use "$Datadir\Derived_data\CPRD\all_AED_prescriptions", clear
gen psych_aed=1 if aed_class==22 | aed_clas==8 | aed_class==2
*valproate or lamotrigine or carbamazepine
keep if psych_aed==1
keep patid eventdate_num psych_aed
duplicates drop
merge 1:m patid eventdate_num using  "$Datadir\Derived_data\CPRD\Prescription_indications_all.dta", keep(match)
gen asm_indication="bipolar" if presc==3 /*Lithium and an AED*/
replace asm_indication="bipolar" if presc==6 /*Quetiapine and an AED*/
replace asm_indication="other_psych" if presc==1 & asm_indication=="" /*Antidep and an AED*/
replace asm_indication="other_psych" if presc==2  & asm_indication==""  /*Antipsych and an AED*/
keep if asm_indication!=""
keep patid eventdate_num asm_indication
save "$Datadir\Derived_data\CPRD\Co_prescribing_bipolar.dta", replace



***
use "$Datadir\Derived_data\CPRD\Prescription_indications_all.dta", clear
keep if presc==1 | presc==2
gen asm_indication="other_psych"
save "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_Rx_APs_ADs.dta", replace

********************************************************************************
* 1.2.1 - HES  APC
********************************************************************************
use "$Codelsdir\ICDCode_epilespy_signed_off.dta", clear 
gen asm_indication="epilepsy"
foreach var in bipolar neuropathicpain fibromyalgia migraine mood_affective_disorders {
append using "$Codelsdir\ICDCode_`var'_signed_off.dta"
replace asm_indication="`var'" if asm_indication==""
}
gen altcode = subinstr(code, ".", "",.)
keep altcode code asm 
save "$Codelsdir\ICD_asm_indications_all_signed_off.dta", replace

use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear
rename icd code
joinby code using "$Codelsdir\ICD_asm_indications_all_signed_off.dta", _merge(mergevar)
rename epistart_num eventdate_num
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
keep patid eventdate_num asm
save "$Datadir\Derived_data\HES\ASM_indications_HES_APC_first_Dx.dta", replace

*Two seizures within 24 hours
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear
rename icd code
keep if d_order==1
joinby code using "$Codelsdir\ICDCode_epilepsy_incident_seizures_signed_off.dta", _merge(mergevar)
rename epistart_num eventdate_num
keep patid eventdate_num
duplicates drop

gen toassign = -1
gen group = 0
local g = 1
qui count if toassign

qui while r(N) > 0 {
    bysort patid (toassign eventdate_num) : replace group = `g' if (eventdate_num - eventdate_num[1]) <= 1 & toassign
      replace toassign = 0 if group == `g'
      local ++g
      count if toassign
}
bysort patid group: gen bign=_N
keep if bign>1
gen asm_indication="epilepsy"
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
save "$Datadir\Derived_data\HES\ASM_indications_HES_APC_seizure.dta", replace


********************************************************************************
* 1.2.2 - HES  OP
********************************************************************************
*Epilepsy diagnoses from HES outpatients
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(3) nogen
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
drop oper* apptdate eth
gen asm_indication_temp=""

foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' altcode
	merge m:1 altcode using "$Codelsdir\ICD_asm_indications_all_signed_off.dta"
	rename _merge _merge_diag_`val'
	replace asm_indication_temp="epilepsy" if _merge_diag_`val'==3 & asm_indication=="epilepsy"
	rename altcode diag_`val'
}
keep if asm_indication_temp=="epilepsy"
drop asm_indication
rename asm_indication_temp asm_indication
keep patid apptdate_num asm_indication
rename apptdate_num eventdate_num
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
save "$Datadir\Derived_data\HES\ASM_indications_HES_OP_epilepsy.dta", replace

********************************************************************************
* 1.2.3 - HES  A and E - seizures
********************************************************************************
*Lift all events relating to seizures from HES A&E attendances
use "$Rawdatdir\stata\data_linked\20_000228_hesae_diagnosis.dta", clear
gen asm_indication=""

	* merge on ICD 10 diagnoses in HES A&E
rename diag code
merge m:1 code using "$Codelsdir\ICDCode_epilepsy_incident_seizures_signed_off.dta", keep(1 3) 
rename code diag
replace asm_indication="epilepsy" if _merge == 3 
drop _merge 

	* merge on Read code diagnoses in HES A&E
rename diag readcode
merge m:1 readcode using "$Codelsdir\READ_epilepsy_incident_seizures_signed_off.dta", keep(1 3) // no readcodes in HES A&E for seizures
rename readcode diag
replace asm_indication="epilepsy" if _merge == 3 
drop _merge 
	
* identify A&E diagnosis codes for epilepsy events 
replace asm_indication="epilepsy" if diag3 == "241" & diagscheme == 1

keep if asm_indication=="epilepsy"
keep patid aekey asm_indication
duplicates drop
merge 1:1 patid aekey using "$Rawdatdir\stata\data_linked\20_000228_hesae_attendance", keep(match) nogen
rename arrivaldate_num eventdate_num

gen toassign = -1
gen group = 0
local g = 1
qui count if toassign

qui while r(N) > 0 {
    bysort patid (toassign eventdate_num) : replace group = `g' if (eventdate_num - eventdate_num[1]) <= 1 & toassign
      replace toassign = 0 if group == `g'
      local ++g
      count if toassign
}
bysort patid group: gen bign=_N
keep if bign>1
keep patid asm_indication eventdate_num
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis*/
save "$Datadir\Derived_data\HES\ASM_indications_HES_AnE_seizure.dta", replace



********************************************************************************
*2) COMBINE DATA FROM ALL SOURCES
********************************************************************************

* join lists together
use "$Datadir\Derived_data\HES\ASM_indications_HES_APC_first_Dx.dta", clear
*drop if asm_indication=="fibromyalgia" | asm_indication=="migraine" | asm_indication=="neuropathicpain" /*no longer using HES to define these indications*/
append using "$Datadir\Derived_data\HES\ASM_indications_HES_APC_seizure.dta"
gen source=1
tab asm_indication, miss

append using "$Datadir\Derived_data\HES\ASM_indications_HES_OP_epilepsy.dta"
replace source=2 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\HES\ASM_indications_HES_AnE_seizure.dta"
replace source=3 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_seizure.dta"
replace source=4 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_meds.dta" /*for epilepsy and bipolar*/
replace source=4 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\CPRD\Co_prescribing_bipolar.dta"
replace source=4 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\CPRD\Co_prescribing_epilepsy.dta"
replace source=4 if source==.
tab asm_indication, miss

append using  "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_first_Dx.dta"
*append using  "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_first_Dx_bipolar_epilepsy.dta"
replace source=4 if source==.
tab asm_indication, miss
*only first Dx codes only for epilepsy and bipolar are sufficient for evidence of indication

append using "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_Rx_APs_ADs.dta"
replace source=4 if source==.
tab asm_indication, miss


/*append using "$Datadir\Derived_data\CPRD\Dx_Rx_migraine_indications"
replace source=4 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\CPRD\Dx_Rx_pain_indications"
replace source=4 if source==.
tab asm_indication, miss

append using "$Datadir\Derived_data\CPRD\Dx_Rx_psych_indications"
replace source=4 if source==.
tab asm_indication, miss
*/


lab define source 1 HES_APC 2 HES_OP 3 HES_AnE 4 CPRD
lab val source source

keep patid asm_indication eventdate_num source
bysort patid asm_indication (eventdate_num): keep if _n==1 /*keep earliest diagnosis in each ASM indication*/
duplicates drop
sort patid eventdate_num

save "$Datadir\Derived_data\CPRD\all_indications_ever", replace

********************************************************************************
*3) merge in the pregnancy data 
********************************************************************************
use "$Datadir\Derived_data\CPRD\all_indications_ever", clear

joinby patid using "$Projectdir\rawdatafiles\stata\data_linked\20_000228_pregnancy_register.dta", _merge(mergevar) 

keep patid pregid asm_indication eventdate_num source pregend_num pregstart_num

* create variables to identify indication vs pregnany dates
	*a: gen date_ind_preg_start = date_preg_start - date_ind
	gen days_ind_pregstart = eventdate_num - pregstart_num
	label var days_ind_pregstart "Date of indication minus date of pregnancy start"
	
	*b: gen date_ind_preg_end = date_preg_end - date_ind
	gen days_ind_pregend = eventdate_num - pregend_num
	label var days_ind_pregend "Date of indication minus date of pregnancy end"

	*c: indicator for timing of indication
	gen ind_timing_flag = 1 if days_ind_pregstart <0
	replace ind_timing_flag = 2 if days_ind_pregend <0 & days_ind_pregstart >0
	replace ind_timing_flag = 3 if days_ind_pregend >0
	label def timing 1 "Indication before start of pregnancy" 2 "Indication during pregnancy" 3"Indication after end of pregnancy"
	label val ind_timing_flag timing
	label var ind_timing_flag "Timing of indication compared to pregnancy"
tab ind_timing_flag

keep if ind_timing_flag==1 /*keep those before preg*/

 

********************************************************************************
*4) Deal with multiple indications
********************************************************************************
bysort patid pregid: gen bign=_N
tab bign

*Make combinations of indication

*concatinate
/*drop days* source eventdate_num 
bysort patid pregid (asm_indication): gen littlen=_n
reshape wide asm_indication, i(pregid) j(littlen)
 egen ind_comb=concat(asm_indication*), punct(" ")
tab ind_comb, sort freq
gen n=1
collapse (sum) n, by(ind_comb)
gsort -n*/

foreach var in epilepsy bipolar neuropathicpain fibromyalgia essential_tremor restless_leg ///
migraine anxiety oth_mood_affective_dis psychosis other_psych {
gen `var'=1 if asm_indication=="`var'"	
recode  `var' .=0
}

collapse (max) epilepsy bipolar neuropathicpain fibromyalgia essential_tremor restless_leg ///
migraine anxiety oth_mood_affective_dis psychosis other_psych, by(patid pregid)

keep patid pregid epilepsy bipolar neuropathicpain fibromyalgia essential_tremor ///
restless_leg migraine anxiety oth_mood_affective_dis psychosis other_psych 
export delimited using "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Analysis\datafiles\Derived_data\CPRD\indication_combinations.txt", replace
gen somatic_cond=1 if neuropathicpain==1 | fibromyalgia==1 | essential_tremor==1 | ///
restless_leg==1 | migraine==1
gen other_psych_gp=1 if anxiety==1 | oth_mood_affective_dis==1 | psychosis==1 | other_psych==1 

lab var somatic "Other somatic conditions"
lab var other_psych_gp "Other psychiatric conditions"
lab var epilepsy "Epilepsy"
lab var bipolar "Bipolar"

save "$Datadir\Derived_data\Indications\ASM_indications_pre_preg_final.dta", replace


/*Create numeric version
gen asm_ind_num=1 if asm_indication=="epilepsy"
replace asm_ind_num=2 if asm_indication=="bipolar" & asm_ind_num==.
replace asm_ind_num=3 if asm_indication=="neuropathicpain" & asm_ind_num==.
replace asm_ind_num=4 if asm_indication=="fibromyalgia" & asm_ind_num==.
replace asm_ind_num=5 if asm_indication=="essential_tremor" & asm_ind_num==.
replace asm_ind_num=6 if asm_indication=="restless_leg" & asm_ind_num==.
replace asm_ind_num=7 if asm_indication=="migraine" & asm_ind_num==.
replace asm_ind_num=8 if asm_indication=="anxiety" & asm_ind_num==.
replace asm_ind_num=9 if asm_indication=="oth_mood_affective_dis" & asm_ind_num==.
replace asm_ind_num=10 if asm_indication=="psychosis" & asm_ind_num==.
replace asm_ind_num=11 if asm_indication=="other_psych" & asm_ind_num==.

tab asm_ind_num, miss

lab var asm_ind_num "ASM indication pre-pregnancy"
label define asm_ind_num 1 epilepsy 2 bipolar 3 "neuropathicpain" ///
4 fibromyalgia 5 "Essential Tremor" 6 "Restless leg" 7 migraine  8 anxiety 9 "Other mood affective disorder" ///
 10 "Psychosis" 11 "Other psychiatric indication" 
lab val asm_ind_num asm_ind_num

**Keep those indications nearest to pregnancy start
*gsort patid pregid -days_ind_pregstart
*by patid pregid: keep if _n==1
*tab asm_ind_num


*Prioritise ASM indications
gsort patid pregid asm_ind_num
by patid pregid: keep if _n==1

keep patid pregid asm_ind_num

gen asm_ind_gp=asm_ind_num
recode asm_ind_gp 4/7=3 8/11=4
label define asm_ind_gp 1 Epilepsy 2 Bipolar 3 "Other somatic conditions" 4 "Other psychiatric indication"
 lab val asm_ind_gp asm_ind_gp
 tab asm_ind_gp, miss
 
 
*/ 

erase  "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_all_Dx.dta"
erase "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_first_Dx.dta"
erase "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_first_Dx_bipolar_epilepsy.dta"
erase "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_seizure.dta"
erase "$Datadir\Derived_data\CPRD\all_AED_prescriptions.dta"
erase "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_meds.dta"
foreach var in psych neuro migraine {
erase "$Datadir\Derived_data\CPRD\ASM_specificflags_`var'_CPRD_meds.dta"

}
erase "$Datadir\Derived_data\CPRD\Dx_Rx_pain_indications.dta"
erase "$Datadir\Derived_data\CPRD\Dx_Rx_psych_indications.dta"
erase "$Datadir\Derived_data\CPRD\Dx_Rx_migraine_indications.dta"
erase "$Datadir\Derived_data\CPRD\Prescription_indications_all.dta"
erase "$Datadir\Derived_data\CPRD\Co_prescribing_epilepsy.dta"
erase "$Datadir\Derived_data\CPRD\Co_prescribing_bipolar.dta"
erase "$Datadir\Derived_data\CPRD\ASM_indications_CPRD_Rx_APs_ADs.dta"
erase "$Codelsdir\ICD_asm_indications_all_signed_off.dta"
erase "$Datadir\Derived_data\HES\ASM_indications_HES_APC_seizure.dta"
erase "$Datadir\Derived_data\HES\ASM_indications_HES_OP_epilepsy.dta"
erase "$Datadir\Derived_data\HES\ASM_indications_HES_AnE_seizure.dta"
erase "$Datadir\Derived_data\CPRD\all_indications_ever.dta"