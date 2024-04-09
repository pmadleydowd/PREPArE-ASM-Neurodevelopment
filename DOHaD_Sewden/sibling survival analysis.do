
		global main_confounders  c.age_atbirth_bm c.age_atbirth_bm_cube i.bcountry_bm_nm i.dispink5atbirth i.edu3atbirth_bmbf i.addicted_bm_prepreg i.paritet i.seizure_visit i.rounded_pregyear i.sambo_atbirth_bm i.visits_1y_cat i.epilepsy_g40_bm_preg i.depression_bm_preg  i.bipolar_bm_preg  i.other_psych_bm_preg  i.migraine_bm_preg  i.diabetes_npr_mbr_bm_preg i.n05_pdr_plusmbr_bm i.a04_pdr_plusmbr_bm i.n06a_pdr_plusmbr_bm i.chronic_pain_bm_preg i.region_bm i.male i.any_ndd_bm
	
	revrs  bcountry_bm_nm, replace
	revrs  sambo_atbirth_bm, replace


	foreach var in bcountry_bm_nm ///
dispink5atbirth ///
edu3atbirth_bmbf ///
addicted_bm_prepreg ///
paritet ///
seizure_visit ///
rounded_pregyear ///
sambo_atbirth_bm ///
visits_1y_cat ///
epilepsy_g40_bm_preg ///
depression_bm_preg ///
bipolar_bm_preg ///
other_psych_bm_preg ///
migraine_bm_preg ///
diabetes_npr_mbr_bm_preg ///
n05_pdr_plusmbr_bm ///
a04_pdr_plusmbr_bm ///
n06a_pdr_plusmbr_bm ///
chronic_pain_bm_preg ///
region_bm ///
male ///
any_ndd_bm {
	tab `var', gen(dum`var')
}

drop dum*1

gen i = 1
bysort famid: egen antal=total(i) if famid!=.
keep if antal>=2 & antal!=.

replace age_atbirth_bm_cube = age_atbirth_bm_cube*10^-3

ds dum* age_atbirth_bm age_atbirth_bm_cube

foreach var in `r(varlist)' {
	
	
	egen b_`var' = mean(`var'), by(famid)

	
}


ds super_exposure

foreach var in `r(varlist)' {
	
	tab `var', gen(dum`var')

	
}
drop dum*super_exposure11
ds dum*super_exposure*

foreach var in `r(varlist)' {
	
		egen b_`var' = mean(`var'), by(famid)
	
}

drop *dum*bcountry_bm* *dum*any_ndd_bm*


	 	 	 foreach var in asd adhd id {


	stset FU_`var', failure(outcome_`var'==1)
	
	stpm3 dum* age_atbirth_bm age_atbirth_bm_cube b_*, df(4) scale(lncumhazard) eform iterate(15)
	est store stpm3_`var'

		 
	 }
	 
	 estout stpm3*  using "C:\Users\vikahl\OneDrive - Karolinska Institutet\Skrivbordet\output_sibs.xls" ///
	  , keep(dum*super*)  cells("b(fmt(5)) se(fmt(5))") label replace 
	 