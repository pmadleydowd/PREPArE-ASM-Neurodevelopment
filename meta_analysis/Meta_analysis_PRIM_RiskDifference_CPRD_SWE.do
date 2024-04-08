cap log close 
log using "$Logdir\NDD study\LOG_Meta_analysis_PRIM_RiskDifference_CPRD_SWE.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		28 Feb 2023
* Description:  Runs meta-analyses of primary risk difference estimates 
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
	drop _at*  _contrast*_1_se
	rename _contrast*_1 _contrast*
	rename _contrast*_1_lci _contrast*_lci	
	rename _contrast*_1_uci _contrast*_uci	
	rename _contrast*_lci  _contrast_lci*
	rename _contrast*_uci  _contrast_uci*
	rename timevar time
	reshape long _contrast _contrast_lci _contrast_uci, i(NDD time) j(ASM_n)
	replace ASM_n = ASM_n-1
	merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Primary\monother_labels.dta", nogen keepusing(ASM_n label)
	merge m:1 label NDD using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_HR_byASM.dta", keep(3) keepusing(label NDD n_exp n_wNDD n_exp_wNDD)
	sort ASM_n
	replace label = "Pregabalin" if label == "Pregbalin"
	drop ASM_n
	sencode label, gen(ASM_n)
	rename  _contrast RiskDiff
	rename  _contrast_lci RiskDiff_lci
	rename  _contrast_uci RiskDiff_uci
	gen country = "CPRD (UK)"	
	save "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_CPRD_`ndd'", replace
}


use "C:\Users\pm0233\University of Bristol\grp-PREPArE - Manuscripts\asm-ndd combining\std_update.dta", clear
local i = 1
foreach drug in Carbamazepine Gabapentin Lamotrigine Levetiracetam Phenytoin Pregabalin Topiramate Valproic_acid Other_ASM Polytherapy  {
		rename Diff_`drug'_asd  		ASD`i'
		rename Diff_`drug'_id  			ID`i'
		rename Diff_`drug'_adhd 	 	ADHD`i'
		rename Diff_`drug'_asd_lci 		ASD_lci`i'
		rename Diff_`drug'_id_lci 		ID_lci`i'
		rename Diff_`drug'_adhd_lci 	ADHD_lci`i'		
		rename Diff_`drug'_asd_uci 		ASD_uci`i'
		rename Diff_`drug'_id_uci 		ID_uci`i'
		rename Diff_`drug'_adhd_uci 	ADHD_uci`i'		
		local i = `i' + 1
}
keep ASD* ID* ADHD* time* 
reshape long ASD ASD_lci ASD_uci ID ID_lci ID_uci ADHD ADHD_lci ADHD_uci , i(time) j(ASM_n)
merge m:1 ASM_n using "$Datadir\NDD_study_PMD\Outputs\Primary\monother_labels.dta", keepusing(ASM_n label)
keep if _merge ==3
drop _merge
replace label = "Pregabalin" if label == "Pregbalin"
drop ASM_n
sencode label, gen(ASM_n)
gen country = "DOHAD (SWE)"

foreach ndd in ASD ID ADHD {
	preserve
	keep time `ndd'* label ASM_n country
	rename `ndd' RiskDiff 
	rename `ndd'_lci RiskDiff_lci
	rename `ndd'_uci RiskDiff_uci 
	gen NDD = "`ndd'"
	save "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_DOHAD_`ndd'", replace	
	restore 
}

use "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_CPRD_ASD", clear
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_CPRD_ID"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_CPRD_ADHD"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_DOHAD_ASD"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_DOHAD_ID"
append using "$Datadir\NDD_study_PMD\Outputs\Primary\_temp\riskDiff_DOHAD_ADHD"

gen NDD_n = 1 if NDD == "ASD" 
replace NDD_n = 2 if NDD == "ID"   
replace NDD_n = 3 if NDD == "ADHD" 

gen ASM = label 

replace RiskDiff = . if n_exp_wNDD == 0  
replace RiskDiff_lci = . if RiskDiff == .  
replace RiskDiff_uci = . if RiskDiff == . 
gen meta_exclude = . /*1 if n_exp_wNDD <=3  */

sort ASM_n NDD_n time country 
order NDD ASM time country  RiskDiff RiskDiff_lci RiskDiff_uci

gen prevDiff 	 = 100*RiskDiff 
gen prevDiff_lci = 100*RiskDiff_lci
gen prevDiff_uci = 100*RiskDiff_uci

gen str_prevDiff_CI = strofreal(prevDiff, "%5.2f") + " (" + strofreal(prevDiff_lci , "%5.2f") + ", " + strofreal(prevDiff_uci, "%5.2f")+ ")"


save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metaready", replace


********************************************************************************
* 2 - Calculate the weights for display in figure (inverse variance use in metan)
********************************************************************************

use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metaready", clear
keep if meta_exclude != 1

sencode country, gen(country_n)
gen RiskDiff_se = (RiskDiff-RiskDiff_lci)/invnormal(0.975)
gen RiskDiff_invV = 1/(RiskDiff_se^2)
keep ASM_n NDD_n country_n time RiskDiff_invV
reshape wide RiskDiff_invV, i(ASM_n NDD_n time) j(country_n)
egen sum_invV = rowtotal(RiskDiff_invV*)
gen wgt1 = RiskDiff_invV1/sum_invV
gen wgt2 = RiskDiff_invV2/sum_invV
egen sum_wgt = rowtotal(wgt1 wgt2) 

keep ASM_n NDD_n time wgt1 wgt2 
reshape long wgt ,i(ASM_n NDD_n time) j(country_n)
decode country_n, gen(country)

order ASM country NDD time wgt*
keep ASM country NDD time wgt*
save  "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_wgts.dta", replace

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

foreach NDD in ASD ID ADHD {
	forvalues time = 4(4)12 {
		use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metaready", clear
		metan RiskDiff RiskDiff_lci RiskDiff_uci if NDD=="`NDD'" & time == `time' & meta_exclude != 1, by(ASM_n) sortby(country) lcols(country) nooverall 	keeporder		
		clear
		set obs 10
		gen ASM = ""
		gen RiskDiff = . 
		gen RiskDiff_lci = . 
		gen RiskDiff_uci = . 		
		gen country = "Combined"
		gen NDD = "`NDD'"
		gen time = `time'
		 
		local i = 0 
		foreach drug in "Carbamazepine" "Gabapentin" "Lamotrigine" "Levetiracetam" "Phenytoin" "Pregabalin" "Topiramate" "Valproate" "Other" "Polytherapy" {
			local i = `i' + 1
			replace ASM = "`drug'" if _n == `i'
			replace RiskDiff     = r(bystats)[1,`i']  if _n == `i'
			replace RiskDiff_lci = r(bystats)[3,`i']  if _n == `i'
			replace RiskDiff_uci = r(bystats)[4,`i']  if _n == `i'
		}	
		
		save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metan_`NDD'_`time'.dta", replace
	}
}

clear 
foreach NDD in ASD ID ADHD{
	forvalues time = 4(4)12 {
		append using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metan_`NDD'_`time'.dta"
	}
}

sencode ASM, gen(ASM_n)
sencode NDD, gen(NDD_n)
sencode country, gen(country_n)

gen prevDiff 	 = 100*RiskDiff 
gen prevDiff_lci = 100*RiskDiff_lci
gen prevDiff_uci = 100*RiskDiff_uci

gen str_prevDiff_CI = strofreal(prevDiff, "%5.2f") + " (" + strofreal(prevDiff_lci , "%5.2f") + ", " + strofreal(prevDiff_uci, "%5.2f")+ ")"


save "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metan_graphready.dta", replace

keep time ASM_n NDD_n country_n str_prevDiff_CI
reshape wide str_prevDiff_CI, i(ASM_n NDD_n country_n) j(time)
sort NDD_n country_n ASM_n 
********************************************************************************
* 4 - Produce plots for risk difference at each age 
********************************************************************************
* Produce forest plots for combined estimates 
********************************************************************************	
ssc install mylabels
*net install gr0075.pkg
*net install gr0034.pkg
net install palettes, replace from("https://raw.githubusercontent.com/benjann/palettes/master/")
net install colrspace, replace from("https://raw.githubusercontent.com/benjann/colrspace/master/")


foreach ndd in "ASD" "ID" "ADHD" {

	* collate data 
	use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metan_graphready.dta", clear
	* prepare data 
	keep if NDD == "`ndd'" 	&  time == 12

	sort ASM_n 
	drop ASM_n
	sencode ASM, gen(ASM_n)
	sort ASM_n country_n 
	order ASM country_n 

	keep ASM* country* NDD prevDiff*  

	* add character versions of numeric variables - added as not available for combined 
	gen prevDiff_str = strofreal(prevDiff,"%5.2f")+"%" if prevDiff != . 

	* sort data
	gsort  +ASM_n 

	* Update order
	gen obsorder = _n
	gsort -obsorder
	gen graphorder = _n
	sort graphorder

	* Create column headers
	summ graphorder

	* Adjust position of HR text 
	gen graphorder_HR = .
	replace graphorder_HR = graphorder + 0.4
	
	* save for text output in figure 
	preserve 
	keep graphorder ASM country 
	save "$Datadir\NDD_study_PMD\Outputs\Primary\graphready__combinedonly_riskDiff`ndd'.dta", replace
	restore 

	replace prevDiff_uci = 5  if prevDiff_uci >  5
	replace prevDiff_lci = -5 if prevDiff_lci < -5

	* produce figures
	twoway ///
		(rcap 	 prevDiff_lci prevDiff_uci graphorder if prevDiff_uci!=5 & prevDiff_lci!=-5, hor col(black)  msize(.9)) ///
		(rspike prevDiff_lci prevDiff graphorder if prevDiff_uci == 5, horiz lc(black))   ///
		(rcap   prevDiff_lci prevDiff_lci graphorder if prevDiff_uci == 5 & prevDiff_lci > -5, hor col(black)  msize(.9))   ///
		(pcarrow graphorder prevDiff graphorder prevDiff_uci if prevDiff_uci==5,   color(black) msize(.9))  ///	
		(rspike prevDiff_uci prevDiff graphorder if prevDiff_lci == -5, horiz lc(black))   ///
		(rcap   prevDiff_uci prevDiff_uci graphorder if prevDiff_lci == -5 & prevDiff_uci < 5 , hor col(black)  msize(.9))   ///
		(pcarrow graphorder prevDiff graphorder prevDiff_lci if prevDiff_lci==-5,   color(black) msize(.9)) ///	
		(scatter graphorder_HR prevDiff, m(i) mlab(prevDiff_str) mlabsize(2.5) mlabcol(black)) ///
		(scatter graphorder prevDiff, msize(1.75)  ms(D)) ///
		, ///
		xline(0, lp(-) lcol(gray))  											///
		xscale(range(-3.5 3.5)) ///		
		xlab(-3 "-3%" -2 "-2%" -1 "-1%" 0 "0%" 1 "1%" 2 "2%" 3 "3%", grid labsize(2) format(%9.0f) tlength(0.8)) ///
		xtitle("Risk Difference age 12 (95% CI)", size(2.5))  ///
		ylab(none) ytitle("") yscale(lcolor(white) range(.5 11))	///
		graphregion(color(white) margin(zero) lcolor(black) lwidth(zero) fcolor(none))  ///
		plotregion(margin(zero) lcolor(black) lwidth(zero) fcolor(none)) ///
		legend(off) ///
		fxsize(100) ///
		fysize(100) ///
		ysize(11.7) xsize(8.3) ///
		name(forest_`ndd', replace) scheme(tab2) ///
		title("{bf:`ndd'}", xoffset(0) size(*1.15)) ///
		yline(1.5(1)10, lc(gray%15))
		
}

gen varx2   = .
replace varx2   = -7

graph combine forest_ASD forest_ID forest_ADHD, cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(30 0 0 0)) ysize(5) xsize(11.7) 
	
	
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

	
graph export "$Graphdir\NDD_study_PMD\Prim_riskDiff_age12_combined_only.png", replace width(2400) height(1600)


* Produce forest plots for country specific and combined estimates 
********************************************************************************	
foreach ndd in "ASD" "ID" "ADHD" {
	forvalues t = 4(4)12 {

		* collate data 
		use "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metaready", clear
		cap drop _merge
		merge 1:1 ASM_n NDD_n country time using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_wgts.dta"
		append using "$Datadir\NDD_study_PMD\Outputs\Primary\NDD_prim_riskDiff_metan_graphready.dta"
		* prepare data 
		keep if NDD == "`ndd'" 	&  time == `t'
		drop if _merge == 2 
		keep if inlist(country, "CPRD (UK)", "Combined", "DOHAD (SWE)")

		drop country_n
		gen country_n = 1 if country ==  "CPRD (UK)"
		replace country_n = 2 if country ==  "DOHAD (SWE)"
		replace country_n = 3 if country ==   "Combined"

		sort ASM_n 
		drop ASM_n
		sencode ASM, gen(ASM_n)
		sort ASM_n country_n 
		order ASM country_n 

		keep ASM* country* NDD prevDiff* wgt 


		* Add additional rows
		gen obsorder = _n
		expand 2 if country_n == 1, gen(expanded1)
		expand 2 if country_n == 3, gen(expanded2)

		* add character versions of numeric variables - added as not available for combined 
		gen prevDiff_str = strofreal(prevDiff,"%5.2f") if prevDiff != . 
		gen wgt_str = strofreal(100*wgt, "%5.1f") + "%"  if wgt !=.			   

		* Remove data for additional rows or where estimate not possible
		foreach var in prevDiff prevDiff_lci prevDiff_uci wgt {
			replace `var'=. if expanded1==1 | expanded2 == 1
		} 
		foreach var in prevDiff_str wgt_str country {
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
		replace wgt_pos = 5.5
		
		* save for text output in figure 
		preserve 
		keep graphorder ASM country 
		save "$Datadir\NDD_study_PMD\Outputs\Primary\graphready_`ndd'.dta", replace
		restore 

		replace prevDiff_uci = 5  if prevDiff_uci >  5
		replace prevDiff_lci = -5 if prevDiff_lci < -5

		replace country = "UK" if country=="CPRD (UK)"
		replace country = "Sweden" if country=="DOHAD (SWE)"
		* produce figures
		twoway ///
			(rcap 	 prevDiff_lci prevDiff_uci graphorder if prevDiff_uci!=5 & prevDiff_lci!=-5, hor col(black)  msize(.9)) ///
			(rspike prevDiff_lci prevDiff graphorder if prevDiff_uci == 5, horiz lc(black))   ///
			(rcap   prevDiff_lci prevDiff_lci graphorder if prevDiff_uci == 5 & prevDiff_lci > -5, hor col(black)  msize(.9))   ///
			(pcarrow graphorder prevDiff graphorder prevDiff_uci if prevDiff_uci==5,   color(black) msize(.9))  ///	
			(rspike prevDiff_uci prevDiff graphorder if prevDiff_lci == -5, horiz lc(black))   ///
			(rcap   prevDiff_uci prevDiff_uci graphorder if prevDiff_lci == -5 & prevDiff_uci < 5 , hor col(black)  msize(.9))   ///
			(pcarrow graphorder prevDiff graphorder prevDiff_lci if prevDiff_lci==-5,   color(black) msize(.9)) ///	
			(scatter graphorder_HR prevDiff, m(i) mlab(prevDiff_str) mlabsize(1.4) mlabcol(black)) ///
			(scatter graphorder prevDiff if _seq==2, col(black) msize(.9)  ms(S)) ///
			(scatter graphorder prevDiff if _seq==3, col(black) msize(.9)  ms(O)) 	///
			(scatter graphorder prevDiff if _seq==4, col(black) msize(.9)  ms(D) mfcolor(white) mlcolor(black)  mlwidth(.2)) ///
			(scatter graphorder wgt_pos, m(i) mlab(wgt_str) mlabsize(1.4) mlabcol(black)) ///		
			, ///
			xline(0, lp(-) lcol(gray))  											///
			/*xscale())*/ ///		
			xlab(-4 "-4%" -2 "-2%" 0 "0%" 2 "2%" 4 "4%", grid labsize(2) format(%9.0f) tlength(0.8)) ///
			xtitle("")  ///
			ylab(none) ytitle("") yscale(lcolor(white))	///
			graphregion(color(white) margin(zero))  ///
			plotregion(margin(zero)) ///
			legend(off) ///
			fxsize(100) ///
			fysize(100) ///
			ysize(11.7) xsize(8.3) ///
			name(forest_`ndd'_`t', replace) scheme(tab2) title("{bf:Age `t'}", xoffset(0) size(*.5))
			
	}
}

gen varx1   = .
gen varx2   = .
replace varx1   = -7
replace varx2   = -6

graph combine	  forest_ASD_4  forest_ASD_8 	forest_ASD_12 	///
			  , name(ASD_all,replace) cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:Autism risk difference relative to no ASM (95% CI)}", size(2))
addplot 1: (scatter graphorder varx1 , m(i) mlab(ASM) mlabsize(2) mlabcol(black)), legend(off) norescaling
addplot 1: (scatter graphorder varx2 , m(i) mlab(country) mlabsize(2) mlabcol(black)) , legend(off)  norescaling	
graph export "$Graphdir\NDD_study_PMD\Prim_RiskDiff_autism.png", replace width(2400) height(1600)
			  
			  

graph combine 	  forest_ID_4  forest_ID_8 	forest_ID_12 	///
			  , name(ID_all,replace) cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:Intellectual disability risk difference relative to no ASM (95% CI)}", size(2))
addplot 1: (scatter graphorder varx1 , m(i) mlab(ASM) mlabsize(2) mlabcol(black)), legend(off) norescaling
addplot 1: (scatter graphorder varx2 , m(i) mlab(country) mlabsize(2) mlabcol(black)) , legend(off)  norescaling	
graph export "$Graphdir\NDD_study_PMD\Prim_RiskDiff_ID.png", replace width(2400) height(1600)

			  
graph combine 	  forest_ADHD_4  forest_ADHD_8 	forest_ADHD_12 	///
			  , name(ADHD_all,replace) cols(3) graphregion(color(white))   imargin(0 7 0 0) graphregion(margin(12 0 0 0)) ysize(8.3) xsize(11.7) b1title("{bf:ADHD risk difference relative to no ASM (95% CI)}", size(2))
addplot 1: (scatter graphorder varx1 , m(i) mlab(ASM) mlabsize(2) mlabcol(black)), legend(off) norescaling
addplot 1: (scatter graphorder varx2 , m(i) mlab(country) mlabsize(2) mlabcol(black)) , legend(off)  norescaling	
graph export "$Graphdir\NDD_study_PMD\Prim_RiskDiff_ADHD.png", replace width(2400) height(1600)
		  
			  
			  

	



********************************************************************************
cap log close		