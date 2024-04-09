	global main_confounders  c.age_atbirth_bm c.age_atbirth_bm_cube i.bcountry_bm_nm i.dispink5atbirth i.edu3atbirth_bmbf i.addicted_bm_prepreg i.paritet i.seizure_visit i.rounded_pregyear i.sambo_atbirth_bm i.visits_1y_cat i.epilepsy_g40_bm_preg i.depression_bm_preg  i.bipolar_bm_preg  i.other_psych_bm_preg  i.migraine_bm_preg  i.diabetes_npr_mbr_bm_preg i.n05_pdr_plusmbr_bm i.a04_pdr_plusmbr_bm i.n06a_pdr_plusmbr_bm i.chronic_pain_bm_preg i.sjukvardsregion_pregstart_bm i.male i.any_ndd_bm




			gen time = 4 in 1/1
	replace time = 8 in 2/2
	replace time = 12 in 3/3
	replace time = 16 in 4/4
	

	
	 foreach var in asd adhd id {

	stset FU_`var', failure(outcome_`var'==1)
	
	stpm3 ib0.super_exposure $main_confounders, df(4) scale(lncumhazard) eform
	est store stpm3_`var'

		 
	 }
	 
	 estout stpm3* using output_active.xls, keep(*.super_exposure)  cells("b(fmt(5)) se(fmt(5))") label replace
	 
