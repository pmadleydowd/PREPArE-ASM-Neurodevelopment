cap log close
log using "$Logdir\NDD study\LOG_cr_NND_dat.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			24 March 2022
* Description : 	Create dataset for use in the PREPArE CPRD NDD study
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************
* 1 - "$Datadir\NDD_study_PMD\NDD_study_data.dta" - dataset for use in NDD study 


********************************************************************************
* Contents
********************************************************************************
* 1 - Load child cohort and merge on outcomes, exposure and covariates 
* 2 - Derive any additional variables 
* 3 - Create exposure variables for use in sibling analyses 

* Apply any further restrictions to cohort
* output dataset 


********************************************************************************
* 1 - Load child cohort and merge on outcomes, exposure and covariates 
********************************************************************************
* load child cohort 
use "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final.dta", clear
keep patid pregid multiple_ev pregstart_num pregend_num
rename patid mumpatid 
merge 1:m mumpatid pregid using "$Datadir\Derived_data\Cohorts\child_cohort_matids_pregids_babyids_followup.dta", keep(3) nogen 



* merge on sex information 
rename babypatid patid 
merge m:1 patid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", nogen keep(1 3)  keepusing(gender)
rename patid babypatid
label define lb_gender 1 "Male" 2 "Female" 3 "Indeterminate" 4 "Unknown"
label values gender lb_gender


* merge on outcome information 
merge m:1 mumpatid pregid babypatid using "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_ASD.dta", nogen keep(1 3)
merge m:1 mumpatid pregid babypatid using "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_ADHD.dta", nogen keep(1 3)
merge m:1 mumpatid pregid babypatid using "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_ID.dta", nogen keep(1 3)
merge m:1 mumpatid pregid babypatid using "$Datadir\Derived_data\Outcomes\Offspring_outcomes\childcohort_Narc.dta", nogen keep(1 3)

	
* merge on exposure information 
rename mumpatid patid
merge m:1 patid pregid using "$Datadir\Derived_data\Exposure\pregnancy_cohort_exposure.dta", nogen keep(1 3)

* merge on indication information 
merge m:1 patid pregid using "$Datadir\Derived_data\Indications\ASM_indications_pre_preg_final.dta", nogen keep(1 3)

* merge on covariate information
merge m:1 patid pregid using "$Datadir\Derived_data\Covariates\pregnancy_cohort_covariates.dta", nogen keep(1 3)
merge m:1 patid pregid using "$Datadir\Derived_data\Covariates\maternal_prepreg_NDD.dta", nogen keep(1 3)

* merge on linkage eligibility information 
cap drop _merge
rename patid mumpatid 
rename babypatid patid
merge m:1 patid using "$Rawdatdir\stata\data_linked\linkage_eligibility_gold21.dta", keep(1 3) keepusing(patid hes_e linkdate)
cap drop linkage_eligible
gen linkage_eligible = _merge == 3 
gen linkdate_num = date(linkdate, "DMY")
format %d linkdate_num
drop _merge  


* prepare any additional variables 
rename patid babypatid
capture drop _merge


********************************************************************************
* 2 - Derive any additional variables
********************************************************************************
* pregnancy year start categories - recode into categories 
drop pregstart_year_cat
recode pregstart_year (1995/1997 = 1) (1998/2000 = 2) (2001/2003 = 3) ///
					  (2004/2006 = 4) (2007/2009 = 5) (2010/2012 = 6) ///
					  (2013/2015 = 7) (2016/2018 = 8) ///
					  , gen(pregstart_year_cat)
label drop lb_yearcat
label define lb_yearcat 1 "1995-1997" 2 "1998-2000" 3 "2001-2003" 4 "2004-2006" 5 "2007-2009" 6 "2010-2012" 7 "2013-2015" 8 "2016-2018"
label values pregstart_year_cat lb_yearcat


* Create categorical variable for prior hospitalisation
summ CPRD_consultation_events, det
gen CPRD_consultation_events_lmh = 1 if r(min) < CPRD_consultation_events & CPRD_consultation_events <= r(p25)
replace CPRD_consultation_events_lmh = 2 if r(p25) < CPRD_consultation_events & CPRD_consultation_events <= r(p75)
replace CPRD_consultation_events_lmh = 3 if r(p75) < CPRD_consultation_events & missing(CPRD_consultation_events) != 1 
label define lb_consult_lmh 1 "Low" 2 "Medium" 3 "High"
label values CPRD_consultation_events_lmh lb_consult_lmh


* create any NDD outcome
egen outcome_NDD = rowmax(outcome_ASD outcome_ID outcome_ADHD)
egen date_NDD = rowmin(date_ASD date_ADHD date_ID)
format %td date_NDD

* update date of failure/censoring for date variables
gen fup_end = end_fup_CPRD
format %td fup_end
replace fup_end = linkdate_num if linkdate_num > end_fup_CPRD & hes_e == 1 // update for those with HES linkage whose linkage date is greater than the CPRD date 
gen fup_years = (fup_end - pregstart_num)/365.25

foreach ndd in NDD ASD ADHD ID {
	replace date_`ndd' = fup_end if date_`ndd' == . // set missing values of date of diagnossis to final date in CPRD
	format %td date_`ndd'
	gen stime_`ndd' = date_`ndd' - pregend_num + 1
	replace stime_`ndd' = 1 if stime_`ndd' <= 0  
}


* indications
foreach indication in epilepsy bipolar somatic_cond other_psych_gp {
	replace `indication' = 0 if `indication' == . 
}
replace other_psych_gp = 1 if bipolar == 1	
 
egen anyindication = rowmax(epilepsy somatic_cond other_psych_gp)



* Primary analysis exposure comparisons 
	* 3 level exposure to create "pure" comparison between use and no use of any ASM  (use of other ASMs in another category)
foreach ASM in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
	* Comparison at any time in pregnancy 
	gen `ASM'_comp1 = 2 if flag_anydrug_preg == 1 
	replace `ASM'_comp1 = 1 if flag_`ASM'_preg == 1 
	replace `ASM'_comp1 = 0 if flag_anydrug_preg == 0

	* Comparison in trimester 1 
	gen `ASM'_comp2 = 2 if flag_anydrug_prd5 == 1 
	replace `ASM'_comp2 = 1 if flag_`ASM'_prd5 == 1 
	replace `ASM'_comp2 = 0 if flag_anydrug_prd5 == 0
	
	* Comparison in trimester 2 	
	gen `ASM'_comp3 = 2 if flag_anydrug_prd6 == 1 
	replace `ASM'_comp3 = 1 if flag_`ASM'_prd6 == 1 
	replace `ASM'_comp3 = 0 if flag_anydrug_prd6 == 0

	* Comparison in trimester 3 
	gen `ASM'_comp4 = 2 if flag_anydrug_prd7 == 1 
	replace `ASM'_comp4 = 1 if flag_`ASM'_prd7 == 1 
	replace `ASM'_comp4 = 0 if flag_anydrug_prd7 == 0

	* Comparison with lamotrigine in the first trimester (monotherapy)
	gen `ASM'_comp5 = 1 if flag_`ASM'_prd5 == 1 & polytherapy_firsttrim == 0
	replace `ASM'_comp5 = 0 if flag_lamotrigine_prd5 == 1 & polytherapy_firsttrim == 0 
	
	label variable `ASM'_comp1 "`ASM' 3 level exposure any time in pregnancy" 
	label variable `ASM'_comp2 "`ASM' 3 level exposure in first trimester"
	label variable `ASM'_comp3 "`ASM' 3 level exposure in second trimester"
	label variable `ASM'_comp4 "`ASM' 3 level exposure in third trimester"
	label variable `ASM'_comp5 "`ASM' comparison with lamotrigine in first trimester (monotherapy)"
}


* Secondary analysis comparisons 
label define lb_discont 1 "Continuous prescription" 2 "Pre-pregnancy discontinuation" 3 "Late discontinuation"

foreach ASM in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
	gen SECAN_`ASM'_init = 1 if initiate_`ASM' == 1 
	replace SECAN_`ASM'_init = 0 if flag_`ASM'_prepreg == 0 & flag_`ASM'_postpreg == 0 
	
	gen SECAN_`ASM'_discont = 1 if continuous_`ASM' == 1  
	replace SECAN_`ASM'_discont = 2 if earlydiscont_`ASM' == 1 
	replace SECAN_`ASM'_discont = 3 if latediscont_`ASM' == 1 
	label values SECAN_`ASM'_discont lb_discont
	
}


* Derive offspring sex 
	* merge on child's patient information 
rename babypatid patid
merge 1:1 patid using "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", keep(1 3) keepusing(gender) nogen
rename patid babypatid
tab gender


* derive additional covariate information 
gen bin_seizure = seizure_events_CPRD_HES > 0 

recode CPRD_consultation_events (0/3=1) (4/10=2) (10/.=3), gen(CPRD_consult_cat2) 
lab define lb_CPRD_consult_cat2 1 "0-3" 2 "4-10" 3 "10+"
lab values CPRD_consult_cat2 lb_CPRD_consult_cat2

gen matage_cubed = matage*matage*matage

* pregnancy year groups
recode pregstart_year 	(1995/1997 = 1) ///
						(1998/2000 = 2) ///
						(2001/2003 = 3) ///
						(2004/2006 = 4) ///
						(2007/2009 = 5) ///
						(2010/2012 = 6) ///
						(2013/2015 = 7) ///
						(2016/2018 = 8) ///
						, gen(pregstart_year_cat2)
label define lb_year2 	1 "1995-1997" ///
						2 "1998-2000" ///
						3 "2001-2003" /// 
						4 "2004-2006" ///
						5 "2007-2009" /// 
						6 "2010-2012" ///
						7 "2013-2015" ///
						8 "2016-2018"
label values pregstart_year_cat2 lb_year2
tab pregstart_year pregstart_year_cat2



* addiction variable
gen addiction = 0 if ///
	missing(hazardous_drinking) == 0 | missing(illicitdrug_preg) == 0
replace addiction = 1 if hazardous_drinking == 1 | illicitdrug_preg == 1 
tab addiction, mis

* gravidity
recode 	gravidity (5/100 = 5), gen(gravidity_cat2)
label define lb_gravcat2 5 "5+"
label values gravidity_cat2 lb_gravcat2

* region
recode 	AreaOfResidence ///
		(1 2 3 4 5 8 9 10 12 13 = 1) ///
		(6 = 2) ///
		(7 = 3) ///
		(11 = 4) ///
		, gen(Area2) 
label define lb_area2 1 "England" 2 "Northern Ireland" 3 "Scotland" 4 "Wales"
label values Area2 lb_area2

* Health care visits 
recode 	CPRD_consultation_events (0/3 = 1) (4/10 = 2) (11/20000 = 3), gen(consult)
label define lb_consult 1 "0-3" 2 "4-10" 3 ">10"
label values consult lb_consult
* seizure events 
recode	CPRD_seizure_events (1/20000 =1), gen(seizure)
label define lb_seizure 0 "0" 1 ">=1"
label values seizure lb_seizure


********************************************************************************
* 3 - Create exposure variables for use in sibling analyses 
********************************************************************************
* Family averaged exposure - for between family effect
preserve 
	sort mumpatid pregid pregstart_num 
	duplicates drop mumpatid pregid , force // remove second row for multiple births
	by mumpatid: egen _seq = seq() // generate identifier for each pregnacy a mother has - 8 children maximum
	keep mumpatid _seq flag_*_prd5
	rename flag_*_prd5 flag_*
	reshape wide flag_*, i(mumpatid) j(_seq)
	foreach ASM in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
		egen famavg_`ASM'_firsttrim = rowmean(flag_`ASM'*)  
	}
	keep mumpatid famavg*
	save "$Datadir\NDD_study_PMD\_temp\famavg_exposure.dta", replace
restore
 
merge m:1 mumpatid using "$Datadir\NDD_study_PMD\_temp\famavg_exposure.dta", nogen

* categorical version of exposure to account for exposure to other ASMs
gen anydrug_firsttrim =  flag_anydrug_prd5
foreach ASM in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
		gen `ASM'_firsttrim = flag_`ASM'_prd5
		replace `ASM'_firsttrim = 2 if flag_`ASM'_prd5 == 0 & flag_anydrug_prd5 == 1
		label define lb_`ASM'_sibexp 0 "Unexposed to any ASM" 1 "Exposed to `ASM'" 2 "Exposed to another ASM"	
		label values `ASM'_firsttrim lb_`ASM'_sibexp	
}

* family averaged exposure to ASMs other than ASM of interest 
preserve 
	sort mumpatid pregid pregstart_num 
	duplicates drop mumpatid pregid , force // remove second row for multiple births
	by mumpatid: egen _seq = seq() // generate identifier for each pregnacy a mother has - 8 children maximum
	foreach ASM in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
		gen ASMs_not_`ASM' = `ASM'_firsttrim == 2
	}
	keep mumpatid _seq ASMs_not_*	
	reshape wide ASMs_not_*, i(mumpatid) j(_seq)
	foreach ASM in carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other { 
		egen famavg_not_`ASM'_tri1 = rowmean(ASMs_not_`ASM'*)  
	}
	keep mumpatid famavg*
	save "$Datadir\NDD_study_PMD\_temp\famavg_othASM_exposure.dta", replace
restore
 
merge m:1 mumpatid using "$Datadir\NDD_study_PMD\_temp\famavg_othASM_exposure.dta", nogen


* deviation from family averaged covariate 
foreach covar in matage matage_cubed hazardous_drinking illicitdrug_preg gravidity parity CPRD_consultation_events seizure_events_CPRD_HES antipsychotics_365_prepreg antidepressants_365_prepreg vom_antiemet_preg{
	preserve 
		sort mumpatid pregid pregstart_num 
		duplicates drop mumpatid pregid , force // remove second row for multiple births
		by mumpatid: egen _seq = seq() // generate identifier for each pregnacy a mother has - 8 children maximum
		keep mumpatid _seq `covar'	
		reshape wide `covar', i(mumpatid) j(_seq)
		egen fa_`covar' = rowmean(`covar'*)  
		keep mumpatid fa_`covar'
		save "$Datadir\NDD_study_PMD\_temp\famavg_`covar'.dta", replace
	restore	
}

foreach covar in matage hazardous_drinking illicitdrug_preg gravidity parity CPRD_consultation_events seizure_events_CPRD_HES antipsychotics_365_prepreg antidepressants_365_prepreg vom_antiemet_preg{
	merge m:1 mumpatid using "$Datadir\NDD_study_PMD\_temp\famavg_`covar'.dta", nogen
	gen dev_`covar' = `covar'-fa_`covar'	
	tab dev_`covar'
}


* Identify family size 
sort mumpatid pregstart_num
by mumpatid: egen border = seq()
by mumpatid: egen famsize = max(border)

preserve 
	 keep if border <= 2 & famsize >=2
	 keep mumpatid border *_firsttrim
	 drop famavg*
	 reshape wide *_firsttrim, i(mumpatid) j(border) 
	 foreach ASM in anydrug carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other {
		gen firstsibexp_`ASM'1  = 1 if  `ASM'_firsttrim1 == 1 & `ASM'_firsttrim2 == 0 
		gen firstsibexp_`ASM'2  = firstsibexp_`ASM'1	
		
		gen secondsibexp_`ASM'1 = 1 if  `ASM'_firsttrim1 == 0 & `ASM'_firsttrim2 == 1 	
		gen secondsibexp_`ASM'2 = secondsibexp_`ASM'1		
	 }
	 keep mumpatid firstsibexp_* secondsibexp_*
	 reshape long firstsibexp_anydrug secondsibexp_anydrug firstsibexp_carbamazepine secondsibexp_carbamazepine firstsibexp_gabapentin secondsibexp_gabapentin firstsibexp_lamotrigine secondsibexp_lamotrigine firstsibexp_levetiracetam secondsibexp_levetiracetam firstsibexp_phenytoin secondsibexp_phenytoin firstsibexp_pregabalin secondsibexp_pregabalin firstsibexp_topiramate secondsibexp_topiramate firstsibexp_valproate secondsibexp_valproate firstsibexp_other secondsibexp_other, i(mumpatid) j(border) 
	 
	 save "$Datadir\NDD_study_PMD\_temp\ord_exposure_expdisc", replace 
restore 

merge m:1 mumpatid border using "$Datadir\NDD_study_PMD\_temp\ord_exposure_expdisc", nogen


********************************************************************************
* Apply any further restrictions to cohort
********************************************************************************
* Drop participants with missing sex
drop if gender == 3
 
 
********************************************************************************
* Output dataset 
********************************************************************************
* output 
save "$Datadir\NDD_study_PMD\NDD_study_data.dta", replace


********************************************************************************
log close 



