cap log close
log using "$Logdir\NDD study\LOG_an_PRIM_survival_by_ASM.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			21 August 2023
* Description : 	Model standardised survival curves (and difference) for NDD outcomes by ASM
*					Developed using https://pclambert.net/software/standsurv/standardized_survival/					
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
cd 	"$Datadir\NDD_study_PMD\Outputs\Primary"

preserve
	statsby mean=r(mean) sd=r(sd) median=r(p50) LQ=r(p25) UQ=r(p75), ///
		by(monother_cat_preg) saving("followup_monother.dta", replace) total ///
		: summarize fup_years, det  
	use "followup_monother.dta", clear
	gen meanSD = 	strofreal(mean, "%5.2f") + " (" + strofreal(sd, "%6.3f") + ")"
	gen medianIQR = strofreal(median, "%5.2f") + " (" + strofreal(LQ , "%5.2f") + "-" + strofreal(UQ, "%5.2f")+ ")"
	save "followup_monother.dta", replace	
restore

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
				   mean_followup median_followup min_followup max_followup LQ_followup UQ_follow_up sd_followup ///
				   mean_followup_case   median_followup_case   min_followup_case   max_followup_case LQ_followup_case UQ_follow_up_case sd_followup_case  ///
				   mean_followup_nocase median_followup_nocase min_followup_nocase max_followup_nocase LQ_followup_nocase UQ_follow_up_nocase sd_followup_nocase  ///   
				   unadj_HR unadj_logHRse unadj_p unadj_HRlci unadj_HRuci ///
				   adj_HR   adj_logHRse   adj_p   adj_HRlci   adj_HRuci ///  
		  using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_HR_byASM.dta", replace

 
* create counts of exposed	  
tab monother_cat_preg, matcell(exposed) gen(mther_)
drop mther_1

preserve
uselabel lb_monothercat, clear
rename value ASM_n
save "$Datadir\NDD_study_PMD\Outputs\Primary\monother_labels.dta", replace
restore

* calculate risk and OR 
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
		local fuplq   = r(p25)
		local fupuq   = r(p75)
		local fupsd   = r(sd)
		
		sum stime_year_`ndd' if monother_cat_preg == `j' & outcome_`ndd' == 1, det
		local fupmean_case = r(mean)
		local fupmed_case  = r(p50)
		local fupmin_case  = r(min)
		local fupmax_case  = r(max)	
		local fuplq_case   = r(p25)
		local fupuq_case   = r(p75)
		local fupsd_case   = r(sd)
		
		
		sum stime_year_`ndd' if monother_cat_preg == `j' & outcome_`ndd' == 0, det
		local fupmean_nocase = r(mean)
		local fupmed_nocase = r(p50)
		local fupmin_nocase = r(min)
		local fupmax_nocase = r(max)
		local fuplq_nocase  = r(p25)
		local fupuq_nocase  = r(p75)
		local fupsd_nocase  = r(sd)		
			
		if `j' == 0 {
			post `memhold' ///
				("`ndd'") (`i') (`j') ///
				(exposed[`k',1]) (cases_`ndd'[2,1]) (exp_case_`ndd'[`k',2]) ///
				(`fupmean') (`fupmed') (`fupmin') (`fupmax') (`fuplq') (`fupuq') (`fupsd') ///
				(`fupmean_case') (`fupmed_case') (`fupmin_case') (`fupmax_case') (`fuplq_case') (`fupuq_case') (`fupsd_case') ///
				(`fupmean_nocase') (`fupmed_nocase') (`fupmin_nocase') (`fupmax_nocase') (`fuplq_nocase') (`fupuq_nocase') (`fupsd_nocase') ///				
				(1) (.) (.) (.) (.) ///
				(1) (.) (.) (.) (.) 			
		}
		if `j' != 0 {
			post `memhold' ///
				("`ndd'") (`i') (`j') ///
				(exposed[`k',1]) (cases_`ndd'[2,1]) (exp_case_`ndd'[`k',2]) ///
				(`fupmean') (`fupmed') (`fupmin') (`fupmax') (`fuplq') (`fupuq') (`fupsd') ///
				(`fupmean_case') (`fupmed_case') (`fupmin_case') (`fupmax_case') (`fuplq_case') (`fupuq_case') (`fupsd_case') ///
				(`fupmean_nocase') (`fupmed_nocase') (`fupmin_nocase') (`fupmax_nocase') (`fuplq_nocase') (`fupuq_nocase') (`fupsd_nocase') ///				
				(exp(unadj_`ndd'_table[1,`j'])) (unadj_`ndd'_table[2,`j']) (unadj_`ndd'_table[4,`j']) ///
				(exp(unadj_`ndd'_table[5,`j'])) (exp(unadj_`ndd'_table[6,`j'])) ///
				(exp(adj_`ndd'_table[1,`j']))   (adj_`ndd'_table[2,`j'])   (adj_`ndd'_table[4,`j']) ///
				(exp(adj_`ndd'_table[5,`j']))   (exp(adj_`ndd'_table[6,`j']))			
		}
	}

	
	* standardised survival function 
	range timevar 4 16 4
	standsurv, at1(mther_2 0 mther_3 0 mther_4 0 mther_5 0 mther_6 0 mther_7 0 mther_8 0 mther_9 0 mther_10 0 mther_11 0) ///
			   at2(mther_2 1 ) ///
			   at3(mther_3 1) ///
			   at4(mther_4 1) ///
			   at5(mther_5 1) ///
			   at6(mther_6 1) ///
			   at7(mther_7 1) ///
			   at8(mther_8 1) ///
			   at9(mther_9 1) ///
			   at10(mther_10 1) ///
			   at11(mther_11 1) ///
			   timevar(timevar) ci se contrast(difference) fail 	
			   
	keep timevar _at* _contrast* 
	drop if timevar == . 
	gen NDD = "`ndd'"
	save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_std_surv_`ndd'.dta", replace 
	
	restore	
}	

* Save dataset  				
postclose `memhold'	

			
			
********************************************************************************		
* 3 - Format output dataset for hazard ratios
********************************************************************************
use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_HR_byASM.dta",  clear
merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Primary\monother_labels.dta", nogen keepusing(ASM_n label)
order NDD_n NDD ASM_n label n_wNDD n_exp n_exp_wNDD
sort NDD_n ASM_n
save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_HR_byASM.dta", replace




********************************************************************************
cap log close 