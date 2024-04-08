cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_Sec_HR_CPRD_SWE_by_indication.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		28 Feb 2023
* Description:  Runs meta-analyses of Secondary analysis survival estimates 
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
ssc install sencode

* prepare DOHAD data
import excel "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\Stratified_results_2024_03_07.xlsx", sheet("Stratified_results_2024_03_07") firstrow clear
gen country = "DOHAD (SWE)"

foreach ndd in asd id adhd {
	foreach indic in epilepsy psych somatic {
		gen `ndd'_`indic'_cpos = strpos(`ndd'_`indic'_ci95, ",")
		gen `ndd'_`indic'_lci  = substr(`ndd'_`indic'_ci95, 1, `ndd'_`indic'_cpos - 1) 
		destring `ndd'_`indic'_lci, replace
		gen `ndd'_`indic'_logHRse = (log(`ndd'_`indic'_b) - log(`ndd'_`indic'_lci)) / invnormal(0.975) 
		gen `ndd'_`indic'_logHR = log(`ndd'_`indic'_b)
	}
}
keep country label ASM_n *_logHRse *_logHR

foreach indic in epilepsy psych somatic {
	rename asd_`indic'_logHR 	 `indic'_adj_logHR1
	rename id_`indic'_logHR 	 `indic'_adj_logHR2
	rename adhd_`indic'_logHR 	 `indic'_adj_logHR3
	rename asd_`indic'_logHRse 	 `indic'_adj_logHRse1
	rename id_`indic'_logHRse 	 `indic'_adj_logHRse2
	rename adhd_`indic'_logHRse  `indic'_adj_logHRse3
}
reshape long epilepsy_adj_logHR epilepsy_adj_logHRse ///
			 psych_adj_logHR psych_adj_logHRse ///
			 somatic_adj_logHR somatic_adj_logHRse, i(label ASM_n country) j(NDD_n)

local i = 0			 
foreach indic in epilepsy psych somatic {
	local i = `i' + 1
	rename `indic'_adj_logHR 	 adj_logHR`i'
	rename `indic'_adj_logHRse 	 adj_logHRse`i'
}
reshape long adj_logHR adj_logHRse, i(label ASM_n country NDD_n) j(indication_n)
			 
gen adj_HR = exp(adj_logHR) 
gen adj_HRuci = exp(adj_logHR + invnormal(0.975)*adj_logHRse) 
gen adj_HRlci = exp(adj_logHR - invnormal(0.975)*adj_logHRse)
gen NDD = "ASD"  if NDD_n == 1
replace NDD = "ID"   if NDD_n == 2
replace NDD = "ADHD" if NDD_n == 3
gen indication = "epilepsy" if indication_n == 1 
replace indication = "psych" if indication_n == 2 
replace indication = "somatic" if indication_n == 3 

save "$Datadir\NDD_study_PMD\Outputs\Secondary\_temp\DOHAD_HR_metaready", replace


* prepare CPRD data 
clear
foreach indic in epilepsy other_psych_gp somatic_cond {
	if "`indic'" == "epilepsy"{
		local indic_out = "epilepsy" 
	} 
	if "`indic'" == "other_psych_gp"{
		local indic_out = "psych" 
	} 
	if "`indic'" == "somatic_cond"{
		local indic_out = "somatic" 
	} 	
	append using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_HR_byASM_`indic'.dta"
	replace indication = "`indic_out'" if indication == "`indic'"	
}
gen country =  "CPRD (UK)" 
replace label = "Pregabalin" if label == "Pregbalin"


* combine datasets 
append using "$Datadir\NDD_study_PMD\Outputs\Secondary\_temp\DOHAD_HR_metaready"
drop indication_n 
sencode indication, gen(indication_n)

replace adj_HR = . if  n_exp_wNDD ==0 | adj_logHRse == 0 
replace adj_HRlci = . if adj_HR == . 
replace adj_HRuci = . if adj_HR == . 
replace adj_logHRse = . if adj_HR == . 
gen meta_exclude = . /*1 if n_exp_wNDD <=3  */
replace meta_exclude = . /* 1 if ///
	(NDD == "ASD"  &  label == "Gabapentin"    & indication == "epilepsy" & country == "DOHAD (SWE)") | ///
	(NDD == "ASD"  &  label == "Phenytoin"     & indication == "somatic"  & country == "DOHAD (SWE)") | ///
	(NDD == "ADHD" &  label == "Phenytoin"     & indication == "psych"    & country == "DOHAD (SWE)") | ///
	(NDD == "ADHD" &  label == "Levetiracetam" & indication == "somatic"  & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Gabapentin"    & indication == "epilepsy" & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Topiramate"    & indication == "psych"    & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Other"         & indication == "psych"    & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Phenytoin"     & indication == "psych"    & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Topiramate"    & indication == "somatic"  & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Phenytoin"     & indication == "psych"    & country == "DOHAD (SWE)") | ///
	(NDD == "ID"   &  label == "Other"         & indication == "psych"    & country == "DOHAD (SWE)") 
*/
replace adj_logHR = log(adj_HR) if country == "CPRD (UK)"
sort indication_n ASM_n NDD_n country 

*drop if ASM_n == 0 

gen ASM = "{bf:" + label + "}"
bys ASM_n: egen wAverage = total(adj_logHR)

label variable country "Country"

cap drop _merge
save "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metaready", replace



********************************************************************************
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************

use "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metaready", clear
keep if meta_exclude != 1

sencode country, gen(country_n)

gen log_adj_HRinvV = 1/(adj_logHRse^2) 

keep indication_n ASM_n NDD_n country_n log_adj_HRinvV
reshape wide log_adj_HRinvV, i(indication_n ASM_n NDD_n) j(country_n)
egen sum_invV = rowtotal(log_adj_HRinvV*)
gen wgt1 = log_adj_HRinvV1/sum_invV
gen wgt2 = log_adj_HRinvV2/sum_invV
egen sum_wgt = rowtotal(wgt1 wgt2) 

keep indication_n ASM_n NDD_n wgt1 wgt2 
reshape long wgt ,i(indication_n ASM_n NDD_n) j(country_n)
decode country_n, gen(country)
decode indication_n, gen(indication)

order indication ASM country NDD wgt*
keep indication ASM country NDD wgt*
save  "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_wgts.dta", replace

sort country 
sencode country, gen(country_n)
drop country
reshape wide wgt, i(indication ASM_n NDD_n) j(country_n)
gen cprd  = round(100*wgt1,0.1)
gen dohad = round(100*wgt2,0.1)
sort indication NDD_n ASM_n
replace dohad = 0 if dohad == . & wgt1 == 1

********************************************************************************
* 3 - meta-analysis
* https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-015-0024-z
* recommends In small meta-analyses, confidence intervals should supplement or replace the biased point estimate I2.
********************************************************************************
foreach indic in epilepsy psych somatic {
	foreach NDD in ASD ADHD ID {
		use "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metaready", clear
		drop if ASM_n == 0

		metan adj_logHR adj_logHRse if indication == "`indic'" &  NDD=="`NDD'" & meta_exclude != 1, by(ASM_n) sortby(country) eform lcols(country) nooverall keeporder 		
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
		
		save "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metan_`indic'_`NDD'.dta", replace
	}
}


********************************************************************************
* 4 - Produce plots 
********************************************************************************
ssc install addplot


* Produce forest plots for country specific and combined estimates 
********************************************************************************	
foreach indic in epilepsy psych somatic {
	foreach ndd in "ASD" "ID" "ADHD" {

		* collate data 
		use"$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metaready", clear
		merge 1:1 indication ASM_n NDD_n country using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_wgts.dta"
		keep if indication == "`indic'"

		foreach NDD in ASD ADHD ID {
			append using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metan_`indic'_`NDD'.dta"
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
		
		
		* update label for pregabalin and remove combined estimates for Epilepsy 
		if "`indic'" == "epilepsy"{
			replace ASM = "{bf:Pregabalin*}" if ASM == "{bf:Pregabalin}" 
			if "`ndd'" == "ASD" | "`ndd'" == "ADHD" { 
				replace adj_HR 		= . if ASM == "{bf:Pregabalin*}"
				replace adj_HRlci 	= . if ASM == "{bf:Pregabalin*}"
				replace adj_HRuci 	= . if ASM == "{bf:Pregabalin*}"
				replace wgt         = . if ASM == "{bf:Pregabalin*}"
			}
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

		keep ASM* country* NDD adj_HR* wgt 


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
		replace wgt_pos = 10.5
		
		* save for text output in figure 
		preserve 
		keep graphorder ASM country 
		save "$Datadir\NDD_study_PMD\Outputs\Secondary\graphready_`ndd'_`indic'.dta", replace
		restore 

		replace adj_HRuci = 10 if adj_HRuci>10 & adj_HRuci!=.
		replace adj_HRlci = .125 if adj_HRlci<.125

		replace country = "UK" if country=="CPRD (UK)"
		replace country = "Sweden" if country=="DOHAD (SWE)"
		
		replace country = "Reference" if country == "UK" & ASM_n == 1
		replace country = " " if country == "Sweden" & ASM_n == 1
		
		
		* produce figures
		twoway ///
			(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==2  & adj_HRuci!=10 & adj_HRlci!=.125, hor legend(off) col(black)  msize(.9)) ///
			(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==3  & adj_HRuci!=10 & adj_HRlci!=.125, hor legend(off) col(black) msize(.9)) ///
			(rcap 	 adj_HRlci adj_HRuci graphorder if _seq==4  & adj_HRuci!=10 & adj_HRlci!=.125, hor legend(off) col(black)  msize(.9)) 	///
			(rspike adj_HRuci adj_HR graphorder if inrange(adj_HRuci, 0, 7.99) & adj_HRlci==.125, horiz lc(black)) ///
			(rspike adj_HRlci adj_HR  graphorder if inrange(adj_HRlci, .125, 7.99) & adj_HRuci==10, horiz lc(black)) ///
			(rcap adj_HRuci adj_HRuci graphorder if inrange(adj_HRuci, 0, 7.99) & adj_HRlci==.125, horiz lc(black)) ///
			(rcap adj_HRlci adj_HRlci  graphorder if inrange(adj_HRlci, .125, 7.99) & adj_HRuci==10, horiz lc(black)) ///
			(pcarrow graphorder adj_HR graphorder adj_HRuci if adj_HRuci==10,   color(black) msize(.9)) ///
			(pcarrow  graphorder adj_HR graphorder adj_HRlci if inrange(adj_HRlci, 0, 0.125),  color(black) msize(.9)) ///
			(scatter graphorder_HR adj_HR, m(i) mlab(adj_HR_str) mlabsize(1.4) mlabcol(black)) ///
			(scatter graphorder adj_HR if _seq==4, legend(off) col(black) msize(1.1)  ms(D) mfcolor(white) mlcolor(black)  mlwidth(.2)) ///
			(scatter graphorder adj_HR if _seq==2, legend(off) col(black) msize(.9)  ms(S) ) ///
			(scatter graphorder adj_HR if _seq==3, legend(off) col(black) msize(.9)  ms(O))  ///
			, ///
			xline(1, lp(-) lcol(gray))  											///
			xscale(log  range(0.125 10)) ///		
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

	if "`indic'" == "epilepsy"{
		graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:Adjusted Hazard Ratio (95% CI)}", size(2)) note("* Pregabalin has been removed from the plot for ADHD as the estimates fall outside the plot region." "Note that this is due to a small number of exposed cases contributed by CPRD only. See Tables S9 and S12.", size(vsmall)) 
	}
	else {
		graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:Adjusted Hazard Ratio (95% CI)}", size(2)) 
	}	
		
		
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

		
	graph export "$Graphdir\NDD_study_PMD\sec_survival_analysis_`indic'.png", replace width(2400) height(1600)
}		
		

* Produce forest plots for combined estimates 
********************************************************************************	

foreach indic in epilepsy psych somatic {
	
	foreach ndd in "ASD" "ID" "ADHD" {
		* collate data 
		use"$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metaready", clear
		merge 1:1 indication ASM_n NDD_n country using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_wgts.dta"
		keep if indication == "`indic'"
		
		foreach NDD in ASD ADHD ID {
			append using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_metan_`indic'_`NDD'.dta"
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
		if "`indic'" == "epilepsy"{
			replace ASM = "{bf:Pregabalin*}" if ASM == "{bf:Pregabalin}" 
			if "`ndd'" == "ASD" | "`ndd'" == "ADHD" { 
				replace adj_HR 		= . if ASM == "{bf:Pregabalin*}"
				replace adj_HRlci 	= . if ASM == "{bf:Pregabalin*}"
				replace adj_HRuci 	= . if ASM == "{bf:Pregabalin*}"
			}
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
		save "$Datadir\NDD_study_PMD\Outputs\Secondary\graphready_combinedonly_`ndd'.dta", replace
		restore 

		replace adj_HRuci = round(7.98, .001) if adj_HRuci>=8
		replace adj_HRlci = round(.182, .001) if adj_HRlci<=.18
		
		if "`ndd'" == "ASD"{ 
			local mfil mfcolor("135 0 82*.5")
			if "`indic'" == "epilepsy"{
				local ttl title("{bf:Autism}", xoffset(0) size(*1.15))
			}
			else {
				local ttl title("{bf: }", xoffset(0) size(*1.15))
			}
		}
		if "`ndd'" == "ID"{ 
			local mfil mfcolor("84 185 134")
			if "`indic'" == "epilepsy"{
				local ttl title("{bf:Intellectual Disability}", xoffset(0) size(*1.15))
			}
			else {
				local ttl title("{bf: }", xoffset(0) size(*1.15))
				}	
			}
		
		if "`ndd'" == "ADHD"{ 
			local mfil ""
			if "`indic'" == "epilepsy"{
				local ttl title("{bf:ADHD}", xoffset(0) size(*1.15))
			}
			else {
				local ttl title("{bf: }", xoffset(0) size(*1.15))
				}		
			}
		
		

		twoway ///
			(rcap 	 adj_HRlci adj_HRuci graphorder if round(adj_HRuci,0.001) != 7.98 & round(adj_HRlci,0.001) !=.182, hor legend(off) col(black)  msize(.9)) ///
			(rspike adj_HRuci adj_HR graphorder if inrange(adj_HRuci, 0, 7.98) & round(adj_HRlci,0.001) == 0.182, horiz lc(black)) ///
			(rspike adj_HRlci adj_HR  graphorder if inrange(adj_HRlci, 0, 7.98) & round(adj_HRuci,0.001) == 7.98, horiz lc(black)) ///
			(rcap adj_HRuci adj_HRuci graphorder if inrange(adj_HRuci, 0, 7.98) & round(adj_HRlci, 0.001) == 0.182, horiz lc(black)) ///
			(rcap adj_HRlci adj_HRlci  graphorder if inrange(adj_HRlci, .182, 7.98) & round(adj_HRuci,0.001) == 7.98, horiz lc(black)) ///
			(pcarrow graphorder adj_HR graphorder adj_HRuci if round(adj_HRuci,0.001) == 7.98,   color(black) msize(.9)) ///
			(pcarrow  graphorder adj_HR graphorder adj_HRlci if round(adj_HRlci,0.001) == 0.182,  color(black) msize(.9)) ///
			(scatter graphorder_or adj_HR, m(i) mlab(adj_HR_str) mlabsize(3) mlabcol(black)) ///
			(scatter graphorder adj_HR if _seq==2 , mlcolor(black) `mfil' legend(off) msize(1.75)  ms(D) ) ///
			, ///
			xline(1, lp(-) lcol(gray))  											///
			xscale(log  range(0.18 8)) ///		
			xlab(0.2 "0.2" 0.5 "0.5" 1 2 5, nogrid labsize(2.5) format(%9.1f) tlength(0.8)) ///
			xtitle("HR (95%CI)", size(2.5))  ///
			ylab(none) ytitle("") yscale(lcolor(none) range(.5 12))	///
			graphregion(color(white) margin(zero) lcolor(black) lwidth(zero) fcolor(none))  ///
			plotregion(margin(none) lcolor(black) lwidth(zero) fcolor(none)) ///
			legend(off) ///
			 fxsize(150) ///
			 fysize(80) ///
			ysize(7) xsize(10) ///
			name(forest_`ndd', replace) scheme(tab2) yline(1.5(1)11, lc(gray%15)) `ttl'

	}
	
	
	gen varx1   = .
	replace varx1   = 1
	gen varx2   = .
	replace varx2   = 2
	gen varx3   = .
	replace varx3   = 0.5
	
	twoway (scatter graphorder varx1 , mcol(white)) ///
		   (scatter graphorder varx2 , mcol(white)) ///
		   (scatter graphorder varx3, m(i) mlab(ASM) mlabsize(3) mlabcol(black)) ///
		  , ///
		  legend(off) ///
		  yscale(lcolor(none) range(.5 12)) xscale(lc(none) range(0 1)) ///
		  ylabel(none) xlabel(,labc(white) tlc(white) nogrid labsize(2.5) format(%9.1f) tlength(0.8)) ///
		  graphregion(margin(0 0 0 0)) plotregion(margin(0 0 0 0)) ///
		  ytitle("") xtitle("") ///
			 fxsize(20) ///
			 fysize(80) ///
			ysize(7) xsize(10) title(" ", xoffset(0) size(*1.15)) ///		  
		  name(labs, replace) 

		  
		  
	if "`indic'" == "epilepsy"{
		local indic_out = "Epilepsy" 
	} 
	if "`indic'" == "psych"{
		local indic_out = "Psychiatric" 
	} 
	if "`indic'" == "somatic"{
		local indic_out = "Somatic" 
	}		  

	graph 	combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white)) name(comb, replace) ///
			imargin(0 0 0 0) graphregion(margin(0 0 0 0)) ysize(5) xsize(11.7) r2t("`indic_out'", size(*1.15))
			
	graph 	combine labs comb, cols(2) graphregion(color(white)) name("`indic'", replace) ///
			imargin(0 0 0 0) graphregion(margin(0 0 0 0)) ysize(5) xsize(11.7) 

}


	graph 	combine epilepsy psych somatic, rows(3) graphregion(color(white)) ///
			imargin(0 0 0 0) graphregion(margin(0 0 0 0)) ysize(15) xsize(14) ///
			note("* Pregabalin has been removed from the plot for epilepsy and ADHD as the estimates fall outside the plot " "region. Note that this is due to a small number of exposed cases contributed by CPRD only. See Table S12", size(vsmall)) 
			
			
graph export "$Graphdir\NDD_study_PMD\sec_survival_analysis_combined_only.png", replace width(2400) height(2400) 


********************************************************************************
cap log close		