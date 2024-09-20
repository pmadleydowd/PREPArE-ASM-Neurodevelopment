cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_SENS_HR_CPRD_SWE.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		28 Feb 2023
* Description:  Runs meta-analyses of primary analysis survival estimates 
******************************************************************************
* Contents 
********************************************************************************
* 1 - Combine output from CPRD and DOHAD datasets
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
* 3 - meta-analysis
* 4 - Produce plot 

********************************************************************************
* 1 - Combine output from CPRD and DOHAD datasets
********************************************************************************
forvalues sensan = 1(1)3 { 
	if `sensan' == 1{ // 1.	Restrict cohort to minimum of 4  years follow-up and replicate primary analysis. 					
		local antext = "fup4"
		local SWE_text = "output_LimitFU"
	} 
	else if `sensan' == 2 { // 2.	Replicating main analysis using first-trimester exposure. 
		local antext = "tri1"
		local SWE_text = "output_T1"
	}
	else if `sensan' == 3 { // 3.	2 prescriptions to define `exposed' and replicate primary analysis.
		local antext = "2Rxs"
		local SWE_text = "dohad_output_dx2"
	}
	
	
	import excel "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\R&R Nat Coms\results/`SWE_text'.xlsx", firstrow clear	
	drop *_logHRci95
	gen country = "DOHAD (SWE)"
	rename ASD_logHR 	 adj_logHR1
	rename ID_logHR 	 adj_logHR2
	rename ADHD_logHR 	 adj_logHR3
	rename ASD_logHRse 	 adj_logHRse1
	rename ID_logHRse 	 adj_logHRse2
	rename ADHD_logHRse  adj_logHRse3
	reshape long adj_logHR adj_logHRse, i(label ASM_n country) j(NDD_n)
	gen adj_HR = exp(adj_logHR) 
	gen adj_HRuci = exp(adj_logHR + invnormal(0.975)*adj_logHRse) 
	gen adj_HRlci = exp(adj_logHR - invnormal(0.975)*adj_logHRse)
	gen NDD = "ASD"  if NDD_n == 1
	replace NDD = "ID"   if NDD_n == 2
	replace NDD = "ADHD" if NDD_n == 3


	append using "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_HR_byASM_`sensan'_`antext'.dta" 
	drop if inlist(ASM_n, 0, 11) // remove the entries for 1 Rx from 2Rx sensitivity analyses
	replace country = "CPRD (UK)" if country==""
	replace adj_HR = . if  n_exp_wNDD ==0
	replace adj_HRlci = . if adj_HR == . 
	replace adj_HRuci = . if adj_HR == . 
	replace adj_logHRse = . if adj_HR == . 
	gen meta_exclude = . /*1 if n_exp_wNDD <=3  */
	
	gen strpos = strpos(label, " ")
	replace label = substr(label, 1, strpos-1) if strpos > 0
	replace label = "Pregabalin" if label == "Pregbalin"

	replace adj_logHR = log(adj_HR) if country == "CPRD (UK)"
	sort ASM_n NDD_n country 

	*drop if ASM_n == 0 

	gen ASM = "{bf:" + label + "}"
	bys ASM_n: egen wAverage = total(adj_logHR)

	label variable country "Country"

	cap drop _merge
	save "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_metaready_`sensan'_`antext'.dta", replace
}

********************************************************************************
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************
ssc install sencode

forvalues sensan = 1(1)3 { 
	if `sensan' == 1{ // 1.	Restrict cohort to minimum of 4  years follow-up and replicate primary analysis. 					
		local antext = "fup4"
	} 
	else if `sensan' == 2 { // 2.	Replicating main analysis using first-trimester exposure. 
		local antext = "tri1"
	}
	else if `sensan' == 3 { // 3.	2 prescriptions to define `exposed' and replicate primary analysis.
		local antext = "2Rxs"
	}

	use "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_metaready_`sensan'_`antext'.dta", clear
	keep if meta_exclude != 1

	sencode country, gen(country_n)
	gen log_adj_HRinvV = 1/(adj_logHRse^2) 
	keep ASM_n NDD_n country_n log_adj_HRinvV
	reshape wide log_adj_HRinvV, i(ASM_n NDD_n) j(country_n)
	
	egen sum_invV = rowtotal(log_adj_HRinvV*)
	gen wgt1 = log_adj_HRinvV1/sum_invV
	gen wgt2 = log_adj_HRinvV2/sum_invV
	egen sum_wgt = rowtotal(wgt1 wgt2) 

	keep ASM_n NDD_n wgt1 wgt2 
	reshape long wgt ,i(ASM_n NDD_n) j(country_n)
	decode country_n, gen(country)

	order ASM country NDD wgt*
	keep ASM country NDD wgt*
	sencode country, gen(country_n)
	drop country

	reshape wide wgt, i(ASM_n NDD_n) j(country_n)
	gen dohad_`sensan' = strofreal(100*wgt2, "%3.1f") + "%"
	sort NDD_n ASM_n
	
	keep ASM_n NDD_n dohad_`sensan'
	
	save  "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_wgts_`sensan'_`antext'.dta", replace
}

* prep weights from primary analysis to include in sensitivity table 

use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_wgts.dta", clear
drop if ASM_n == 0 
sencode country, gen(country_n)
drop country
reshape wide wgt, i(ASM_n NDD_n) j(country_n)
gen primary_dohad = strofreal(100*wgt2, "%3.1f") + "%"
sort NDD_n ASM_n
keep ASM_n NDD_n primary_dohad

save "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_primforsens_wgts.dta", replace

********************************************************************************
* 3 - meta-analysis
* https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-015-0024-z
* recommends In small meta-analyses, confidence intervals should supplement or replace the biased point estimate I2.
********************************************************************************
forvalues sensan = 1(1)3 { 
	if `sensan' == 1{ // 1.	Restrict cohort to minimum of 4  years follow-up and replicate primary analysis. 					
		local antext = "fup4"
	} 
	else if `sensan' == 2 { // 2.	Replicating main analysis using first-trimester exposure. 
		local antext = "tri1"
	}
	else if `sensan' == 3 { // 3.	2 prescriptions to define `exposed' and replicate primary analysis.
		local antext = "2Rxs"
	}

	foreach NDD in ASD ADHD ID {
		use "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_metaready_`sensan'_`antext'.dta", clear

		metan adj_logHR adj_logHRse if NDD=="`NDD'" & meta_exclude != 1, by(ASM_n) sortby(country) eform lcols(country) nooverall 
		clear
		set obs 10
		gen ASM = ""
		gen adj_HR = . 
		gen adj_HRlci = . 
		gen adj_HRuci = . 
		gen country = "Combined"
		gen NDD = "`NDD'"
		gen sensan = `sensan'
		 
		local i = 0 
		foreach drug in "Carbamazepine" "Gabapentin" "Lamotrigine" "Levetiracetam" "Phenytoin" "Pregabalin" "Topiramate" "Valproate" "Other" "Polytherapy" {
			local i = `i' + 1
			replace ASM = "{bf:" + "`drug'" + "}" if _n == `i'
			replace adj_HR    = exp(r(bystats)[1,`i']) if _n == `i'
			replace adj_HRlci = exp(r(bystats)[3,`i']) if _n == `i'
			replace adj_HRuci = exp(r(bystats)[4,`i']) if _n == `i'
		}	
		
		save "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_metan_`NDD'_`sensan'_`antext'.dta", replace
	}
}




********************************************************************************
* 4 - Produce table to output 
********************************************************************************
clear 
foreach NDD in ASD ID ADHD {
		append using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_metan_`NDD'.dta"	
}
gen sensan = 0 

forvalues sensan = 1(1)3 { 
	if `sensan' == 1{ // 1.	Restrict cohort to minimum of 4  years follow-up and replicate primary analysis. 					
		local antext = "fup4"
	} 
	else if `sensan' == 2 { // 2.	Replicating main analysis using first-trimester exposure. 
		local antext = "tri1"
	}
	else if `sensan' == 3 { // 3.	2 prescriptions to define `exposed' and replicate primary analysis.
		local antext = "2Rxs"
	}

	foreach NDD in ASD ID ADHD {
		append using "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_metan_`NDD'_`sensan'_`antext'.dta"
	
	}
}

sencode NDD, gen(NDD_n)
sencode ASM, gen(ASM_n)
gen str_HR_CI = strofreal(adj_HR, "%5.2f") + " (" + strofreal(adj_HRlci , "%5.2f") + "-" + strofreal(adj_HRuci, "%5.2f")+ ")"
drop adj* NDD ASM country 
reshape wide str_HR_CI , i(NDD_n ASM_n) j(sensan)
rename str_HR_CI0 primary
rename str_HR_CI1 Fup4Yr
rename str_HR_CI2 Trim1
rename str_HR_CI3 Rx2


merge 1:1 NDD_n ASM_n using "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_primforsens_wgts.dta", nogen

forvalues sensan = 1(1)3 { 
	if `sensan' == 1{ // 1.	Restrict cohort to minimum of 4  years follow-up and replicate primary analysis. 					
		local antext = "fup4"
	} 
	else if `sensan' == 2 { // 2.	Replicating main analysis using first-trimester exposure. 
		local antext = "tri1"
	}
	else if `sensan' == 3 { // 3.	2 prescriptions to define `exposed' and replicate primary analysis.
		local antext = "2Rxs"
	}

	merge 1:1 NDD_n ASM_n using "$Datadir\NDD_study_PMD\Outputs\Sensitivity\NDD_sens_wgts_`sensan'_`antext'.dta", nogen
}




********************************************************************************
cap log close		