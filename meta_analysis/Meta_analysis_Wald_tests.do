cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_Wald_tests.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		18 March 2024
* Description:  Runs Wald tests of primary vs secondary estimates 
* Notes: 		guidance: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4026206/
********************************************************************************
* Contents 
********************************************************************************
* 1 - Check heterogeneity of estimates between CPRD and DOHAD 
* 2 - Check heterogeneity of primary and sibling estimates  
* 3 - Check heterogeneity of primary and indication restricted estimates   

********************************************************************************
* 1 - Check heterogeneity of estimates between CPRD and DOHAD 
********************************************************************************
ssc install sencode 


use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_metaready", clear
drop ASM_n NDD_n 
sencode ASM, gen(ASM_n)
sencode NDD, gen(NDD_n)
sencode country, gen(country_n)

keep ASM ASM_n country_n NDD NDD_n adj_logHR adj_logHRse 
reshape wide adj_logHR adj_logHRse, i(ASM ASM_n NDD NDD_n) j(country_n)

gen wald_stat = ((adj_logHR1-adj_logHR2)^2)/(adj_logHRse1^2 + adj_logHRse2^2) 
gen wald_p = strofreal(round(1-chi2(1, wald_stat), 0.001), "%5.3f")
gen wald_stat_c = strofreal(round(wald_stat, 0.001), "%6.3f")

sort NDD_n ASM_n 
order NDD_n ASM_n wald_stat_c wald_p
save "$Datadir\NDD_study_PMD\Outputs\Meta_analysis\NDD_WALD_prim_country.dta", replace


********************************************************************************
* 2 - Check heterogeneity of primary and sibling estimates  
********************************************************************************
foreach ndd in ASD ID ADHD {
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metan_`ndd'.dta", clear
	
	sencode ASM, gen(ASM_n)
	gen sib_logHR   = log(adj_HR)
	gen sib_logHRse = (log(adj_HRuci) - log(adj_HR))/invnormal(0.975)
	keep ASM* sib*

	merge 1:1 ASM using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_metan_`ndd'.dta", nogen
	gen prim_logHR   = log(adj_HR)
	gen prim_logHRse = (log(adj_HRuci) - log(adj_HR))/invnormal(0.975)
	keep ASM* sib* prim* NDD 	

	gen wald_stat = ((sib_logHR-prim_logHR)^2) / ((sib_logHRse)^2 + (prim_logHRse)^2)
	gen wald_p = strofreal(round(1-chi2(1, wald_stat), 0.001), "%5.3f")
	gen wald_stat_c = strofreal(round(wald_stat, 0.001), "%6.3f")
	
	save "$Datadir\NDD_study_PMD\Outputs\Meta_analysis\_temp\NDD_WALD_prim_sibs_`ndd'.dta", replace
 
}

clear 
foreach ndd in ASD ID ADHD {
	append using "$Datadir\NDD_study_PMD\Outputs\Meta_analysis\_temp\NDD_WALD_prim_sibs_`ndd'.dta"
}
sencode NDD, gen(NDD_n)
sort NDD_n ASM_n 
order NDD_n ASM_n wald_stat_c wald_p


save "$Datadir\NDD_study_PMD\Outputs\Meta_analysis\NDD_WALD_prim_sibs.dta", replace


********************************************************************************
* 3 - Check heterogeneity of primary and indication restricted estimates   
********************************************************************************
clear
foreach NDD in ASD ADHD ID {
	append using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_metan_`NDD'.dta", gen(noind_`NDD')
	
	foreach indic in epilepsy psych somatic {
		append using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metan_`indic'_`NDD'.dta", gen(`indic'_`NDD')
	}
}

egen noind = rowtotal(noind*) 
egen epilepsy = rowtotal(epilepsy*)
egen psych = rowtotal(psych*)
egen somatic = rowtotal(somatic*)

gen indication = ""
replace indication = "No indication" if noind 		== 1
replace indication = "Epilepsy" 	 if epilepsy 	== 1
replace indication = "Psychiatric"	 if psych 		== 1
replace indication = "Somatic"		 if somatic 	== 1
	
sencode ASM, gen(ASM_n)
sencode NDD, gen(NDD_n)
sencode indication, gen(indication_n)

gen adj_logHR   = log(adj_HR)
gen adj_logHRse = (log(adj_HRuci) - log(adj_HR))/invnormal(0.975)
keep ASM* NDD* indication_n adj_log* 
reshape wide adj_logHR adj_logHRse, i(ASM ASM_n NDD NDD_n) j(indication_n)

forvalues i = 2(1)4 {
	gen wald_stat_`i'	 = ((adj_logHR`i' - adj_logHR1)^2) / ((adj_logHRse`i')^2 + adj_logHRse1^2)
	gen wald_p_`i'		 = strofreal(round(1-chi2(1, wald_stat_`i'), 0.001), "%5.3f")
	gen wald_stat_c_`i'	 = strofreal(round(wald_stat_`i', 0.001), "%6.3f")	
}

sort NDD_n ASM_n 
order NDD_n ASM_n wald_stat_c_2 wald_p_2 wald_stat_c_3 wald_p_3  wald_stat_c_4 wald_p_4 
keep ASM_n NDD_n wald_p* wald_stat_c* 

save "$Datadir\NDD_study_PMD\Outputs\Meta_analysis\NDD_WALD_prim_indication.dta", replace



********************************************************************************
cap log close 