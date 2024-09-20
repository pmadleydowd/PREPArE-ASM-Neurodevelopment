cap log close
log using "$Logdir\LOG_cr_Select_eligible_participants.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			07 October 2021
* Description: 		Select all eligible participants
* Notes: 1 - Study population is identified using Pregnancy Register (July 2020) and Mother-Baby Link (August 2021) datasets. Data will be supplied as two separate cohorts in CPRD Gold based on the August 2021 CPRD snapshot. Cohorts 1 (mothers): Data will be provided for all women with a record of a pregnancy within the CPRD pregnancy register since the estimated start of pregnancy as defined in the CPRD pregnancy register (`pregstart' field) after 1st January 1995. Cohorts 2 (children): Within this population, we will define the sub-population of children from mothers having a liveborn child recorded in the mother baby link dataset.
* 		 2 - made use of files written by Hein Heuvelman to produce sections 2-4:
*			- 1_create pregnancy and mother cohorts/1_Using data from CPRD Gold/11b_Select eligible mothers and save study dataset_no restriction.do
*			- 2_create offspring cohort/1_Identify linked offspring via the pregnancy register and mother baby link datasets.do
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************
* 1 - "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta" - dataset of all mother IDs and pregnancy IDs included in the pregnancy cohort (n = 1,229,901)
* 2 - "$Datadir\Derived_data\Cohorts\pregnancy_cohort_follow_up_info.dta" - as above but with additional information on number of days since start of current registration to start of pregnancy and number of days from pregstart to earliest of lcd, tod or death
* 3 - "$Datadir\Derived_data\Cohorts\livebirth_cohort_matids_pregids_babyids.dta" - dataset of all mother, baby and pregnancy IDs for pregnancies in the livebirth cohort (n = 675,094) 
* 4 - "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta" - dataset of all mother, baby and pregnancy IDs for pregnancies in the child cohort with additional information for end of child follow up in Cohorts and a binary indicator for 4 year follow up (n = 499,067;  293,570   of which followed up for 4 years) 


********************************************************************************
* Contents
********************************************************************************
* 1 - Create Pregnancy cohort
* 2 - Create Livebirth cohort
* 3 - Create Child cohort

* Delete all temporary files
********************************************************************************
* 1 - Create Pregnancy cohort
********************************************************************************
/* pregnancy cohort definition
	A - a record of pregnancy within the CPRD pregnancy register since 01/01/1995
    B - Drop pregnancies with pregnancy start date 2019 onwards	
	C - acceptable patients
	D - Merge in linked HES data for pregnancies which have unknown outcome
	E - Merge in linked HES data for pregnancies which have unspecified loss outcomes
	F - registered for a minimum of 365 days with an up to standard (UTS) practice before the estimated start of pregnancy as defined in the CPRD pregnancy register (pregstart)
	G - registered throughout pregnancy til the end of pregnancy as defined in the pregnancy register (pregend)
	H - exclude records with pregnancies spaced less than 4 years apart. We do this to:
		 (a) minimise the liklihood of the outcome of the first episode affecting the treatment status of the second episode 
		 (b) minimise the liklihood of the outcomes of the first episode affected by the treatment status of the second episode (e.g. if women are again pregnant during follow-up for an earlier pregnancy this may influence their service use)
		 (c) to allow two years for the outcomes of a given pregnancy to occure, and another 2 years during which women may be trying to conceive (which may also influence their willingess to take antiseizure medication)
	I - exclude pregnancies with missing age data
	J - Drop pregnancies which start after patients follow-up ends
    K - Drop pregnancies with less than 9 months follow-up prior to last collection date
	L - Run algorithm to resolve conflicting pregnancy episodes (overlap in days between pregnancies among same mum)
	M - Run algorithm to exclude episodes which are likely to be derived from historical data 
	N - Drop remaining conflicts
*/


* save variables from pregnancy register that are neccesary for use in this section 
use "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", clear // 7,255,676 pregnancies in curent build of pregnancy register (01Jul2020)
order patid pregid babypatid pregstart_num pregend_num conflict outcome 
keep patid pregid babypatid pregstart_num pregend_num conflict outcome
save "$Datadir\Derived_data\CPRD\_temp\preg_reg_reduced", replace 

* Join patient data with list of maternal IDs and pregnancy register information	
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", clear
joinby patid using "$Datadir\Derived_data\CPRD\_temp\preg_reg_reduced"
count // 4,853,636 pregancies in pregnancy register who were obtained during initial cohort extraction (see .do file written by Ruta, available patients include all mothers with a pregnancy starting after 01/01/1995 and all mothers of babies in MBL born after 01/01/1995)


* A - pregnancy start since 01/01/1995 
********************************************************************************
keep if missing(pregstart_num)==0
keep if pregstart_num>date("01January1995", "DMY")  // 660,920 pregnancies started before 01/01/1995
count // 4,192,716 remaining

* B - Drop pregnancies with pregnancy start date 2019 onwards
********************************************************************************
gen pregyear=year(pregstart_num)
bysort pregyear: tab outcome 
drop if pregyear>=2019 // 60,674 pregnancies started from 2019 onwards

codebook patid
codebook pregid
graph hbar, over(outcome) yscale( range(0(10)100)) ylabel(0 (20) 100) blabel(bar, format(%4.1f) size(vsmall)) 
graph export "$Graphdir/descriptivepaper/Outcomes_step2.jpg", as(jpg) replace  width(10000)


* C - remove patients who are not acceptable
********************************************************************************
drop if accept == 0 // 54,660 not acceptable
count //  4,077,382 remaining



* D - Merge in linked HES data for pregnancies which have unknown outcome
********************************************************************************			
save  "$Datadir\Derived_data\CPRD\_temp\pregreg_hesoutcomesstep.dta", replace  // dataset used for merging HES outcomes together in cr_pregnancy_outcomes_HES.do

do "$Dodir\Data management\cr_pregnancy_outcomes_HES.do"
do "$Dodir\Data management\cr_distinguish_miscarraige_TOP_outcomes.do"
 

use "$Datadir\Derived_data\CPRD\_temp\pregreg_hesoutcomesstep.dta", clear
cap drop _m
tab outcome
tab conflict
merge 1:1 patid pregid using "$Datadir\Derived_data\Outcomes\Maternal_outcomes\hes_deliveries_final", update replace keep(1 3 4 5) keepusing(patid pregid outcome)
tab outcome
gen outcome_updated_flag = 0 if _merge == 1 
replace outcome_updated_flag = 1 if _merge == 5 

cap drop _m
merge 1:1 patid pregid using "$Datadir\Derived_data\Outcomes\Maternal_outcomes\hes_losses_final", update replace keep(1 3 4 5)
tab outcome
replace outcome_updated_flag = 2 if _merge == 5 

codebook patid
codebook pregid
graph hbar, over(outcome) yscale( range(0(10)100)) ylabel(0 (20) 100) blabel(bar, format(%4.1f) size(vsmall)) 
graph export "$Graphdir/descriptivepaper/Outcomes_step3.jpg", as(jpg) replace  width(10000)


label variable outcome_updated_flag "Pregnancy outcome updated"
label define lb_outcome_updated 0 "Outcome not updated" 1 "Updated using deliveries" 2 "Updated using losses" 3 "Updated unspecified losses"
label values outcome_updated_flag lb_outcome_updated
tab outcome_updated_flag

* E - Merge in linked HES data for pregnancies with unspecified loss outcomes
********************************************************************************			




cap drop _m
tab outcome
merge 1:1 patid pregid using "$Datadir\Derived_data\Outcomes\Maternal_outcomes\hes_losses_outcome_6_10_final", update replace keep(1 3 4 5)
tab outcome
replace outcome_updated_flag = 3 if _merge == 5 
tab outcome_updated_flag

codebook patid
codebook pregid
graph hbar, over(outcome) yscale( range(0(10)100)) ylabel(0 (20) 100) blabel(bar, format(%4.1f) size(vsmall)) 
graph export "$Graphdir/descriptivepaper/Outcomes_step4.jpg", as(jpg) replace  width(10000)



* F - registered 365 days before pregstart within UTS practice & 
* G - registered throughout pregnancy til preg end
********************************************************************************
* identify which mothers registered 365 days before pregstart within UTS practice
	* This implies 
		* 1 - The date of the current registration with the practice must have preceded the pregnancy start date minus 365 days 
		* 2 - The practice must have become of UTS quality before the estimated pregnancy start date 
		* 3 - Mothers should have left the practice no earlier than pregnancy end date 
cap drop _m
tostring patid, gen(patid_s) format(%12.0f)
gen pracid = substr(patid_s,-5,5)
destring pracid, replace
drop patid_s
joinby pracid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Practice_Files.dta", _merge(_merge) unmatched(master)
tab _merge
drop _merge
count //  4,077,382 remaining

sort pracid patid pregid
order pracid patid pregid pregstart_num crd_num tod_num uts_num
list pracid patid pregid pregstart_num crd_num tod_num uts_num in 1/20

gen pregstart_num_minus365 = pregstart_num - 365
gen pregstart_num_minus6months = pregstart_num - (365/2)

gen timefrom_preg_uts = uts_num - pregstart_num // negative number shows uts date before pregnancy start
gen timefrom_preg_crd = crd_num - pregstart_num //	negative number shows crd date before pregnancy start
hist timefrom_preg_uts
hist timefrom_preg_crd

count if uts_num>pregstart_num //  1,098,815 excluded for not achieving uts before preg start
count if crd_num>pregstart_num_minus365 // 2,098,057 excluded for current registration date less than 365 days before preg start
count if tod_num < pregend_num // 29,385 excluded for transfer out before pregnancy end date 


keep if crd_num <= pregstart_num_minus365 & uts_num <= pregstart_num // 2,543,562 observations deleted
drop if tod_num <= pregend_num // 14,501 observations deleted
 /// 2,558,063 pregnancies removed

/*lab define outcome 1 "Live birth" 2 "Stillbirth" 3 "Live birth or still birth" ///
4 "Miscarriage" 5 "TOP" 6 "Probable TOP" 7 "Ectopic" 8 "Molar" 9 "Blighted ovum" 10 "Unspecified loss" 11 "Delivery based on a third trimester pregnancy record" 12 "Delivery based on a late pregnancy record4"  13 "Outcome unknown"*/
lab val outcome outcome

graph hbar, over(outcome) yscale( range(0(10)100)) ylabel(0 (20) 100) blabel(bar, format(%4.1f) size(vsmall)) 
graph export "$Graphdir/descriptivepaper/Outcomes_before_cleaning1.jpg", as(jpg) replace  width(10000)


count // 1,519,319


* H - exclude records with pregnancies spaced less than 4 years apart
********************************************************************************
* Check with HF if this is something that we want to do - I dont think we should. Depression is more transient than epilepsy so the issues suggested here may not be relevant to our study
* HF: I agree - let's get agreement from PIs at next meeting.

* I - exclude pregnancies with missing age data
********************************************************************************
merge m:1 patid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", keep(3) nogen
drop if yob==1900 | yob==1899 // 11 pregnancies removed


* J - Drop pregnancies which start after patients follow-up ends
********************************************************************************
*Drop if pregnancy starts before patients end of follow-up
gen start_fup_CPRD=max(uts_num, crd_num)
format start_fup_CPRD %td

merge m:1 patid using "$Rawdatdir\stata\data_linked\20_000228_ONS_death_patient.dta", keep(1 3) nogen
gen deathdate_num = dod_num 
replace deathdate_num = date(deathdate, "DMY") if deathdate_num == . 
format  %d deathdate_num 
gen end_fup_CPRD=min(tod_num, lcd_num, deathdate_num)
format end_fup_CPRD %td

count if  pregstart_num >= tod_num // 0 
count if  pregstart_num >= lcd_num // 4 
count if  pregstart_num >= dod_num // 1 with pregnancy start after date of death from ONS data 
count if  pregstart_num >= date(deathdate, "DMY") // 120 with pregnancy start after date of death from CPRD data
* NOTE FOR HF should we update the date of death variable to just be ONS Date as there seems to be issues with the CPRD date
drop if pregstart_num>=end_fup_CPRD /* 124 pregnancies start after end of follow-up*/


codebook patid
codebook pregid
graph hbar, over(outcome) yscale( range(0(10)100)) ylabel(0 (20) 100) blabel(bar, format(%4.1f) size(vsmall)) 
graph export "$Graphdir/descriptivepaper/Outcomes_before_cleaning2.jpg", as(jpg) replace  width(10000)

count // 1,519,184


 
* K - Drop pregnancies with less than 9 months follow-up prior to last collection date
********************************************************************************
*require pregnancies to have 9 months follow-up before LCD 
tab outcome  if pregstart_num+273.9375>=lcd_num
drop if pregstart_num+273.9375>=lcd_num /*38,670 pregnancies start less than 9 months before last collection date */

codebook patid
codebook pregid
graph hbar, over(outcome) yscale(range(0(10)100)) ylabel(0 (20) 100) blabel(bar, format(%4.1f) size(vsmall)) 
graph export "$Graphdir/descriptivepaper/Outcomes_step1.jpg", as(jpg) replace  width(10000)

count // 1,480,514




* L - Run algorithm to resolve conflicting pregnancy episodes (overlap in days between pregnancies among same mum)
********************************************************************************
save "$Datadir\Derived_data\CPRD\_temp\pregreg_preconflictstep.dta" , replace  // dataset used for merging conflicts together in cr_pregreg_conflicts.do

preserve
keep if conflict==1
codebook patid
codebook pregid
graph hbar, over(outcome) yscale(range(0(10)100)) ylabel(0 (20) 100)
graph export "$Graphdir/descriptivepaper/Outcomes in conflicting pregs", as(jpg) replace  width(10000)
restore

*  Create list of all events showing evidence for a current pregnancy and antenatal scans (needed for conflicts and historical pregnancies algorithm)
use "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", clear
append using  "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta"
keep patid medcode eventdate_num /*to reduce dataset size*/
keep if eventdate_num > date("01January1994", "DMY")  /*to reduce dataset size*/

* create list of all events showing evidence for a current pregnancy 
preserve
merge m:1 medcode using "$Codelsdir\READ_currently_pregnant_codes_JCAMPBELL.dta", nogen keep(3)
save "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_currentlypregnantevents.dta", replace

* create list of all events showing evidence for an antenatal scan
restore
merge m:1 medcode using "$Codelsdir\READ_antenatal_scan_JCAMPBELL.dta", nogen keep(3)
save "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_antenatalscanevents.dta", replace


* call pregnancy conflicts algorithm
do "$Dodir\Data management\Uncertain_pregnancies\cr_pregreg_conflicts.do"
 
* load data from start of step  
use "$Datadir\Derived_data\CPRD\_temp\pregreg_preconflictstep.dta" , clear


* merge on data from conflicts algorithm and determine which pregnancies to keep
rename pregid p1_pregid 
merge 1:1 patid p1_pregid using "$Datadir\Derived_data\CPRD\pregconflicts_Scen4.dta", keepusing(patid p1_pregid Ev*) gen(_conflict1_p1)
rename Ev* p1_Ev*
rename p1_pregid p2_pregid 
merge 1:1 patid p2_pregid using "$Datadir\Derived_data\CPRD\pregconflicts_Scen4.dta", keepusing(patid p2_pregid Ev*)  gen(_conflict1_p2)
rename p2_pregid pregid 
rename Ev* p2_Ev*

* Notes from JC - For pairs consistent with 4a, 4B and 4c I would keep the first episode and drop the 2nd. 4d and 4e  I would consider merging the episodes. 4d is the biggest headache as these are essentially sporadic antenatal codes in the data being made into multiple episodes. I would suggest taking the start of pregnancy from the episode which has a startsource derived from the data. You could then treat this as a pregnancy with no outcome as above.

gen conflict_retain = 99 if conflict == 0
label variable conflict_retain ""
label define lb_conflict_retain -1 "Conflict to be dropped" 1 "Conflict retained in first step" 2 "Conflict retained in second step (historical pregnancies)" 99 "No conflict"
label values conflict_retain lb_conflict_retain
replace conflict_retain =  1 if _conflict1_p1 == 3 & (p1_EvScen_4a == 1 | p1_EvScen_4c == 1)  // records to be kept - 27,864
replace conflict_retain = -1 if _conflict1_p2 == 3 & (p2_EvScen_4a == 1 | p2_EvScen_4c == 1)  // records to be dropped - 27,864

count if p1_EvScen_4a == 1 // 27,669 pregnancies fitting scenario 4a
count if p1_EvScen_4c == 1 // 195 pregnancies fitting scenario 4c
count if p1_EvScen_4d == 1 // no pregnancies picked up using scenario 4d
tab conflict_retain, mis
* 27,864 pregnancies to be dropped, 
* 27,717 pregnancies retained using algorithm
count if (_conflict1_p1 == 3 & (p1_EvScen_4a == 1 | p1_EvScen_4c == 1))  & (_conflict1_p2 == 3 & (p2_EvScen_4a == 1 | p2_EvScen_4c == 1)) // 147 conflicts where the first pregnancy is also the second pregnancy of a second conflict (i.e. chain of conflicts) - keeping only the first pregnancy of the chain

drop if conflict_retain == -1 // 27,864 pregnancies dropped after conflict algorithm implemented


* M - Run algorithm to exclude episodes which are likely to be derived from historical data 
********************************************************************************
save "$Datadir\Derived_data\CPRD\_temp\pregreg_prehistoricalpregstep.dta" , replace  // dataset used for merging conflicts together in cr_pregreg_historical_episodes_exclude.do

do "$Dodir\Data management\Uncertain_pregnancies\cr_pregreg_historical_episodes_exclude.do"

use "$Datadir\Derived_data\CPRD\_temp\pregreg_prehistoricalpregstep.dta" , clear

* implement conflicts section of historical data uncertain pregnancies
rename pregid p1_pregid 
merge 1:1 patid p1_pregid using "$Datadir\Derived_data\CPRD\Hist_Conflict.dta", keepusing(patid p1_pregid Hist_Conflict*) gen(_conflict2_p1)  keep(1 3)
rename Hist_Conflict* p1_Hist_Conflict*
rename p1_pregid p2_pregid 
merge 1:1 patid p2_pregid using "$Datadir\Derived_data\CPRD\Hist_Conflict.dta", keepusing(patid p2_pregid Hist_Conflict*)  gen(_conflict2_p2)  keep(1 3)
rename p2_pregid pregid 
rename Hist_Conflict* p2_Hist_Conflict*

* drop first episode, retain second episode for conflicts 
tab conflict_retain, mis
replace conflict_retain =  2 if _conflict2_p2 == 3 & (p2_Hist_Conflict_1a == 1 | p2_Hist_Conflict_1b == 1) & conflict_retain == .   // records to be kept - 18,654 pregnancies
replace conflict_retain = -1 if _conflict2_p1 == 3 & (p1_Hist_Conflict_1a == 1 | p1_Hist_Conflict_1b == 1)  // records to be dropped - 19,716 pregnancies
tab conflict_retain, mis 
* 19,716 pregnancies to be dropped
* 18,207 pregnancies to be retained (difference of 447 from 18,654 above due to chain of conflicts - 2nd pregnancy in a pair is also the 1st pregnancy in another pair, keeping only the last pregnancy)

count if inlist(conflict_retain , 1, 2) // total number of conflicts retained -  45,765
 
count if (_conflict1_p1 == 3 & (p1_EvScen_4a == 1 | p1_EvScen_4c == 1)) & (_conflict2_p2 == 3 & (p2_Hist_Conflict_1a == 1 | p2_Hist_Conflict_1b == 1)) // number of conflicting pregnancies who were identified to be kept in both steps - 1,062
count if (_conflict1_p1 == 3 & (p1_EvScen_4a == 1 | p1_EvScen_4c == 1)) & (_conflict2_p1 == 3 & (p1_Hist_Conflict_1a == 1 | p1_Hist_Conflict_1b == 1)) // number of conflicting pregnancies identified to be kept in first step but removed in second step - 159
drop if conflict_retain == -1 // 19,716 dropped 


* implement unknown outcome section historical data uncertain pregnancies
* on advice of Jennifer Campbell (see email 29 March 2022) we are keeping the first pregnancy and dropping the second, retaining a note that the pregnancy end date (of the first pregnancy) is likley to be earlier than the pregend_num value states 
* Note that the algorithm groups outcome records of the same type (so outcome will be the same broadly between the two records) but does not differentiate between termination or miscarriage (so these two could be conflated)
rename pregid p1_pregid 
merge 1:1 patid p1_pregid using "$Datadir\Derived_data\CPRD\Hist_Misout.dta", keepusing(patid p1_pregid Hist_Misout) gen(_misout_p1) keep(1 3)
rename Hist_Misout p1_Hist_Misout
rename p1_pregid p2_pregid 
merge 1:1 patid p2_pregid using "$Datadir\Derived_data\CPRD\Hist_Misout.dta", keepusing(patid p2_pregid Hist_Misout)  gen(_misout_p2)  keep(1 3)
rename p2_pregid pregid 
rename Hist_Misout p2_Hist_Misout

drop if _misout_p2==3 // 162,921 pregnancies with unknown outcome dropped as evidence of a historical pregnancy 
gen ev_pregend_error_Histmisout = 1 if _misout_p1==3 //  142,050 pregnancies retained which may have pregnany end earlier than it should be
tab ev_pregend_error_Histmisout 
label variable ev_pregend_error_Histmisout "Evidence pregnancy end date influenced by historical pregnancy"



* N - Drop remaining conflicts and other issues (including pregnancies lasting less than a day)
********************************************************************************
tab conflict_retain conflict, mis
drop if conflict_retain == . // 79,172 remaining conflicting pregnancies dropped as not picked up in algorithm


* check for duplicate pregnancies where two pregnancy records (with different pregnancy ids) start on the same date for a mother 
duplicates report patid pregstart_num // duplicate pregnancies in register (with different pregnancy id) 
duplicates tag patid pregstart_num, gen(_check1)
tab _check1

* keep all those with a babypatid and then keep the latest pregnancy end date for remaining entries as this is likely the most up to date info
gsort + patid pregstart_num - babypatid pregend_num
egen _seq = seq(), by(patid pregstart_num)
drop if _seq >1 // 265 pregnancies removed for duplicate pregnancy start date
drop _seq _check1

* drop pregnancies where pregnancy start = pregnancy end 
drop if pregstart_num == pregend_num // 233 pregnancies dropped 



*Save dataset maternal ids included in pregnancy cohort
********************************************************************************			
preserve
	duplicates drop patid pregid, force // no duplicates
	rename outcome updated_outcome
	keep patid pregid conflict_retain updated_outcome outcome_updated_flag ev_pregend_error_Histmisout
	compress
	count //  1,190,343
	save "$Datadir\Derived_data\Cohorts\pregnancy_cohort_conflicts_outcome_update.dta", replace

	keep patid pregid 
	save "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", replace
restore


********************************************************************************
*Dataset for use in covariate derivation
********************************************************************************

preserve
*Create inidividual datasets with unique pat ids, and add on key covariate information
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_conflicts_outcome_update.dta", clear
merge 1:1 patid pregid using "$Projectdir\rawdatafiles\stata\data_linked\20_000228_pregnancy_register.dta", keep(match) nogen
merge m:1 patid using "$Projectdir\rawdatafiles\stata\data_linked\linkage_eligibility_gold21", keep(match master) keepusing(hes_e) nogen
gen linkage_hes=1 if hes_e==1
recode linkage_hes .=0
save "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", replace

*Create datasets containing unique patids combinations
*(occurs because there can be multiple pregnancies for one mum)
bysort patid: gen bign=_N /*unique patids*/
summ bign // 14 pregnancies 
local maxpreg = r(max) // automatically updates max number of pregnancies if these change, need to delete extra datasets so as to not cause errors if this hasnt been updated in later programs
sort patid pregstart
drop big

forvalues x=1/`maxpreg' {
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", clear
bysort patid (pregid): keep if _n==`x' /*unique patids*/
save "$Datadir\Derived_data\Cohorts/pregnancy_cohort_final_`x'", replace
}
restore

 
*Create variables to measure length of data history and follow-up
********************************************************************************
*Length of data history 
gen data_history =  crd_num - pregstart_num 
label variable data_history "number of days since start of current registration to start of pregnancy"

gen data_followup=.
replace data_followup = lcd_num - pregstart_num if tod_num==. & deathdate_num==.  
replace data_followup = tod_num - pregstart_num if tod_num!=. & tod_num<=deathdate_num 
replace data_followup = deathdate_num - pregstart_num if deathdate_num!=. & deathdate_num<=tod_num
label variable data_followup "number of days from pregstart to earliest of lcd, tod or death" // maximum value of lcd is 20Jul2021
summ lcd_num
disp string(22481, "%td")


* identify why individuals have a negative length of follow up
count if data_followup<0 // 
count if 22481 < pregstart_num // 0 born after max last collection date value
count if tod_num < pregstart_num // 0 born after transfer out date
count if deathdate_num < pregstart_num //  0 pregnancies where mother identified as dead before the start of pregnancy
list patid pregstart_num pregend_num deathdate_num lcd_num tod_num if data_followup <0

bysort pregyear: tab outcome 
br patid pregid pregstart_num pregend_num start_fup_CPRD end_fup_CPRD data_followup outcome if pregyear>=2020

sum pregstart_num
sum pregend_num

*Save data
keep patid pregid pracid data_followup data_history
compress
count //  1,190,343
save "$Datadir\Derived_data\Cohorts\pregnancy_cohort_follow_up_info.dta", replace

	
* check how many eligible for linkage to HES data 
********************************************************************************				
preserve
	merge m:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta"
	count if _merge == 3 // 587,321 eligible for linkage to HES
restore
		


********************************************************************************
* 2 - Create Livebirth cohort
********************************************************************************
/* Live birth cohort definition
This is a subset of the pregnancy cohort with eligibility dependent on having a liveborn child recorded in the data sources. Must be included in the CPRD mother baby link 	
*/  

* load pregnancy ids from pregnancy cohort
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear

* merge on pregnancy register to obtain additional information on pregnancies
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", nogen keep(3)
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_conflicts_outcome_update.dta", nogen keep(3) 
label values outcome updated_outcome lb_outcome
label define lb_outcome /*
	*/ 1 "live birth" /*
	*/ 2 "stillbirth" /*
	*/ 3 "live birth and stillbirth" /*
	*/ 4 "miscarriage" /*
	*/ 5 "termination of pregnancy" /*
	*/ 6 "probable termination of pregnancy" /*
	*/ 7 "ectopic pregnancy" /*
	*/ 8 "molar pregnancy" /*
	*/ 9 "blighted ovum" /*
	*/ 10 "unspecified loss" /*
	*/ 11 "delivery based on a third trim preg record" /*
	*/ 12 "delivery based on a late preg trim record" /*
	*/ 13 "outcome unknown"
tab outcome
tab updated_outcome
keep patid pregid mblbabies babypatid updated_outcome outcome gestdays multiple_ev pregstart_num pregend_num
order patid pregid mblbabies babypatid updated_outcome outcome gestdays multiple_ev pregstart_num pregend_num
rename outcome original_outcome

* retain those who were liveborn
keep if updated_outcome==1 // 456,355 not live born
count //  734,707 live born

* save as a temporary dataset
rename patid mumpatid
save "$Datadir\Derived_data\CPRD\_temp\livebirth_cohort_initial.dta", replace



* NOTE: The baby ID in the CPRD Pregnancy Register only covers one linked child. Variable "mblbabies" identifies pregnancies where additional children (i.e. twins/triplets/etc) are linked in the mother-baby link dataset.
********************************************************************************

*Save mother/baby IDs and delivery date from mother-baby link dataset
use "$Rawdatdir\stata\data_linked\20_000228_mother_baby_link.dta", clear
keep mumpatid babypatid deldate_num 
save "$Datadir\Derived_data\CPRD\_temp\linked_babies_id's_from_MBL.dta", replace	

*Open linked baby dataset, keeping pregnancies where additional children were present in MBL
use "$Datadir\Derived_data\CPRD\_temp\livebirth_cohort_initial.dta", clear	
keep if mblbabies>1 & mblbabies!=. 
count // 9,117 multiple birth pregnancies
rename babypatid patid
keep patid mumpatid pregid pregstart_num pregend_num mblbabies multiple_ev

		
*Add the MBL linked baby IDs		
joinby mumpatid using "$Datadir\Derived_data\CPRD\_temp\linked_babies_id's_from_MBL.dta", _merge(_merge) unmatched(master)
tab _merge // 2 multiple births in pregnancy cohort not identified in MBL
drop _merge
count //  25,088 children from 8686 pregnancies 
	
*Drop observations where the child identified in the MBL was the same as the child already present in the PR
drop if patid == babypatid // 9,114 observations deleted
count //  15,974 children of multiple birth pregnancies not currently in live birth cohort
	
*Create variable to measure the absolute difference between MBL delivery date and PR delivery date
gen diffdate = abs(deldate_num - pregend_num)
	
*Now keep any observations where the MBL delivery date was the same as the PR pregnancy end date
keep if diffdate==0 // 9,330 observations where delivery date differs between PR and MBL
count // 6,644 multiple pregnancy children retained who's DOB matches PR
 	
*Drop variables you don't need
drop patid diffdate multiple_ev
	
*Save data as temporary file
save "$Datadir\Derived_data\CPRD\_temp\additional babies from MBL.dta", replace	
	
*Now add additional children identified via the MBL to children already identified in the PR
use "$Datadir\Derived_data\CPRD\_temp\livebirth_cohort_initial.dta", clear	
count //  734,707
append using "$Datadir\Derived_data\CPRD\_temp\additional babies from MBL.dta", gen(source)
count //  741,351
	
format mumpatid babypatid pregid %13.0g
sort mumpatid pregid babypatid

*Drop any duplicates
duplicates report babypatid mumpatid pregid // no duplicates
count 
						
*Save data
keep mumpatid pregid babypatid
count // 741,351
save "$Datadir\Derived_data\Cohorts\livebirth_cohort_matids_pregids_babyids.dta", replace

********************************************************************************
* 3 - Create Child cohort
********************************************************************************
/* Child cohort definition

Child cohort to study child neurodevelopmental outcomes: we will define a sub-cohort of women from the 2nd cohort who also have follow-up data on children for at least 4 years in order to allow sufficient time for neurodevelopmental disorders to be diagnosed. Follow up will be until the latest available date of data collection or CPRD death date of the child or diagnosis of an outcome. We will explore, using multiple analysis methods and simulations, the impact of restricting to 4 years follow up on bias in effect estimates as a result of selection/live birth bias 

*/

use "$Datadir\Derived_data\Cohorts\livebirth_cohort_matids_pregids_babyids.dta", clear
rename babypatid patid

* merge onto patient data
drop if patid == 10 // 233,174 without a babypatid
merge 1:1 patid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta" 
tab _merge // no patient data for  123 patients
drop if _merge!=3
drop _merge
count // 518,054 children with patient data


* merge onto practice data 
tostring patid, gen(patid_s) format(%12.0f)
gen pracid = substr(patid_s,-5,5)
destring pracid, replace
drop patid_s
count //   518,054 
joinby pracid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Practice_Files.dta", _merge(_merge) unmatched(master) 
count // 518,054 
tab _merge
drop _merge
count //   518,054 

* merge on pregnancy register info 
joinby pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", _merge(_merge) unmatched(master)
count //   518,054 
tab _merge
drop _merge
count //   518,04 

* check all practices are up to standard for follow up
assert uts_num<pregend_num

* generate numeric death date variable 
merge m:1 patid using "$Rawdatdir\stata\data_linked\20_000228_ONS_death_patient.dta", keep(1 3) nogen
gen deathdate_num = dod_num 
replace deathdate_num = date(deathdate, "DMY") if deathdate_num == . 
format  %d deathdate_num 
count if deathdate_num!=. // 1007 died


* identify end of follow up for each child - earliest of transfer out date (TOD) and last colection date (LCD) and death date
gen end_fup_CPRD = min(tod_num,lcd_num,deathdate_num)
format end_fup_CPRD %td
	
* create flag for four year follow-up
count	//      518,054
count if pregend_num + (4*365) > tod_num //  86,718
count if pregend_num + (4*365) > lcd_num //  125,804
count if pregend_num + (4*365) > deathdate_num //    762
count if pregend_num + (4*365) > d(01Aug2021) //  33,969

gen four_yr_followup = end_fup_CPRD - pregend_num > (4*365) 
tab four_yr_followup //     321,166    followed up for 4 years


* save dataset
keep mumpatid pregid patid end_fup_CPRD four_yr_followup
rename patid babypatid
label variable end_fup_CPRD 		"Number of days follow up in CPRD"
label variable four_yr_followup		"Flag to indicate 4 years of follow up"
save "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", replace
		


********************************************************************************
* Delete all temporary files
********************************************************************************
capture erase "$Datadir\Derived_data\CPRD\_temp\preg_reg_reduced"
capture erase "$Datadir\Derived_data\CPRD\_temp\livebirth_cohort_initial.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\linked_babies_id's_from_MBL.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\additional babies from MBL.dta"


********************************************************************************
log close
