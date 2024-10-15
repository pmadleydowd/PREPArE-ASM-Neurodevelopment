*2664726
use "P:\AED_ASD_VA\Dohad Data\Compressed Stata versions\PREPARE_analytical_data_v1.dta", clear
	merge 1:1 lopnr_ip using "P:/AED_ASD_VA/Shuyun Diabetes/mfr_variabler_shuyun-derived.dta", gen(mfr)
	drop if mfr==2
	*keep if BORDF2=="1"

drop n03_preg_pdr_plusmbr_bm
gen n03_preg_pdr_plusmbr_bm = n03_pdr_preg_bm
replace n03_preg_pdr_plusmbr_bm = n03_mbr_bm if birthyear_ip<2005
replace n03_preg_pdr_plusmbr_bm = n03_mbr_bm if n03_pdr_preg_bm==0 & n03_mbr_bm==1
rename n03_preg_pdr_plusmbr_bm any_asm_exposure


 replace n05_pdr_plusmbr_bm = 0 if n05_pdr_plusmbr_bm==.
 
 * lan
 generate lan_real = real(preg_start_lan)
**labmask lan_real, values(preg_start_lan_txt)
 
 generate sjukvardsregion_pregstart_bm  = .
 replace sjukvardsregion_pregstart_bm = 1 if lan_real==24 | lan_real==25 | lan_real==23 | lan_real==22
 replace sjukvardsregion_pregstart_bm = 2 if lan_real==21 | lan_real==20 | lan_real==3  | lan_real==17  | lan_real==18  | lan_real==19  | lan_real==4 
 replace sjukvardsregion_pregstart_bm = 3 if lan_real==1 | lan_real==9
 replace sjukvardsregion_pregstart_bm = 4 if lan_real==5 | lan_real==6 | lan_real==8  | lan_real==8
 replace sjukvardsregion_pregstart_bm = 5 if lan_real==14 | lan_real==15 | lan_real==16 | lan_real==13
 replace sjukvardsregion_pregstart_bm = 6 if lan_real==10 | lan_real==7 | lan_real==11 | lan_real==12
 
*rename outcomes according to paul
		  rename any_ndd NDD
		  rename asd_ip ASD
		  rename adhd_ip ADHD
		  rename id_ip ID
		  foreach ndd in NDD ASD ADHD ID {
		  rename `ndd' outcome_`ndd'
		  }
	
	merge 1:1 lopnr_ip using "P:\AED_ASD_VA\Dohad Data\id_asd_adhd_fk.dta", gen(fk_diag)
drop if fk_diag==2
rename id_fk ID_fk
rename asd_fk ASD_fk
rename adhd_fk ADHD_fk 
gen NDD_fk = 0
replace NDD_fk = 1 if ID_fk==1 |  ASD_fk==1 |  ADHD_fk==1


		  foreach ndd in NDD ASD ADHD ID {
		  replace outcome_`ndd' = 1 if `ndd'_fk ==1
		  }

*rename exposures according to paul	
gen flag_anydrug_preg = any_asm_exposure
		  
		  foreach asm in carbamazep gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproic {
		  rename `asm'_exposure flag_`asm'_preg
		  }
		  
*create "other ASM" class

generate  flag_other_preg = flag_anydrug_preg

		  foreach asm in carbamazep gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproic {
		  replace flag_other_preg = 2 if flag_`asm'_preg==1
		  }
	
* Generate comp groups
	  foreach asm in anydrug carbamazep gabapentin lamotrigine levetiracetam phenytoin pregabalin topiramate valproic other {
		  gen `asm'_comp1 = flag_`asm'_preg
		  }

		  
		   foreach asm in anydrug carbamazep gabapentin levetiracetam phenytoin pregabalin topiramate valproic other {
				gen `asm'_comp5 = .
		  		  replace `asm'_comp5 = 1 if  flag_`asm'_preg == 1
				  replace `asm'_comp5 = 0 if  flag_lamotrigine_preg == 1 & `asm'_comp5!=1
				  replace `asm'_comp5 = 2 if  `asm'_comp5==.
				  
		  }
 gen lamotrigine_comp5 = .
		  
		 		 gen rounded_pregyear = round(preg_start_year, 3) 
** flip dates
gen chronic_pain_bm_preg = chronic_pain_bm
replace chronic_pain_bm_preg = 0 if chronic_pain_date_bm>preg_start_date & chronic_pain_date_bm!=.

gen anxiety_bm_preg = anxiety_bm
replace anxiety_bm_preg = 0 if anxiety_date_bm>preg_start_date & anxiety_date_bm!=.

gen depression_bm_preg = depression_bm
replace depression_bm_preg = 0 if depression_date_bm>preg_start_date & depression_date_bm!=.


gen migraine_bm_preg = migraine_bm
replace migraine_bm_preg = 0 if migraine_date_bm>preg_start_date & migraine_date_bm!=.

gen bipolar_bm_preg = bipolar_bm
replace bipolar_bm_preg = 0 if bipolar_date_bm>preg_start_date & bipolar_date_bm!=.

gen other_psych_bm_preg = other_psych_bm
replace other_psych_bm_preg = 0 if other_psych_date_bm>preg_start_date & other_psych_date_bm!=.
				 
	
codebook 	diabetes_npr_mbr_date_bm if diabetes_npr_mbr_date_bm==0 & diabetes_npr_mbr_bm==0
replace diabetes_npr_mbr_date_bm = . if diabetes_npr_mbr_date_bm==0 & diabetes_npr_mbr_bm==0
				 
gen diabetes_npr_mbr_bm_preg = diabetes_npr_mbr_bm
replace diabetes_npr_mbr_bm_preg = 0 if diabetes_npr_mbr_date_bm>preg_start_date & diabetes_npr_mbr_date_bm!=.
					
gen preterm_class = 1 if gestational_weeks<28
replace preterm_class = 2 if gestational_weeks>=28 & gestational_weeks<32
replace preterm_class = 3 if gestational_weeks>=32 & gestational_weeks<37
replace preterm_class = 4 if gestational_weeks>=37 & gestational_weeks<42
replace preterm_class = 5 if gestational_weeks>=42
label define preterm_class 1 "Extreme pre" 2 "Very pre" 3 "Preterm" 4 "Term" 5 "Post-term"
label values preterm_class preterm_class
replace preterm_class = . if gestational_weeks==.

gen other_preg_bm = flag_other_preg
replace other_preg_bm = 0 if other_preg_bm==2

gen preterm_class2 = preterm_class
replace preterm_class2 = 1 if  preterm_class<=3
replace preterm_class2 = 2 if  preterm_class==4
replace preterm_class2 = 3 if  preterm_class==5
label define preterm_class2 1 "Preterm" 2 "Term" 3 "Post-term"
label values preterm_class2 preterm_class2
gen preterm = preterm_class2
replace preterm = 0 if  preterm_class2>1 & preterm_class2!=.



gen preg_start_year_cub = preg_start_year^3

gen any_ndd_bm = asd_bm
replace any_ndd_bm = id_bm if any_ndd_bm==0
replace any_ndd_bm = adhd_bm if any_ndd_bm==0

 
*retain complete case
local conflist c.age_atbirth_bm c.age_atbirth_bm_cube i.bcountry_bm_nm i.dispink5atbirth i.edu3atbirth_bmbf i.addicted_bm_prepreg i.paritet i.seizure_visit c.preg_start_year   i.sambo_atbirth_bm i.visits_1y_cat i.epilepsy_g40_bm_preg i.depression_bm_preg  i.bipolar_bm_preg  i.other_psych_bm_preg  i.migraine_bm_preg  i.diabetes_npr_mbr_bm_preg i.n05_pdr_plusmbr_bm i.a04_pdr_plusmbr_bm i.n06a_pdr_plusmbr_bm i.chronic_pain_bm_preg i.sjukvardsregion_pregstart_bm i.male i.any_ndd_bm
logit preterm i.flag_anydrug_preg `conflist', or
gen sample = e(sample)

drop if sample==0
est drop _all
count


gen other_filter = flag_other_preg
replace other_filter = 0 if other_filter==2

egen poly = rowtotal(lamotrigine_preg_bm carbamazep_preg_bm gabapentin_preg_bm levetiracetam_preg_bm phenytoin_preg_bm pregabalin_preg_bm topiramate_preg_bm valproic_acid_preg_bm other_filter)

generate super_exposure = .
replace super_exposure = 0 if topiramate_comp5==0

local i = 1
		   foreach asm in carbamazep gabapentin levetiracetam phenytoin pregabalin topiramate valproic other {
				  		  replace super_exposure = `i' if  poly == 1 & flag_`asm'_preg==1
			local i = `i'+1
				  
		  }

		  replace super_exposure = 9 if poly>1
		  replace super_exposure = 10 if poly==0
		  
label define super_exposure  ///
0 "Mono Lamotrigine" ///
1 "Mono Carbamazepine" ///
2 "Mono Gabapentin" ///
3 "Mono Levetiracetam" ///
4 "Mono Phenytoin" ///
5 "Mono Pregabalin" ///
6 "Mono Topiramate" ///
7 "Mono Valproic Acid" ///
8 "Mono Other ASM" ///
9 "Polytherapy" ///
10 "No ASM" 
label values super_exposure super_exposure 

 egen somatic_bm_preg = rowmax(chronic_pain_bm_preg migraine_bm_preg diabetes_npr_mbr_bm_preg)

egen psych_bm_preg = rowmax(bipolar_bm_preg anxiety_bm_preg other_psych_bm_preg depression_bm_preg)


egen first_NDD_date = rowmin(id_date_ip  adhd_date_ip asd_date_ip)

** GENERATE  EVENT TIME

egen first_event = rowmin(emigration_date_ip  death_date_ip first_NDD_date)
format first_event %td 
generate outcome = 3 if emigration_date_ip==first_event & first_event!=.
replace outcome = 2 if death_date_ip==first_event & first_event!=.
replace outcome = 1 if first_NDD_date==first_event & first_event!=.
replace outcome = 0 if outcome==. | first_event>td(31dec2021)
replace first_event = td(31dec2021) if first_event==. | first_event>td(31dec2021)
label define outcome 0 "End of follow-up" 1 "NDD" 2 "Death" 3 "Emigration"
label values outcome outcome
*create the distance between NDD censor and birth date
generate FU_ndd = (first_event-birthdate_ip)/365.25
*drop 2 individuals with NDD diagnosis before birth
drop if FU_ndd <=0 & outcome == 1
*add one day to those who died first day of life
replace FU_ndd = FU_ndd+(1/365.25) if FU_ndd<=0 & outcome==2


** GENERATE  EVENT TIME
drop first_event 
egen first_event = rowmin(emigration_date_ip  death_date_ip asd_date_ip )
format first_event %td 
generate outcome_asd = 3 if emigration_date_ip==first_event & first_event!=.
replace outcome_asd = 2 if death_date_ip==first_event & first_event!=.
replace outcome_asd = 1 if asd_date_ip==first_event & first_event!=.
replace outcome_asd = 0 if outcome_asd==. | first_event>td(31dec2021)
replace first_event = td(31dec2021) if first_event==. | first_event>td(31dec2021)

label values outcome_asd outcome
*create the distance between NDD censor and birth date
generate FU_asd = (first_event-birthdate_ip)/365.25
*drop 2 individuals with NDD diagnosis before birth
drop if FU_asd <=0 & outcome_asd == 1
*add one day to those who died first day of life
replace FU_asd = FU_asd+(1/365.25) if FU_asd<=0 & outcome_asd==2

** GENERATE  EVENT TIME
drop first_event 
egen first_event = rowmin(emigration_date_ip  death_date_ip adhd_date_ip )
format first_event %td 
generate outcome_adhd = 3 if emigration_date_ip==first_event & first_event!=.
replace outcome_adhd = 2 if death_date_ip==first_event & first_event!=.
replace outcome_adhd = 1 if adhd_date_ip==first_event & first_event!=.
replace outcome_adhd = 0 if outcome_adhd==. | first_event>td(31dec2021)
replace first_event = td(31dec2021) if first_event==. | first_event>td(31dec2021)

label values outcome_adhd outcome
*create the distance between NDD censor and birth date
generate FU_adhd = (first_event-birthdate_ip)/365.25
*drop 2 individuals with NDD diagnosis before birth
drop if FU_adhd <=0 & outcome_adhd == 1
*add one day to those who died first day of life
replace FU_adhd = FU_adhd+(1/365.25) if FU_adhd<=0 & outcome_adhd==2


** GENERATE  EVENT TIME
drop first_event 
egen first_event = rowmin(emigration_date_ip death_date_ip id_date_ip)
format first_event %td 
generate outcome_id = 3 if emigration_date_ip==first_event & first_event!=.
replace outcome_id = 2 if death_date_ip==first_event & first_event!=.
replace outcome_id = 1 if id_date_ip==first_event & first_event!=.
replace outcome_id = 0 if outcome_id==. | first_event>td(31dec2021)
replace first_event = td(31dec2021) if first_event==. | first_event>td(31dec2021)

label values outcome_id outcome
*create the distance between NDD censor and birth date
generate FU_id = (first_event-birthdate_ip)/365.25
*drop 2 individuals with NDD diagnosis before birth
drop if FU_id <=0 & outcome_id == 1
*add one day to those who died first day of life
replace FU_id = FU_id+(1/365.25) if FU_id<=0 & outcome_id==2

**** histogram over censoring
*hist FU_ndd, by(outcome) xtitle("Age at censoring")



	*replace time = 16 in 4/4
	
	
	
	rename sjukvardsregion_pregstart_bm sjukvarsregion
rename a04_pdr_plusmbr_bm a04
rename n06a_pdr_plusmbr_bm n06a
rename n05_pdr_plusmbr_bm n05
rename addicted_bm_prepreg addicted
rename epilepsy_g40_bm_preg epilepsy
rename chronic_pain_bm_preg pain
rename edu3atbirth_bmbf education
rename diabetes_npr_mbr_bm_preg diabetes
rename super_exposure exposure

foreach var of varlist bcountry_bm_nm dispink5atbirth education addicted paritet seizure_visit sambo_atbirth_bm visits_1y_cat epilepsy depression_bm_preg  bipolar_bm_preg  other_psych_bm_preg  migraine_bm_preg  diabetes n05 a04 n06a pain sjukvarsregion male any_ndd_bm exposure rounded_pregyear {
	
	quietly tab `var', gen(dum_`var')
}

quietly tab exposure, gen(exposure_dum)

*sample 5

	foreach indication in somatic psych  epilepsy  { // 
		
	
	if "`indication'" == "somatic" global covar age_atbirth_bm age_atbirth_bm_cube bcountry_bm_nm dum_dispink5atbirth1 dum_dispink5atbirth2 dum_dispink5atbirth3 dum_dispink5atbirth4 dum_education1 dum_education2 dum_addicted1 dum_paritet1 dum_paritet2 dum_paritet3 dum_paritet4 dum_seizure_visit1 dum_sambo_atbirth_bm1 dum_visits_1y_cat1 dum_visits_1y_cat2 dum_epilepsy1 dum_depression_bm_preg1 dum_bipolar_bm_preg1 dum_other_psych_bm_preg1 dum_n051 dum_a041 dum_n06a1 dum_sjukvarsregion1 dum_sjukvarsregion2 dum_sjukvarsregion3 dum_sjukvarsregion4 dum_sjukvarsregion5 dum_male1 dum_any_ndd_bm1 dum_rounded_pregyear1 dum_rounded_pregyear2 dum_rounded_pregyear3 dum_rounded_pregyear4 dum_rounded_pregyear5 dum_rounded_pregyear6 dum_rounded_pregyear7 dum_rounded_pregyear8

	
	if "`indication'" == "psych" global covar age_atbirth_bm age_atbirth_bm_cube bcountry_bm_nm dum_dispink5atbirth1 dum_dispink5atbirth2 dum_dispink5atbirth3 dum_dispink5atbirth4 dum_education1 dum_education2 dum_addicted1 dum_paritet1 dum_paritet2 dum_paritet3 dum_paritet4 dum_seizure_visit1 dum_sambo_atbirth_bm1 dum_visits_1y_cat1 dum_visits_1y_cat2 dum_epilepsy1 dum_n051 dum_a041 dum_n06a1 dum_sjukvarsregion1 dum_sjukvarsregion2 dum_sjukvarsregion3 dum_sjukvarsregion4 dum_sjukvarsregion5 dum_male1 dum_any_ndd_bm1 dum_diabetes1 dum_pain1 dum_migraine_bm_preg1 dum_rounded_pregyear1 dum_rounded_pregyear2 dum_rounded_pregyear3 dum_rounded_pregyear4 dum_rounded_pregyear5 dum_rounded_pregyear6 dum_rounded_pregyear7 dum_rounded_pregyear8
	
		if "`indication'" == "epilepsy" global covar age_atbirth_bm age_atbirth_bm_cube bcountry_bm_nm dum_dispink5atbirth1 dum_dispink5atbirth2 dum_dispink5atbirth3 dum_dispink5atbirth4 dum_education1 dum_education2 dum_addicted1 dum_paritet1 dum_paritet2 dum_paritet3 dum_paritet4 dum_seizure_visit1 dum_sambo_atbirth_bm1 dum_visits_1y_cat1 dum_visits_1y_cat2 dum_depression_bm_preg1 dum_bipolar_bm_preg1 dum_other_psych_bm_preg1 dum_n051 dum_a041 dum_n06a1 dum_sjukvarsregion1 dum_sjukvarsregion2 dum_sjukvarsregion3 dum_sjukvarsregion4 dum_sjukvarsregion5 dum_male1 dum_any_ndd_bm1 dum_diabetes1 dum_pain1 dum_migraine_bm_preg1 dum_rounded_pregyear1 dum_rounded_pregyear2 dum_rounded_pregyear3 dum_rounded_pregyear4 dum_rounded_pregyear5 dum_rounded_pregyear6 dum_rounded_pregyear7 dum_rounded_pregyear8 
	
	

			preserve
		if "`indication'" == "epilepsy" keep if epilepsy==1
		if "`indication'" == "psych" keep if psych_bm_preg==1
		if "`indication'" == "somatic" keep if somatic_bm_preg==1
		
	
	 foreach var in asd adhd id {

	stset FU_`var', failure(outcome_`var'==1)
	
	stpm2 exposure_dum1 exposure_dum2 exposure_dum3 exposure_dum4 exposure_dum5 exposure_dum6 exposure_dum7 exposure_dum8 exposure_dum9 exposure_dum10 $covar , scale(hazard) df(4) eform
	est store stpm2_`var'_`indication'

	
	 }
	
	  estout stpm2*`indication' using "C:\Users\vikahl\OneDrive - Karolinska Institutet\Skrivbordet\standsurv export\output_`indication'_oct2024.xls", keep(exposure*)  cells("b(fmt(5)) se(fmt(5)) ci(fmt(5))") label replace 
restore 
	}
	
	gen time =. 
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

*keep if e(sample)
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
at11(exposure_dum1 0 exposure_dum2 0 exposure_dum3 0 exposure_dum4 0 exposure_dum5 0 exposure_dum6 0 exposure_dum7 0 exposure_dum8 0 exposure_dum9 0 exposure_dum10 0) ///
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
	save "C:\Users\vikahl\OneDrive - Karolinska Institutet\Skrivbordet\standsurv export\std_`indication'_oct2024.dta", replace
	restore
	**drop Lamotrigine_asd-Diff_Polytherapy_id_uci
 }
	
	
	