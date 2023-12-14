capture log close 
log using "$Logdir\NDD study\LOG_an_NDD_Table1_descriptives.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			24 March 2022
* Description: 		Creation of Table 1 descriptive statistics for NDD study 
* Notes:			
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Install required packages
********************************************************************************
* ssc install table1_mc

********************************************************************************
* Datasets output
********************************************************************************
* 1 - 

 
********************************************************************************
* Contents
********************************************************************************
* 1 - Load and merge exposure and covariate data
* 2 - Prepare formats for data for output
* 3 - Create descriptive statistics using table1_mc package 

********************************************************************************
* 1 - Load data
********************************************************************************
* load pregnancy cohort
use "$Datadir\NDD_study_PMD\NDD_study_data.dta", clear


********************************************************************************
* 2 - Prepare formats for data for output
********************************************************************************
* moved to data derivations 


********************************************************************************
* 3 - Create descriptive statistics using table1_mc package 
********************************************************************************
foreach drug in anydrug /*carbamazepine gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproate other*/ {
	table1_mc,  by(flag_`drug'_preg) ///
					vars( /// 
						 anyindication cat %5.1f \ ///
						 epilepsy bin %5.1f \ ///
						 other_psych_gp bin %5.1f \ ///
						 somatic_cond bin %5.1f \ ///
						 gravidity_cat2 cat %5.1f \ /// 
						 gender cat %5.1f \ ///
						 matage contn %5.1f \ ///
						 marital_derived cat %5.1f \ ///
						 eth5 cat %5.1f \ ///
						 Area2 cat %5.1f \ ///
						 imd5 cat %5.1f \ ///
						 smokstatus cat %5.1f \ ///
						 bmi_cat cat %5.1f \ ///
						 addiction cat %5.1f \ ///
						 consult cat %5.1f \ ///
						 seizure cat %5.1f \ ///
						 antipsychotics_365_prepreg cat %5.1f \ ///
						 antidepressants_365_prepreg cat %5.1f \ ///
						 vom_antiemet_preg cat %5.1f \ ///
						 maternal_NDD_prepreg cat %5.1f \ ///
						 pregstart_year_cat2	cat %5.1f \ ///
						 outcome_ASD bin %5.1f  \ ///
						 outcome_ADHD bin %5.1f \ ///
						 outcome_ID bin %5.1f  ///
						) ///
					nospace onecol missing total(before) ///
					saving("$Datadir\NDD_study_PMD\Outputs\Descriptives\Table1_`drug'.xlsx", replace)
}


foreach indication in anyindication epilepsy other_psych_gp somatic_cond {
	table1_mc,  by(`indication') ///
					vars( /// 
						 flag_anydrug_preg cat %5.1f \ ///
						 gravidity_cat cat %5.1f /// 
						 matage_cat cat %5.1f \ ///
						 marital_derived cat %5.1f \ ///
						 eth5 cat %5.1f \ ///
						 AreaOfResidence cat %5.1f \ ///
						 imd5 cat %5.1f \ ///
						 smokstatus cat %5.1f \ ///
						 bmi_cat cat %5.1f \ ///
						 addiction cat %5.1f \ ///
						 CPRD_consultation_events_cat cat %5.1f \ ///
						 CPRD_seizure_events_cat cat %5.1f \ ///
						 antipsychotics_365_prepreg cat %5.1f \ ///
						 antidepressants_365_prepreg cat %5.1f \ ///
						 vom_antiemet_preg cat %5.1f \ ///
						 pregstart_year_cat2	cat %5.1f  ///
						) ///
					nospace onecol missing total(before) ///
					saving("$Datadir\NDD_study_PMD\Outputs\Descriptives\Table1_`indication'.xlsx", replace)
}

				 

********************************************************************************
log close