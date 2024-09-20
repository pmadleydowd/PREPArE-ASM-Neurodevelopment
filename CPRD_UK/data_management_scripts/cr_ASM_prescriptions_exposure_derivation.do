cap log close 
log using "$Logdir\LOG_cr_ASM_presciptions_exposure_derivations.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			07 October 2021
* Description: 		Derive exposure status using cleaned ASM prescription information  
* Notes: 			Originally part of the do file for cleaning prescriptions but now separated into its own .do file

********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************
* 26/May/2022: Jess Rast added identification of hte highest daily dose from pregnancy perdio 4 and pregnancy period 6 (second trimester)
* 13/July/2022: Jess Rast added identification of the last dose in the 3-6 months pre-pregnnacy and the last dose from the 1st trimester 
********************************************************************************			
* Output datasets: 					
********************************************************************************
* 1 - "$Datadir\Derived_data\CPRD\pregnancy_cohort_exposure.dta" - dataset contains all ASM exposure variables for everyone in the preganncy cohort
 
********************************************************************************
* Contents
********************************************************************************
* 1 - Definitions 
* 2 - Define periods of interest for each individual  
* 3 - Create binary exposure information 
* 4 - Identify the proportion of days exposed in each trimester 	
* 5 - Obtain number of prescriptions for each drug in each period
* 6 - Define intiation, discontinuation and continuous use
* 7 - Identify polytherapy in the first trimester for pregnancy x - two prescriptions of different drug classes prescribed on the same day 
* 8 - Identify high, medium and low dose for the first trimester
* 8b -Identify highest daily dose from perdio 4 and period 6
* 9 - Create monotherapy categorical variable

* Final - Merge all exposure information into the same dataset 
* Clear temporary datasets


********************************************************************************
* 1 - Definitions 
********************************************************************************
* Periods of interest 
***********************
*	Pre-pregnancy - (1) 9-12 months, (2) 6-9 months, (3) 3-6 months, (4) 0-3 months
* 	Pregnancy - (5) 1st trimester, (6) 2nd trimester, (7) 3rd trimester
* 	Post-pregnancy - (8) 0-3 months, (9) 3-6 months, (10) 6-9 months, (11) 9-12 months

* Exposure types 
***********************
* 	Monotherapy - One medication only (where women have prescriptions for more than one type of drug on different days, we will classify them according to the drug class prescribed first)
* 	Polytherapy - Prescriptions of two or more distinct ASMs prescribed on the same day in the first trimester
* 	High dose -  Daily doses in top quartile
* 	Continuous use - prescription of the same drug class in the pre-pregnancy period and in the first, second and third trimester
* 	Early discontinuation - a prescription in the pre-pregnancy, but not pregnancy, period 
* 	Late discontinuation - a prescription in the pre-pregnancy, and first trimester, but not second and third trimester
* 	Switching - receiving one ASM in the pre-pregnancy period and initiation of a different ASM in one of the three trimesters
*	Initiators - a first ever ASM prescription during any trimester, but no prescription in the 365 days prior to pregnancy start 

patid	pregid
1906710410	1906741001

********************************************************************************
* 2 - Define periods of interest for each individual  
********************************************************************************
* obtain pregnancy information on pregnancy cohort
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", clear
merge 1:1 patid pregid using "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", keep(match) nogen
keep patid pregid pregstart_num pregend_num secondtrim_num thirdtrim_num 

* define periods of interest
gen prepreg_3month_num  = round(pregstart_num-3*30.5)
gen prepreg_6month_num  = round(pregstart_num-6*30.5)
gen prepreg_9month_num  = round(pregstart_num-9*30.5)
gen prepreg_12month_num = round(pregstart_num-12*30.5)

gen postpreg_3month_num  = round(pregend_num+3*30.5)
gen postpreg_6month_num  = round(pregend_num+6*30.5)
gen postpreg_9month_num  = round(pregend_num+9*30.5)
gen postpreg_12month_num = round(pregend_num+12*30.5)

format %td prepreg_* postpreg_* 

* verify max number of pregnancies a mother has
bysort patid: egen _seq=seq()
summ _seq // max number of pregnancies for a mother is 14
global pregmax = r(max) 

* save in temporary file 
save "$Datadir\Derived_data\CPRD\_temp\preg_cohort.dta", replace


********************************************************************************
* 3 - Create binary exposure information 
********************************************************************************
* merge on to prescription information and define exposure information for each pregnancy a mother has
forvalues x=1/$pregmax {
	disp "x = `x'"
	use "$Datadir\Derived_data\CPRD\_temp\preg_cohort.dta", clear
	bysort pregid (patid): keep if _seq==`x' /*unique patids*/
	merge 1:m patid using "$Datadir\Derived_data\Exposure\ASM_prescriptions_cleaned.dta", keep(match) nogen
	drop _seq
	
	* check for any missing values in timing variables 
	assert missing(prepreg_3month_num)==0
	assert missing(prepreg_6month_num)==0
	assert missing(prepreg_9month_num)==0
	assert missing(prepreg_12month_num)==0

	assert missing(pregstart_num)==0
	assert missing(pregend_num)==0 // some will have missing values for secondtrim_num and thirdtrim_num where the pregnancy terminated early
	
	assert missing(postpreg_3month_num)==0
	assert missing(postpreg_6month_num)==0
	assert missing(postpreg_9month_num)==0
	assert missing(postpreg_12month_num)==0
	
	assert missing(presc_startdate_num)==0
	drop if missing(presc_enddate_num)==1 // very small number with missing prescription end date - removing these
	
	
	* generate flags for prescriptions in each window (named period 1-11 from now on)
		* trimesters of pregnancy need special consideration here as second/third trimester start date are often missing where pregnancies terminated early. Pregnancy start and end date are never missing	
		* prepregnancy period
	gen flag1_prepreg_12_9 		= 1 if (prepreg_12month_num <= presc_startdate_num & presc_startdate_num < prepreg_9month_num) | (prepreg_12month_num <= presc_enddate_num & presc_enddate_num < prepreg_9month_num) | (presc_startdate_num <= prepreg_12month_num & prepreg_9month_num <= presc_enddate_num) 	
	gen flag2_prepreg_9_6  		= 1 if (prepreg_9month_num <= presc_startdate_num & presc_startdate_num < prepreg_6month_num) | (prepreg_9month_num <= presc_enddate_num & presc_enddate_num < prepreg_6month_num) | (presc_startdate_num <= prepreg_9month_num & prepreg_6month_num <= presc_enddate_num) 	
	gen flag3_prepreg_6_3  		= 1 if (prepreg_6month_num <= presc_startdate_num & presc_startdate_num < prepreg_3month_num) | (prepreg_6month_num <= presc_enddate_num & presc_enddate_num < prepreg_3month_num) | (presc_startdate_num <= prepreg_6month_num & prepreg_3month_num <= presc_enddate_num) 	
	gen flag4_prepreg_3_0  		= 1 if (prepreg_3month_num <= presc_startdate_num & presc_startdate_num < pregstart_num) | (prepreg_3month_num <= presc_enddate_num & presc_enddate_num < pregstart_num) | (presc_startdate_num <= prepreg_3month_num & pregstart_num <= presc_enddate_num) 	

		* pregnancy period
	gen flag5_preg_firsttrim  	= 1 if (secondtrim_num!=. & ((pregstart_num <= presc_startdate_num & presc_startdate_num < secondtrim_num) | (pregstart_num <= presc_enddate_num & presc_enddate_num < secondtrim_num)  | (presc_startdate_num <= pregstart_num & secondtrim_num <= presc_enddate_num))) | (secondtrim_num==. & ((pregstart_num <= presc_startdate_num & presc_startdate_num < pregend_num) | (secondtrim_num==. & pregstart_num <= presc_enddate_num & presc_enddate_num < pregend_num) | (presc_startdate_num <= pregstart_num & pregend_num <= presc_enddate_num)))
	
	gen flag6_preg_secondtrim 	= 1 if (secondtrim_num!=. & thirdtrim_num!=. & ((secondtrim_num <= presc_startdate_num & presc_startdate_num < thirdtrim_num) | (secondtrim_num <= presc_enddate_num & presc_enddate_num < thirdtrim_num) | (presc_startdate_num <= secondtrim_num & thirdtrim_num <= presc_enddate_num))) | (secondtrim_num!=. & thirdtrim_num==. & ((secondtrim_num <= presc_startdate_num & presc_startdate_num < pregend_num) | (secondtrim_num <= presc_enddate_num & presc_enddate_num < pregend_num) | (presc_startdate_num <= secondtrim_num & pregend_num <= presc_enddate_num)))
	
	gen flag7_preg_thirdtrim  	= 1 if (thirdtrim_num!=. & ((thirdtrim_num <= presc_startdate_num & presc_startdate_num < pregend_num) | (thirdtrim_num <= presc_enddate_num & presc_enddate_num < pregend_num) | (presc_startdate_num <= thirdtrim_num & pregend_num <= presc_enddate_num)))
	
		* Post pregnancy period
	gen flag8_postpreg_0_3   	= 1 if (pregend_num <= presc_startdate_num & presc_startdate_num < postpreg_3month_num) | (pregend_num <= presc_enddate_num & presc_enddate_num < postpreg_3month_num) | (presc_startdate_num <= pregend_num & postpreg_3month_num <= presc_enddate_num) 	
	gen flag9_postpreg_3_6   	= 1 if (postpreg_3month_num <= presc_startdate_num & presc_startdate_num < postpreg_6month_num) | (postpreg_3month_num <= presc_enddate_num & presc_enddate_num < postpreg_6month_num) | (presc_startdate_num <= postpreg_3month_num & postpreg_6month_num <= presc_enddate_num) 	
	gen flag10_postpreg_6_9  	= 1 if (postpreg_6month_num <= presc_startdate_num & presc_startdate_num < postpreg_9month_num) | (postpreg_6month_num <= presc_enddate_num & presc_enddate_num < postpreg_9month_num) | (presc_startdate_num <= postpreg_6month_num & postpreg_9month_num <= presc_enddate_num)
	gen flag11_postpreg_9_12 	= 1 if (postpreg_9month_num <= presc_startdate_num & presc_startdate_num < postpreg_12month_num) | (postpreg_9month_num <= presc_enddate_num & presc_enddate_num < postpreg_12month_num) | (presc_startdate_num <= postpreg_9month_num & postpreg_12month_num <= presc_enddate_num)

	egen anytime = rowmax(flag*)
	count if anytime == 1
	drop if anytime != 1 // removing all prescriptions not relevant to the pregnancy period 
	
	
		*  create additional flags for prepreg, preg and postpreg
	gen flag12_preg_firsttrim  	= 1 if flag1_ == 1 | flag2_ == 1 | flag3_  ==1 | flag4_ == 1
	gen flag13_preg_secondtrim 	= 1 if flag5_ == 1 | flag6_ == 1 | flag7_  ==1
	gen flag14_preg_thirdtrim  	= 1 if flag8_ == 1 | flag9_ == 1 | flag10_ ==1 | flag11_ == 1

	
	save "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'.dta", replace // dataset also used later for derivation of proportion of days exposed, polytherapy etc.

	
	* Create flags for binary exposure variable (any exposure during period)
	* reshape data to wide format - repeat over each time window (y)
	forvalues y = 1/14{ // 11 periods of interest + 3 sensitivity flags
		use "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'.dta",  clear
		keep if flag`y'_ == 1 // keep prescriptions in period only
		keep patid pregid presc_startdate_num daily_dose dd_mg ddd_who aed_class qty prescr_length

		if _N>0 { // some datasets with no observations 
			* keep only the first prescription of each drug 
			sort patid presc_startdate_num
			duplicates drop patid aed_class, force
		
			* create index variable for reshaping
			bysort patid: egen _presseq=seq()
			* reshape data to one row per person
			reshape wide aed_class presc_startdate_num daily_dose dd_mg ddd_who qty prescr_length, i(patid pregid) j(_presseq)
			
			* create flag for each drug class 
			egen flag_carbamazepine_prd`y'	= anymatch(aed_class*), values(2)
			egen flag_gabapentin_prd`y'   	= anymatch(aed_class*), values(6)
			egen flag_lamotrigine_prd`y' 	= anymatch(aed_class*), values(8)
			egen flag_levetiracetam_prd`y'  = anymatch(aed_class*), values(9)
			egen flag_phenytoin_prd`y' 		= anymatch(aed_class*), values(13)
			egen flag_pregabalin_prd`y' 	= anymatch(aed_class*), values(14)
			egen flag_topiramate_prd`y' 	= anymatch(aed_class*), values(21)
			egen flag_valproate_prd`y'  	= anymatch(aed_class*), values(22)	
			egen flag_other_prd`y' 			= anymatch(aed_class*), values(1 3/5 7 10/12 15/20 23/37)
			
			* keep relevant data 
			keep patid pregid flag*  
			
		}
		else if _N==0 {	// populate variables even if no data exists 
			keep patid pregid
			gen flag_carbamazepine_prd`y'	= .
			gen flag_gabapentin_prd`y'   	= .
			gen flag_lamotrigine_prd`y' 	= .
			gen flag_levetiracetam_prd`y'  	= .
			gen flag_phenytoin_prd`y' 		= .
			gen flag_pregabalin_prd`y' 		= .
			gen flag_topiramate_prd`y' 		= .
			gen flag_valproate_prd`y'  		= .	
			gen flag_other_prd`y' 			= .

		}		
		
		* label variables 
		label variable flag_carbamazepine_prd`y' 	"Period `y': Carbamazepine prescription"
		label variable flag_gabapentin_prd`y'   	"Period `y': Gabapentin prescription"	
		label variable flag_lamotrigine_prd`y' 		"Period `y': Lamotrigine prescription"
		label variable flag_levetiracetam_prd`y' 	"Period `y': Levitiracetam prescription"
		label variable flag_phenytoin_prd`y' 		"Period `y': Phenytoin prescription"
		label variable flag_pregabalin_prd`y' 		"Period `y': Pregbalin prescription"
		label variable flag_topiramate_prd`y' 		"Period `y': Topiramate prescription"
		label variable flag_valproate_prd`y'  		"Period `y': Valproate prescription"	
		label variable flag_other_prd`y' 			"Period `y': Other prescription"
		
		* save data for period y of pregnancy x 
		save "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'_period`y'.dta", replace
	}
	
	use "$Datadir\Derived_data\CPRD\_temp\preg_cohort.dta", clear
	keep patid pregid _seq
	bysort pregid (patid): keep if _seq==`x' 
	forvalues y = 1/14 { // 11 periods of interest + 3 sensitivity flags
		merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'_period`y'.dta"
		assert inlist(_merge, 1, 3) // check that only those in the cohort for pregnancy x are being merged
		drop _merge 
	}
	
	* set values to 0 if missing 
	foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
		forvalues y = 1/14 {  // 11 periods of interest + 3 larger periods
				replace flag_`drug'_prd`y'=0 if flag_`drug'_prd`y'==. 
		}		
	}
	
	
	* save dataset of binary exposures for pregnancy x
	save "$Datadir\Derived_data\CPRD\_temp\prescr_preg_`x'", replace

}


* append binary exposure datasets back together 
use "$Datadir\Derived_data\CPRD\_temp\prescr_preg_1", clear
forvalues x=2/$pregmax {
	append using "$Datadir\Derived_data\CPRD\_temp\prescr_preg_`x'"
}
duplicates drop // no duplicates, correct number of pregnancies 
* merge onto full pregnancy cohort to check - all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen

save "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_drugbyperiod.dta", replace


use "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_drugbyperiod.dta", clear

* define exposure with any drug for each period	
forvalues prd = 1/14 {
    egen flag_anydrug_prd`prd'= rowmax(flag_carbamazepine_prd`prd' flag_gabapentin_prd`prd' flag_lamotrigine_prd`prd' flag_levetiracetam_prd`prd' flag_phenytoin_prd`prd' flag_pregabalin_prd`prd' flag_topiramate_prd`prd' flag_valproate_prd`prd' flag_other_prd`prd')
} 


* define exposure during prepregnancy, pregnancy and postpregnancy
foreach drug in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
	egen flag_`drug'_prepreg = 	rowmax(flag_`drug'_prd1 flag_`drug'_prd2 flag_`drug'_prd3 flag_`drug'_prd4 )
	egen flag_`drug'_preg = 	rowmax(flag_`drug'_prd5 flag_`drug'_prd6 flag_`drug'_prd7 )
	egen flag_`drug'_postpreg = rowmax(flag_`drug'_prd8 flag_`drug'_prd9 flag_`drug'_prd10 flag_`drug'_prd11)
	
}	

save  "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", replace 
	

********************************************************************************	
* 4 - Identify the proportion of days exposed in each trimester 	
********************************************************************************
forvalues x=1/$pregmax { 		
	foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
		forvalues prd = 5/7 {
			use "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'.dta", clear
			
			* create string variable to identify aed classes
			decode aed_class, generate(aed_class_c)

			* restrict to drug in period of interest 
			keep if flag`prd'_ == 1
			if "`drug'" != "other" {
				keep if aed_class_c == "`drug'"
			} 
			else if "`drug'" == "other"{
				keep if !inlist(aed_class_c, "carbamazepine", "gabapentin", "lamotrigine", "levetiracetam" ,"phenytoin", "pregabalin", "topiramate", "valproate")
			}
			
			
			if _N!=0 {	// some datasets with no observations so need to filter code to account for them
				* define start and end dates for each period of pregnancy 
				gen start = presc_startdate_num
				gen end   = presc_enddate_num

				if `prd' == 5 {
					replace start	= pregstart_num  if presc_startdate_num < pregstart_num
					replace end 	= secondtrim_num if secondtrim_num < presc_enddate_num
					
					gen days_in_prd = secondtrim_num - pregstart_num if secondtrim_num !=. 
					replace days_in_prd = pregend_num - pregstart_num if secondtrim_num ==. 
				}
				else if `prd' == 6 {
					replace start	= secondtrim_num if presc_startdate_num < secondtrim_num 
					replace end 	= thirdtrim_num  if thirdtrim_num < presc_enddate_num
					
					gen days_in_prd = thirdtrim_num - secondtrim_num if thirdtrim_num !=.
					replace days_in_prd = pregend_num - secondtrim_num if thirdtrim_num == . 
				}
				else if `prd' == 7 {
					replace start	= thirdtrim_num if presc_startdate_num < thirdtrim_num
					replace end 	= pregend_num   if pregend_num < presc_enddate_num			
					
					gen days_in_prd = pregend_num - thirdtrim_num
				}
				format %td start end 

				sort patid aed_class presc_startdate_num
				by patid: egen _seq=seq() // order of Rx for each drug class within patient

				gen ndays_exposed_in_prd = end - start // calculate number of days exposed in period for Rx
				
				egen total_days_exposed_in_prd = total(ndays_exposed_in_prd), by(patid pregid) // total number of days exposed to drug in period 
				keep if _seq == 1 // keep only the first Rx (all information now in this row) 
				
				gen propdaysexposed_prd = total_days_exposed_in_prd/days_in_prd // proportion of days exposed 
				replace propdaysexposed_prd = 1 if propdaysexposed_prd >1 // where Rx overlap some patients will have more days exposed than the number of days in the window
				
				keep patid pregid total_days_exposed_in_prd propdaysexposed_prd
				rename total_days_exposed_in_prd totdays_`drug'_prd`prd'  
				rename propdaysexposed_prd propdays_`drug'_prd`prd'
				
				label variable totdays_"Total number of days exposed: `drug', prd `prd'"
				label variable propdays_ "Proportion of days exposed: `drug', prd `prd'"	
			}
			else if _N==0 {	// create variables where no data exists (to aid with merge commands in loops later) 
				keep patid pregid
				gen totdays_`drug'_prd`prd'  = . 
				gen propdays_`drug'_prd`prd' = . 
			}
			save "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_prd`prd'_`x'.dta", replace 
		}			
	}
}


forvalues x=1/$pregmax { 		
	foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
		use "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_prd5_`x'.dta", clear
		merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_prd6_`x'.dta", nogen
		merge 1:1 patid pregid using  "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_prd7_`x'.dta", nogen
		save "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_`x'.dta", replace
	}
}

foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
	use "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_1.dta", clear
	forvalues x=2/$pregmax {
		append using "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_`x'.dta",
	}
	save "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'.dta", replace
}	


use "$Datadir\Derived_data\CPRD\_temp\propdays_carbamazepine.dta",  clear
foreach drug in gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
	merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'.dta", nogen
}
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen
			
save "$Datadir\Derived_data\CPRD\_temp\propdays_exposed.dta", replace
	

	
********************************************************************************
* 5 - Obtain number of prescriptions for each drug in each period
********************************************************************************
forvalues x=1/$pregmax { 
	use "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'.dta", clear
	if _N!=0 {	// some datasets with no observations so need to filter code to account for them
		* create string variable to identify aed classes
		decode aed_class, generate(aed_class_c)
	
		sort patid aed_class presc_startdate_num
		by patid aed_class: egen _seq=seq() // order of Rx for each drug class within patient
		
		* Count the number of prescriptions in each window 
			* doing this for one pregnancy at a time per mother 
			* all pregnancies will be appended together after the loops and sumamry statistics are calulated there
		duplicates drop patid aed_class presc_startdate_num, force // exclude prescriptions of the same type occuring on the same day
		foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
			forvalues prd = 1/14 {	
				if "`drug'" != "other" {
					egen totalRx_`drug'_`prd' = total(flag`prd'_p) if aed_class_c=="`drug'", by(patid) // creates count of prescriptions of the same class within each period 
				}
				else if "`drug'" == "other" {
					egen totalRx_`drug'_`prd' = total(flag`prd'_p) if !inlist(aed_class_c, "carbamazepine", "gabapentin", "lamotrigine", "levetiracetam" ,"phenytoin", "pregabalin", "topiramate", "valproate"), by(patid) // creates count of prescriptions of the class "other" within each period 
				}
				label variable totalRx_`drug'_`prd' "Total `drug' Rx for period `prd'"
			}
		}	
		keep if _seq==1 // keeping only the first instance for each drug to reduce the datasize 
		keep patid pregid aed_class aed_class_c totalRx*
	}
	else if _N==0 {	// create variables where no data exists (to aid with merge commands in loops later) 
		gen aed_class_c= ""
		foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
			forvalues prd = 1/14 {	
					gen totalRx_`drug'_`prd' = .			
			}
		}
		keep patid pregid aed_class aed_class_c totalRx*
	}
	save "$Datadir\Derived_data\CPRD\_temp\totalRx_`x'.dta", replace
}	



* the number of prescriptions are on separate rows for each drug - merging them back into a single row per patient
forvalues x=1/$pregmax {
	disp "x = `x'"
	foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
		use "$Datadir\Derived_data\CPRD\_temp\totalRx_`x'.dta", clear 
		disp "test1"

		if "`drug'" != "other" {
			disp "test1a - `drug'" 

			keep if aed_class_c=="`drug'"
			keep patid pregid totalRx_`drug'*
			save "$Datadir\Derived_data\CPRD\_temp\totalRx_`drug'.dta", replace
		}
		else if "`drug'" == "other" { // for other drugs, still have one row per drug, so need to reduce to a single row 
			disp "test1b - `drug'"
			keep if !inlist(aed_class_c, "carbamazepine", "gabapentin", "lamotrigine", "levetiracetam" ,"phenytoin", "pregabalin", "topiramate", "valproate")
			keep patid pregid totalRx_other*
			sort patid pregid
			if _N != 0 {
				forvalues prd = 1/14{
					egen new_totalRx_other_`prd' = total(totalRx_other_`prd'), by(patid)
					drop totalRx_other_`prd'
					rename new_totalRx_other_`prd' totalRx_other_`prd'
				}
			by patid: keep if _n==1			
			}
			save "$Datadir\Derived_data\CPRD\_temp\totalRx_other.dta", replace
		}				
	}
	disp "test2"

	use "$Datadir\Derived_data\CPRD\_temp\totalRx_carbamazepine.dta", clear 
	foreach drug in gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
		disp "test 3 - `drug'"
		merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\totalRx_`drug'.dta", nogen	
	}	
	save "$Datadir\Derived_data\CPRD\_temp\totalRxwide_`x'.dta", replace 
}


* append datasets back together 
use "$Datadir\Derived_data\CPRD\_temp\totalRxwide_1.dta", clear
forvalues x=2/$pregmax{
	append using "$Datadir\Derived_data\CPRD\_temp\totalRxwide_`x'.dta", 
}
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen

* save number of prescriptions dataset 
save  "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_Count_byPeriod.dta", replace
 
 
 
********************************************************************************	
* 6 - Define intiation, discontinuation and continuous use
********************************************************************************	
use  "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_Count_byPeriod.dta", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", nogen

 * Define evidence of prepregnancy exposure - 2 or more Rx in year before preg, @ least 1 in 12-6 months prepreg and @ least 1 in 6-0 months prepreg
foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
	gen prepreg_`drug' = 1 if ((totalRx_`drug'_1 >= 1 & !missing(totalRx_`drug'_1)) | ///
							   (totalRx_`drug'_2 >= 1 & !missing(totalRx_`drug'_2))) & ///
							  ((totalRx_`drug'_3 >= 1 & !missing(totalRx_`drug'_3)) | ///
							   (totalRx_`drug'_4 >= 1 & !missing(totalRx_`drug'_4))) & ///
							  (totalRx_`drug'_12 >= 2 & !missing(totalRx_`drug'_12))
}
egen prepreg_anydrug = rowmax(prepreg_carbamazepine prepreg_gabapentin prepreg_lamotrigine prepreg_levetiracetam prepreg_phenytoin prepreg_pregabalin prepreg_topiramate prepreg_valproate prepreg_other) 
							   
 * Define exposure variables - continuous use, early discontinuation, late discontinuation, initiation and switching
foreach drug in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
								   
	*	Continuous use 
	gen continuous_`drug' = 1 if prepreg_`drug' == 1  & ///
								 flag_`drug'_prd5==1 & ///
								 flag_`drug'_prd6==1 & ///
								 flag_`drug'_prd7==1
	
	* 	Early discontinuation 
	gen earlydiscont_`drug' = 1 if prepreg_`drug' == 1 & /// 
								   flag_`drug'_prd5==0 & flag_`drug'_prd6==0 & flag_`drug'_prd7==0 	
	
	* 	Late discontinuation
	gen latediscont_`drug' = 1 if prepreg_`drug' == 1 & /// 
								  flag_`drug'_prd5==1  & flag_`drug'_prd7==0	
	
	*	Initiators 
	gen initiate_`drug' = 1 if flag_`drug'_prd1==0 & flag_`drug'_prd2==0 & flag_`drug'_prd3==0 & flag_`drug'_prd4==0 & (flag_`drug'_prd5==1 | flag_`drug'_prd6==1 | flag_`drug'_prd7==1)
	
	*	Starting post-pregnancy_cohort_exposure
	gen initiate_post_preg_`drug'=1 if flag_`drug'_prepreg==0 & flag_`drug'_preg==0 & flag_`drug'_postpreg==1 	
}	

	* 	Switching: - receiving one ASM in the pre-pregnancy period and initiation of a different ASM in one of the three trimesters
*Gabepentin to other
gen switch=.
foreach firstdrug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
	foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
		replace switch = 1 if flag_`firstdrug'_prepreg == 1 & flag_`firstdrug'_preg == 0 & flag_`drug'_prepreg == 0 & flag_`drug'_preg == 1 
	}
}

	
	*	Combined patterns of use variable
gen use=1 if continuous_anydrug==1
replace use=2 if earlydiscont_anydrug==1
replace use=3 if latediscont_anydrug==1
replace use=4 if initiate_anydrug==1
replace use=5 if initiate_post_preg_anydrug==1
replace use=9 if use==. & (flag_anydrug_prepreg==1 |  flag_anydrug_preg==1 | flag_anydrug_postpreg==1)
lab def use 1 Continuous 2 "Early Discontinuation" 3 "Late Discontinuation" ///
4 "Initiate during pregnancy" 5 "Initiate after pregnancy" ///
 9 "Other"
lab val use use
lab var use "Combined patterns of use variable "
tab use
 
keep patid pregid prepreg_* continuous_* earlydiscont_* latediscont_* initiate_* switch use  
count 

save "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_patterns.dta", replace
 
 
 
********************************************************************************	
* 7 - Identify polytherapy in the first trimester for pregnancy x - two prescriptions of different drug classes prescribed in the same period 
********************************************************************************
* generic version - overlap in use within first trimester
use  "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", clear 

foreach prd in "prd5" "prd6" "prd7" "preg" {
	if "`prd'" == "prd5" { 
		local prd_c = "firsttrim"
		local prd_lb = "first trimester"		
	}
	if "`prd'" == "prd6" { 
		local prd_c = "secondtrim"		
		local prd_lb = "second trimester"				
	}
	if "`prd'" == "prd7" { 
		local prd_c = "thirdtrim"
		local prd_lb = "third trimester"
	}
	if "`prd'" == "preg" { 
		local prd_c = "preg"
		local prd_lb = "pregnancy"		
	}
	
	preserve
	keep patid pregid flag_*_`prd'
	drop flag_anydrug
	rename flag_*_`prd' *

	egen polytherapy_`prd_c'_ndrugs = rowtotal(carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other)
	gen polytherapy_`prd_c' = polytherapy_`prd_c'_ndrugs > 1 if polytherapy_`prd_c'_ndrugs > 0 & missing(polytherapy_`prd_c'_ndrugs)==0 

	keep patid pregid polytherapy*
	label variable polytherapy_`prd_c'_ndrugs 	"Number of drug classes prescribed in `prd_lb'"
	label variable polytherapy_`prd_c' 		 	"Mother prescribed 2 or more drug classes in `prd_lb'"
	
	save "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_`prd'.dta", replace
	restore
} 

use "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_prd5.dta", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_prd6.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_prd7.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_preg.dta", nogen 

save "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy.dta", replace



* Specific version - overlap with same day prescribed both drugs 
forvalues x=1/$pregmax { // running separately for each pregnancy a mother has 
	use "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'.dta", replace

	keep if flag5 == 1

	if _N > 0 { 
		decode aed_class , gen(aed_class_c)
		sort patid aed_class
		by patid: egen _seq = seq()
		forvalues day = 1/ 98 { // length of first trimester as defined in pregnancy register
			foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {		
				disp "preg =`x', day = `day', drug = `drug'"
			
				if "`drug'" != "other" {
					gen day`day'_`drug' = 1 if aed_class_c == "`drug'" & (presc_startdate_num <= pregstart_num + `day' - 1) & (pregstart_num + `day' - 1 <= presc_enddate_num)
				} 
				else if "`drug'" == "other"{
					gen day`day'_`drug' = 1 if !inlist(aed_class_c, "carbamazepine", "gabapentin", "lamotrigine", "levetiracetam" ,"phenytoin", "pregabalin", "topiramate", "valproate")
				}
				
				by patid: egen day`day'_`drug'_collapsed = max(day`day'_`drug')			
			} 
		
			egen drugcnt_day`day' = rowtotal(day`day'_*_collapsed) 		// number of drugs being prescribed on given day
			gen poly_day`day' = 1 if drugcnt_day`day' > 1		// polytherapy if more than one drug being prescribed on given day	
		}
		
		keep if _seq == 1 
		keep patid pregid pregstart_num pregend_num drugcnt_day* poly_day*
	}
	else if _N == 0 {
		keep patid pregid
	}	
	save "$Datadir\Derived_data\CPRD\_temp\polytherapy_`x'", replace
}

* append all pregnancies back together
use "$Datadir\Derived_data\CPRD\_temp\polytherapy_1", clear
forvalues x=2/$pregmax { 
	disp "pregnancy=`x'"
	append using "$Datadir\Derived_data\CPRD\_temp\polytherapy_`x'"
}

gen gestlen = pregend_num - pregstart_num
drop pregstart_num pregend_num
reshape long drugcnt_day poly_day, i(patid pregid gestlen) j(day) // convert to long format
keep if day<=gestlen // keeping only days in the pregnancy (where the pregnancy ended early)

by patid pregid: egen polytherapy_ft_sameday = max(poly_day)
by patid pregid: egen polytherapy_ndrugs_ft_sameday = max(drugcnt_day)
by patid pregid: egen _seq = seq() 

keep if _seq==1
keep if polytherapy_ft_sameday == 1

merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", nogen
replace polytherapy_ft_sameday = 0 if polytherapy_ft_sameday == . & flag_anydrug_prd5 == 1


keep patid pregid polytherapy*
label variable polytherapy_ndrugs_ft_sameday "Number of drug classes prescribed in first trimester (with overlap)"
label variable polytherapy_ft_sameday "Polytherapy (with overlap) first trimester"

save "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_sameday.dta", replace


********************************************************************************
* 8 - Identify high, medium and low dose for the first trimester and last dose pre-pregnancy
********************************************************************************#

*First identify cut-off values for low, mediuma and high dose categories, using pre-preg Rx
use "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_1.dta", clear
forvalues x= 2/$pregmax {
    append using "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'"
}

*Define cut-offs using all prescriptions from the year prior to pregnancy start 
gen diff=presc_start-pregstart_num
keep if diff>-365 & diff<0
keep patid pregid dd_mg aed_class
decode aed_class, generate(aed_class_c) // create string variable to identify aed classes
tab aed_class_c

tempname myhandle	
file open `myhandle' using "$Datadir\Descriptive_statistics\ASM_use_paper\dosage.txt", write replace
file write `myhandle' "Drug" _tab "Total Rx" _tab "Level" _tab "Value (mg)" _tab "N" _tab
file write `myhandle' "Minimum" _tab "25% QI" _tab "50% Median" _tab "75% Q3" _tab "Maximium" _n

qui foreach drug in carbamazepine lamotrigine phenobarbital valproate brivaracetam  eslicarbazepine ethosuximide gabapentin lacosamide  levetiracetam oxcarbazepine perampanel  phenytoin pregabalin primidone retigabine rufinamide stiripentol tiagabine topiramate  vigabatrin zonisamide clonazepam {
preserve
file write `myhandle' "`drug'" _tab 
keep if aed_class_c=="`drug'"
count
file write `myhandle' (`r(N)') _tab 

if `r(N)'!=0 {
noi di "************"
noi di "`drug'"

*Keep highest dose, if a single preg has different doses in first trimesters
*Keep single Rx per pregnancy
gsort patid pregid -dd_mg
by patid pregid: keep if _n==1

*Generate dosage
noi sum dd_mg, det
local low`drug'=`r(p25)'
local high`drug'=`r(p75)'

gen dosage=1 if dd_mg<=`r(p25)'
replace dosage=2 if dd_mg>`r(p25)' & dd_mg<=`r(p75)'
replace dosage=3 if dd_mg>`r(p75)'
noi bysort dosage: sum dd_mg
noi tab dosage

count if dosage==1
local lowN=`r(N)'
count if dosage==2
local medN=`r(N)'
count if dosage==3
local highN=`r(N)'

noi sum dd_mg if dosage==1, det
if `r(N)'!=0 {
local lowMIN=`r(min)'
local low25=`r(p25)'
local low50=`r(p50)'
local low75=`r(p75)'
local lowMAX=`r(max)'
}

sum dd_mg if dosage==2, det
if `r(N)'!=0 {
local medMIN=`r(min)'
local med25=`r(p25)'
local med50=`r(p50)'
local med75=`r(p75)'
local medMAX=`r(max)'
}

sum dd_mg if dosage==3, det
if `r(N)'!=0 {
local highMIN=`r(min)'
local high25=`r(p25)'
local high50=`r(p50)'
local high75=`r(p75)'
local highMAX=`r(max)'
}


file write `myhandle' "Low" _tab "<=" (`low`drug'') _tab (`lowN') _tab
file write `myhandle' (`lowMIN') _tab (`low25') _tab (`low50') _tab (`low75') _tab (`lowMAX') _n

 file write `myhandle' _tab _tab  "Medium" _tab ">" (`low`drug'') " to <=" (`high`drug'') _tab (`medN') _tab
file write `myhandle' (`medMIN') _tab (`med25') _tab (`med50') _tab (`med75') _tab (`medMAX') _n

file write `myhandle' _tab _tab   "High" _tab ">" (`high`drug'') _tab (`highN') _tab
file write `myhandle' (`highMIN') _tab (`high25') _tab (`high50') _tab (`high75') _tab (`highMAX') _n

keep patid pregid aed_class dosage
noi tab dosage
noi di "************"
}
file write `myhandle' _n
restore
}



*Apply cut-offs to all prescriptions
use "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_1.dta", clear
forvalues x= 2/$pregmax {
    append using "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'"
}
decode aed_class, generate(aed_class_c) // create string variable to identify aed classes

gen dosage=. 
foreach drug in carbamazepine lamotrigine phenobarbital valproate brivaracetam  eslicarbazepine ethosuximide gabapentin lacosamide  levetiracetam oxcarbazepine perampanel  phenytoin pregabalin primidone retigabine stiripentol tiagabine topiramate  vigabatrin zonisamide clonazepam {
	count if aed_class_c=="`drug'"
	if r(N)!=0 {	
		replace dosage=1 if dd_mg<=`low`drug'' & aed_class_c=="`drug'"
		replace dosage=2 if dd_mg>`low`drug'' & dd_mg<=`high`drug'' & aed_class_c=="`drug'"
		replace dosage=3 if dd_mg>`high`drug'' & aed_class_c=="`drug'"
	}
}

*Label dosage variable
lab define dosage 1 Low 2 Medium 3 High
lab val dosage dosage
save "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", replace

*check
tab dd_mg if dosage==1 & aed_class_c=="valproate"

*dosage in 1st trimester: if different doses, take highest
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
keep if flag5_preg_firsttrim==1
rename dosage dosage_tri_1

gsort patid pregid -dosage_tri_1 
by patid pregid: keep if _n==1


replace aed_class_c="other" if aed_class_c!="valproate" & aed_class_c!="carbamazepine" & aed_class_c!="gabapentin" &  aed_class_c!="lamotrigine" & aed_class_c!="levetiracetam" & aed_class_c!="phenytoin" & aed_class_c!="pregabalin" & aed_class_c!="topiramate"
tab aed_class_c

keep patid pregid dd_mg aed_class* dosage*
tab dosage
save "$Datadir\Derived_data\CPRD\_temp\dosage_first_trimester", replace


*dosage in pre-pregnancy: if different doses, take highest
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
keep if flag1_prepreg_12_9==1 | flag4_prepreg_3_0==1 | flag2_prepreg_9_6==1 |  flag3_prepreg_6_3==1
rename dosage dosage_pre_preg

gsort patid pregid -dosage_pre_preg 
by patid pregid: keep if _n==1


replace aed_class_c="other" if aed_class_c!="valproate" & aed_class_c!="carbamazepine" & aed_class_c!="gabapentin" &  aed_class_c!="lamotrigine" & aed_class_c!="levetiracetam" & aed_class_c!="phenytoin" & aed_class_c!="pregabalin" & aed_class_c!="topiramate"
tab aed_class_c

keep patid pregid dd_mg aed_class* dosage*
tab dosage
save "$Datadir\Derived_data\CPRD\_temp\dosage_pre_preg", replace


*dosage in 2nd trimester: if different doses, take highest
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
keep if flag6_preg==1
rename dosage dosage_tri_2

gsort patid pregid -dosage_tri_2 
by patid pregid: keep if _n==1


replace aed_class_c="other" if aed_class_c!="valproate" & aed_class_c!="carbamazepine" & aed_class_c!="gabapentin" &  aed_class_c!="lamotrigine" & aed_class_c!="levetiracetam" & aed_class_c!="phenytoin" & aed_class_c!="pregabalin" & aed_class_c!="topiramate"
tab aed_class_c

keep patid pregid dd_mg aed_class* dosage*
tab dosage
save "$Datadir\Derived_data\CPRD\_temp\dosage_second_trimester", replace


*dosage in 3rd trimester: if different doses, take highest
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
keep if flag7_preg==1
rename dosage dosage_tri_3

gsort patid pregid -dosage_tri_3 
by patid pregid: keep if _n==1


replace aed_class_c="other" if aed_class_c!="valproate" & aed_class_c!="carbamazepine" & aed_class_c!="gabapentin" &  aed_class_c!="lamotrigine" & aed_class_c!="levetiracetam" & aed_class_c!="phenytoin" & aed_class_c!="pregabalin" & aed_class_c!="topiramate"
tab aed_class_c

keep patid pregid dd_mg aed_class* dosage*
tab dosage
save "$Datadir\Derived_data\CPRD\_temp\dosage_third_trimester", replace


* Dosages for individual drugs in each trimester
forvalues trim = 0(1)3 {
	use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
	
	if `trim'==0 {
		keep if flag1_prepreg==1 | flag2_prepreg==1 | flag3_prepreg==1 | flag4_prepreg==1 
	}
	else if `trim'==1{
		keep if flag5_preg==1
	}
	else if `trim'==2{
		keep if flag6_preg==1	
	}
	else if `trim'==3{
		keep if flag7_preg==1		
	}
		
	replace aed_class_c="other" if aed_class_c!="valproate" & aed_class_c!="carbamazepine" & aed_class_c!="gabapentin" &  aed_class_c!="lamotrigine" & aed_class_c!="levetiracetam" & aed_class_c!="phenytoin" & aed_class_c!="pregabalin" & aed_class_c!="topiramate"

	encode aed_class_c, gen(aed_class_n)
	tab aed_class_n
	tab aed_class_n, nol

	gsort patid pregid aed_class_n -dosage 
	by patid pregid aed_class_n: keep if _n==1
	keep patid pregid aed_class_n dosage
	reshape wide dosage, i(patid pregid) j(aed_class_n) 
		   
	rename dosage1 dosage_carbamazepine_trim`trim'
	rename dosage2 dosage_gabapentin_trim`trim'
	rename dosage3 dosage_lamotrigine_trim`trim'
	rename dosage4 dosage_levetiracetam_trim`trim'
	rename dosage5 dosage_other_trim`trim'
	rename dosage6 dosage_phenytoin_trim`trim'
	rename dosage7 dosage_pregabalin_trim`trim'
	rename dosage8 dosage_topiramate_trim`trim'
	rename dosage9 dosage_valproate_trim`trim'

	save "$Datadir\Derived_data\CPRD\_temp\dosage_eachdrug_trim`trim'", replace
} 



********************************************************************************
* 8b - Identify highest dose from pregnancy perdiod 4 (three months before pregnancy) and from period 6 (second trimester) 
********************************************************************************
*Use RX file
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear

*Keep highest dose, if a single preg has different doses, in period 4
*Keep single Rx per pregnancy
keep if flag4_prepreg_3_0==1
gsort pregid -dd_mg
by pregid: keep if _n==1
rename dd_mg dd_mg_flag4_prepreg
keep patid pregid dd_mg_flag4_prepreg 
save "$Datadir\Derived_data\CPRD\_temp\dd_mg_flag4_prepreg", replace

*Use RX file
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
*keep highest dose, if a single preg has different doses, in perdiod 6 (second trimester)
keep if flag6_preg_secondtrim==1
gsort pregid -dd_mg
by pregid: keep if _n==1
rename dd_mg dd_mg_flag6_preg_second
keep patid pregid dd_mg_flag6_preg_second 
save "$Datadir\Derived_data\CPRD\_temp\dd_mg_flag6_preg_second", replace


********************************************************************************
* 8b - Identify last dose dose from pregnancy perdiod 3 (6-3 months before pregnancy) and from period 5 (first trimester) also identify first prescirpiotn from the second trimester (perdiod 6)
********************************************************************************
*Use RX file
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear

*Keep single Rx per pregnancy
*keep those in the time period (period 3)
keep if flag3_prepreg_6_3==1
gsort pregid -presc_startdate_num
by pregid: keep if _n==1
rename dd_mg dd_mg_prepreg3_last
label var dd_mg_prepreg3_last "Dose of last RX in 3-6 months pre-pregnancy"
keep patid pregid dd_mg_prepreg3_last 
save "$Datadir\Derived_data\CPRD\_temp\dd_mg_prepreg3_last", replace


*Use RX file
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
*Keep single Rx per pregnancy
*keep those in the time period (period 5)
keep if flag5_preg_firsttrim==1
gsort pregid -presc_startdate_num
by pregid: keep if _n==1
rename dd_mg dd_mg_preg5_last
label var dd_mg_preg5_last "Dose of last RX in the first trimester of pregnancy"
keep patid pregid dd_mg_preg5_last 
save "$Datadir\Derived_data\CPRD\_temp\dd_mg_preg5_last", replace

*Use RX file
use  "$Datadir\Derived_data\CPRD\_temp\dosages_all_Rx.dta", clear
*Keep single Rx per pregnancy
*keep those in the time period (period 6)
keep if flag6_preg_secondtrim==1
gsort pregid presc_startdate_num //sort by earliest to latest 
by pregid: keep if _n==1 //keep earliest RX
rename dd_mg dd_mg_preg6_first
label var dd_mg_preg6_first "Dose of first RX in the second trimester of pregnancy"
keep patid pregid dd_mg_preg6_first 
save "$Datadir\Derived_data\CPRD\_temp\dd_mg_preg6_first", replace

********************************************************************************
* 9 - Create monotherapy categorical variable
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", clear 
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy.dta", nogen

label define lb_monothercat ///
	0 "No ASM exposure" ///
	1 "Carbamazepine" ///
	2 "Gabapentin" ///
	3 "Lamotrigine" ///
	4 "Levetiracetam" ///
	5 "Phenytoin" ///
	6 "Pregbalin" ///
	7 "Topiramate" ///
	8 "Valproate" ///
	9 "Other" ///
	10 "Polytherapy" 
	
foreach prd in "prd5" "prd6" "prd7" "preg" {
	if "`prd'" == "prd5" { 
		local prd_c = "firsttrim"
		local prd_lb = "first trimester"		
	}
	if "`prd'" == "prd6" { 
		local prd_c = "secondtrim"		
		local prd_lb = "second trimester"				
	}
	if "`prd'" == "prd7" { 
		local prd_c = "thirdtrim"
		local prd_lb = "third trimester"
	}
	if "`prd'" == "preg" { 
		local prd_c = "preg"
		local prd_lb = "pregnancy"		
	}
	
	preserve

	gen monother_cat_`prd_c' = 0 if flag_anydrug_`prd' == 0 
	replace monother_cat_`prd_c' = 1  if flag_carbamazepine_`prd' 	== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 2  if flag_gabapentin_`prd' 		== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 3  if flag_lamotrigine_`prd' 	== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 4  if flag_levetiracetam_`prd' 	== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 5  if flag_phenytoin_`prd' 		== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 6  if flag_pregabalin_`prd'		== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 7  if flag_topiramate_`prd' 		== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 8  if flag_valproate_`prd' 		== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 9  if flag_other_`prd' 			== 1 & polytherapy_`prd_c' == 0 
	replace monother_cat_`prd_c' = 10 if polytherapy_`prd_c' 		== 1 

	label values monother_cat_`prd_c' lb_monothercat
	label variable monother_cat_`prd_c' "Categorical monotherapy in `prd_lb'"
		
	save "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_`prd'.dta", replace
	restore
}

* 2 prescriptions in pregnancy as sensitivity analysis 
use "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", clear 
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_Count_byPeriod.dta", nogen

label define lb_monothercat_2Rx ///
	0 "No ASM exposure" ///
	1 "Carbamazepine 2Rx" ///
	2 "Gabapentin 2Rx" ///
	3 "Lamotrigine 2Rx" ///
	4 "Levetiracetam 2Rx" ///
	5 "Phenytoin 2Rx" ///
	6 "Pregbalin 2Rx" ///
	7 "Topiramate 2Rx" ///
	8 "Valproate 2Rx" ///
	9 "Other 2Rx" ///
	10 "Polytherapy 2Rx" /// 
	11 "ASM 1Rx"

foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
	egen nRx_`drug'_preg = rowtotal(totalRx_`drug'_5 totalRx_`drug'_6 totalRx_`drug'_7)  
} 
	
gen monother_cat_2Rx = 0 if flag_anydrug_preg == 0
replace monother_cat_2Rx = 1  if nRx_carbamazepine_preg >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 2  if nRx_gabapentin_preg    >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 3  if nRx_lamotrigine_preg   >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 4  if nRx_levetiracetam_preg >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 5  if nRx_phenytoin_preg     >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 6  if nRx_pregabalin_preg    >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 7  if nRx_topiramate_preg    >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 8  if nRx_valproate_preg     >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 9  if nRx_other_preg         >= 2 & polytherapy_preg == 0 
replace monother_cat_2Rx = 10 if polytherapy_preg 		== 1 
replace monother_cat_2Rx = 11 if monother_cat_2Rx == . & ///
	(nRx_carbamazepine_preg == 1 | nRx_gabapentin_preg == 1 | nRx_lamotrigine_preg == 1 | nRx_levetiracetam_preg == 1 | ///
	 nRx_phenytoin_preg     == 1 | nRx_pregabalin_preg == 1 | nRx_topiramate_preg  == 1 | nRx_valproate_preg == 1 | /// 
	 nRx_other_preg         == 1)
replace monother_cat_2Rx = 11 if monother_cat_2Rx == . & flag_anydrug_preg == 1

label values monother_cat_2Rx lb_monothercat_2Rx
label variable monother_cat_2Rx "Categorical monotherapy in (2 Rx) in pregnancy"
tab monother_cat_2Rx, mis
keep patid pregid monother_cat* 
save "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_2Rx_preg.dta", replace

* combine variables together into single dataset 
use "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_prd5.dta", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_prd6.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_prd7.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_preg.dta", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical_2Rx_preg.dta", nogen

* test 
foreach drug in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other{ 
	tab monother_cat_firsttrim flag_`drug'_prd5
}

foreach drug in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other{ 
	tab monother_cat_2Rx flag_`drug'_preg
}

keep patid pregid monother_cat* 
save "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical.dta", replace

	
********************************************************************************
* Final - Merge all exposure information into the same dataset 
********************************************************************************
use "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta", clear 
 
* merge on proportion of days exposed 
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\propdays_exposed.dta", nogen // all matched
 
* merge on number of prescriptions for each period 
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_Count_byPeriod.dta", nogen // all matched
 
* merge on patterns data 
merge 1:1 patid pregid using  "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_patterns.dta", nogen // all matched
 
* merge on polytherapy data 
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy.dta", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy_sameday.dta"
* merge on dosage data
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_first_trimester", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_second_trimester", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_third_trimester", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_pre_preg", nogen // all matched

merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_eachdrug_trim0", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_eachdrug_trim1", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_eachdrug_trim2", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dosage_eachdrug_trim3", nogen // all matched

merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dd_mg_flag4_prepreg", nogen // all matched
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dd_mg_flag6_preg_second", nogen // all matched
merge 1:1 patid pregid using  "$Datadir\Derived_data\CPRD\_temp\dd_mg_prepreg3_last", nogen
merge 1:1 patid pregid using  "$Datadir\Derived_data\CPRD\_temp\dd_mg_preg5_last", nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\dd_mg_preg6_first", nogen

merge 1:1 patid pregid using "$Datadir\Derived_data\CPRD\_temp\monotherapy_categorical.dta", nogen

* save exposure information dataset 
drop _seq
save "$Datadir\Derived_data\Exposure\pregnancy_cohort_exposure.dta", replace 
cap log close	
	

/********************************************************************************
* Clear temporary datasets
********************************************************************************
capture erase "$Datadir\Derived_data\CPRD\_temp\preg_cohort.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_drugbyperiod.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\binary_exposure_vars.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\propdays_exposed.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\ASM_Rx_Count_byPeriod.dta"
capture erase "$Datadir\Derived_data\CPRD\_temp\pregnancy_cohort_polytherapy.dta"

forvalues x=1/$pregmax {
	capture erase "$Datadir\Derived_data\CPRD\_temp\prescr_preg_`x'.dta"
	capture erase "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'.dta"
	capture erase "$Datadir\Derived_data\CPRD\_temp\totalRx_`x'.dta"
	capture erase "$Datadir\Derived_data\CPRD\_temp\totalRxwide_`x'.dta"
	capture erase "$Datadir\Derived_data\CPRD\_temp\polytherapy_`x'.dta"
	forvalues y=1/14 {
		capture erase "$Datadir\Derived_data\CPRD\_temp\stage1_pregpresc_`x'_period`y'.dta"
		
		foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
			capture erase "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_prd`y'_`x'.dta"
		}
	}
	
	foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
			capture erase "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'_`x'.dta"
	}
}

foreach drug in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
	capture erase "$Datadir\Derived_data\CPRD\_temp\totalRx_`drug'.dta"
	capture erase "$Datadir\Derived_data\CPRD\_temp\firsttrim_RxStartdates_`drug'.dta"
	capture erase "$Datadir\Derived_data\CPRD\_temp\propdays_`drug'.dta"
}





********************************************************************************
