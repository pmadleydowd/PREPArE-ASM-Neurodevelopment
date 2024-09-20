*cap log close
*log using "$Logdir\LOG_cr_pregreg_historical_episodes_exclude.txt", text replace
*HF note: this do file is run within cr_select_eligible_participants, therefore logged there

********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			22 March 2022
* Description : 	Exclude episodes which are likely to be derived from historical data. These are pregnancies consistent with problem 4 of the outcome unknown section and problem 1 of the conflicting pregnancies section in Jennifer Campbell's BMJ paper on uncertain pregnancy episodes in CPRD GOLD pregnancy register - http://dx.doi.org/10.1136/bmjopen-2021-055773 
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

 
********************************************************************************
* Output datasets 
********************************************************************************
* 1 - "$Datadir\Derived_data\CPRD\Hist_Misout.dta" 
* 2 - "$Datadir\Derived_data\CPRD\Hist_Conflict.dta"

********************************************************************************
* Contents
********************************************************************************
* 1 - Identify for outcome unknown
* 2 - Prepare dataset of conflicting episodes - one row per conflicting pregnancy - ordered on pregnancy end
* 3 - Identify for conflicting pregnancies


********************************************************************************
* 1 - Identify for outcome unknown
********************************************************************************
/* For outcome unknown: we have already excluded pregnancies recorded in the 365 days following registration at GP, as these are more likely to be historical.  

Problem 4: The pregnancy record belongs to another pregnancy episode in the Register  

Solution: append the pregnancy with outcome unknown onto the previous pregnancy and bring the start date forward  

Scenario 4d A code recorded relating to the patient's delivery history is incorrectly identified by the algorithm as a delivery uncovering records at the end. 
	* The woman must have >1 episode in the pregnancy register.  
	* The pregend** date for the episode with missing outcome had to be <= 175 days (25 weeks) after the pregend** for the previous episode. 
*/

use "$Datadir\Derived_data\CPRD\_temp\pregreg_prehistoricalpregstep.dta", clear // dataset following all steps prior to step L in cr_Select_elligible_participants
keep patid pregid 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) nogen

order patid pregid pregstart_num pregend_num
sort patid pregend_num pregstart_num

foreach var in pregid pregstart_num pregend_num outcome  { // generate variables from previous row for 1st pregnancy and rename current row for second preganncy
	tostring `var' , gen(str_`var') force format(%13.0g)
    gen p1_`var' = str_`var'[_n-1] 
	destring p1_`var', replace
	rename `var'  p2_`var'
}
format %d p1_pregstart_num p1_pregend_num 
format %12.0g p1_pregid
duplicates tag p1_pregid, gen(_dupp1pregid)
assert _dupp1pregid == 0 

by patid: keep if _n > 1 // keep all rows after the first one for each mother id (data now stored on subsequent row) - this will remove all women with 1 pregnancy in the register only

recode p1_outcome (4/10 = 1) (1/3 11 12 = 2) (13 = 3), gen(p1_outcome_rc)
recode p2_outcome (4/10 = 1) (1/3 11 12 = 2) (13 = 3), gen(p2_outcome_rc)
label define lb_outrc 1 "Loss" 2 "Delivery" 3 "Missing"
label values p1_outcome_rc p2_outcome_rc lb_outrc

* identify pregnancies where the pregend date for the episode with missing outcome is <= 175 days (25 weeks) after the pregend for the previous episode
count if p2_pregend_num <= p1_pregend_num + 175 & p2_outcome_rc == 3
gen Hist_Misout = 1 if p2_pregend_num <= p1_pregend_num + 175 & p2_outcome_rc == 3
keep if Hist_Misout == 1

keep patid p1_pregid p2_pregid p1_outcome p2_outcome Hist_Misout

save "$Datadir\Derived_data\CPRD\Hist_Misout.dta", replace


********************************************************************************
* 2 - Prepare dataset of conflicting episodes - one row per conflicting pregnancy - ordered on pregnancy end
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\pregreg_prehistoricalpregstep.dta", clear // dataset following all steps prior to step L in cr_Select_elligible_participants
keep patid pregid 
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(3) nogen

order patid pregid pregstart_num pregend_num

tab conflict // 221,644 conflicting pregnancies out of 1,451,545 in the register 
keep if conflict == 1 
sort patid pregend_num pregstart_num

foreach var in pregid pregstart_num pregend_num outcome /*endadj firstantenatal*/ gestdays { // generate variables from previous row for 1st pregnancy and rename current row for second preganncy
	tostring `var' , gen(str_`var') force format(%13.0g)
    gen p1_`var' = str_`var'[_n-1] 
	destring p1_`var', replace
	rename `var'  p2_`var'
}

format %d p1_pregstart_num p1_pregend_num 
format %13.0g p1_pregid

duplicates tag p1_pregid, gen(_dupp1pregid)
assert _dupp1pregid == 0 

by patid: keep if _n > 1 // keep all rows after the first one for each mother id (data now stored on subsequent row)

keep if (p2_pregstart_num <=  p1_pregend_num  & p1_pregend_num <= p2_pregend_num) // keeping overlapping pregnancies (as previously sorted on pregsend, pregend of teh first pregnancy must fall between the window of pregnancy start and end of the second pregnancy)

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
replace outcome_combo = 7 if p1_outcome_rc == 2 & p2_outcome_rc == 1
label define lb_outcombo 1 "Loss - Loss" 2 "Loss - Delivery" 3 "Loss - Unknown" 4 "Delivery - Delivery" 5 "Delivery - Unkown" 6 "Unknown - Unknown" 7 "Delivery - Loss"
label values outcome_combo lb_outcombo

keep  patid p1* p2* outcome_combo
order patid p1* p2*

save "$Datadir\Derived_data\CPRD\_temp\pregconflicts_pregendsort.dta", replace



********************************************************************************
* 3 - Identify for conflicting pregnancies
* NOTE: uses "$Datadir\Derived_data\CPRD\_temp\pregconflicts.dta" and "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_currentlypregnantevents.dta", both derived in "$Dodir\Data management\cr_Select_elligible_participants.do" 
********************************************************************************
/* Problem 1: Both pregnancies are true but one is a current pregnancy and one is a historical pregnancy 

Solution: drop first episode, retain second episode (ensure the pregnancies are ordered on pregnancy end) 

Scenario 1a: the GP records a past delivery or loss during a current pregnancy with the same outcome resulting in another episode being created
	* outcome combination of the two episodes must be delivery/delivery or loss/loss  
	* The second episode had an antenatal code from a list deemed likely to only be recorded if the patient was currently pregnant (saved on server as READ_currently_pregnant_codes_JCAMPBELL)  .  

Scenario 1b: A patient has a record relating to a loss recorded during a pregnancy ending in delivery or vice-versa. Conflicting episodes are generated by the algorithm 
	* The outcome combination of the two episodes must be delivery/loss or loss/delivery  
	* The second episode had an antenatal code from a list deemed likely to only be recorded if the patient was currently pregnant (saved on server as READ_currently_pregnant_codes_JCAMPBELL)  

*/

* Scenario 1a and 1b
use "$Datadir\Derived_data\CPRD\_temp\pregconflicts_pregendsort.dta", clear
keep if inlist(outcome_combo, 1, 2, 4, 7) // keeping delivery/delivery, loss/loss  (scen 1a) and delivery/loss, loss/delivery (scen 1b)

by patid: egen _seq = seq()
summ _seq
local max = r(max)
forvalues i = 1/`max' {
	disp `i'
	preserve 
	
	keep if _seq == `i' 
	merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp\pregreg_conflicts_currentlypregnantevents.dta", nogen keep(3)
	keep if p2_pregstart_num <= eventdate_num & eventdate_num <= p2_pregend_num 

	gen Hist_Conflict_1a = 1 if inlist(outcome_combo, 1, 4) // delivery/delivery, loss/loss
	gen Hist_Conflict_1b = 1 if inlist(outcome_combo, 2, 7) // loss/delivery, delivery/loss

	keep patid p1_pregid p2_pregid Hist_Conflict_*

	duplicates drop
	
	save "$Datadir\Derived_data\CPRD\_temp\Hist_Conflict_`i'.dta", replace
	
	restore
}

* append datasets together 
use "$Datadir\Derived_data\CPRD\_temp\Hist_Conflict_1.dta", clear
forvalues i = 2/`max' {
    append using "$Datadir\Derived_data\CPRD\_temp\Hist_Conflict_`i'.dta"
}

save "$Datadir\Derived_data\CPRD\Hist_Conflict.dta", replace



********************************************************************************
*log close