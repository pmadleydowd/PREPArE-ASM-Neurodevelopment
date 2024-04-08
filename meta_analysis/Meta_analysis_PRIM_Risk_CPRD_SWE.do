cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_PRIM_Risk_CPRD_SWE.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		28 Feb 2023
* Description:  Runs meta-analyses of primary risk estimates 
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

foreach ndd in ASD ID ADHD {
	use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_std_surv_`ndd'.dta", clear
	drop if timevar == 16
	drop _contrast* _at*_se 
	rename _at*_lci _atlci*
	rename _at*_uci _atuci*	
	rename timevar time
	reshape long _at _atlci _atuci, i(NDD time) j(ASM_n)
	replace ASM_n = ASM_n-1
	merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Primary\monother_labels.dta", nogen keepusing(ASM_n label)
	merge m:1 label NDD using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_HR_byASM.dta", keep(3) keepusing(label NDD n_exp n_wNDD n_exp_wNDD)
	sort ASM_n
	replace label = "Pregabalin" if label == "Pregbalin"
	drop ASM_n
	sencode label, gen(ASM_n)
	rename  _at risk
	rename  _atlci risk_lci
	rename _atuci risk_uci
	*drop _at* 
	gen country = "CPRD (UK)"	
	save "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_CPRD_`ndd'", replace
}


use "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\std_update.dta", clear
drop Diff* _*

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
merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Primary\monother_labels.dta", nogen keepusing(ASM_n label)
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
	save "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_DOHAD_`ndd'", replace	
	restore 
}

use "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_CPRD_ASD", clear
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_CPRD_ID"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_CPRD_ADHD"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_DOHAD_ASD"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_DOHAD_ID"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\risk_DOHAD_ADHD"

gen NDD_n = 1 if NDD == "ASD" 
replace NDD_n = 2 if NDD == "ID"   
replace NDD_n = 3 if NDD == "ADHD" 

replace risk = . if n_exp_wNDD == 0  
replace risk_lci = . if risk == .  
replace risk_uci = . if risk == . 
gen meta_exclude = . /*1 if n_exp_wNDD <=3*/  

sort ASM_n NDD_n time country 
order NDD ASM time country  risk risk_lci risk_uci

gen log_risk = log(risk)
gen log_risk_lci = log(risk_lci)
gen log_risk_uci = log(risk_uci)

gen prev 	 = 100*risk 
gen prev_lci = 100*risk_lci
gen prev_uci = 100*risk_uci

gen str_prev_CI = strofreal(prev, "%5.2f") + " (" + strofreal(prev_lci , "%5.2f") + "-" + strofreal(prev_uci, "%5.2f")+ ")"


save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_risk_metaready", replace


********************************************************************************
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************

use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_risk_metaready", clear
keep if meta_exclude != 1

sencode country, gen(country_n)
gen log_risk_se = (log_risk-log_risk_lci)/invnormal(0.975)
gen logrisk_invV = 1/(log_risk_se^2)
keep ASM_n NDD_n country_n time logrisk_invV
reshape wide logrisk_invV, i(ASM_n NDD_n time) j(country_n)
egen sum_invV = rowtotal(logrisk_invV*)
gen wgt1 = logrisk_invV1/sum_invV
gen wgt2 = logrisk_invV2/sum_invV
egen sum_wgt = rowtotal(wgt1 wgt2) 

keep ASM_n NDD_n time wgt1 wgt2 
reshape long wgt ,i(ASM_n NDD_n time) j(country_n)
decode country_n, gen(country)

order ASM country NDD time wgt*
keep ASM country NDD time wgt*
save  "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_risk_wgts.dta", replace

sencode country, gen(country_n)
drop country
reshape wide wgt, i(ASM_n NDD_n time) j(country_n)
gen dohad = round(100*wgt2,0.1)
sort time  NDD_n ASM_n
keep ASM_n NDD_n time dohad
reshape wide dohad, i(ASM_n NDD_n) j(time)
sort NDD_n ASM_n
********************************************************************************
* 3 - meta-analysis
* https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-015-0024-z
* recommends In small meta-analyses, confidence intervals should supplement or replace the biased point estimate I2.
********************************************************************************

foreach NDD in ASD ADHD ID {
	forvalues time = 4(4)12 {
		use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_risk_metaready", clear
		metan log_risk log_risk_lci log_risk_uci if NDD=="`NDD'" & time == `time' & meta_exclude != 1, by(ASM_n) sortby(country) lcols(country) nooverall keeporder		
		clear
		set obs 11
		gen ASM = ""
		gen risk = . 
		gen risk_lci = . 
		gen risk_uci = . 		
		gen country = "Combined"
		gen NDD = "`NDD'"
		gen time = `time'
		 
		local i = 0 
		foreach drug in "No ASM exposure" "Carbamazepine" "Gabapentin" "Lamotrigine" "Levetiracetam" "Phenytoin" "Pregabalin" "Topiramate" "Valproate" "Other" "Polytherapy" {
			local i = `i' + 1
			replace ASM = "`drug'" if _n == `i'
			replace risk     = exp(r(bystats)[1,`i'])  if _n == `i'
			replace risk_lci = exp(r(bystats)[3,`i'])  if _n == `i'
			replace risk_uci = exp(r(bystats)[4,`i'])  if _n == `i'
		}	
		
		save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_primrisk_metan_`NDD'_`time'.dta", replace
	}
}

clear 
foreach NDD in ASD ADHD ID {
	forvalues time = 4(4)12 {
		append using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_primrisk_metan_`NDD'_`time'.dta"
	}
}

sencode ASM, gen(ASM_n)
sencode NDD, gen(NDD_n)
sencode country, gen(country_n)

gen prev 	 = 100*risk 
gen prev_lci = 100*risk_lci
gen prev_uci = 100*risk_uci

gen str_prev_CI = strofreal(prev, "%5.2f") + " (" + strofreal(prev_lci , "%5.2f") + "-" + strofreal(prev_uci, "%5.2f")+ ")"


save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_primrisk_metan_graphready.dta", replace

keep time ASM_n NDD_n country_n str_prev_CI
reshape wide str_prev_CI, i(ASM_n NDD_n country_n) j(time)
sort NDD_n country_n ASM_n 
********************************************************************************
* 4 - Produce bar plots for risk at each age in each country 
********************************************************************************
ssc install mylabels
*net install gr0075.pkg
*net install gr0034.pkg
net install palettes, replace from("https://raw.githubusercontent.com/benjann/palettes/master/")
net install colrspace, replace from("https://raw.githubusercontent.com/benjann/colrspace/master/")


use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_primrisk_metan_graphready.dta", clear 
replace ASM = "No ASM" if ASM == "No ASM exposure" 
replace ASM = "{bf:" + ASM + "}"

bysort NDD_n time (ASM_n): gen x_pos = _n-1
replace x_pos = 0  if ASM=="{bf:No ASM}"
replace x_pos = 1  if ASM=="{bf:Pregabalin}"
replace x_pos = 2  if ASM=="{bf:Phenytoin}"
replace x_pos = 3  if ASM=="{bf:Lamotrigine}"
replace x_pos = 4  if ASM=="{bf:Levetiracetam}"
replace x_pos = 5  if ASM=="{bf:Topiramate}"
replace x_pos = 6  if ASM=="{bf:Carbamazepine}"
replace x_pos = 7  if ASM=="{bf:Other}"
replace x_pos = 8  if ASM=="{bf:Gabapentin}"
replace x_pos = 9  if ASM=="{bf:Polytherapy}"
replace x_pos = 10 if ASM=="{bf:Valproate}"

replace x_pos = x_pos+1 if x_pos>0
labmask x_pos, values(ASM)

forvalues age = 4(4)12 {
	foreach ndd in ASD ID ADHD {
		if "`ndd'" == "ASD" {
			local yttl = "Autism"
		}
		if "`ndd'" == "ID" {
			local yttl = "Intellectual disability"
		}
		if "`ndd'" == "ADHD" {
			local yttl = "ADHD"
		}		
		if `age' == 4 {
			local yscale ""
			local ytitle "ytitle(Absolute adjusted risk (%), margin(vsmall) size(*.85))"
			local l1tcol ""		
			local ylabcol ""
		}
		if `age' > 4 {
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
					local mygraph `mygraph' (bar prev x_pos if NDD=="`ndd'" & time==`age' & x_pos==`x', barwidth(.9) sort fcolor("`r(p`newx')'%100") lc(black) lw(medthick)) || ///
					 (rcap prev_lci prev_uci x_pos if NDD=="`ndd'" & time==`age' & x_pos==`x', lc(black%50) lw(thin)) ||
			local i =`i'+1
		}

		local mygraph `mygraph' (bar prev x_pos if NDD=="`ndd'" & time==`age' & x_pos==0, barwidth(.9) sort fcolor(dimgray) lc(black) lw(medthick)) || ///
				 (rcap prev_lci prev_uci x_pos if NDD=="`ndd'" & time==`age' & x_pos==0, lc(black%50) lw(thin)) ||
				 
		mylabels 0(1)10, local(myla) suffix(%) format(%1.0f)
				 
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
		 `ytitle' name(`ndd'_age`age', replace) fxsize(100)  ///
		 l1title("{bf:`yttl'}", `l1tcol' size(*.85))		
		 
	}
} 




graph combine  ASD_age4 ID_age4 ADHD_age4, ysize(15) xsize(8.3)  ///
	row(4) ycommon  plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0)  color(white%100))  name(age4, replace) ///
	title("{bf:Age 4}", size(large) margin(0 0 0 2) xoffset(3.5)) 
 

graph combine  ASD_age8 ID_age8 ADHD_age8, ysize(15) xsize(8.3)  ///
	row(4) ycommon  plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0)  color(white%100))  name(age8, replace) ///
	title("{bf:Age 8}", size(large) margin(0 0 0 2) xoffset(3.5)) 
  
  
graph combine  ASD_age12 ID_age12 ADHD_age12, ysize(15) xsize(8.3)  ///
row(4) ycommon  plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0)  color(white%100))  name(age12, replace) ///
  title("{bf:Age 12}", size(large) margin(0 0 0 2) xoffset(3.5)) 
  
graph combine age4 age8 age12 , ysize(15) xsize(15)  ///
	col(3) ycommon  plotregion(margin(0 0 0 0)) graphregion(margin(0 0 0 0) color(white%100)) name(combine, replace) ///
	l2title("", size(large) margin(0 2 0 0)) 

graph export "$Graphdir\NDD_study_PMD\Prim_risk_t_combined_only.png", replace width(2400) height(2400)



********************************************************************************
cap log close		