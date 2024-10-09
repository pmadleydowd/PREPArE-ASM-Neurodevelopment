foreach var of varlist bcountry_bm_nm dispink5atbirth education addicted paritet seizure_visit sambo_atbirth_bm visits_1y_cat epilepsy depression_bm_preg  bipolar_bm_preg  other_psych_bm_preg  migraine_bm_preg  diabetes n05 a04 n06a pain sjukvarsregion male any_ndd_bm exposure {
	
	quietly tab `var', gen(dum_`var')
}

quietly tab exposure, gen(exposure_dum)


	foreach indication in somatic psych epilepsy  {
		
	
	if "`indication'" == "somatic" global covar age_atbirth_bm age_atbirth_bm_cube bcountry_bm_nm dum_dispink5atbirth1 dum_dispink5atbirth2 dum_dispink5atbirth3 dum_dispink5atbirth4 dum_education1 dum_education2 dum_addicted1 dum_paritet1 dum_paritet2 dum_paritet3 dum_paritet4 dum_seizure_visit1 dum_sambo_atbirth_bm1 dum_visits_1y_cat1 dum_visits_1y_cat2 dum_epilepsy1 dum_depression_bm_preg1 dum_bipolar_bm_preg1 dum_other_psych_bm_preg1 dum_n051 dum_a041 dum_n06a1 dum_sjukvarsregion1 dum_sjukvarsregion2 dum_sjukvarsregion3 dum_sjukvarsregion4 dum_sjukvarsregion5 dum_male1 dum_any_ndd_bm1

	
	if "`indication'" == "psych" global covar age_atbirth_bm age_atbirth_bm_cube bcountry_bm_nm dum_dispink5atbirth1 dum_dispink5atbirth2 dum_dispink5atbirth3 dum_dispink5atbirth4 dum_education1 dum_education2 dum_addicted1 dum_paritet1 dum_paritet2 dum_paritet3 dum_paritet4 dum_seizure_visit1 dum_sambo_atbirth_bm1 dum_visits_1y_cat1 dum_visits_1y_cat2 dum_epilepsy1 dum_n051 dum_a041 dum_n06a1 dum_sjukvarsregion1 dum_sjukvarsregion2 dum_sjukvarsregion3 dum_sjukvarsregion4 dum_sjukvarsregion5 dum_male1 dum_any_ndd_bm1 dum_diabetes1 dum_pain1 dum_migraine_bm_preg1
	
		if "`indication'" == "epilepsy" global covar age_atbirth_bm age_atbirth_bm_cube bcountry_bm_nm dum_dispink5atbirth1 dum_dispink5atbirth2 dum_dispink5atbirth3 dum_dispink5atbirth4 dum_education1 dum_education2 dum_addicted1 dum_paritet1 dum_paritet2 dum_paritet3 dum_paritet4 dum_seizure_visit1 dum_sambo_atbirth_bm1 dum_visits_1y_cat1 dum_visits_1y_cat2 dum_depression_bm_preg1 dum_bipolar_bm_preg1 dum_other_psych_bm_preg1 dum_n051 dum_a041 dum_n06a1 dum_sjukvarsregion1 dum_sjukvarsregion2 dum_sjukvarsregion3 dum_sjukvarsregion4 dum_sjukvarsregion5 dum_male1 dum_any_ndd_bm1 dum_diabetes1 dum_pain1 dum_migraine_bm_preg1
	
	

			preserve
		if "`indication'" == "epilepsy" keep if epilepsy==1
		if "`indication'" == "psych" keep if psych_bm_preg==1
		if "`indication'" == "somatic" keep if somatic_bm_preg==1
		
	
	 foreach var in asd adhd id {

	stset FU_`var', failure(outcome_`var'==1)
	
	stpm2 exposure_dum1 exposure_dum2 exposure_dum3 exposure_dum4 exposure_dum5 exposure_dum6 exposure_dum7 exposure_dum8 exposure_dum9 exposure_dum10 $covar , scale(hazard) df(4) eform
	est store stpm2_`var'_`indication'

	
	 }
	
	  estout stpm2*`indication' using "C:\Users\vikahl\OneDrive - Karolinska Institutet\Skrivbordet\standsurv export\output_`indication'.xls", keep(exposure*)  cells("b(fmt(5)) se(fmt(5)) ci(fmt(5))") label replace eform
restore 
	}
	
	  	foreach indication in somatic psych epilepsy  {
					 				preserve
		if "`indication'" == "epilepsy" keep if epilepsy==1
		if "`indication'" == "psych" keep if psych_bm_preg==1
		if "`indication'" == "somatic" keep if somatic_bm_preg==1
	  	
		
	replace time = 4 in 1/1
	replace time = 8 in 2/2
	replace time = 12 in 3/3
		 foreach var in asd adhd id { 
		 	

stset FU_`var', failure(outcome_`var'==1)
	
est restore stpm2_`var'_`indication'
	standsurv, at1(exposure_dum1 1) ///
at2(exposure_dum2 1) ///
at3(exposure_dum3 1) ///
at4(exposure_dum4 1) ///
at5(exposure_dum5 1) ///
at6(exposure_dum6 1) ///
at7(exposure_dum7 1) ///
at8(exposure_dum8 1) ///
at9(exposure_dum9 1) ///
at10(exposure_dum10 1) ///
at11(exposure_dum11 1) ///
           atvar(Lamotrigine_`var' ///
Carbamazepine_`var' ///
Gabapentin_`var' ///
Levetiracetam_`var' ///
Phenytoin_`var' ///
Pregabalin_`var' ///
Topiramate_`var' ///
Valproic_acid_`var' ///
Other_ASM_`var' ///
Polytherapy_`var' ///
No_ASM_`var' ///
)           ///    
			failure  ///
           timevar(time) ci contrast(difference) ///
		   contrastvars( ///
Diff_Lamotrigine_`var' ///
Diff_Carbamazepine_`var' ///
Diff_Gabapentin_`var' ///
Diff_Levetiracetam_`var' ///
Diff_Phenytoin_`var' ///
Diff_Pregabalin_`var' ///
Diff_Topiramate_`var' ///
Diff_Valproic_acid_`var' ///
Diff_Other_ASM_`var' ///
Diff_Polytherapy_`var' ///
) ///
 atref(11)
 }
	
	drop if time==.
	keep time Lamotrigine_asd-Diff_Polytherapy_id_uci
	save "C:\Users\vikahl\OneDrive - Karolinska Institutet\Skrivbordet\standsurv export\std_`indication'.dta", replace
	restore
	**drop Lamotrigine_asd-Diff_Polytherapy_id_uci
 }
	
	
	