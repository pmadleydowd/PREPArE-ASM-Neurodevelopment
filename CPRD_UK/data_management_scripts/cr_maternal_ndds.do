cap log close
log using "$Logdir\LOG_cr_maternal_ndds.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			07 August 2023
* Description: 		Derive maternal ndds to be used as a confounder
* Notes: 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************
* 1 - "$Datadir\Derived_data\..." - Pregnancy cohort with indicator for maternal NDD

********************************************************************************
* Contents
********************************************************************************
* 1 - Derive maternal ASD,ADHD and ID in CPRD
* 2 - Derive maternal ASD,ADHD and ID in HES
* 3 - Merge datasets 


********************************************************************************
* 1 - Derive maternal ASD,ADHD and ID in CPRD
********************************************************************************
*Lift all events relating to ASD from Clinical and referral Files
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/

* merge ASD
merge m:1 medcode using "$Codelsdir\ReadCode_ASD_signed_off_DR.dta", keepusing(medcode) 
gen ASD_CPRD = 1 if _merge == 3
drop _merge

* merge ADHD 
merge m:1 medcode using "$Codelsdir\Read_ADHD_codelist_signed_off_DR.dta", keepusing(medcode)
gen ADHD_CPRD = 1 if _merge == 3
drop _merge


* merge ID
merge m:1 medcode using "$Codelsdir\ReadCode_ID_signed_off_DR.dta", keepusing(medcode)
gen ID_CPRD = 1 if _merge == 3
drop _merge


* obtain first ASD, ADHD or ID diagnosis in cprd
keep if ASD_CPRD == 1 | ADHD_CPRD == 1 | ID_CPRD == 1 

rename eventdate_num clinical_date
bysort patid (clinical_date): egen _seq = seq()
keep if _seq==1 // keeping first event only 
drop _seq

rename clinical_date matNDD_Date_CPRD
keep patid matNDD_Date

* merge onto pregnancy cohort 
*rename patid mumpatid
merge 1:m patid using  "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta", nogen keep(2 3)

keep patid pregid babypatid matNDD_Date  
order patid pregid babypatid matNDD_Date  

save "$Datadir\Derived_data\CPRD\_temp\maternal_NDD_CPRD.dta", replace


********************************************************************************
* 2 - Derive maternal ASD,ADHD and ID in HES
********************************************************************************
* Create unique maternal id list
*******************************************************************
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta"
keep patid 
duplicates drop patid, force
save "$Datadir\Derived_data\CPRD\_temp\preg_cohort_unique_matid.dta", replace


* Lift all events relating to ASD from HES admitted patients
******************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hes_diagnosis_epi.dta", clear

	* Merge on maternal IDs from pregnancy cohort 
merge m:1 patid using "$Datadir\Derived_data\CPRD\_temp\preg_cohort_unique_matid.dta", nogen keep(3)

	* merge on ASD codelist
rename icd code
merge m:1 code using "$Codelsdir\ICDCode_ASD_signed_off_DR.dta"
list code description if _merge ==2 
gen ASD_HESAPC = 1 if _merge == 3 
drop _merge 


	* merge on ADHD codelist
merge m:1 code using "$Codelsdir\ICD_ADHD_codelist_signed_off_DR.dta"
list code description if _merge ==2 
gen ADHD_HESAPC = 1 if _merge == 3 
drop _merge 


	* merge on ID codelist
merge m:1 code using "$Codelsdir\ICDCode_ID_signed_off_DR.dta"
list code description if _merge ==2 
gen ID_HESAPC = 1 if _merge == 3 
drop _merge 


	* restrict dataset
keep if ASD == 1 | ADHD == 1 | ID == 1 

	* Keep first diagnosis from each mother
rename epistart_num clinical_date
sort patid clinical_date
by patid: egen _seq = seq()
keep if _seq==1 
drop _seq

rename clinical_date matNDD_Date_HESAPC
keep patid matNDD_Date

merge 1:m patid using  "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta", nogen keep(2 3)

keep patid pregid babypatid matNDD_Date  
order patid pregid babypatid matNDD_Date  

compress
save "$Datadir\Derived_data\HES\_temp\maternal_NDD_HESAPC.dta", replace



*Lift all events relating to ASD from HES outpatients
************************************************************
use "$Rawdatdir\stata\data_linked\20_000228_hesop_clinical.dta", clear

	* Merge on maternal IDs from pregnancy cohort 
merge m:1 patid using "$Datadir\Derived_data\CPRD\_temp\preg_cohort_unique_matid.dta", nogen keep(3)
 
	* merge on ASD codelist
gen ICD_NDD_HESOP = .
foreach val in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" {
	disp "diag = " `val'
	rename diag_`val' alt_code
	
	merge m:1 alt_code using "$Codelsdir\ICDCode_ASD_signed_off_DR.dta"
	rename _merge _merge_ASD_diag_`val'
	
	merge m:1 alt_code using "$Codelsdir\ICD_ADHD_codelist_signed_off_DR.dta"
	rename _merge _merge_ADHD_diag_`val'
	
	merge m:1 alt_code using "$Codelsdir\ICDCode_ID_signed_off_DR.dta"
	rename _merge _merge_ID_diag_`val'	
	
	replace ICD_NDD_HESOP = 1 if _merge_ASD_diag_`val'==3 | _merge_ADHD_diag_`val'==3 | _merge_ID_diag_`val'==3
	rename alt_code diag_`val'
}

keep if ICD_NDD_HESOP == 1
keep patid attendkey ICD_NDD 
save "$Datadir\Derived_data\HES\_temp\mat_NDD_HESOP_nodate.dta", replace


* merge onto appointment dates
merge 1:1 patid attendkey using "$Rawdatdir\stata\data_linked\20_000228_hesop_appointment.dta", keep(1 3) nogen
rename apptdate_num clinical_date
keep if inlist(attended, 5, 6) // keep only appointments where the patient was seen 
keep patid clinical_date ICD_NDD_HESOP 

sort patid clinical_date
by patid: egen _seq = seq()

keep if _seq==1 // keeping first diagnosis only but have created count of total ASD diagnoses
drop _seq

rename clinical_date matNDD_Date_HESOP
keep patid matNDD_Date

merge 1:m patid using  "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta", nogen keep(2 3)

keep patid pregid babypatid matNDD_Date  
order patid pregid babypatid matNDD_Date  


compress
save "$Datadir\Derived_data\HES\_temp\maternal_NDD_HESOP.dta", replace


********************************************************************************
* 3 - Merge datasets 
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\maternal_NDD_CPRD.dta", clear
merge 1:1 patid pregid babypatid using "$Datadir\Derived_data\HES\_temp\maternal_NDD_HESAPC.dta", nogen
merge 1:1 patid pregid babypatid using "$Datadir\Derived_data\HES\_temp\maternal_NDD_HESOP.dta", nogen


* generate new earliest date of NDD
egen earliest_NDDdat = rowmin(matNDD_Date_CPRD matNDD_Date_HESAPC matNDD_Date_HESOP)
format %td earliest_NDDdat


* merge on pregnancy information to compare to start of pregnancy
merge 1:1 patid pregid babypatid using  "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta", nogen 
gen maternal_NDD_prepreg     = 1 if earliest_NDDdat <   pregstart_num
replace maternal_NDD_prepreg = 0 if earliest_NDDdat >=  pregstart_num | missing(earliest_NDDdat) == 1
tab maternal_NDD_prepreg
keep patid pregid babypatid maternal_NDD_prepreg
sort patid pregid

save "$Datadir\Derived_data\Covariates\maternal_prepreg_NDD.dta", replace






********************************************************************************
* Delete all temporary files
********************************************************************************
* capture erase 


********************************************************************************
log close
