cap log close
log using "$Logdir\NDD study\LOG_an_CAUSINF_activecomparator.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			19 April 2022
* Description : 	Model odds ratio of NDD outcomes by ASM for the active comparison
********************************************************************************
* Notes on major updates (Date - description):
********************************************************************************

********************************************************************************
* Output datasets 
********************************************************************************


********************************************************************************
* Contents
********************************************************************************
* 1 - Create environment and load data
* 2 - Calculate absolute risk and hazard ratio according to ASM  
* 3 - Format output dataset for hazard ratios
 
********************************************************************************
* 1 - Create environment and load data
********************************************************************************
use "$Datadir\NDD_study_PMD\NDD_study_data.dta", clear

foreach ndd in NDD ASD ID ADHD {
	gen stime_year_`ndd' = round(stime_`ndd'/365.25,0.001)
	bysort outcome_`ndd': summ  stime_year_`ndd'	
}

********************************************************************************
* 2 - Calculate absolute risks and odds ratios according to ASM  
********************************************************************************
* create dummy vars for categorical confounders
foreach conf in AreaOfResidence gravidity_cat2 consult pregstart_year_cat {
	tab `conf', gen(dummy_`conf')
}
drop dummy_*1

* create confounder list 
global conflist gender matage matage_cubed imd5 addiction seizure antipsychotics_365_prepreg antidepressants_365_prepreg vom_antiemet_preg maternal_NDD_prepreg epilepsy other_psych_gp somatic_cond dummy*

			
* Prepare dataset to store output 
cap postutil close 
tempname memhold 

postfile `memhold' str4 NDD NDD_n ASM_n ///
				   n_exp n_wNDD n_exp_wNDD ///
				   mean_followup median_followup min_followup max_followup ///
				   mean_followup_case   median_followup_case   min_followup_case   max_followup_case ///
				   mean_followup_nocase median_followup_nocase min_followup_nocase max_followup_nocase ///   
				   unadj_HR unadj_logHRse unadj_p unadj_HRlci unadj_HRuci ///
				   adj_HR   adj_logHRse   adj_p   adj_HRlci   adj_HRuci ///  
		  using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp.dta", replace

 
* create counts of exposed	  
tab monother_cat_preg, matcell(exposed) gen(mther_)
drop mther_4 // removing lamotrigine dummy variable to make it the reference group 

preserve
uselabel lb_monothercat, clear
rename value ASM_n
save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\monother_labels.dta", replace
restore

* calculate risk and HR 
local i = 0
foreach ndd in NDD ASD ID ADHD {
	local i = `i'+1
	preserve 
	
	* create counts and follow up time 
	tab outcome_`ndd', matcell(cases_`ndd')
	tab monother_cat_preg outcome_`ndd', matcell(exp_case_`ndd')
	
	stset stime_year_`ndd', f(outcome_`ndd'==1) 
	* unadjusted HR
	stpm2 mther_*, df(4) scale(hazard) vce(cluster mumpatid) failconvlininit
	matrix unadj_`ndd'_table = r(table)
	
	* adjusted HR 
	stpm2 mther_* $conflist, df(4) scale(hazard) vce(cluster mumpatid) failconvlininit
	matrix adj_`ndd'_table = r(table)
	
	* store values 
	forvalues j = 0(1)10 {
		local k = `j' + 1

		sum stime_year_`ndd' if monother_cat_preg == `j' , det
		local fupmean = r(mean)
		local fupmed  = r(p50)
		local fupmin  = r(min)
		local fupmax  = r(max)
		
		sum stime_year_`ndd' if monother_cat_preg == `j' & outcome_`ndd' == 1, det
		local fupmean_case = r(mean)
		local fupmed_case  = r(p50)
		local fupmin_case  = r(min)
		local fupmax_case  = r(max)	
		
		sum stime_year_`ndd' if monother_cat_preg == `j' & outcome_`ndd' == 0, det
		local fupmean_nocase = r(mean)
		local fupmed_nocase = r(p50)
		local fupmin_nocase = r(min)
		local fupmax_nocase = r(max)		
			
		if `j' == 3 { // lamotrigine is ASM_n == 3 (but mther_4)
			post `memhold' ///
				("`ndd'") (`i') (`j') ///
				(exposed[`k',1]) (cases_`ndd'[2,1]) (exp_case_`ndd'[`k',2]) ///
				(`fupmean') (`fupmed') (`fupmin') (`fupmax') ///
				(`fupmean_case') (`fupmed_case') (`fupmin_case') (`fupmax_case') ///
				(`fupmean_nocase') (`fupmed_nocase') (`fupmin_nocase') (`fupmax_nocase') ///				
				(1) (.) (.) (.) (.) ///
				(1) (.) (.) (.) (.) 			
		}
		if `j' < 3 {
			post `memhold' ///
				("`ndd'") (`i') (`j') ///
				(exposed[`k',1]) (cases_`ndd'[2,1]) (exp_case_`ndd'[`k',2]) ///
				(`fupmean') (`fupmed') (`fupmin') (`fupmax') ///
				(`fupmean_case') (`fupmed_case') (`fupmin_case') (`fupmax_case') ///
				(`fupmean_nocase') (`fupmed_nocase') (`fupmin_nocase') (`fupmax_nocase') ///				
				(exp(unadj_`ndd'_table[1,`k'])) (unadj_`ndd'_table[2,`k']) (unadj_`ndd'_table[4,`k']) ///
				(exp(unadj_`ndd'_table[5,`k'])) (exp(unadj_`ndd'_table[6,`k'])) ///
				(exp(adj_`ndd'_table[1,`k']))   (adj_`ndd'_table[2,`k'])   (adj_`ndd'_table[4,`k']) ///
				(exp(adj_`ndd'_table[5,`k']))   (exp(adj_`ndd'_table[6,`k']))			
		}
		if `j' > 3 {
			post `memhold' ///
				("`ndd'") (`i') (`j') ///
				(exposed[`k',1]) (cases_`ndd'[2,1]) (exp_case_`ndd'[`k',2]) ///
				(`fupmean') (`fupmed') (`fupmin') (`fupmax') ///
				(`fupmean_case') (`fupmed_case') (`fupmin_case') (`fupmax_case') ///
				(`fupmean_nocase') (`fupmed_nocase') (`fupmin_nocase') (`fupmax_nocase') ///				
				(exp(unadj_`ndd'_table[1,`j'])) (unadj_`ndd'_table[2,`j']) (unadj_`ndd'_table[4,`j']) ///
				(exp(unadj_`ndd'_table[5,`j'])) (exp(unadj_`ndd'_table[6,`j'])) ///
				(exp(adj_`ndd'_table[1,`j']))   (adj_`ndd'_table[2,`j'])   (adj_`ndd'_table[4,`j']) ///
				(exp(adj_`ndd'_table[5,`j']))   (exp(adj_`ndd'_table[6,`j']))			
		}		
	}
	restore 
}	

* Save dataset  				
postclose `memhold'	

			
			
********************************************************************************		
* 3 - Format output dataset for hazard ratios
********************************************************************************
use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp.dta", clear
merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\monother_labels.dta", nogen keepusing(ASM_n label)
order NDD_n NDD ASM_n label n_wNDD n_exp n_exp_wNDD
sort NDD_n ASM_n
save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp.dta", replace


********************************************************************************
log close