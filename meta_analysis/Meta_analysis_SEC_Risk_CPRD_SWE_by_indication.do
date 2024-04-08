cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_SEC_Risk_CPRD_SWE_by_indication.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		01 March 2024
* Description:  Runs meta-analyses of secondary risk estimates 
******************************************************************************
* Contents 
********************************************************************************
* 1 - Combine output from CPRD and DOHAD datasets
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
* 3 - meta-analysis
* 4 - Produce bar plots for risk at each age in each country 

********************************************************************************
* 1 - Combine output from CPRD and DOHAD datasets
********************************************************************************
ssc install sencode
foreach indic in epilepsy other_psych_gp somatic_cond {
	foreach ndd in ASD ID ADHD {
		use "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_std_surv_`ndd'_`indic'.dta", clear
		drop if timevar == 16		
		drop _contrast* _at*_se 
		rename _at*_lci _atlci*
		rename _at*_uci _atuci*	
		rename timevar time
		reshape long _at _atlci _atuci, i(NDD indication time) j(ASM_n)
		replace ASM_n = ASM_n-1
		merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Secondary\monother_labels.dta", nogen keepusing(ASM_n label)
		merge m:1 label NDD using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_HR_byASM_`indic'.dta", nogen keep(3) keepusing(label NDD n_exp n_wNDD n_exp_wNDD)
		sort ASM_n
		replace label = "Pregabalin" if label == "Pregbalin"
		drop ASM_n
		sencode label, gen(ASM_n)
		rename  _at risk
		rename  _atlci risk_lci
		rename _atuci risk_uci
		*drop _at* 
		gen country = "CPRD (UK)"
		
		if "`indic'" == "epilepsy" {
			local indic_out = "epilepsy"
		}
		else if "`indic'" == "other_psych_gp" {
			local indic_out = "psych"
		}
		else if "`indic'" == "somatic_cond" {
			local indic_out = "somatic"
		}		
		replace indication = "`indic_out'"
		save "$Datadir\NDD_study_PMD\Outputs\Secondary\_temp\risk_CPRD_`ndd'_`indic_out'", replace
	}
}


foreach indic in epilepsy psych somatic {
	use "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\std_`indic'.dta", clear 
	drop Diff*
	
	local i = 0
	foreach drug in No_ASM Carbamazepine Gabapentin Lamotrigine Levetiracetam Phenytoin Pregabalin Topiramate Valproic_acid Other_ASM Polytherapy  {
			rename `drug'_asd  		ASD`i'
			rename `drug'_id  		ID`i'
			rename `drug'_adhd 	 	ADHD`i'
			rename `drug'_asd_lci 	ASD_lci`i'
			rename `drug'_id_lci 	ID_lci`i'
			rename `drug'_adhd_lci 	ADHD_lci`i'		
			rename `drug'_asd_uci 	ASD_uci`i'
			rename `drug'_id_uci 	ID_uci`i'
			rename `drug'_adhd_uci 	ADHD_uci`i'		
			local i = `i' + 1
	}
	reshape long ASD ASD_lci ASD_uci ID ID_lci ID_uci ADHD ADHD_lci ADHD_uci , i(time) j(ASM_n)
	merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Secondary\monother_labels.dta", nogen keepusing(ASM_n label)
	replace label = "Pregabalin" if label == "Pregbalin"
	drop ASM_n
	sencode label, gen(ASM_n)
	gen country = "DOHAD (SWE)"

	foreach ndd in ASD ID ADHD {
		preserve
		keep time `ndd'* label ASM_n country
		rename `ndd' risk 
		rename `ndd'_lci risk_lci
		rename `ndd'_uci risk_uci 
		gen NDD = "`ndd'"
		gen indication = "`indic'"
		save "$Datadir\NDD_study_PMD\Outputs\Secondary\_temp\risk_DOHAD_`ndd'_`indic'", replace	
		restore 
	}
}

clear 
foreach indic in epilepsy psych somatic {
	foreach ndd in ASD ID ADHD {
		append using "$Datadir\NDD_study_PMD\Outputs\Secondary\_temp\risk_CPRD_`ndd'_`indic'"
		append using "$Datadir\NDD_study_PMD\Outputs\Secondary\_temp\risk_DOHAD_`ndd'_`indic'"
	}
}
	
gen NDD_n = 1 if NDD == "ASD" 
replace NDD_n = 2 if NDD == "ID"   
replace NDD_n = 3 if NDD == "ADHD" 

replace risk = . if n_exp_wNDD == 0  | risk_uci == .
replace risk_lci = . if risk == .  
replace risk_uci = . if risk == . 
gen meta_exclude = . /*1 if n_exp_wNDD <=3  */
replace meta_exclude = . /*1 if ///
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
	(NDD == "ID"   &  label == "Other"         & indication == "psych"    & country == "DOHAD (SWE)") */

	
sort indication NDD_n ASM_n time country 
order indication NDD ASM time country  risk risk_lci risk_uci

gen log_risk = log(risk)
gen log_risk_lci = log(risk_lci)
gen log_risk_uci = log(risk_uci)

gen prev 	 = 100*risk 
gen prev_lci = 100*risk_lci
gen prev_uci = 100*risk_uci

gen str_prev_CI = strofreal(prev, "%5.2f") + " (" + strofreal(prev_lci , "%5.2f") + "-" + strofreal(prev_uci, "%5.2f")+ ")"


save "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_risk_metaready", replace


********************************************************************************
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************

use "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_risk_metaready", clear
keep if meta_exclude != 1

sencode country, gen(country_n)
sencode indication, gen(indication_n)
gen log_risk_se = (log_risk-log_risk_lci)/invnormal(0.975)
gen logrisk_invV = 1/(log_risk_se^2)
keep indication_n ASM_n NDD_n country_n time logrisk_invV
reshape wide logrisk_invV, i(indication_n ASM_n NDD_n time) j(country_n)
egen sum_invV = rowtotal(logrisk_invV*)
gen wgt1 = logrisk_invV1/sum_invV
gen wgt2 = logrisk_invV2/sum_invV
egen sum_wgt = rowtotal(wgt1 wgt2) 

keep indication_n ASM_n NDD_n time wgt1 wgt2 
reshape long wgt ,i(indication_n ASM_n NDD_n time) j(country_n)
decode country_n, gen(country)
decode indication_n, gen(indication)

order indication ASM country NDD time wgt*
keep indication ASM country NDD time wgt*
save  "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_risk_wgts.dta", replace

sencode country, gen(country_n)
sencode indication, gen(indication_n)
drop country
reshape wide wgt, i(indication_n ASM_n NDD_n time) j(country_n)
gen dohad = round(100*wgt2,0.1)
sort time  indication_n NDD_n ASM_n

********************************************************************************
* 3 - meta-analysis
* https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-015-0024-z
* recommends In small meta-analyses, confidence intervals should supplement or replace the biased point estimate I2.
********************************************************************************

foreach indic in epilepsy psych somatic {
	foreach NDD in ASD ADHD ID {
		forvalues time = 4(4)12 {
			use "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_sec_risk_metaready", clear
			metan log_risk log_risk_lci log_risk_uci if indication == "`indic'" & NDD=="`NDD'" & time == `time' & meta_exclude != 1, by(ASM_n) sortby(country) lcols(country) nooverall keeporder 		
			clear
			set obs 11
			gen ASM = ""
			gen risk = . 
			gen risk_lci = . 
			gen risk_uci = . 		
			gen country = "Combined"
			gen NDD = "`NDD'"
			gen indication = "`indic'"
			gen time = `time'
			 
			local i = 0 
			foreach drug in "No ASM exposure" "Carbamazepine" "Gabapentin" "Lamotrigine" "Levetiracetam" "Phenytoin" "Pregabalin" "Topiramate" "Valproate" "Other" "Polytherapy" {
				local i = `i' + 1
				replace ASM = "`drug'" if _n == `i'
				replace risk     = exp(r(bystats)[1,`i'])  if _n == `i'
				replace risk_lci = exp(r(bystats)[3,`i'])  if _n == `i'
				replace risk_uci = exp(r(bystats)[4,`i'])  if _n == `i'
			}	
			
			save "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_secrisk_metan_`NDD'_`indic'_`time'.dta", replace
		}
	}
}

clear 
foreach indic in epilepsy psych somatic {
	foreach NDD in ASD ADHD ID {
		forvalues time = 4(4)12 {
			append using "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_secrisk_metan_`NDD'_`indic'_`time'.dta"
		}
	}
}

sencode indication, gen(indication_n)
sencode ASM, gen(ASM_n)
sencode NDD, gen(NDD_n)
sencode country, gen(country_n)

gen prev 	 = 100*risk 
gen prev_lci = 100*risk_lci
gen prev_uci = 100*risk_uci

gen str_prev_CI = strofreal(prev, "%5.2f") + " (" + strofreal(prev_lci , "%5.2f") + "-" + strofreal(prev_uci, "%5.2f")+ ")"


save "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_secrisk_metan_graphready.dta", replace

********************************************************************************
* 4 - Produce bar plots for risk at each age in each country 
********************************************************************************
ssc install mylabels
*net install gr0075.pkg
*net install gr0034.pkg
net install palettes, replace from("https://raw.githubusercontent.com/benjann/palettes/master/")
net install colrspace, replace from("https://raw.githubusercontent.com/benjann/colrspace/master/")



foreach indic in epilepsy psych somatic {
	foreach ndd in ASD ID ADHD {
		
		use "$Datadir\NDD_study_PMD\Outputs\Secondary\NDD_secrisk_metan_graphready.dta", clear 
		preserve
			bysort NDD: sum prev_uci 
		restore
		keep if indication == "`indic'" & NDD == "`ndd'" & time == 12

		bysort NDD_n time (ASM_n): gen x_pos = _n-1
		replace x_pos = 0  if ASM=="No ASM"
		replace x_pos = 1  if ASM=="Carbamazepine"
		replace x_pos = 2  if ASM=="Gabapentin"
		replace x_pos = 3  if ASM=="Lamotrigine"
		replace x_pos = 4  if ASM=="Levetiracetam"
		replace x_pos = 5  if ASM=="Phenytoin"
		replace x_pos = 6  if ASM=="Pregabalin"
		replace x_pos = 7  if ASM=="Topiramate"
		replace x_pos = 8  if ASM=="Valproate"
		replace x_pos = 9  if ASM=="Other"
		replace x_pos = 10 if ASM=="Polytherapy"
		
		if "`ndd'" == "ASD" {
			local yttl = "Autism age 12"
		}
		if "`ndd'" == "ID" {
			local yttl = "Intellectual disability age 12"
		}
		if "`ndd'" == "ADHD" {
			local yttl = "ADHD age 12"
		}
		
		local ymax = 30

		
		if `ymax' < 15 {
			local step = 1
		}
		if 15 < `ymax' <= 30 {  
			local step = 2
		}
		if 30 < `ymax' {
			local step = 4
		} 

		replace ASM = ASM + "*" if prev == . 	
		replace ASM = ASM + "**"	 if (prev > `ymax' |  prev_uci >= `ymax') & prev != . 
		replace prev_lci = . if prev >= `ymax' | prev_uci >= `ymax'
		replace prev_uci = . if prev >= `ymax' |  prev_uci >= `ymax'
		replace prev = . if prev >= `ymax' |  prev_uci >= `ymax'	
		
		
		replace ASM = "No ASM" if ASM == "No ASM exposure" 
		replace ASM = "{bf:" + ASM + "}"

		replace x_pos = x_pos+1 if x_pos>0
		labmask x_pos, values(ASM)
		
		
		if "`indic'" == "epilepsy" {
			local yscale ""
			local ytitle "ytitle(Absolute adjusted risk (%), margin(vsmall) size(*.85))"
			local l1tcol ""		
			local ylabcol ""
		}
		if "`indic'" != "epilepsy" {
			local yscale "" // "yscale(lcolor(white))"
			local ytitle "ytitle(" ", margin(vsmall) size(*.85))"
			local l1tcol "color(white)"
			local ylabcol "" // "labcolor(white%0) tlc(none)" 
		}
		disp "`yscale'"
		disp "`ytitle'"
		disp "`l1tcol'"
		disp "`ylabcol'"
		
		
		local mygraph 
		local i = 1
		levelsof x_pos, local(levels) 
		local items = `r(r)'  + 1
		foreach x of numlist 2(1)11 {
			local x = `x'
			local newx = 12 - `i'   // reverse the sorting
			colorpalette  matplotlib hot   , n(`items') nograph  
					local mygraph `mygraph' (bar prev x_pos if indication=="`indic'" & NDD=="`ndd'" & time==12 & x_pos==`x', barwidth(.9) sort fcolor("`r(p`newx')'%100") lc(black) lw(medthick)) || ///
					 (rcap prev_lci prev_uci x_pos if indication=="`indic'" & NDD=="`ndd'" & time==12 & x_pos==`x', lc(black%50) lw(thin)) ||
			local i =`i'+1
		}

		local mygraph `mygraph' (bar prev x_pos if indication=="`indic'" & NDD=="`ndd'" & time==12 & x_pos==0, barwidth(.9) sort fcolor(dimgray) lc(black) lw(medthick)) || ///
				 (rcap prev_lci prev_uci x_pos if indication=="`indic'" & NDD=="`ndd'" & time==12 & x_pos==0, lc(black%50) lw(thin)) ||
				 
		mylabels 0(`step')`ymax', local(myla) suffix(%) format(%1.0f)
				 
		twoway  `mygraph'  ,  ///
		 xtitle("") ///
		 ytitle(" ") ///
		  ///
		 legend(off) ///
		 scheme(tab2) ///
		 ylabel(`myla', format(%1.0f) labsize(vsmall) `ylabcol' angle(0)) ///
		 `yscale' ///
		 xlabel(0 2(1)11, nogrid labsize(vsmall) valuelabels angle(40))  ///
		 xscale(extend range(0 11.45)) yscale(extend)   ///
		 ysize(12) xsize(12) graphregion(margin(0 0 0 0) color(none) lcolor(none)) ///
		 plotregion(margin(1 1 1 1) color(none)  lc(none)) ///
		 `ytitle' name(`indic'_`ndd', replace) fxsize(100)  ///
		 l1title("{bf:`yttl'}", `l1tcol' size(*.85))		
		 
	} 
}

graph combine  epilepsy_ASD epilepsy_ID epilepsy_ADHD, ysize(15) xsize(8.3)  ///
	row(4) plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0)  color(white%100))  name(epilepsy, replace) ///
	title("{bf:Epilepsy}", size(large) margin(0 0 0 2) xoffset(3.5)) 
 

graph combine  psych_ASD psych_ID psych_ADHD, ysize(15) xsize(8.3)  ///
	row(4) plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0)  color(white%100))  name(psych, replace) ///
	title("{bf:Psychiatric}", size(large) margin(0 0 0 2) xoffset(3.5)) 
  
  
graph combine  somatic_ASD somatic_ID somatic_ADHD, ysize(15) xsize(8.3)  ///
row(4) plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0)  color(white%100))  name(somatic, replace) ///
  title("{bf:Somatic}", size(large) margin(0 0 0 2) xoffset(3.5)) 
  
graph combine epilepsy psych somatic , ysize(15) xsize(15)  ///
	col(3) plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0) color(white%100)) name(combine, replace) ///
	l2title("", size(large) margin(0 2 0 0)) ///
	note("* Unable to estimate due to 0 exposed case counts across both cohorts. See Table S9" "** Estimate not presented as it falls outside the plot region. Note that this is due to a small number of " "   exposed cases. See Table S10", size(vsmall)) 


graph export "$Graphdir\NDD_study_PMD\Sec_risk_t_combined_only.png", replace width(2400) height(2400)




********************************************************************************
cap log close		