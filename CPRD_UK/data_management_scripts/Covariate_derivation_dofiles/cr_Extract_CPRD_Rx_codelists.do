/*==============================================================================

AUTHOR: H FORBES
DATE; 10th January 2022
==============================================================================*/

set more off, permanently


*#################
*### Rx in 365 days pre-pregnancy ###
*#################


	*### ALL ADs, APs ###
	foreach x in antipsychotics multivitamin folic_acid antidepressants {
		use "$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Therapy_Files", clear
		
		*Merge with prodcodes
		merge m:1 prodcode using "$Codelsdir/Prescription_`x'_signed_off_DR.dta", keepusing(prodcode)
		
		*Keep if matched
		keep if _merge==3
		drop _merge
		sort patid

		save "$Datadir\Derived_data\CPRD\_temp/`x'_Rx_all.dta", replace
	}
	
	*### IN 365 days pre-preg ###
	
	foreach x in antipsychotics multivitamin folic_acid antidepressants {

		forvalues n=1/14 {
			use "$Datadir\Derived_data\Cohorts/pregnancy_cohort_final_`n'", clear
			keep patid pregid pregstart_num 	
			*Merge with pregnancy register
			merge 1:m patid using "$Datadir\Derived_data\CPRD\_temp/`x'_Rx_all.dta"
			
			*Keep if matched
			keep if _merge==3
			drop _merge
			sort patid
			
			gen _dist= pregstart_num-eventdate_num
			keep if _dist<=0 & _dist>-365
			
			gen `x'_365_prepreg=1
			
			keep patid pregid `x'_365_prepreg
			save "$Datadir\Derived_data\CPRD\_temp/`x'_`n'", replace
		}
	}
	
	use "$Datadir\Derived_data\CPRD\_temp\antipsychotics_1", clear
	forvalues n=2/14 {
		append using "$Datadir\Derived_data\CPRD\_temp\antipsychotics_`n'"
	}
	duplicates drop
	merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
	replace antipsychotics = 0 if antipsychotics ==.
	label variable antipsychotics "Antipsychotic use in the year before pregnancy (binary)"
	keep patid pregid antipsychotics
	save "$Datadir\Derived_data\covariates\antipsychotics_Rx_365_pre_preg.dta", replace
	
	
	use "$Datadir\Derived_data\CPRD\_temp\antidepressants_1", clear
	forvalues n=2/14 {
		append using "$Datadir\Derived_data\CPRD\_temp\antidepressants_`n'"
	}
	duplicates drop
	merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
	replace antidepressants = 0 if antidepressants ==.
	label variable antidepressants "Antidepressant use in the year before pregnancy (binary)"
	keep patid pregid antidepressants
	save "$Datadir\Derived_data\covariates\antidepressants_Rx_365_pre_preg.dta", replace
	
	

	use "$Datadir\Derived_data\CPRD\_temp\multivitamin_1", clear
	forvalues n=2/14 {
		append using "$Datadir\Derived_data\CPRD\_temp\multivitamin_`n'"
	}
	duplicates drop
	merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
	replace multivitamin = 0 if multivitamin ==.
	label variable multivitamin "Multivitamin use in the year before pregnancy (binary)"
	keep patid pregid multivitamin
	save "$Datadir\Derived_data\covariates\multivitamin_Rx_365_pre_preg.dta", replace
	
	
	use "$Datadir\Derived_data\CPRD\_temp\folic_acid_1", clear
	forvalues n=2/14 {
		append using "$Datadir\Derived_data\CPRD\_temp\folic_acid_`n'"
	}
	duplicates drop
	merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_matids_pregids.dta", nogen keep(2 3)
	replace folic_acid = 0 if folic_acid ==.
	label variable folic_acid "Folic acid use in the year before pregnancy (binary)"
	keep patid pregid folic_acid
	save "$Datadir\Derived_data\covariates\folic_acid_Rx_365_pre_preg.dta", replace
	
	*### IN FIRST TRIMESTER PREGNANCY ? ###
	