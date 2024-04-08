cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_Causinf_HR_CPRD_SWE.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		28 Feb 2023
* Description:  Runs meta-analyses of sibling design and active coparison survival estimates 
******************************************************************************
* Contents 
********************************************************************************
* A - sibling analyses
	* 1a - Combine output from CPRD and DOHAD datasets
	* 2a - Calculate the weights for display in figure (inverse variance use in metan)
	* 3a - meta-analysis
* B - active comparators 
	* 1b - Combine output from CPRD and DOHAD datasets
	* 2b - Calculate the weights for display in figure (inverse variance use in metan)
	* 3b - meta-analysis
* 4 - Produce plots for combined estimates
* 5 - Produce forest plots for country specific and combined estimates 


********************************************************************************
* A - sibling analyses
* 1a - Combine output from CPRD and DOHAD datasets
********************************************************************************

import excel "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\Results 2023-11-21 (active comp & sibs).xlsx", sheet("sibs") firstrow clear
*destring ASD* ADHD* ID*, replace
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

append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_discordant_siblings.dta", 
drop if NDD == "NDD"
replace NDD_n = NDD_n - 1 if country == "" 
replace country = "CPRD (UK)" if country==""
replace adj_HR = . if n_exp_wNDD == 0  
replace adj_HRlci = . if adj_HR == . 
replace adj_HRuci = . if adj_HR == . 
replace adj_logHRse = . if adj_HR == . 
gen meta_exclude = . /*1 if n_exp_wNDD <=3 */ 
replace label = "Pregabalin" if label == "Pregbalin"

replace adj_logHR = log(adj_HR) if country == "CPRD (UK)"
sort ASM_n NDD_n country 

*drop if ASM_n == 0 

gen ASM = "{bf:" + label + "}"
bys ASM_n: egen wAverage = total(adj_logHR)

label variable country "Country"

cap drop _merge
save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metaready", replace



********************************************************************************
* 2a - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************

use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metaready", clear
keep if meta_exclude != 1

ssc install sencode
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
save  "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_wgts.dta", replace

sencode country, gen(country_n)
drop country
reshape wide wgt, i(ASM_n NDD_n) j(country_n)
gen cprd  = round(100*wgt1,0.1)
gen dohad = round(100*wgt2,0.1)
sort NDD_n ASM_n


********************************************************************************
* 3a - meta-analysis
* https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-015-0024-z
* recommends In small meta-analyses, confidence intervals should supplement or replace the biased point estimate I2.
********************************************************************************
foreach NDD in ASD ADHD ID {
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metaready", clear

	metan adj_logHR adj_logHRse if NDD=="`NDD'" & meta_exclude != 1, by(ASM_n) sortby(country) eform lcols(country) nooverall 
	clear
	set obs 10
	gen ASM = ""
	gen adj_HR = . 
	gen adj_HRlci = . 
	gen adj_HRuci = . 
	gen country = "Combined"
	gen NDD = "`NDD'"
	 
	local i = 0 
	foreach drug in "Carbamazepine" "Gabapentin" "Lamotrigine" "Levetiracetam" "Phenytoin" "Pregabalin" "Topiramate" "Valproate" "Other" "Polytherapy" {
		local i = `i' + 1
		replace ASM = "{bf:" + "`drug'" + "}" if _n == `i'
		replace adj_HR    = exp(r(bystats)[1,`i']) if _n == `i'
		replace adj_HRlci = exp(r(bystats)[3,`i']) if _n == `i'
		replace adj_HRuci = exp(r(bystats)[4,`i']) if _n == `i'
	}	
	
	save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metan_`NDD'.dta", replace
}

clear 
foreach NDD in ASD ADHD ID {
	append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metan_`NDD'.dta"
}	

********************************************************************************
* B - active comparator 
* 1b - Combine output from CPRD and DOHAD datasets
********************************************************************************

import excel "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\Results 2023-11-21 (active comp & sibs).xlsx", sheet("active comp") firstrow clear
*destring ASD* ADHD* ID*, replace
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

append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp.dta", 
drop if NDD == "NDD"
replace NDD_n = NDD_n - 1 if country == "" 
replace country = "CPRD (UK)" if country==""
replace adj_HR = . if n_exp_wNDD == 0  
replace adj_HRlci = . if adj_HR == . 
replace adj_HRuci = . if adj_HR == . 
replace adj_logHRse = . if adj_HR == . 
gen meta_exclude = . /*1 if n_exp_wNDD <=3*/  

replace label = "Pregabalin" if label == "Pregbalin"

replace adj_logHR = log(adj_HR) if country == "CPRD (UK)"
sort ASM_n NDD_n country 

*drop if ASM_n == 3 

replace label = "No ASM" if label == "No ASM exposure"
gen ASM = "{bf:" + label + "}"
bys ASM_n: egen wAverage = total(adj_logHR)

label variable country "Country"

cap drop _merge
save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metaready", replace



********************************************************************************
* 2b - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************

use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metaready", clear
keep if meta_exclude != 1

ssc install sencode
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
save  "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_wgts.dta", replace

sencode country, gen(country_n)
drop country
reshape wide wgt, i(ASM_n NDD_n) j(country_n)
gen cprd  = round(100*wgt1,0.1)
gen dohad = round(100*wgt2,0.1)
sort NDD_n ASM_n

********************************************************************************
* 3b - meta-analysis
* https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-015-0024-z
* recommends In small meta-analyses, confidence intervals should supplement or replace the biased point estimate I2.
********************************************************************************
foreach NDD in ASD ADHD ID {
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metaready", clear

	metan adj_logHR adj_logHRse if NDD=="`NDD'" & meta_exclude != 1, by(ASM_n) sortby(country) eform lcols(country) nooverall 
	clear
	set obs 10
	gen ASM = ""
	gen adj_HR = . 
	gen adj_HRlci = . 
	gen adj_HRuci = . 
	gen country = "Combined"
	gen NDD = "`NDD'"
	 
	local i = 0 
	foreach drug in "No ASM" "Carbamazepine" "Gabapentin" "Levetiracetam" "Phenytoin" "Pregabalin" "Topiramate" "Valproate" "Other" "Polytherapy" {
		local i = `i' + 1
		replace ASM = "{bf:" + "`drug'" + "}" if _n == `i'
		replace adj_HR    = exp(r(bystats)[1,`i']) if _n == `i'
		replace adj_HRlci = exp(r(bystats)[3,`i']) if _n == `i'
		replace adj_HRuci = exp(r(bystats)[4,`i']) if _n == `i'
	}	
	
	save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metan_`NDD'.dta", replace
}

clear 
foreach NDD in ASD ADHD ID {
	append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metan_`NDD'.dta"
}	


********************************************************************************
* 4 - Produce plots for combined estimates
********************************************************************************
ssc install addplot


* A - Produce forest plots for combined estimates of sibling estimates
********************************************************************************	
foreach ndd in "ASD" "ID" "ADHD" {
	* collate data 
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metaready", clear
	merge 1:1 ASM_n NDD_n country using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_wgts.dta"
	foreach NDD in ASD ADHD ID {
		append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metan_`NDD'.dta"
	}

	* prepare data 
	keep if NDD == "`ndd'" 	
	drop if _merge == 2 
	keep if inlist(country, "Combined")

	insobs 1, before(1)
	replace adj_HR = 1 if _n ==1 
	replace adj_HRlci = 1 if _n ==1 
	replace adj_HRuci = 1 if _n ==1 
	replace ASM = "{bf:No ASM}" if _n == 1
	replace country = "Combined" if _n == 1	
	drop ASM_n
	sencode ASM, gen(ASM_n)

	sencode country, gen(country_n)
	sort ASM_n country_n 
	order ASM country_n 

	keep ASM* country* NDD adj_HR* wgt 
	
	* update label for phenytoin and remove combined estimates for Autism and ADHD
	replace ASM = "{bf:Phenytoin*}" if ASM == "{bf:Phenytoin}" 
	if "`ndd'" == "ASD" | "`ndd'" == "ADHD" { 
		replace adj_HR 		= . if ASM == "{bf:Phenytoin*}"
		replace adj_HRlci 	= . if ASM == "{bf:Phenytoin*}"
		replace adj_HRuci 	= . if ASM == "{bf:Phenytoin*}"
	}

	* Add additional rows
	gen obsorder = _n
	expand 2 if country_n == 1, gen(expanded1)
	expand 2 if country_n == 3, gen(expanded2)

	* add character versions of numeric variables - added as not available for combined 
	gen adj_HR_str = "" + strofreal(adj_HR,"%5.2f") + "" if adj_HR != . 
	replace adj_HR_str =  "" + strofreal(adj_HR,"%5.2f") + " (Reference)" if ASM_n == 1 & adj_HR != . 
	
	gen wgt_str = strofreal(100*wgt, "%5.1f") + "%"  if wgt !=.			   

	* Remove data for additional rows or where estimate not possible
	foreach var in adj_HR adj_HRlci adj_HRuci wgt {
		replace `var'=. if expanded1==1 | expanded2 == 1
	} 
	foreach var in adj_HR_str wgt_str country {
		replace `var'="" if expanded1==1 | expanded2 == 1
	} 
	replace wgt_str = "" if country == "Combined"

	* sort data
	gsort  +ASM_n country_n -expanded1 +expanded2
	by ASM_n: gen _seq=_n

	* Update order
	drop if _seq==1
	drop obsorder
	gen obsorder = _n
	gsort -obsorder
	gen graphorder = _n
	sort graphorder

	* Create column headers
	summ graphorder
	replace ASM = "" if _seq == 1
	drop if _seq==1
	* Adjust position of ASM label 
	replace graphorder = graphorder + 0.2 if _seq == 1 	
	
	* Adjust position of OR text 
	gen graphorder_or = .
	replace graphorder_or = graphorder + 0.3
	
	* create position for weight text
	gen wgt_pos = . 
	replace wgt_pos = 8.5
	
	* save for text output in figure 
	preserve 
	keep graphorder ASM country 
	save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\graphready_combinedonly_sibs_`ndd'.dta", replace
	restore 

	replace adj_HRuci = round(7.98, .001) if adj_HRuci>=8
	replace adj_HRlci = round(.182, .001) if adj_HRlci<=.18
	
	* produce figures
	twoway ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if round(adj_HRuci,0.001) != 7.98 & round(adj_HRlci,0.001) !=.182, hor legend(off) col(black)  msize(.9)) ///
		(rspike adj_HRuci adj_HR graphorder if inrange(adj_HRuci, 0, 7.98) & round(adj_HRlci,0.001) == 0.182, horiz lc(black)) ///
		(rspike adj_HRlci adj_HR  graphorder if inrange(adj_HRlci, 0, 7.98) & round(adj_HRuci,0.001) == 7.98, horiz lc(black)) ///
		(rcap adj_HRuci adj_HRuci graphorder if inrange(adj_HRuci, 0, 7.98) & round(adj_HRlci, 0.001) == 0.182, horiz lc(black) msize(.9)) ///
		(rcap adj_HRlci adj_HRlci  graphorder if inrange(adj_HRlci, .182, 7.98) & round(adj_HRuci,0.001) == 7.98, horiz lc(black) msize(.9)) ///
		(pcarrow graphorder adj_HR graphorder adj_HRuci if round(adj_HRuci,0.001) == 7.98,   color(black) msize(.9)) ///
		(pcarrow  graphorder adj_HR graphorder adj_HRlci if round(adj_HRlci,0.001) == 0.182,  color(black) msize(.9)) ///
		(scatter graphorder_or adj_HR, m(i) mlab(adj_HR_str) mlabsize(2.5) mlabcol(black)) ///
		(scatter graphorder adj_HR if _seq==2 , legend(off) msize(1.75)  ms(D) ) ///
		, ///
		xline(1, lp(-) lcol(gray))  											///
		xscale(log  range(0.18 8)) ///		
		xlab(0.2 "0.2" 0.5 "0.5" 1 2 5 , nogrid labsize(2.5) format(%9.1f) tlength(0.8)) ///
		xtitle("Within-family HR (95%CI)", size(2.5))  ///
		ylab(none) ytitle("") yscale(lcolor(none) range(.5 12))	///
		graphregion(color(white) margin(zero) lcolor(black) lwidth(zero) fcolor(none))  ///
		plotregion(margin(none) lcolor(black) lwidth(zero) fcolor(none)) ///
		legend(off) ///
		 fxsize(150) ///
		 fysize(80) ///
		ysize(7) xsize(10) ///
		name(forest_`ndd', replace) scheme(tab2) title("{bf:`ndd'}", xoffset(0) size(*1.15)) yline(1.5(1)11, lc(gray%15))

}

gen varx2   = .
replace varx2   = 0.035


graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(30 0 0 5)) ysize(5) xsize(11.7) name("combined_sibs", replace) title("{bf:A - Sibling comparison}", pos(11)) 
	
	
	addplot 1: (scatter graphorder varx2 , m(i) mlab(ASM) mlabsize(3) mlabcol(black)) ///
	, 	///	
		legend(off)  norescaling	plotregion(margin(zero) lcolor(black) lwidth(zero))

		gr_edit .plotregion1.graph1.title.text = {}
		gr_edit .plotregion1.graph1.title.text.Arrpush {bf:Autism}
		gr_edit .plotregion1.graph2.title.text = {}
		gr_edit .plotregion1.graph2.title.text.Arrpush {bf:Intellectual Disability}
			
		gr_edit .plotregion1.graph1.plotregion1.plot9.style.editstyle marker(fillcolor("135 0 82*.5")) editcopy
		gr_edit .plotregion1.graph1.plotregion1.plot9.style.editstyle marker(linestyle(color(black))) editcopy

		gr_edit .plotregion1.graph2.plotregion1.plot9.style.editstyle marker(fillcolor("84 185 134")) editcopy
		gr_edit .plotregion1.graph2.plotregion1.plot9.style.editstyle marker(linestyle(color(black))) editcopy
		
		gr_edit .plotregion1.graph3.plotregion1.plot9.style.editstyle marker(linestyle(color(black))) editcopy

		
* B - Produce forest plots for combined estimates of active comparator estimates
********************************************************************************	

foreach ndd in "ASD" "ID" "ADHD" {
	* collate data 
	
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metaready", clear
	merge 1:1 ASM_n NDD_n country using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_wgts.dta"
	foreach NDD in ASD ADHD ID {
		append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metan_`NDD'.dta"
	}

	* prepare data 
	keep if NDD == "`ndd'" 	
	drop if _merge == 2 
	keep if inlist(country, "Combined")

	insobs 1, before(4)
	replace adj_HR = 1 if _n ==4 
	replace adj_HRlci = 1 if _n ==4 
	replace adj_HRuci = 1 if _n ==4 
	replace ASM = "{bf:Lamotrigine}" if _n == 4
	replace country = "Combined" if _n == 4	
	drop ASM_n
	sencode ASM, gen(ASM_n)
	
	sencode country, gen(country_n)
	sort ASM_n country_n 
	order ASM country_n 

	keep ASM* country* NDD adj_HR* wgt 


	* Add additional rows
	gen obsorder = _n
	expand 2 if country_n == 1, gen(expanded1)
	expand 2 if country_n == 3, gen(expanded2)

	* add character versions of numeric variables - added as not available for combined 
	gen adj_HR_str = "" + strofreal(adj_HR,"%5.2f") + "" if adj_HR != .
	replace adj_HR_str =  "" + strofreal(adj_HR,"%5.2f") + " (Reference)" if ASM_n == 4 & adj_HR != . 	
	gen wgt_str = strofreal(100*wgt, "%5.1f") + "%"  if wgt !=.			   

	* Remove data for additional rows or where estimate not possible
	foreach var in adj_HR adj_HRlci adj_HRuci wgt {
		replace `var'=. if expanded1==1 | expanded2 == 1
	} 
	foreach var in adj_HR_str wgt_str country {
		replace `var'="" if expanded1==1 | expanded2 == 1
	} 
	replace wgt_str = "" if country == "Combined"

	* sort data
	gsort  +ASM_n country_n -expanded1 +expanded2
	by ASM_n: gen _seq=_n

	* Update order
	drop if _seq==1
	drop obsorder
	gen obsorder = _n
	gsort -obsorder
	gen graphorder = _n
	sort graphorder

	* Create column headers
	summ graphorder
	replace ASM = "" if _seq == 1
	drop if _seq==1
	* Adjust position of ASM label 
	replace graphorder = graphorder + 0.2 if _seq == 1 	
	
	* Adjust position of OR text 
	gen graphorder_or = .
	replace graphorder_or = graphorder + 0.3
	
	* create position for weight text
	gen wgt_pos = . 
	replace wgt_pos = 8.5
	
	* save for text output in figure 
	preserve 
	keep graphorder ASM country 
	save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\graphready_combinedonly_activecomp_`ndd'.dta", replace
	restore 

	replace adj_HRuci = round(7.98, .001) if adj_HRuci>=8
	replace adj_HRlci = round(.182, .001) if adj_HRlci<=.18

	twoway ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if round(adj_HRuci,0.001) != 7.98 & round(adj_HRlci,0.001) !=.182, hor legend(off) col(black)  msize(.9)) ///
		(rspike adj_HRuci adj_HR graphorder if inrange(adj_HRuci, 0, 7.98) & round(adj_HRlci,0.001) == 0.182, horiz lc(black)) ///
		(rspike adj_HRlci adj_HR  graphorder if inrange(adj_HRlci, 0, 7.98) & round(adj_HRuci,0.001) == 7.98, horiz lc(black)) ///
		(rcap adj_HRuci adj_HRuci graphorder if inrange(adj_HRuci, 0, 7.98) & round(adj_HRlci, 0.001) == 0.182, horiz lc(black)) ///
		(rcap adj_HRlci adj_HRlci  graphorder if inrange(adj_HRlci, .182, 7.98) & round(adj_HRuci,0.001) == 7.98, horiz lc(black)) ///
		(pcarrow graphorder adj_HR graphorder adj_HRuci if round(adj_HRuci,0.001) == 7.98,   color(black) msize(.9)) ///
		(pcarrow  graphorder adj_HR graphorder adj_HRlci if round(adj_HRlci,0.001) == 0.182,  color(black) msize(.9)) ///
		(scatter graphorder_or adj_HR, m(i) mlab(adj_HR_str) mlabsize(2.5) mlabcol(black)) ///
		(scatter graphorder adj_HR if _seq==2 , legend(off) msize(1.75)  ms(D) ) ///
		, ///
		xline(1, lp(-) lcol(gray))  											///
		xscale(log  range(0.18 8)) ///		
		xlab(0.2 "0.2" 0.5 "0.5" 1 2 5 , nogrid labsize(2.5) format(%9.1f) tlength(0.8)) ///
		xtitle("HR (95%CI)", size(2.5))  ///
		ylab(none) ytitle("") yscale(lcolor(none) range(.5 12))	///
		graphregion(color(white) margin(zero) lcolor(black) lwidth(zero) fcolor(none))  ///
		plotregion(margin(none) lcolor(black) lwidth(zero) fcolor(none)) ///
		legend(off) ///
		 fxsize(150) ///
		 fysize(80) ///
		ysize(7) xsize(10) ///
		name(forest_`ndd', replace) scheme(tab2) title("{bf:`ndd'}", xoffset(0) size(*1.15)) yline(1.5(1)11, lc(gray%15))

}

gen varx2   = .
replace varx2   = 0.035


graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white)) imargin(0 7 0 0) graphregion(margin(30 0 0 5)) ysize(5) xsize(11.7) name("combined_activecomp", replace) title("{bf:B - Active comparison with Lamotrigine}", pos(11)) 
	
	
	addplot 1: (scatter graphorder varx2 , m(i) mlab(ASM) mlabsize(3) mlabcol(black)) ///
	, 	///	
		legend(off)  norescaling	plotregion(margin(zero) lcolor(black) lwidth(zero)) 

		gr_edit .plotregion1.graph1.title.text = {}
		gr_edit .plotregion1.graph1.title.text.Arrpush {bf:Autism}
		gr_edit .plotregion1.graph2.title.text = {}
		gr_edit .plotregion1.graph2.title.text.Arrpush {bf:Intellectual Disability}
			
		gr_edit .plotregion1.graph1.plotregion1.plot9.style.editstyle marker(fillcolor("135 0 82*.5")) editcopy
		gr_edit .plotregion1.graph1.plotregion1.plot9.style.editstyle marker(linestyle(color(black))) editcopy

		gr_edit .plotregion1.graph2.plotregion1.plot9.style.editstyle marker(fillcolor("84 185 134")) editcopy
		gr_edit .plotregion1.graph2.plotregion1.plot9.style.editstyle marker(linestyle(color(black))) editcopy
		
		gr_edit .plotregion1.graph3.plotregion1.plot9.style.editstyle marker(linestyle(color(black))) editcopy


* C - Combine plots 		
********************************************************************************	
graph export "$Graphdir\NDD_study_PMD\Causinf_sibs_survival_analysis_combined_only.png", replace width(2400) height(1600) name("combined_sibs") 
graph export "$Graphdir\NDD_study_PMD\Causinf_activecomp_survival_analysis_combined_only.png", replace width(2400) height(1600) name("combined_activecomp") 

graph combine combined_sibs combined_activecomp, cols(1) graphregion(color(white)) name("combined", replace) 
graph export "$Graphdir\NDD_study_PMD\Causinf_survival_analysis_combined_only.png", replace width(2400) height(1600) name("combined") 


********************************************************************************	
* 5 - Produce forest plots for country specific and combined estimates 
********************************************************************************	
* A - Produce forest plots for sibling estimates
********************************************************************************	

foreach ndd in "ASD" "ID" "ADHD" {

	* collate data 
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metaready", clear
	merge 1:1 ASM_n NDD_n country using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_wgts.dta"
	foreach NDD in ASD ADHD ID {
		append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_sibs_metan_`NDD'.dta"
	}
	gen str_HR_CI = strofreal(adj_HR, "%5.2f") + " (" + strofreal(adj_HRlci , "%5.2f") + "-" + strofreal(adj_HRuci, "%5.2f")+ ")"
	
	* prepare data 
	keep if NDD == "`ndd'" 	
	drop if _merge == 2 
	keep if inlist(country, "CPRD (UK)", "Combined", "DOHAD (SWE)")
	
	if "`ndd'" == "ASD"{
		local ndd_text = "Autism"
	}
	if "`ndd'" == "ID"{
		local ndd_text = "Intellectual disability"
	}	
	if "`ndd'" == "ADHD"{
		local ndd_text = "ADHD"
	}	
	 

	/*
	gen NDD_n = 1 if NDD == "ASD"
	replace NDD_n = 2 if NDD == "ID"
	replace NDD_n = 3 if NDD == "ADHD"
	label define lb_NDD 1 "ASD" 2 "ID" 3 "ADHD" 	
	label values NDD_n lb_NDD
	*/

	sort ASM_n
	drop ASM_n
	replace ASM = "{bf:No ASM}" if ASM == "{bf:No ASM exposure}"
	sencode ASM, gen(ASM_n)
	sencode country, gen(country_n)
	sort ASM_n country_n 
	order ASM country_n 

	keep ASM* country* NDD adj_HR* wgt str_HR_CI 

	replace country = "Reference" if ASM_n == 1

	* Add additional rows
	gen obsorder = _n
	expand 2 if country_n == 1, gen(expanded1)
	expand 2 if country_n == 3, gen(expanded2)

	* add character versions of numeric variables - added as not available for combined 
	gen adj_HR_str = strofreal(adj_HR,"%5.2f") if adj_HR != . 
	gen wgt_str = strofreal(100*wgt, "%5.1f") + "%"  if wgt !=.			   

	* Remove data for additional rows or where estimate not possible
	foreach var in adj_HR adj_HRlci adj_HRuci wgt {
		replace `var'=. if expanded1==1 | expanded2 == 1
	} 
	foreach var in adj_HR_str wgt_str country {
		replace `var'="" if expanded1==1 | expanded2 == 1
	} 
	replace wgt_str = "" if country == "Combined"

	* sort data
	gsort  +ASM_n country_n -expanded1 +expanded2
	by ASM_n: gen _seq=_n

	* Update order
	drop obsorder
	gen obsorder = _n
	gsort -obsorder
	gen graphorder = _n
	sort graphorder

	* Create column headers
	summ graphorder
	replace ASM = "" if _seq != 1

	* Adjust position of ASM label 
	replace graphorder = graphorder + 0.2 if _seq == 1 	
	
	* Adjust position of HR text 
	gen graphorder_HR = .
	replace graphorder_HR = graphorder + 0.4
	
	* create position for weight text
	gen wgt_pos = . 
	replace wgt_pos = 53
	
	* save for text output in figure 
	preserve 
	keep graphorder ASM country 
	save "$Datadir\NDD_study_PMD\Outputs\Causal_inference\graphready_allcountries_`ndd'.dta", replace
	restore 

	replace adj_HRuci = 50 if adj_HRuci> 50 & adj_HRuci != . 
	replace adj_HRlci = round(.1, .1) if adj_HRlci<.1

	replace country = "UK" if country=="CPRD (UK)"
	replace country = "Sweden" if country=="DOHAD (SWE)"
	* produce figures
	twoway ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==2  & adj_HRuci!=50 & !inrange(adj_HRlci, 0, 0.101), hor legend(off) col(black)  msize(.9)) ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==3  & adj_HRuci!=50 & !inrange(adj_HRlci, 0, 0.101), hor legend(off) col(black) msize(.9)) ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==4  & adj_HRuci!=50 & !inrange(adj_HRlci, 0, 0.101), hor legend(off) col(black)  msize(.9)) 	///
		(rspike adj_HRuci adj_HR graphorder if inrange(adj_HRuci, 0, 49.99) & inrange(adj_HRlci, 0, 0.101), horiz lc(black)) ///
		(rspike adj_HRlci adj_HR  graphorder if inrange(adj_HRlci, .1, 49.99) & adj_HRuci==50, horiz lc(black)) ///
		(rcap adj_HRuci adj_HRuci graphorder if inrange(adj_HRuci, 0, 49.99) & inrange(adj_HRlci, 0, 0.101), horiz lc(black) msize(.9)) ///
		(rcap adj_HRlci adj_HRlci  graphorder if inrange(adj_HRlci, .1, 49.99) & adj_HRuci==50, horiz lc(black) msize(.9)) ///
		(pcarrow graphorder adj_HR graphorder adj_HRuci if adj_HRuci==50,   color(black) msize(.9)) ///
		(pcarrow  graphorder adj_HR graphorder adj_HRlci if inrange(adj_HRlci, 0, 0.101),  color(black) msize(.9)) ///
		(scatter graphorder_HR adj_HR, m(i) mlab(adj_HR_str) mlabsize(1.4) mlabcol(black)) ///
		(scatter graphorder adj_HR if _seq==4, legend(off) col(black) msize(1.1)  ms(D) mfcolor(white) mlcolor(black)  mlwidth(.2)) ///
		(scatter graphorder adj_HR if _seq==2, legend(off) col(black) msize(.9)  ms(S) ) ///
		(scatter graphorder adj_HR if _seq==3, legend(off) col(black) msize(.9)  ms(O))  ///
		, ///
		xline(1, lp(-) lcol(gray))  											///
		xscale(log  range(0.095 51)) ///		
		xlab(0.1 0.2 0.5 1 2 5 10 20 40, grid labsize(2) format(%9.1f) tlength(0.8)) ///
		xtitle("")  ///
		ylab(none) ytitle("") yscale(lcolor(white))	///
		graphregion(color(white) margin(zero))  ///
		plotregion(margin(zero)) ///
		legend(off) ///
		fxsize(100) ///
		fysize(100) ///
		ysize(11.7) xsize(8.3) ///
		name(forest_`ndd', replace) scheme(tab2) title("{bf:`ndd_text'}", xoffset(0) size(*.5))
		
		replace wgt_str = "Weight" if ASM=="{bf:Any ASM}"
		replace wgt_pos = wgt_pos-.4 
		addplot :  (scatter graphorder wgt_pos, m(i) mlab(wgt_str) mlabsize(1.4) mlabcol(black)) ///		
	, 	///	
		legend(off)  norescaling	

}

gen varx1   = .
gen varx2   = .
replace varx1   = 0.01
replace varx2   = 0.02


graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:Adjusted Within-Family Hazard Ratio (95% CI)}", size(2))
	
	
	addplot 1: (scatter graphorder varx1 , m(i) mlab(ASM) mlabsize(2) mlabcol(black)) ///
	, 	///	
		legend(off)  norescaling
	
	addplot 1: (scatter graphorder varx2 , m(i) mlab(country) mlabsize(2) mlabcol(black)) ///
	, 	///	
		legend(off)  norescaling	
	
		/*
addplot 2:  ///
	, 	///	
		legend(off)  norescaling	plotregion(color("202 228 241%30")) bgcolor("202 228 241%30") title("", box bexpand bcolor("202 228 241%30"))
	*/

	
graph export "$Graphdir\NDD_study_PMD\Causalinf_sibling_survival_analysis.png", replace width(2400) height(1600)
	
* B - Produce forest plots for active comparator estimates
********************************************************************************	
foreach ndd in "ASD" "ID" "ADHD" {

	* collate data 
	use "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metaready", clear
	merge 1:1 ASM_n NDD_n country using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_wgts.dta"
	foreach NDD in ASD ADHD ID {
		append using "$Datadir\NDD_study_PMD\Outputs\Causal_inference\NDD_causinf_activecomp_metan_`NDD'.dta"
	}
	gen str_HR_CI = strofreal(adj_HR, "%5.2f") + " (" + strofreal(adj_HRlci , "%5.2f") + "-" + strofreal(adj_HRuci, "%5.2f")+ ")"

	
	* prepare data 
	keep if NDD == "`ndd'" 	
	drop if _merge == 2 
	keep if inlist(country, "CPRD (UK)", "Combined", "DOHAD (SWE)")

	if "`ndd'" == "ASD"{
		local ndd_text = "Autism"
	}
	if "`ndd'" == "ID"{
		local ndd_text = "Intellectual disability"
	}	
	if "`ndd'" == "ADHD"{
		local ndd_text = "ADHD"
	}		
	
	/*
	gen NDD_n = 1 if NDD == "ASD"
	replace NDD_n = 2 if NDD == "ID"
	replace NDD_n = 3 if NDD == "ADHD"
	label define lb_NDD 1 "ASD" 2 "ID" 3 "ADHD" 	
	label values NDD_n lb_NDD
	*/

	sort ASM_n
	drop ASM_n
	sencode ASM, gen(ASM_n)
	sencode country, gen(country_n)
	sort ASM_n country_n 
	order ASM country_n 

	keep ASM* country* NDD adj_HR* wgt str_HR_CI 
	
	drop if ASM_n == 4 & country == "DOHAD (SWE)"
	replace country = "Reference" if ASM_n == 4


	* Add additional rows
	gen obsorder = _n
	expand 2 if country_n == 1, gen(expanded1)
	expand 2 if country_n == 3, gen(expanded2)

	* add character versions of numeric variables - added as not available for combined 
	gen adj_HR_str = strofreal(adj_HR,"%5.2f") if adj_HR != . 
	gen wgt_str = strofreal(100*wgt, "%5.1f") + "%"  if wgt !=.			   

	* Remove data for additional rows or where estimate not possible
	foreach var in adj_HR adj_HRlci adj_HRuci wgt {
		replace `var'=. if expanded1==1 | expanded2 == 1
	} 
	foreach var in adj_HR_str wgt_str country {
		replace `var'="" if expanded1==1 | expanded2 == 1
	} 
	replace wgt_str = "" if country == "Combined"

	* sort data
	gsort  +ASM_n country_n -expanded1 +expanded2
	by ASM_n: gen _seq=_n

	* Update order
	drop obsorder
	gen obsorder = _n
	gsort -obsorder
	gen graphorder = _n
	sort graphorder

	* Create column headers
	summ graphorder
	replace ASM = "" if _seq != 1

	* Adjust position of ASM label 
	replace graphorder = graphorder + 0.2 if _seq == 1 	
	
	* Adjust position of HR text 
	gen graphorder_HR = .
	replace graphorder_HR = graphorder + 0.4
	
	* create position for weight text
	gen wgt_pos = . 
	replace wgt_pos = 8.5
	
	* save for text output in figure 
	preserve 
	keep graphorder ASM country 
	save "$Datadir\NDD_study_PMD\Outputs\Primary\graphready_`ndd'_active_comp.dta", replace
	restore 

	replace adj_HRuci = 8 if adj_HRuci>8 & adj_HRuci != . 
	replace adj_HRlci = .125 if adj_HRlci<.125

	replace country = "UK" if country=="CPRD (UK)"
	replace country = "Sweden" if country=="DOHAD (SWE)"
	* produce figures
	twoway ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==2  & adj_HRuci!=8 & adj_HRlci!=.125, hor legend(off) col(black)  msize(.9)) ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==3  & adj_HRuci!=8 & adj_HRlci!=.125, hor legend(off) col(black) msize(.9)) ///
		(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==4  & adj_HRuci!=8 & adj_HRlci!=.125, hor legend(off) col(black)  msize(.9)) 	///
		(rspike adj_HRuci adj_HR graphorder if inrange(adj_HRuci, 0, 7.99) & adj_HRlci==.125, horiz lc(black)) ///
		(rspike adj_HRlci adj_HR  graphorder if inrange(adj_HRlci, .125, 7.99) & adj_HRuci==8, horiz lc(black)) ///
		(rcap adj_HRuci adj_HRuci graphorder if inrange(adj_HRuci, 0, 7.99) & adj_HRlci==.125, horiz lc(black)) ///
		(rcap adj_HRlci adj_HRlci  graphorder if inrange(adj_HRlci, .125, 7.99) & adj_HRuci==8, horiz lc(black)) ///
		(pcarrow graphorder adj_HR graphorder adj_HRuci if adj_HRuci==8,   color(black) msize(.9)) ///
		(pcarrow  graphorder adj_HR graphorder adj_HRlci if inrange(adj_HRlci, 0, 0.125),  color(black) msize(.9)) ///
		(scatter graphorder_HR adj_HR, m(i) mlab(adj_HR_str) mlabsize(1.4) mlabcol(black)) ///
		(scatter graphorder adj_HR if _seq==4, legend(off) col(black) msize(1.1)  ms(D) mfcolor(white) mlcolor(black)  mlwidth(.2)) ///
		(scatter graphorder adj_HR if _seq==2, legend(off) col(black) msize(.9)  ms(S) ) ///
		(scatter graphorder adj_HR if _seq==3, legend(off) col(black) msize(.9)  ms(O))  ///
		, ///
		xline(1, lp(-) lcol(gray))  											///
		xscale(log  range(0.125 8)) ///		
		xlab(0.125 "0.125" 0.25 "0.25" 0.5 1 2 4 8, grid labsize(2) format(%9.1f) tlength(0.8)) ///
		xtitle("")  ///
		ylab(none) ytitle("") yscale(lcolor(white))	///
		graphregion(color(white) margin(zero))  ///
		plotregion(margin(zero)) ///
		legend(off) ///
		fxsize(100) ///
		fysize(100) ///
		ysize(11.7) xsize(8.3) ///
		name(forest_`ndd', replace) scheme(tab2) title("{bf:`ndd_text'}", xoffset(0) size(*.5))
		
		replace wgt_str = "Weight" if ASM=="{bf:Any ASM}"
		replace wgt_pos = wgt_pos-.4 
		addplot :  (scatter graphorder wgt_pos, m(i) mlab(wgt_str) mlabsize(1.4) mlabcol(black)) ///		
	, 	///	
		legend(off)  norescaling	

}

gen varx1   = .
gen varx2   = .
replace varx1   = 0.03
replace varx2   = 0.03


graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:Adjusted Hazard Ratio (95% CI)}", size(2))
	
	
	addplot 1: (scatter graphorder varx1 , m(i) mlab(ASM) mlabsize(2) mlabcol(black)) ///
	, 	///	
		legend(off)  norescaling
	
	addplot 1: (scatter graphorder varx2 , m(i) mlab(country) mlabsize(2) mlabcol(black)) ///
	, 	///	
		legend(off)  norescaling	
	
		/*
addplot 2:  ///
	, 	///	
		legend(off)  norescaling	plotregion(color("202 228 241%30")) bgcolor("202 228 241%30") title("", box bexpand bcolor("202 228 241%30"))
	*/

	
graph export "$Graphdir\NDD_study_PMD\Causalinf_active_comparator_analysis.png", replace width(2400) height(1600)


********************************************************************************
cap log close		