********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			07 March 2022
* Description : 	Merge confliciting episodes in the pregnancy register that are consistent with pronlem 4 in Jennifer Campbell's BMJ paper on uncertain pregnancy episodes in CPRD GOLD pregnancy register - http://dx.doi.org/10.1136/bmjopen-2021-055773 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************
* 22 Mar 2022
	* unable to implement scenario 4b or 4e as we do not have the variable endadj - have commented these out
	* do not have access to firstantenatal so using pregstart_num + 4 weeks instead 

 
********************************************************************************
* Output datasets 
********************************************************************************
* 1 - "$Datadir\Derived_data\CPRD\pregconflicts_Scen4.dta" - identifies evidence to resolve conflicts between pregnancy pairs


********************************************************************************
* Contents
********************************************************************************
* 1 - Prepare dataset of conflicting episodes - one row per conflicting pregnancy 
* 2 - Resolve scenario from Jennifer Campbell's BMJ paper
* 	2.1 - Resolve scenario 4b
* 	2.2 - Resolve scenario 4b
* 	2.3 - Resolve scenario 4c
* 	2.4 - Resolve scenario 4d 
* 	2.5 - Resolve scenario 4e
* 3 - Merge evidence of each scenario onto list of conflicting pregnancies 



********************************************************************************
* 1 - Prepare dataset of conflicting episodes - one row per conflicting pregnancy 
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\pregreg_preconflictstep.dta", clear // dataset following all steps prior to step K in cr_Select_elligible_participants
keep patid pregid 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) nogen

order patid pregid pregstart_num pregend_num

tab conflict // 221,644 conflicting pregnancies out of 1,451,545 in the register 
keep if conflict == 1 
sort patid pregstart_num pregend_num

foreach var in pregid pregstart_num pregend_num outcome /*endadj firstantenatal*/ gestdays { // generate variables from previous row for 1st pregnancy and rename current row for second preganncy
	tostring `var' , gen(str_`var') force format(%13.0g)
    gen p1_`var' = str_`var'[_n-1] 
	destring p1_`var', replace
	rename `var'  p2_`var'
}

format %d p1_pregstart_num p1_pregend_num /* p1_firstantenatal*/
format %13.0g p1_pregid
duplicates tag p1_pregid, gen(_dupp1pregid)
assert _dupp1pregid == 0 

by patid: keep if _n > 1 // keep all rows after the first one for each mother id (data now stored on subsequent row)
keep if (p1_pregstart_num <=  p2_pregstart_num  & p2_pregstart_num <= p1_pregend_num) // keeping overlapping pregnancies (as previously sorted on pregstart, pregstart of the second pregnancy must fall within the window of the pregnancy start and end of the first pregnancy)

recode p1_outcome (4/10 = 1) (1/3 11 12 = 2) (13 = 3), gen(p1_outcome_rc)
recode p2_outcome (4/10 = 1) (1/3 11 12 = 2) (13 = 3), gen(p2_outcome_rc)
label define lb_outrc 1 "Loss" 2 "Delivery" 3 "Missing"
label values p1_outcome_rc p2_outcome_rc lb_outrc

gen     outcome_combo = 1 if p1_outcome_rc == 1 & p2_outcome_rc == 1 // generate combination variable for outcomes (earliest pregnancy - labeled as prev - comes first) using appendix 12 of BMJ paper by JC
replace outcome_combo = 2 if p1_outcome_rc == 1 & p2_outcome_rc == 2
replace outcome_combo = 3 if p1_outcome_rc == 1 & p2_outcome_rc == 3
replace outcome_combo = 4 if p1_outcome_rc == 2 & p2_outcome_rc == 2
replace outcome_combo = 5 if p1_outcome_rc == 2 & p2_outcome_rc == 3
replace outcome_combo = 6 if p1_outcome_rc == 3 & p2_outcome_rc == 3
label define lb_outcombo 1 "Loss - Loss" 2 "Loss - Delivery" 3 "Loss - Unknown" 4 "Delivery - Delivery" 5 "Delivery - Unkown" 6 "Unknown - Unknown"
label values outcome_combo lb_outcombo

keep  patid p1* p2* outcome_combo
order patid p1* p2*

save "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", replace





********************************************************************************
* 2 - Resolve scenarios from Jennifer Campbell's BMJ paper
********************************************************************************
* Notes from JC - For pairs consistent with 4a, 4B and 4c I would keep the first episode and drop the 2nd. 4d and 4e  I would consider merging the episodes. 4d is the biggest headache as these are essentially sporadic antenatal codes in the data being made into multiple episodes. I would suggest taking the start of pregnancy from the episode which has a startsource derived from the data. You could then treat this as a pregnancy with no outcome as above.


****************************
* 2.1 - Resolve scenario 4a
**************************** 
/*
Scenario 4a The GP records further information about a pregnancy outcome >25 weeks later for deliveries or >8weeks <12 weeks later for losses. 
	- 1	The outcome combination of the two episodes must be delivery/delivery or loss/loss (Appendix 12) 
	- 2	The first episode had an antenatal code from a list deemed likely to only be recorded if the patient was currently pregnant (saved on server as READ_currently_pregnant_codes_JCAMPBELL) OR a scan record in the HES DID data between firstantenatal* and pregend*.

* Note - we do not have access to HES DID so can only implement first half of bullet point 2
*/

* identify all conflicting pairs where the first pregnancy has evidence for being a current pregnancy
use "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", clear
keep if inlist(outcome_combo, 1, 4) 
tab outcome_combo

by patid: egen _seq = seq()
summ _seq
local max = r(max)
forvalues i = 1/`max' {
	disp `i'
	preserve 
	
	keep if _seq == `i' 
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_currentlypregnantevents.dta", nogen keep(3)
	keep if p1_pregstart_num <= eventdate_num & eventdate_num <= p1_pregend_num 
	
	keep patid p1_pregid p2_pregid 
	gen EvScen_4a = 1
	
	if _N > 0 {
		duplicates drop
	}
	
	save "$Datadir\Derived_data\CPRD\_temp\EvScen4a_`i'.dta", replace
	
	restore
}

* append datasets together 
use "$Datadir\Derived_data\CPRD\_temp\EvScen4a_1.dta", clear
forvalues i = 2/`max' {
    append using "$Datadir\Derived_data\CPRD\_temp\EvScen4a_`i'.dta"
}

save "$Datadir\Derived_data\CPRD\_temp\EvScen4a.dta", replace


***********************
* 2.2 - Resolve scenario 4b
***********************
/*
 Scenario 4b The GP records further antenatal information after the end of a pregnancy. Conflicting episodes are generated by the algorithm 
•	The first episode must have outcome= 1-10 in the register (Appendix 2) and must have endadj* =0 
•	 The second episode must have no recorded outcome (outcome= 13) 
•	The second episode must have a gestdays* =28 (likely to consist of one code) and there must NOT be a scan code (READ_antenatal_scan_JCAMPBELL) with an eventdate* = pregend* of the second episode.

* Note - we currently do not have the variable endadj in the pregnancy register 
*/

/*
use "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", clear
keep if inlist(p1_outcome, 1,2,3,4,5,6,7,8,9,10) /* & p1_endadj == 0 */ & p2_outcome ==  13 & p2_gestdays == 28 

by patid: egen _seq = seq()
summ _seq
local max = r(max)
forvalues i = 1/`max' {
	disp `i'
	preserve 
	
	keep if _seq == `i' 
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_antenatalscanevents.dta", keep(1 3)
	
	gen     scan_test = 1 if _merge==3 & eventdate_num == p2_pregend_num
	replace scan_test = 0 if _merge==1 | (_merge==3 & eventdate_num != p2_pregend_num)
	
	bysort patid: egen _seq2 = seq()

	keep patid p1_pregid p2_pregid scan_test _seq2
	reshape wide scan_test, i(patid p1 p2) j(_seq2)
	egen scan_test = rowmax(scan_test*)
	
	drop if scan_test == 1	
	keep patid p1_pregid p2_pregid 
	gen EvScen_4b = 1 
	
	save "$Datadir\Derived_data\CPRD\_temp\EvScen4b_`i'.dta", replace
	
	restore
}

* append datasets together 
use "$Datadir\Derived_data\CPRD\_temp\EvScen4b_1.dta", clear
forvalues i = 2/3 {
    append using "$Datadir\Derived_data\CPRD\_temp\EvScen4b_`i'.dta"
}

save "$Datadir\Derived_data\CPRD\_temp\EvScen4b.dta", replace

*/

****************************
* 2.3 - Resolve scenario 4c
****************************
/*
Scenario 4c The patient has a follow up scan after a pregnancy loss. The scan is recorded in the data as an antenatal scan, a conflicting episode is then generated by the algorithm. 
•	The outcome combination of the two episodes must be loss/missing. 
•	The second episode must have a gestdays* =28 (likely to consist of one code) and there must be a scan code (READ_antenatal_scan_JCAMPBELL) with an eventdate* = pregend* of the second episode
*/


use "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", clear
keep if outcome_combo == 3 & p2_gestdays == 28

if _N>0 {
	by patid: egen _seq = seq()
	summ _seq
	local max = r(max)
	forvalues i = 1/`max' {
		disp `i'
		preserve 
		
		keep if _seq == `i' 
		merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_antenatalscanevents.dta", keep(3)
		
		keep if eventdate_num == p2_pregend_num
		keep patid p1_pregid p2_pregid 
		gen EvScen_4c = 1 
		
		if _N>0 {
			duplicates drop
		}
		
		save "$Datadir\Derived_data\CPRD\_temp\EvScen4c_`i'.dta", replace
		
		restore
	}

	* append datasets together 
	use "$Datadir\Derived_data\CPRD\_temp\EvScen4c_1.dta", clear
	forvalues i = 2/3 {
		append using "$Datadir\Derived_data\CPRD\_temp\EvScen4c_`i'.dta"
	}
}

if _N == 0 {
	
	keep patid p1_pregid p2_pregid 
	gen EvScen_4c = . 

}
save "$Datadir\Derived_data\CPRD\_temp\EvScen4c.dta", replace


****************************
* 2.4 - Resolve scenario 4d 
****************************
/*
Scenario 4d The GP records information about a pregnancy but no outcome with >6 weeks between records. If the second episode has gestational information the start may be assigned before the start of the first episode. 
•	The outcome combination of the two episodes must be missing/missing. 
•	The pregend* of the first episode is > 42 days before the firstantenatal* date of the second episode.

* NOTE: Currently do not have firstantenatal date variable - using preg start + 4 weeks on the recommendation of Jenny Campbell
*/

use "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", clear
keep if outcome_combo == 6 & (p1_pregend_num + 42 < p2_pregstart_num + 28 )
gen EvScen_4d = 1 
save "$Datadir\Derived_data\CPRD\_temp\EvScen4d.dta", replace



****************************
* 2.5 - Resolve scenario 4e
****************************
/*
Scenario 4e The pregnancy dates have been shifted backwards by the rules of the algorithm leaving uncovered records. Conflicting episodes are generated by the algorithm.
•	The first episode must have a delivery outcome code and endadj* variable not = to 0 
•	The second episode must have outcome= to 11, 12 or 13.
*/
/*
use "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", clear
keep if (p1_outcome_rc == 2 /*& p1_endadj != 0*/) & inlist(p2_outcome, 11, 12, 13) 
gen EvScen_4e = 1 
save "$Datadir\Derived_data\CPRD\_temp\EvScen4e.dta", replace
*/



********************************************************************************
* 3 - Merge evidence of each scenario onto list of conflicting pregnancies 
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta", clear
merge 1:1 patid p1_pregid p2_pregid using "$Datadir\Derived_data\CPRD\_temp\EvScen4a.dta", /*nogen */
/*merge 1:1 patid p1_pregid p2_pregid using "$Datadir\Derived_data\CPRD\_temp\EvScen4b.dta", nogen */
merge 1:1 patid p1_pregid p2_pregid using "$Datadir\Derived_data\CPRD\_temp\EvScen4c.dta", nogen 
merge 1:1 patid p1_pregid p2_pregid using "$Datadir\Derived_data\CPRD\_temp\EvScen4d.dta", nogen 
/*merge 1:1 patid p1_pregid p2_pregid using "$Datadir\Derived_data\CPRD\_temp\EvScen4e.dta", nogen */

keep patid *pregid EvScen* 
egen conflict_retain = rowmax(EvScen*) 
tab conflict_retain , mis
keep if conflict_retain==1 
drop conflict_retain
tab EvScen_4a
tab EvScen_4c
tab EvScen_4d

save "$Datadir\Derived_data\CPRD\pregconflicts_Scen4.dta", replace


********************************************************************************
*log close