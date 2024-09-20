cap log close
log using "$Logdir\LOG_cr_Offspring_outcomes.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			31 January 2022
* Description: 		Derive offspring outcomes 
* Notes: 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************
* 1 - "$Datadir\Derived_data\Outcomes\childcohort_ASD" - Child cohort with indicator for ASD
* 2 - "$Datadir\Derived_data\Outcomes\childcohort_ASD" - Child cohort with indicator for ADHD
* 3 - "$Datadir\Derived_data\Outcomes\childcohort_ASD" - Child cohort with indicator for ID
* 4 - "$Datadir\Derived_data\Outcomes\Outcome_Cleft.dta" - Child cohort with indicator for cleft 
* 5 - "$Datadir\Derived_data\Outcomes\Outcome_Cleft.dta" - Child cohort with indicator for narcolepsy (used as exclusion criteria for ADHD analyses)

********************************************************************************
* Contents
********************************************************************************
* 1 - Derive offspring ASD outcomes
* 	1.1 - CPRD 
* 	1.2 - HES 
*	1.3 - Merge datasets 
* 2 - Derive offspring ADHD outcomes
* 	2.1 - CPRD 
* 	2.2 - HES 
* 	2.3 - Prescription information
* 	2.4 - Merge datasets 
* 3 - Derive offspring ID outcomes
* 	3.1 - CPRD 
* 	3.2 - HES 
* 	3.3 - Merge datasets 
* 4 - Derive offspring Cleft outcomes
* 	4.1 - CPRD 
* 	4.2 - HES 
* 	4.3 - Merge datasets 
* 5 - Derive offspring narcolepsy - used as an exclusion criteria 
* 	5.1 - CPRD 
* 	5.2 - HES 
*	5.3 - Merge datasets 
* Delete all temporary files
********************************************************************************
* 1 - Derive offspring ASD outcomes
********************************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta", clear
rename patid mumpatid 
keep mumpatid pregid pregend_num
merge 1:m mumpatid pregid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)
keep babypatid pregend_num
save "$Datadir\Derived_data\Cohorts\child_cohort_babyids_birthday.dta", replace 


	* 1.1 - CPRD
******************
*Lift all events relating to ASD from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
joinby medcode using "$Codelsdir\ReadCode_ASD_signed_off_DR.dta", _merge(mergevar) /*keeps matches only*/

gen Read_ASD = 1
label variable Read_ASD "Outcome: ASD identified in CPRD"
rename eventdate_num clinical_date_CPRD_ASD

rename patid babypatid 
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_babyids_birthday.dta", nogen keep(3)
drop if clinical_date <= pregend_num
rename babypatid patid

bysort patid (clinical_date): egen _seq = seq()

gsort + patid - clinical_date
by patid: egen cnt_ASDdiags_CPRD = seq()
label variable cnt_ASDdiags_CPRD "Number of ASD diagnoses in CPRD"

keep if _seq==1 // keeping first event only but have created count of total ASD diagnosis events
drop _seq

keep patid medcode clinical_date Read cnt 

* merge onto child cohort 
rename patid babypatid
merge m:1 babypatid using  "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(2 3)

keep mumpatid pregid babypatid clinical_date Read cnt 
order mumpatid pregid babypatid clinical_date Read cnt 

replace Read = 0 if Read == . 
replace cnt = 0 if cnt == . 

save "$Datadir\Derived_data\CPRD\_temp\Outcome_ASD_CPRD.dta", replace


******************
	* 1.2 - HES 
******************
* Lift all events relating to ASD from HES admitted patients
******************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)

	* merge on ASD codelist
count
rename icd code
merge m:1 code using "$Codelsdir\ICDCode_ASD_signed_off_DR.dta"
list code description if _merge ==2 // F84 not merged but subclassifications have been  
keep if _merge == 3 
drop _merge 
count

rename epistart_num clinical_date_HESAPC_ASD
rename code ASD_diag_HESAPC
keep mumpatid pregid babypatid clinical_date ASD_diag_HESAPC
sort mumpatid pregid babypatid clinical_date
gen ICD_ASD_HESAPC=1
label variable ICD_ASD "Outcome: ASD identified in HES APC"

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_ASDdiags_HESAPC = seq()
label variable cnt_ASDdiags_HESAPC "Number of ASD diagnoses in HES APC"

keep if _seq==1 // keeping first diagnosis only but have created count of total ASD diagnoses
drop _seq

compress
save "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES_APC.dta", replace



*Lift all events relating to ASD from HES outpatients
************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)
 
	* merge on ASD codelist
gen ICD_ASD_HESOP = .
label variable ICD_ASD_HESOP "Outcome: ASD identified in HES OP"
foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' alt_code
	merge m:1 alt_code using "$Codelsdir\ICDCode_ASD_signed_off_DR.dta"
	rename _merge _merge_diag_`val'
	replace ICD_ASD_HESOP = 1 if _merge_diag_`val'==3
	rename alt_code diag_`val'
}


keep if ICD_ASD_HESOP == 1
count

keep babypatid mumpatid pregid attendkey ICD_ASD 
order mumpatid babypatid pregid 
save "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES_OP_nodate.dta", replace
rename babypatid patid

count
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(1 3) nogen
rename apptdate_num clinical_date_HESOP_ASD
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
keep patid mumpatid pregid clinical_date_HESOP_ASD ICD_ASD_HESOP 
rename patid babypatid

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_ASDdiags_HESOP = seq()
label variable cnt_ASDdiags_HESOP "Number of ASD diagnoses in HES OP"

keep if _seq==1 // keeping first diagnosis only but have created count of total ASD diagnoses
drop _seq


compress
save "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES_OP.dta", replace




* merge all ICD ASD info onto livebirth cohort 
***************************************************
use "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", clear
keep mumpatid pregid babypatid
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES_APC.dta", nogen
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES_OP.dta", nogen

rename babypatid patid 
merge 1:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta"
keep if inlist(_merge, 1, 3)
gen linkage_eligible = 1 if _merge == 3 
replace linkage_eligible = 0 if _merge == 1 
drop _merge
keep mumpatid-cnt_ASDdiags_HESOP linkage_eligible
rename patid babypatid 

replace ICD_ASD_HESAPC = 0 if ICD_ASD_HESAPC == . 
replace ICD_ASD_HESOP = 0 if ICD_ASD_HESOP == . 

replace cnt_ASDdiags_HESAPC = 0 if cnt_ASDdiags_HESAPC == . 
replace cnt_ASDdiags_HESOP = 0 if cnt_ASDdiags_HESOP == . 

egen ICD_ASD_HES = rowmax(ICD_ASD_HESAPC ICD_ASD_HESOP)
label variable ICD_ASD_HES "Outcome: ASD identified in HES APC or OP"

gen cnt_ASDdiags_HES = cnt_ASDdiags_HESAPC + cnt_ASDdiags_HESOP
label variable cnt_ASDdiags_HES "Number of ASD diagnoses in HES APC and OP"

save "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES.dta", replace


* 1.3 - Merge datasets 
**********************
use "$Datadir\Derived_data\CPRD\_temp\Outcome_ASD_CPRD.dta", clear
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ASD_HES.dta", nogen

* generate single variable for outcome and counts
gen outcome_ASD = ICD_ASD_HES == 1 |  Read_ASD == 1
gen cnt_ASDdiags_CPRD_HES = cnt_ASDdiags_HES + cnt_ASDdiags_CPRD
egen date_ASD = rowmin(clinical_date_CPRD_ASD clinical_date_HESAPC_ASD clinical_date_HESOP_ASD)
format %td date_ASD 

label variable outcome_ASD "Outcome: ASD identified in CPRD or HES"
label variable cnt_ASDdiags_CPRD_HES "Number of ASD diagnoses in CPRD or HES"
label variable date_ASD "Date of ASD diagnosis in CPRD or HES"

save "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_ASD", replace


********************************************************************************
* 2 - Derive offspring ADHD outcomes 
********************************************************************************
	* 2.1 - CPRD
******************
*Lift all events relating to ADHD from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num 
merge m:1 medcode using "$Codelsdir\Read_ADHD_codelist_signed_off_DR.dta", nogen keep(3)

gen Read_ADHD = 1
label variable Read_ADHD "Outcome: ADHD identified in CPRD"
rename eventdate_num clinical_date_CPRD_ADHD

rename patid babypatid 
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_babyids_birthday.dta", nogen keep(3)
drop if clinical_date <= pregend_num
rename babypatid patid

bysort patid (clinical_date): egen _seq = seq()

gsort + patid - clinical_date
by patid: egen cnt_ADHDdiags_CPRD = seq()
label variable cnt_ADHDdiags_CPRD "Number of ADHD diagnoses in CPRD"

keep if _seq==1 // keeping first event only but have created count of total Cleft diagnosis events
drop _seq

keep patid medcode clinical_date Read cnt 

* merge onto child cohort 
rename patid babypatid
merge m:1 babypatid using  "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(2 3)

keep mumpatid pregid babypatid clinical_date Read cnt 
order mumpatid pregid babypatid clinical_date Read cnt 

replace Read = 0 if Read == . 
replace cnt = 0 if cnt == . 

save "$Datadir\Derived_data\CPRD\_temp\Outcome_ADHD_CPRD.dta", replace


******************
	* 2.2 - HES 
******************
* Lift all events relating to ADHD from HES admitted patients
******************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)

	* merge on ADHD codelist
count
rename icd code
merge m:1 code using "$Codelsdir\ICD_ADHD_codelist_signed_off_DR.dta"
list code description if _merge ==2 // F90 not merged but subclassifications have been  
keep if _merge == 3 
drop _merge 
count

rename epistart_num clinical_date_HESAPC_ADHD
rename code ADHD_diag_HESAPC
keep mumpatid pregid babypatid clinical_date ADHD_diag_HESAPC
sort mumpatid pregid babypatid clinical_date
gen ICD_ADHD_HESAPC=1
label variable ICD_ADHD "Outcome: ADHD identified in HES APC"

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_ADHDdiags_HESAPC = seq()
label variable cnt_ADHDdiags_HESAPC "Number of ADHD diagnoses in HES APC"

keep if _seq==1 // keeping first diagnosis only but have created count of total ADHD diagnoses
drop _seq

compress
save "$Datadir\Derived_data\HES\_temp\Outcome_ADHD_HES_APC.dta", replace



*Lift all events relating to ADHD from HES outpatients
************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)
 
	* merge on ADHD codelist
gen ICD_ADHD_HESOP = .
label variable ICD_ADHD_HESOP "Outcome: ADHD identified in HES OP"
foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' alt_code
	merge m:1 alt_code using "$Codelsdir\ICD_ADHD_codelist_signed_off_DR.dta"
	rename _merge _merge_diag_`val'
	replace ICD_ADHD_HESOP = 1 if _merge_diag_`val'==3
	rename alt_code diag_`val'
}


keep if ICD_ADHD_HESOP == 1
count

keep babypatid mumpatid pregid attendkey ICD_ADHD 
order mumpatid babypatid pregid 
rename babypatid patid

count
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(1 3) nogen
rename apptdate_num clinical_date_HESOP_ADHD
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
keep patid mumpatid pregid clinical_date_HESOP_ADHD ICD_ADHD_HESOP 
rename patid babypatid

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_ADHDdiags_HESOP = seq()
label variable cnt_ADHDdiags_HESOP "Number of ADHD diagnoses in HES OP"

keep if _seq==1 // keeping first diagnosis only but have created count of total ADHD diagnoses
drop _seq


compress
save "$Datadir\Derived_data\HES\_temp\Outcome_ADHD_HES_OP.dta", replace




* merge all ICD ADHD info onto livebirth cohort 
***************************************************
use "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", clear
keep mumpatid pregid babypatid
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ADHD_HES_APC.dta", nogen
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ADHD_HES_OP.dta", nogen

rename babypatid patid 
merge 1:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta"
keep if inlist(_merge, 1, 3)
gen linkage_eligible = 1 if _merge == 3 
replace linkage_eligible = 0 if _merge == 1 
drop _merge
keep mumpatid-cnt_ADHDdiags_HESOP linkage_eligible
rename patid babypatid 

replace ICD_ADHD_HESAPC = 0 if ICD_ADHD_HESAPC == . 
replace ICD_ADHD_HESOP = 0 if ICD_ADHD_HESOP == . 

replace cnt_ADHDdiags_HESAPC = 0 if cnt_ADHDdiags_HESAPC == . 
replace cnt_ADHDdiags_HESOP = 0 if cnt_ADHDdiags_HESOP == . 

egen ICD_ADHD_HES = rowmax(ICD_ADHD_HESAPC ICD_ADHD_HESOP)
label variable ICD_ADHD_HES "Outcome: ADHD identified in HES APC or OP"

gen cnt_ADHDdiags_HES = cnt_ADHDdiags_HESAPC + cnt_ADHDdiags_HESOP
label variable cnt_ADHDdiags_HES "Number of ADHD diagnoses in HES APC and OP"

save "$Datadir\Derived_data\HES\_temp\Outcome_ADHD_HES.dta", replace



***********************************
	* 2.3 - Prescription information
***********************************
use "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", clear
keep mumpatid pregid babypatid
rename babypatid patid 
merge 1:m patid using "$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Therapy_Files", keep(3) nogen

*Merge with prodcodes
merge m:1 prodcode using "$Codelsdir/Prescription_ADHDs_HF_signed_off_DR.dta"

*Keep if matched
keep if _merge==3
drop _merge
rename patid babypatid

rename eventdate_num clinical_date_Rx_ADHD
gen ADHD_Rx=1
label variable ADHD_Rx "Outcome: ADHD identified in prescriptions"

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_ADHDRx = seq()
label variable cnt_ADHDRx "Number of ADHD Rx"

keep if _seq==1 // keeping first diagnosis only but have created count of total ADHD diagnoses
drop _seq

keep mumpatid pregid babypatid clinical_date ADHD_Rx cnt_ADHDRx

save "$Datadir\Derived_data\CPRD\_temp\Child_ADHD_Rx.dta", replace




****************************
	* 2.4 - Merge datasets 
****************************
use "$Datadir\Derived_data\CPRD\_temp\Outcome_ADHD_CPRD.dta", clear
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ADHD_HES.dta", nogen
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\CPRD\_temp\Child_ADHD_Rx.dta", nogen

* generate single variable for outcome and counts
gen outcome_ADHD = ICD_ADHD_HES == 1 |  Read_ADHD == 1 | ADHD_Rx == 1
gen cnt_ADHDdiags_CPRD_HES = cnt_ADHDdiags_HES + cnt_ADHDdiags_CPRD + cnt_ADHDRx
egen date_ADHD = rowmin(clinical_date_CPRD_ADHD clinical_date_HESAPC_ADHD clinical_date_HESOP_ADHD clinical_date_Rx_ADHD)
format %td date_ADHD 

label variable outcome_ADHD "Outcome: ADHD identified in CPRD or HES"
label variable cnt_ADHDdiags_CPRD_HES "Number of ADHD diagnoses in CPRD, HES or Rx"
label variable date_ADHD "Date of ADHD diagnosis or med prescription in CPRD or HES"

save "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_ADHD", replace





********************************************************************************
* 3 - Derive offspring ID outcomes 
********************************************************************************
	* 3.1 - CPRD
******************
*Lift all events relating to ID from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
joinby medcode using "$Codelsdir\ReadCode_ID_signed_off_DR.dta", _merge(mergevar) /*keeps matches only*/

gen Read_ID = 1
label variable Read_ID "Outcome: ID identified in CPRD"
rename eventdate_num clinical_date_CPRD_ID

rename patid babypatid 
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_babyids_birthday.dta", nogen keep(3)
drop if clinical_date <= pregend_num
rename babypatid patid

bysort patid (clinical_date): egen _seq = seq()

gsort + patid - clinical_date
by patid: egen cnt_IDdiags_CPRD = seq()
label variable cnt_IDdiags_CPRD "Number of ID diagnoses in CPRD"

keep if _seq==1 // keeping first event only but have created count of total Cleft diagnosis events
drop _seq

keep patid medcode clinical_date Read cnt 

* merge onto child cohort 
rename patid babypatid
merge m:1 babypatid using  "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(2 3)

keep mumpatid pregid babypatid clinical_date Read cnt 
order mumpatid pregid babypatid clinical_date Read cnt 

replace Read = 0 if Read == . 
replace cnt = 0 if cnt == . 

save "$Datadir\Derived_data\CPRD\_temp\Outcome_ID_CPRD.dta", replace


******************
	* 3.2 - HES 
******************
* Lift all events relating to ID from HES admitted patients
******************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)

	* merge on ID codelist
count
rename icd code
merge m:1 code using "$Codelsdir\ICDCode_ID_signed_off_DR.dta"
list code description if _merge ==2 // F70-F79 not merged but most subclassifications have been - F73.0, F73.1, F73.8, F78.0 also not merged
keep if _merge == 3 
drop _merge 
count

rename epistart_num clinical_date_HESAPC_ID
rename code ID_diag_HESAPC
keep mumpatid pregid babypatid clinical_date ID_diag_HESAPC
sort mumpatid pregid babypatid clinical_date
gen ICD_ID_HESAPC=1
label variable ICD_ID "Outcome: ID identified in HES APC"

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_IDdiags_HESAPC = seq()
label variable cnt_IDdiags_HESAPC "Number of ID diagnoses in HES APC"

keep if _seq==1 // keeping first diagnosis only but have created count of total ID diagnoses
drop _seq

compress
save "$Datadir\Derived_data\HES\_temp\Outcome_ID_HES_APC.dta", replace



*Lift all events relating to ID from HES outpatients
************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)
 
	* merge on cleft codelist
gen ICD_ID_HESOP = .
label variable ICD_ID_HESOP "Outcome: ID identified in HES OP"
foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' alt_code
	merge m:1 alt_code using "$Codelsdir\ICDCode_ID_signed_off_DR.dta"
	rename _merge _merge_diag_`val'
	replace ICD_ID_HESOP = 1 if _merge_diag_`val'==3
	rename alt_code diag_`val'
}


keep if ICD_ID_HESOP == 1
count

keep babypatid mumpatid pregid attendkey ICD 
order mumpatid babypatid pregid 
rename babypatid patid
count
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(1 3) nogen
rename apptdate_num clinical_date_HESOP_ID
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
keep patid mumpatid pregid clinical_date_HESOP ICD 
rename patid babypatid

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_IDdiags_HESOP = seq()
label variable cnt_IDdiags_HESOP "Number of ID diagnoses in HES OP"

keep if _seq==1 // keeping first diagnosis only but have created count of total ID diagnoses
drop _seq


compress
save "$Datadir\Derived_data\HES\_temp\Outcome_ID_HES_OP.dta", replace




* merge all ICD ASD info onto livebirth cohort 
***************************************************
use "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", clear
keep mumpatid pregid babypatid
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ID_HES_APC.dta", nogen
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ID_HES_OP.dta", nogen

rename babypatid patid 
merge 1:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta"
keep if inlist(_merge, 1, 3)
gen linkage_eligible = 1 if _merge == 3 
replace linkage_eligible = 0 if _merge == 1 
drop _merge
keep mumpatid-cnt_IDdiags_HESOP linkage_eligible
rename patid babypatid 

replace ICD_ID_HESAPC = 0 if ICD_ID_HESAPC == . 
replace ICD_ID_HESOP = 0 if ICD_ID_HESOP == . 

replace cnt_IDdiags_HESAPC = 0 if cnt_IDdiags_HESAPC == . 
replace cnt_IDdiags_HESOP = 0 if cnt_IDdiags_HESOP == . 

egen ICD_ID_HES = rowmax(ICD_ID_HESAPC ICD_ID_HESOP)
label variable ICD_ID_HES "Outcome: ID identified in HES APC or OP"

gen cnt_IDdiags_HES = cnt_IDdiags_HESAPC + cnt_IDdiags_HESOP
label variable cnt_IDdiags_HES "Number of ID diagnoses in HES APC and OP"

save "$Datadir\Derived_data\HES\_temp\Outcome_ID_HES.dta", replace

*************************
	* 3.3 - Merge datasets 
*************************
use "$Datadir\Derived_data\CPRD\_temp\Outcome_ID_CPRD.dta", clear
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_ID_HES.dta", nogen

* generate single variable for outcome and counts
gen outcome_ID = ICD_ID_HES == 1 |  Read_ID == 1
gen cnt_IDdiags_CPRD_HES = cnt_IDdiags_HES + cnt_IDdiags_CPRD
egen date_ID = rowmin(clinical_date_CPRD_ID clinical_date_HESAPC_ID clinical_date_HESOP_ID)
format %td date_ID 

label variable outcome_ID "Outcome: ID identified in CPRD or HES"
label variable cnt_IDdiags_CPRD_HES "Number of ID diagnoses in CPRD or HES"
label variable date_ID "Date of ID diagnosis in CPRD or HES"

save "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_ID", replace



********************************************************************************
* 4 - Derive offspring Cleft outcomes 
********************************************************************************
	* 4.1 - CPRD
******************
*Lift all events relating to cleft from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
joinby medcode using "$Codelsdir\ReadCode_Cleft_signed_off_AD.dta", _merge(mergevar) /*keeps matches only*/

gen Read_cleft = 1
label variable Read_cleft "Outcome: Cleft identified in CPRD"

rename eventdate_num clinical_date_CPRD

bysort patid (clinical_date): egen _seq = seq()

gsort + patid - clinical_date
by patid: egen cnt_Cleftdiags_CPRD = seq()
label variable cnt_Cleftdiags_CPRD "Number of Cleft diagnoses in CPRD"

by patid: egen cleft_lip_CPRD 				= max(cleft_lip)
by patid: egen cleft_palate_CPRD 			= max(cleft_palate)
by patid: egen cleft_lip_and_palate_CPRD 	= max(cleft_lip_and_palate)
by patid: egen bifid_uvula_CPRD 			= max(bifid_uvula)
label variable cleft_lip_CPRD 				"Outcome: Cleft lip identified in CPRD"
label variable cleft_palate_CPRD  			"Outcome: Cleft palate identified in CPRD"
label variable cleft_lip_and_palate_CPRD 	"Outcome: Cleft lip and palate identified in CPRD"
label variable bifid_uvula_CPRD  			"Outcome: Bifid uvula identified in CPRD"

keep if _seq==1 // keeping first event only but have created count of total Cleft diagnosis events
drop _seq

keep patid medcode clinical_date Read_cleft cnt_Cleftdiags_CPRD cleft_lip_CPRD cleft_palate_CPRD cleft_lip_and_palate_CPRD bifid_uvula_CPRD

* merge onto child cohort 
rename patid babypatid
merge m:1 babypatid using  "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(2 3)

keep mumpatid pregid babypatid Read_cleft cnt_Cleftdiags_CPRD cleft_lip_CPRD cleft_palate_CPRD cleft_lip_and_palate_CPRD bifid_uvula_CPRD
order mumpatid pregid babypatid Read_cleft cnt_Cleftdiags_CPRD cleft_lip_CPRD cleft_palate_CPRD cleft_lip_and_palate_CPRD bifid_uvula_CPRD

replace Read_cleft = 0 if Read_cleft == . 
replace cleft_lip_CPRD 				= 0 if cleft_lip_CPRD == . 
replace cleft_palate_CPRD  			= 0 if cleft_palate_CPRD == . 
replace cleft_lip_and_palate_CPRD 	= 0 if cleft_lip_and_palate_CPRD == . 
replace bifid_uvula_CPRD  			= 0 if bifid_uvula_CPRD == . 

save "$Datadir\Derived_data\CPRD\_temp\Outcome_Cleft_CPRD.dta", replace



******************
	* 4.2 - HES 
******************
* Lift all events relating to Cleft from HES admitted patients
******************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)

	* merge on cleft codelist
count
rename icd code
merge m:1 code using "$Codelsdir\ICDCode_Cleft_signed_off_AD.dta"
list code description if _merge ==2 // C35, C36 and C37 not merged but subclassifications have been  
keep if _merge == 3 
drop _merge 
count

rename epistart_num clinical_date_HESAPC
rename code cleft_diag_HESAPC
keep mumpatid pregid babypatid clinical_date cleft_diag_HESAPC
sort mumpatid pregid babypatid clinical_date
gen ICD_cleft_HESAPC=1
label variable ICD_cleft "Outcome: Cleft identified in HES APC"

gen cleft_palate 			= 1 if substr(cleft_diag_HESAPC,1,3) == "Q35"
gen cleft_lip 				= 1 if substr(cleft_diag_HESAPC,1,3) == "Q36"
gen cleft_lip_and_palate 	= 1 if substr(cleft_diag_HESAPC,1,3) == "Q37"
gen cleft_bifid_uvula	 	= 1 if substr(cleft_diag_HESAPC,1,5) == "Q35.7"


sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_Cleftdiags_HESAPC = seq()
label variable cnt_Cleftdiags_HESAPC "Number of Cleft diagnoses in HES APC"

by babypatid: egen ICD_cleft_palate_HESAPC 			= max(cleft_palate)
by babypatid: egen ICD_cleft_lip_HESAPC 			= max(cleft_lip) 
by babypatid: egen ICD_cleft_lip_and_palate_HESAPC 	= max(cleft_lip_and_palate)
by babypatid: egen ICD_cleft_bifid_uvula_HESAPC 	= max(cleft_bifid_uvula)		
label variable ICD_cleft_palate_HESAPC 				"Outcome: Cleft palate identified in HES APC"
label variable ICD_cleft_lip_HESAPC				 	"Outcome: Cleft lip identified in HES APC"
label variable ICD_cleft_lip_and_palate_HESAPC 		"Outcome: Cleft lip and palate identified in HES APC"
label variable ICD_cleft_bifid_uvula_HESAPC		  	"Outcome: Bivid uvula identified in HES APC"

keep if _seq==1 // keeping first event only but have created count of total Cleft diagnosis events
drop _seq cleft_palate cleft_lip cleft_lip_and_palate cleft_bifid_uvula

compress
save "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES_APC.dta", replace



*Lift all events relating to Cleft from HES outpatients
************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)
 
	* merge on cleft codelist
gen ICD_cleft_HESOP = .
label variable ICD_cleft_HESOP "Outcome: Cleft identified in HES OP"
foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' alt_code
	merge m:1 alt_code using "$Codelsdir\ICDCode_Cleft_signed_off_AD.dta"
	rename _merge _merge_diag_`val'
	replace ICD_cleft_HESOP = 1 if _merge_diag_`val'==3
	rename alt_code diag_`val'
}

keep if ICD_cleft_HESOP == 1
count

* identify first cleft diagnosis for an episode
gen first_cleft_diag_HESOP = ""
gen first_cleft_diag_posit = ""
foreach val in  "12" "11" "10" "09" "08" "07" "06" "05" "04" "03" "02" "01" {
	replace first_cleft_diag_HESOP = diag_`val' if _merge_diag_`val' == 3
	replace first_cleft_diag_posit = "`val'" if _merge_diag_`val' == 3
}
gen second_cleft_diag_HESOP = ""
foreach val in  "12" "11" "10" "09" "08" "07" "06" "05" "04" "03" "02" "01" {
	replace second_cleft_diag_HESOP = diag_`val' if _merge_diag_`val' == 3 & first_cleft_diag_posit !=  "`val'" 
}


* identify cleft lip, palate and cleft lip and palate diagnosis for an episode
gen _ICD_cleft_palate_HESOP 		= .
gen _ICD_cleft_lip_HESOP  			= .
gen _ICD_cleft_lip_and_palate_HESOP = .
gen _ICD_cleft_bifid_uvula_HESOP	 = . 

foreach val in  "12" "11" "10" "09" "08" "07" "06" "05" "04" "03" "02" "01" {
	replace _ICD_cleft_palate_HESOP 			= 1 if substr(diag_`val', 1,3) == "Q35"
	replace _ICD_cleft_lip_HESOP  			= 1 if substr(diag_`val', 1,3) == "Q36"
	replace _ICD_cleft_lip_and_palate_HESOP  = 1 if substr(diag_`val', 1,3) == "Q37"
	replace _ICD_cleft_bifid_uvula_HESOP  = 1 if substr(diag_`val', 1,4) == "Q357"	
}


keep babypatid mumpatid pregid attendkey ICD_cleft first* second* _ICD_cleft* 
order mumpatid babypatid pregid 
label variable first_cleft_diag_HESOP "First diagnosis of cleft within HES OP episode"
label variable first_cleft_diag_posit "Position of first cleft diagnosis within HES OP episode"
label variable second_cleft_diag_HESOP "Second diagnosis of cleft within HES OP episode"


save "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES_OP_nodate.dta", replace
rename babypatid patid

count
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(1 3) nogen
rename apptdate_num clinical_date_HESOP
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
keep patid mumpatid pregid clinical_date ICD_cleft first* second* _ICD_cleft* 
rename patid babypatid

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_Cleftdiags_HESOP = seq()
label variable cnt_Cleftdiags_HESOP "Number of Cleft diagnoses in HES OP"

by babypatid: egen ICD_cleft_palate_HESOP 			= max(_ICD_cleft_palate_HESOP)
by babypatid: egen ICD_cleft_lip_HESOP 				= max(_ICD_cleft_lip_HESOP)
by babypatid: egen ICD_cleft_lip_and_palate_HESOP 	= max(_ICD_cleft_lip_and_palate_HESOP)
by babypatid: egen ICD_cleft_bifid_uvula_HESOP 		= max(_ICD_cleft_bifid_uvula_HESOP)
label variable ICD_cleft_palate_HESOP "Outcome: Cleft palate identified in HES OP"
label variable ICD_cleft_lip_HESOP "Outcome: Cleft lip identified in HES OP"
label variable ICD_cleft_lip_and_palate_HESOP "Outcome: Cleft lip and palate identified in HES OP"
label variable ICD_cleft_bifid_uvula_HESOP "Outcome: Bifid uvula identified in HES OP"



keep if _seq==1 // keeping first diagnosis only but have created count of total Cleft diagnosis events
drop _*


compress
save "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES_OP.dta", replace




* merge all ICD cleft info onto livebirth cohort 
***************************************************
use "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", clear
keep mumpatid pregid babypatid
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES_APC.dta", nogen
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES_OP.dta", nogen

rename babypatid patid 
merge 1:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta"
keep if inlist(_merge, 1, 3)
gen linkage_eligible = 1 if _merge == 3 
replace linkage_eligible = 0 if _merge == 1 
drop _merge
keep mumpatid-ICD_cleft_bifid_uvula_HESOP linkage_eligible
rename patid babypatid 

egen ICD_cleft_HES = rowmax(ICD_cleft_HESAPC ICD_cleft_HESOP)
replace ICD_cleft_HES = 0 if ICD_cleft_HES == . 
label variable ICD_cleft_HES "Outcome: Cleft identified in HES APC or OP"

egen ICD_cleft_lip_HES = rowmax(ICD_cleft_lip_HESAPC ICD_cleft_lip_HESOP)
replace ICD_cleft_lip_HES = 0 if ICD_cleft_lip_HES == . 
label variable ICD_cleft_lip_HES "Outcome: Cleft lip identified in HES APC or OP"

egen ICD_cleft_palate_HES = rowmax(ICD_cleft_palate_HESAPC ICD_cleft_palate_HESOP)
replace ICD_cleft_palate_HES = 0 if ICD_cleft_palate_HES == . 
label variable ICD_cleft_palate_HES "Outcome: Cleft palate identified in HES APC or OP"

egen ICD_cleft_lip_and_palate_HES = rowmax(ICD_cleft_lip_and_palate_HESAPC ICD_cleft_lip_and_palate_HESOP)
replace ICD_cleft_lip_and_palate_HES = 0 if ICD_cleft_lip_and_palate_HES == . 
label variable ICD_cleft_lip_and_palate_HES "Outcome: Cleft lip and palate identified in HES APC or OP"

egen ICD_cleft_bifid_uvula_HES = rowmax(ICD_cleft_bifid_uvula_HESAPC ICD_cleft_bifid_uvula_HESOP)
replace ICD_cleft_bifid_uvula_HES = 0 if ICD_cleft_bifid_uvula_HES == . 
label variable ICD_cleft_bifid_uvula_HES "Outcome: Bifid uvula identified in HES APC or OP"


save "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES.dta", replace


*******************************
	* 4.3 - Merge datasets 
*******************************
use "$Datadir\Derived_data\CPRD\_temp\Outcome_Cleft_CPRD.dta", clear
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_Cleft_HES.dta", nogen

* generate single variable for outcome and counts
gen outcome_cleft = ICD_cleft_HES == 1 |  Read_cleft == 1
egen cnt_Cleftdiags_CPRD_HES = rowtotal(cnt_Cleftdiags_HESAPC cnt_Cleftdiags_HESOP cnt_Cleftdiags_CPRD)
gen outcome_cleft_lip 				= ICD_cleft_lip_HES == 1 |  cleft_lip_CPRD == 1
gen outcome_cleft_palate 			= ICD_cleft_palate_HES == 1 |  cleft_palate_CPRD == 1
gen outcome_cleft_lip_and_palate	= ICD_cleft_lip_and_palate_HES == 1 |  cleft_lip_and_palate_CPRD == 1
gen outcome_bifid_uvula 			= ICD_cleft_bifid_uvula_HES == 1 | bifid_uvula_CPRD == 1

label variable outcome_cleft 					"Outcome: Cleft identified in CPRD or HES"
label variable cnt_Cleftdiags_CPRD_HES 			"Number of Cleft diagnoses in CPRD or HES"
label variable outcome_cleft_lip 				"Outcome: Cleft lip identified in CPRD or HES"
label variable outcome_cleft_palate 			"Outcome: Cleft palate identified in CPRD or HES"
label variable outcome_cleft_lip_and_palate 	"Outcome: Cleft lip and palate identified in CPRD or HES"
label variable outcome_bifid_uvula			 	"Outcome: Bifid uvula identified in CPRD or HES"

save "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_Cleft", replace

********************************************************************************
* 5 - Derive offspring Narcolepsy outcomes
********************************************************************************
	* 5.1 - CPRD
******************
*Lift all events relating to Narcolepsy from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
joinby medcode using "$Codelsdir\ReadCode_narcolepsy_signed_off_DR.dta", _merge(mergevar) /*keeps matches only*/

gen Read_Narc = 1
label variable Read_Narc "Outcome: Narcolepsy identified in CPRD"

rename eventdate_num clinical_date_CPRD

bysort patid (clinical_date): egen _seq = seq()

gsort + patid - clinical_date
by patid: egen cnt_Narcdiags_CPRD = seq()
label variable cnt_Narcdiags_CPRD "Number of Narcolepsy diagnoses in CPRD"

keep if _seq==1 // keeping first event only but have created count of total narcolespy diagnosis events
drop _seq

keep patid medcode clinical_date Read cnt 

* merge onto child cohort 
rename patid babypatid
merge m:1 babypatid using  "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(2 3)

keep mumpatid pregid babypatid Read cnt 
order mumpatid pregid babypatid Read cnt 

replace Read = 0 if Read == . 
replace cnt = 0 if cnt == . 

save "$Datadir\Derived_data\CPRD\_temp\Outcome_Narc_CPRD.dta", replace


******************
	* 5.2 - HES 
******************
* Lift all events relating to Narcolepsy from HES admitted patients
******************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)

	* merge on Narcolepsy codelist
count
rename icd code
merge m:1 code using "$Codelsdir\ICDCode_narcolepsy_signed_off_DR.dta"
list code description if _merge ==2 // F84 not merged but subclassifications have been  
keep if _merge == 3 
drop _merge 
count

rename epistart_num clinical_date_HESAPC_Narc
rename code Narc_diag_HESAPC
keep mumpatid pregid babypatid clinical_date Narc_diag_HESAPC
sort mumpatid pregid babypatid clinical_date
gen ICD_Narc_HESAPC=1
label variable ICD_Narc "Outcome: Narcolepsy identified in HES APC"

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_Narcdiags_HESAPC = seq()
label variable cnt_Narcdiags_HESAPC "Number of Narcolepsy diagnoses in HES APC"

keep if _seq==1 // keeping first diagnosis only but have created count of total Narcolepsy diagnoses
drop _seq

compress
save "$Datadir\Derived_data\HES\_temp\Outcome_Narc_HES_APC.dta", replace



*Lift all events relating to Narcolepsy from HES outpatients
************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear

	* Merge on child cohort 
rename patid babypatid
merge m:1 babypatid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", nogen keep(3)
 
	* merge on Narcolepsy codelist
gen ICD_Narc_HESOP = .
label variable ICD_Narc_HESOP "Outcome: Narcolepsy identified in HES OP"
foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' alt_code
	merge m:1 alt_code using "$Codelsdir\ICDCode_narcolepsy_signed_off_DR.dta"
	rename _merge _merge_diag_`val'
	replace ICD_Narc_HESOP = 1 if _merge_diag_`val'==3
	rename alt_code diag_`val'
}


keep if ICD_Narc_HESOP == 1
count

keep babypatid mumpatid pregid attendkey ICD_Narc 
order mumpatid babypatid pregid 
rename babypatid patid

count
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(1 3) nogen
rename apptdate_num clinical_date_HESOP_Narc
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
keep patid mumpatid pregid clinical_date_HESOP_Narc ICD_Narc_HESOP 
rename patid babypatid

sort babypatid clinical_date
by babypatid: egen _seq = seq()

gsort + babypatid - clinical_date
by babypatid: egen cnt_Narcdiags_HESOP = seq()
label variable cnt_Narcdiags_HESOP "Number of Narcolepsy diagnoses in HES OP"

keep if _seq==1 // keeping first diagnosis only but have created count of total Narcolepsy diagnoses
drop _seq


compress
save "$Datadir\Derived_data\HES\_temp\Outcome_Narc_HES_OP.dta", replace




* merge all ICD Narcolepsy info onto livebirth cohort 
***************************************************
use "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", clear
keep mumpatid pregid babypatid
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_Narc_HES_APC.dta", nogen
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_Narc_HES_OP.dta", nogen

rename babypatid patid 
merge 1:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta"
keep if inlist(_merge, 1, 3)
gen linkage_eligible = 1 if _merge == 3 
replace linkage_eligible = 0 if _merge == 1 
drop _merge
keep mumpatid-cnt_Narcdiags_HESOP linkage_eligible
rename patid babypatid 

replace ICD_Narc_HESAPC = 0 if ICD_Narc_HESAPC == . 
replace ICD_Narc_HESOP = 0 if ICD_Narc_HESOP == . 

replace cnt_Narcdiags_HESAPC = 0 if cnt_Narcdiags_HESAPC == . 
replace cnt_Narcdiags_HESOP = 0 if cnt_Narcdiags_HESOP == . 

egen ICD_Narc_HES = rowmax(ICD_Narc_HESAPC ICD_Narc_HESOP)
label variable ICD_Narc_HES "Outcome: Narcolepsy identified in HES APC or OP"

gen cnt_Narcdiags_HES = cnt_Narcdiags_HESAPC + cnt_Narcdiags_HESOP
label variable cnt_Narcdiags_HES "Number of Narcolepsy diagnoses in HES APC and OP"

save "$Datadir\Derived_data\HES\_temp\Outcome_Narc_HES.dta", replace


* 5.3 - Merge datasets 
**********************
use "$Datadir\Derived_data\CPRD\_temp\Outcome_Narc_CPRD.dta", clear
merge 1:1 mumpatid pregid babypatid using "$Datadir\Derived_data\HES\_temp\Outcome_Narc_HES.dta", nogen

* generate single variable for outcome and counts
gen outcome_Narc = ICD_Narc_HES == 1 |  Read_Narc == 1
gen cnt_Narcdiags_CPRD_HES = cnt_Narcdiags_HES + cnt_Narcdiags_CPRD

label variable outcome_Narc "Outcome: Narcolepsy identified in CPRD or HES"
label variable cnt_Narcdiags_CPRD_HES "Number of Narcolepsy diagnoses in CPRD or HES"

save "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_Narc", replace




********************************************************************************
* Delete all temporary files
********************************************************************************
* capture erase 


********************************************************************************
log close
