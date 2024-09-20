log using "$Logdir\LOG_cr_Insheet_and_format_CPRD.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			28 September 2021
* Description: 		Create .dta files of CPRD data and format
* Notes: 			Builds on  \\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\cohort_identification\cohort_identification.do written by Ruta Margelyte and on scripts written by Hein Heuvelman as part of the antidepressants in pregnancy project
********************************************************************************
* Notes on major updates (Date - description):
* 
********************************************************************************
* Contents
********************************************************************************
* 1 - Baby-mother link
* 2 - Pregnancy register
* 3 - Therapy files
* 4 - Test files
* 5 - Staff files
* 6 - Referral files
* 7 - Practice files
* 8 - Patient files
* 9 - Immunisation files
* 10 - Consultation files 
* 11 - Clinical files
* 12 - Additional files 
* 13 - CPRD linkage eligibility
* 14 - Delete all individual stata files

********************************************************************************
* 1 - Baby-mother link
********************************************************************************
import delimited "$Rawtextdir\data_linked\20_000228_mother_baby_link.txt", clear

format %12.0g babypatid 
		
gen deldate_num = date(deldate, "DMY")
format %d deldate_num

* Label variables
label variable pracid "CPRD practice identifier"
label variable mumpatid "Mother's CPRD patient identifier"
label variable babypatid "Child's CPRD patient identifier"
label variable deldate "Assumed delivery date for the baby (from mothers record)"
label variable deldate_num "Assumed delivery date for the baby (from mothers record) - numerical"
label variable mumbirthyear "Mother's year of birth"
label variable children "The number of children matched to this mother"

compress *

save "$Rawdatdir\stata\data_linked\20_000228_mother_baby_link.dta", replace


********************************************************************************
* 2 - Pregnancy register
********************************************************************************
*pregnancy register (July 2020)

import delimited "$Rawtextdir\data_linked\20_000228_pregnancy_register.txt", clear

format %12.0g babypatid 

*Create numerical variables for eventdate and sysdate
gen pregstart_num = date(pregstart, "DMY")
format pregstart_num %td

gen secondtrim_num = date(secondtrim, "DMY")
format secondtrim_num %td				

gen thirdtrim_num = date(thirdtrim, "DMY")
format thirdtrim_num %td		

gen pregend_num = date(pregend, "DMY")
format pregend_num %td

*Label variables
label variable patid "patient id"
label variable pregid "pregnancy id"
label variable mblbabies "number of babies pregnancy is linked to in MBL"
label variable babypatid "patient id for linked baby"
label variable babymob "baby's month of birth"
label variable babyyob "baby's year of birth"
label variable totalpregs "total number of identified pregnancy episodes"
label variable pregnumber "pregnancy episode number"
label variable pregstart "estimated start date of pregnancy - string"
label variable secondtrim "estimated start date of second trimester - string"
label variable thirdtrim "estimated start date of third trimester - string"
label variable pregend "estimated end date of pregnancy (see documentation) - string"
label variable gestdays "estimated duration of pregnancy in gestational days"
label variable matage "mother's age at end of pregnancy in years"
label variable outcome "outcome of pregnancy (see documentation)"
label variable preterm_ev "flag to indicate evidence of preterm delivery (see documentation)"
label variable multiple_ev "flag to indicate evidence of a multiple pregnancy (see documentation)"
label variable conflict "flag to indicate whether the pregnancy episode overlaps with another episode"
label variable pregstart_num "estimated start date of pregnancy - numerical"
label variable secondtrim_num "estimated start date of second trimester - numerical"
label variable thirdtrim_num "estimated start date of third trimester - numerical"
label variable pregend_num "estimated end date of pregnancy (see documentation) - numerical"

*Sort on patient ID and pregnancy ID
sort patid pregid

*Compress data
compress *

save "$Rawdatdir\stata\data_linked\20_000228_pregnancy_register.dta", replace

********************************************************************************
* 3 Therapy files
********************************************************************************
* Save CPRD Therapy files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "027" "028" "029" "030" "031" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" 
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Therapy_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Therapy_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Therapy_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Therapy_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
			
			
			* Generate numerical date variables, add variable labels, sort data on patid and eventdate and compress
			*Create numerical variables for eventdate and sysdate
			gen eventdate_num = date(eventdate, "DMY")
			format eventdate_num %td

			gen sysdate_num = date(sysdate, "DMY")
			format sysdate_num %td
				
			*Label variables
			label variable patid "patient id"
			label variable eventdate "date of therapy event - string"
			label variable eventdate_num "date of therapy event - numerical"
			label variable sysdate "date entered on Vision - string"
			label variable sysdate_num "date entered on Vision - numerical"
			label variable consid "consultation id: linkage with consultation file when used with pracid"
			label variable prodcode "CPRD code for treatment, selected by GP"
			label variable staffid "id of staff entering data onto Vision, zero is unknown"
			label variable dosageid "dosage id: linkage with dosage info when used with pracid and eventtype therapy"
			label variable bnfcode "chapter and section of British National Formulary pharmaceutical reference book"
			label variable qty "total quantity entered by GP for prescribed product"
			label variable numdays "number of treatment days prescribed for therapy event"
			label variable numpacks "number of product packs prescribed for therapy event"
			label variable packtype "pack size or type of prescribed product"
			label variable issueseq "prescription part of repeat schedule"
			label variable prn "prescription supplied 'as required' (see documentation)"
			label variable drugdmd "mapped drug DMD code"  
						
			*Sort on patient ID and eventdate	
			sort patid eventdate_num
						
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}


* append files into single therapy file
use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Therapy_001.dta", clear

foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "027" "028" "029" "030" "031" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" 
		}

	
		disp "chno = `chno'; partno = `partno'"
	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Therapy_`fileno'.dta"
			}	

			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Therapy_`fileno'.dta"
			}
			
			disp "`filename'"
			append using "`filename'"
			count
			
		}
	
	}
}	

duplicates report
duplicates tag, gen(tag)
tab tag
duplicates drop	
count
drop tag
sort patid eventdate_num
save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Therapy_Files.dta", replace




********************************************************************************
* 4 Test files
********************************************************************************
* Save CPRD Test files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Test_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Test_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Test_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Test_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
			
			
			* Generate numerical date variables, add variable labels, sort data on patid and eventdate and compress
			*Create numerical variables for eventdate and sysdate
			gen eventdate_num = date(eventdate, "DMY")
			format eventdate_num %td

			gen sysdate_num = date(sysdate, "DMY")
			format sysdate_num %td
				
			*Label variables
				label variable patid "patient id"
				label variable eventdate "date of therapy event - string"
				label variable eventdate_num "date of therapy event - numerical"
				label variable sysdate "date entered on Vision - string"
				label variable sysdate_num "date entered on Vision - numerical"
				label variable consid "consultation id: linkage with consultation file when used with pracid"
				label variable constype "consultation type: category of event"
				label variable medcode "CPRD code for medical term, selected by GP"
				label variable staffid "id of staff entering data onto Vision, zero is unknown"
				label variable enttype "entity type: structure data area in Vision where data was entered"
				label variable data1 "depends on enttype: see CPRD data dictionary for further info"
				label variable data2 "depends on enttype: see CPRD data dictionary for further info"
				label variable data3 "depends on enttype: see CPRD data dictionary for further info"
				label variable data4 "depends on enttype: see CPRD data dictionary for further info"
				label variable data5 "depends on enttype: see CPRD data dictionary for further info"
				label variable data6 "depends on enttype: see CPRD data dictionary for further info"
				label variable data7 "depends on enttype: see CPRD data dictionary for further info"
				label variable data8 "depends on enttype: see CPRD data dictionary for further info"
				label variable sctid "The mapped SNOMED CT Concept ID" /* flag for deltion*/
				label variable sctdescid "description ID of the selected term" /* flag for deltion*/
				label variable sctexpression "SNOMED CT post-coordinated expressions" /* flag for deltion*/
				label variable sctmaptype "Indicates the native encoding of the record in the Vision software (4 = term selected from Read dictionary, 5= term selected from SNOMED CT)" /* flag for deltion*/
				label variable sctmapversion "The version of the READ-SNOMED CT mapping table applied" /* flag for deltion*/
				label variable sctisindicative "Used to indicate the reliability of the reverse SNOMED CT-Read map. Where SNOMED CT codes do not have a direct mapping to READ, the code 'Rz…00' will be utilised." /* flag for deltion*/
				label variable sctisassured "Indicates whether the Read to SNOMED mapping has been verified by a panel of physicians" /* flag for deltion*/
						
			*Sort on patient ID and eventdate	
			sort patid eventdate_num
						
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}


* append files into single test file
use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Test_001.dta", clear

foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		disp "chno = `chno'; partno = `partno'"
	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Test_`fileno'.dta"
			}	

			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Test_`fileno'.dta"
			}
			
			disp "`filename'"
			append using "`filename'"
			count
			
		}
	
	}
}	


duplicates drop	
count
sort patid eventdate_num
save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Test_Files.dta", replace


********************************************************************************
* 5 Staff files
********************************************************************************
* Save CPRD Staff files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Staff_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Staff_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Staff_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Staff_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
				
			*Label variables
			label variable staffid "id of staff member who entered the data"
			label variable gender "staff's gender"
			label variable role "role of the staff member who created the event (lookup ROL)"
						
			*Sort on patient ID and eventdate	
			sort staffid
						
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}

use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Staff_001.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part2_extract\20_000228_ch1_2_Extract_Staff_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part1_extract\20_000228_patid_ch3_1_Extract_Staff_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Staff_001.dta"

duplicates drop	
count
sort staffid

save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Staff_Files.dta", replace



********************************************************************************
* 6 - Referral files
********************************************************************************
* Save CPRD Referral files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Referral_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Referral_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Referral_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Referral_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
				
			*Create numerical variables for eventdate and sysdate
			gen eventdate_num = date(eventdate, "DMY")
			format eventdate_num %td
				
			gen sysdate_num = date(sysdate, "DMY")
			format sysdate_num %td
			
			*Label variables
			label variable patid "patient id"
			label variable eventdate "date of therapy event - string"
			label variable eventdate_num "date of therapy event - numerical"
			label variable sysdate "date entered on Vision - string"
			label variable sysdate_num "date entered on Vision - numerical"
			label variable consid "consultation id: linkage with consultation file when used with pracid"
			label variable constype "consultation type: category of event"
			label variable medcode "CPRD code for medical term, selected by GP"
			label variable staffid "id of staff entering data onto Vision, zero is unknown"
			label variable source "classification of source of referral, e.g. GP, Self"
			label variable nhsspec "referral speciality according to the NHS classification"
			label variable fhsaspec "referral speciality according to the Family Health Services Authority classification"
			label variable inpatient "classification of type of referral, e.g. day case, in-patient"
			label variable attendance "category describing whether referral event is first visit, follow-up, etc"
			label variable urgency "classification of the urgency of the referral, e.g. routine, urgent"
					
			*Sort on patient ID and eventdate
			sort patid eventdate_num
				
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}

use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Referral_001.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part2_extract\20_000228_ch1_2_Extract_Referral_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part1_extract\20_000228_patid_ch3_1_Extract_Referral_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Referral_001.dta"

duplicates drop	
count
sort patid eventdate_num

save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Referral_Files.dta", replace


********************************************************************************
* 7 - Practice files
********************************************************************************
* Save CPRD Practice files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Practice_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Practice_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Practice_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Practice_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
				
			*Create numerical variables for eventdate and sysdate	
			gen lcd_num = date(lcd, "DMY")
			format lcd_num %td
			
			gen uts_num = date(uts, "DMY")
			format uts_num %td
			
			*Label variables
			label variable pracid "practice id"
			label variable region "region within the UK (lookup PRG)"
			label variable lcd "date of last collection for the practice - string"
			label variable lcd_num "date of last collection for the practice - numerical"
			label variable uts "date at which practice data is deemed to be of research quality - string"
			label variable uts_num "date at which practice data is deemed to be of research quality - numerical"
					
			*Sort on patient ID and eventdate
			sort pracid
				
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}

use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Practice_001.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part2_extract\20_000228_ch1_2_Extract_Practice_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part1_extract\20_000228_patid_ch3_1_Extract_Practice_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Practice_001.dta"

duplicates drop	
count
sort pracid

save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Practice_Files.dta", replace

********************************************************************************
* 8 - Patient files
********************************************************************************
* Save CPRD Patient files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Patient_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Patient_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Patient_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Patient_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
				
			*Create numerical variables for eventdate and sysdate	
			gen chsdate_num = date(chsdate, "DMY")
			format chsdate_num %td
			
			gen frd_num = date(frd, "DMY")
			format frd_num %td
			
			gen crd_num = date(crd, "DMY")
			format crd_num %td
			
			gen tod_num = date(tod, "DMY")
			format tod_num %td
			
			*Label variables
			label variable patid "patient id"
			label variable vmid "old VM id for patient when practice used the VAMP system"
			label variable gender "patient's gender"
			label variable yob "patient's year of birth"
			label variable mob "patient's month of birth"
			label variable marital "patients current marital status (lookup MAR)"
			label variable famnum "family id"
			label variable chsreg "patient registered with Child Health Surveillance"
			label variable chsdate "date of registration with CHS - string"
			label variable chsdate_num "date of registration with CHS - numerical"
			label variable prescr "type of prescribing exception the patient has currently (medical, maternity)"
			label variable capsup "level of capitation supplement the patient has currently (low, medium, high)"
			label variable frd "date of patient's first registation with practice (important: see data spec for info)"
			label variable frd_num "date of patient's first registration - numerical"
			label variable crd "date the patients current registration with practice began (important: see data spec for info)"
			label variable crd_num "date the patient's current registration with practice began - numerical"
			label variable regstat "status of registration detailing gaps and temporary patients"
			label variable reggap "number of days missing in the patients' registration details"
			label variable internal "number of internal transfer out periods, in the patient's registration details"
			label variable tod "date patient transferred out of practice, if relevant"
			label variable tod_num "date patient transferred out of practice, if relevant - numerical"
			label variable toreason "reason for patient transferring out of practice"
			label variable deathdate "date of death of patient - derived using a CPRD algorithm"
			label variable accept "flag to indicate whether patient has met certain quality standards"
					
			*Sort on patient ID and eventdate
			sort  patid
				
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}

use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Patient_001.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part2_extract\20_000228_ch1_2_Extract_Patient_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part1_extract\20_000228_patid_ch3_1_Extract_Patient_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Patient_001.dta"

duplicates drop	
count
sort patid

save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Patient_Files.dta", replace

********************************************************************************
* 9 - Immunisation files
********************************************************************************
* Save CPRD Immunisation files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002"
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002"
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  "002" "003"
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Immunisation_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Immunisation_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Immunisation_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Immunisation_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
				
			*Create numerical variables for eventdate and sysdate	
			gen eventdate_num = date(eventdate, "DMY")
			format eventdate_num %td
			
			gen sysdate_num = date(sysdate, "DMY")
			format sysdate_num %td
			
			*Label variables
			label variable patid "patient id"
			label variable eventdate "date of therapy event - string"
			label variable eventdate_num "date of therapy event - numerical"
			label variable sysdate "date entered on Vision - string"
			label variable sysdate_num "date entered on Vision - numerical"
			label variable consid "consultation id: linkage with consultation file when used with pracid"
			label variable constype "consultation type: category of event"
			label variable medcode "CPRD code for medical term, selected by GP"
			label variable staffid "id of staff entering data onto Vision, zero is unknown"
			label variable immstype "individual components of an immunisation (e.g. Mumps, Rubella, Measles)"
			label variable stage "stage of immunisation given"
			label variable status "status of the immunisation (advised, given, refusal)"
			label variable compound "immunisation compound administered, single or multi-component preparation"
			label variable source "location where immunisation was administered"
			label variable reason "reason for administering immunisation, e.g. routine measure"
			label variable method "rout of administration of the immunisation, e.g. oral, intramuscular"
			label variable batch "immunisation batch number"
			label variable sctid "The mapped SNOMED CT Concept ID" /* flag for deltion*/
			label variable sctdescid "description ID of the selected term" /* flag for deltion*/
			label variable sctexpression "SNOMED CT post-coordinated expressions" /* flag for deltion*/
			label variable sctmaptype "Indicates the native encoding of the record in the Vision software (4 = term selected from Read dictionary, 5= term selected from SNOMED CT)" /* flag for deltion*/
			label variable sctmapversion "The version of the READ-SNOMED CT mapping table applied" /* flag for deltion*/
			label variable sctisindicative "Used to indicate the reliability of the reverse SNOMED CT-Read map. Where SNOMED CT codes do not have a direct mapping to READ, the code 'Rz…00' will be utilised." /* flag for deltion*/
			label variable sctisassured "Indicates whether the Read to SNOMED mapping has been verified by a panel of physicians" /* flag for deltion*/
				
				
			*Sort on patient ID and eventdate
			sort patid eventdate_num
				
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}

use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Immunisation_001.dta", clear
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Immunisation_002.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part2_extract\20_000228_ch1_2_Extract_Immunisation_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part2_extract\20_000228_ch1_2_Extract_Immunisation_002.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part1_extract\20_000228_patid_ch3_1_Extract_Immunisation_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part1_extract\20_000228_patid_ch3_1_Extract_Immunisation_002.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Immunisation_001.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Immunisation_002.dta"
append using "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch3_part2_extract\20_000228_patid_ch3_2_Extract_Immunisation_003.dta"

duplicates drop	
count
sort patid eventdate_num

save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Immunisation_Files.dta", replace

********************************************************************************
* 10 - Consultation files 
********************************************************************************
* Save CPRD Consultation files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Consultation_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Consultation_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Consultation_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Consultation_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
			
			
			* Generate numerical date variables, add variable labels, sort data on patid and eventdate and compress
			*Create numerical variables for eventdate and sysdate
			gen eventdate_num = date(eventdate, "DMY")
			format eventdate_num %td

			gen sysdate_num = date(sysdate, "DMY")
			format sysdate_num %td
				
			*Label variables
			label variable patid "patient id"
			label variable eventdate "date of therapy event - string"
			label variable eventdate_num "date of therapy event - numerical"
			label variable sysdate "date entered on Vision - string"
			label variable sysdate_num "date entered on Vision - numerical"
			label variable consid "consultation id: linkage with consultation file when used with pracid"
			label variable constype "consultation type: category of event"
			label variable staffid "id of staff entering data onto Vision, zero is unknown"
			label variable duration "length of time between opening and closing consultation record"
			
						
			*Sort on patient ID and eventdate	
			sort patid eventdate_num
						
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}


* append files into single test file
use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Consultation_001.dta", clear

foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		disp "chno = `chno'; partno = `partno'"
	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Consultation_`fileno'.dta"
			}	

			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Consultation_`fileno'.dta"
			}
			
			disp "`filename'"
			append using "`filename'"
			count
			
		}
	
	}
}	


duplicates drop	
count
sort patid eventdate_num
save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Consultation_Files.dta", replace


********************************************************************************
* 11 - Clinical files 
********************************************************************************
* Save CPRD Clinical files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "027" "028" "029"
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Clinical_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Clinical_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Clinical_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Clinical_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
			
			
			* Generate numerical date variables, add variable labels, sort data on patid and eventdate and compress
			*Create numerical variables for eventdate and sysdate
			gen eventdate_num = date(eventdate, "DMY")
			format eventdate_num %td

			gen sysdate_num = date(sysdate, "DMY")
			format sysdate_num %td
				
			*Label variables
			label variable patid "patient id"
			label variable eventdate "date of therapy event - string"
			label variable eventdate_num "date of therapy event - numerical"
			label variable sysdate "date entered on Vision - string"
			label variable sysdate_num "date entered on Vision - numerical"
			label variable consid "consultation id: linkage with consultation file when used with pracid"
			label variable constype "consultation type: category of event"
			label variable medcode "CPRD code for medical term, selected by GP"
			label variable staffid "id of staff entering data onto Vision, zero is unknown"
			label variable episode "episode type for a specific clinical event (lookup EPI)"
			label variable enttype "identifies representing the structured data area in Vision (lookup Entity)"
			label variable adid "identified allowing additional info to be retrieved in combination with pracid"
			label variable sctid "The mapped SNOMED CT Concept ID" /* flag for deltion*/
			label variable sctdescid "description ID of the selected term" /* flag for deltion*/
			label variable sctexpression "SNOMED CT post-coordinated expressions" /* flag for deltion*/
			label variable sctmaptype "Indicates the native encoding of the record in the Vision software (4 = term selected from Read dictionary, 5= term selected from SNOMED CT)" /* flag for deltion*/
			label variable sctmapversion "The version of the READ-SNOMED CT mapping table applied" /* flag for deltion*/
			label variable sctisindicative "Used to indicate the reliability of the reverse SNOMED CT-Read map. Where SNOMED CT codes do not have a direct mapping to READ, the code 'Rz…00' will be utilised." /* flag for deltion*/
			label variable sctisassured "Indicates whether the Read to SNOMED mapping has been verified by a panel of physicians" /* flag for deltion*/
									
			*Sort on patient ID and eventdate	
			sort patid eventdate_num
						
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}


* append files into single test file
use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Clinical_001.dta", clear

foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "027" "028" "029"
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022"
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005"  
		}
		
		disp "chno = `chno'; partno = `partno'"
	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Clinical_`fileno'.dta"
			}	

			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Clinical_`fileno'.dta"
			}
			
			disp "`filename'"
			append using "`filename'"
			count
			
		}
	
	}
}		


duplicates drop	
count
sort patid eventdate_num
save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Clinical_Files.dta", replace

********************************************************************************
* 12 - Additional files 
********************************************************************************
* Save CPRD Additional files in rawdata folder as stata files
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}

	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Additional_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Additional_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filein "$Rawtextdir\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Additional_`fileno'.txt"
				local fileout "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Additional_`fileno'.dta"
			}
	
			import delimited using "`filein'" , clear
			
				
			*Label variables
			label variable patid "patient id"
			label variable enttype "identifies representing the structured data area in Vision (lookup Entity)"
			label variable adid "identified allowing additional info to be retrieved in combination with pracid"
			label variable data1 "depends on enttype (lookup Entity)"
			label variable data2 "depends on enttype (lookup Entity)"
			label variable data3 "depends on enttype (lookup Entity)"
			label variable data4 "depends on enttype (lookup Entity)"
			label variable data5 "depends on enttype (lookup Entity)"
			label variable data6 "depends on enttype (lookup Entity)"
			label variable data7 "depends on enttype (lookup Entity)"
			label variable data8 "depends on enttype (lookup Entity)"
			label variable data9 "depends on enttype (lookup Entity)"
			label variable data10 "depends on enttype (lookup Entity)"
			label variable data11 "depends on enttype (lookup Entity)"
			label variable data12 "depends on enttype (lookup Entity)"			
									
			*Sort on patient ID 
			sort patid 
						
			*Compress data
			compress *
			
			save "`fileout'", replace
			
		}	
	}
}


* append files into single test file
use "$Rawdatdir\stata\data_gold_2021_08\20_000228_ch1_part1_extract\20_000228_ch1_1_Extract_Additional_001.dta", clear

foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" 
		}
	
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}


	
		disp "chno = `chno'; partno = `partno'"
	
		foreach fileno in "`filelist'" {
			
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Additional_`fileno'.dta"
			}	

			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Additional_`fileno'.dta"
			}
			
			disp "`filename'"
			append using "`filename'"
			count
			
		}
	
	}
}		


duplicates drop	
count
sort patid 
save "$Rawdatdir\stata\data_gold_2021_08\collated_files\All_Additional_Files.dta", replace

********************************************************************************
* 13 - CPRD linkage eligibility
********************************************************************************
* Files already in stata format found in \\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\cohort_identification

* Copied \\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Analysis\rawdatafiles\stata\data_linked



********************************************************************************
* 14 - Delete all individual stata files
********************************************************************************
* Therapy files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "027" "028" "029" "030" "031" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" 
		}	
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Therapy_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Therapy_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}



* Test files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Test_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Test_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}


* Staff files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Staff_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Staff_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}


* Referral files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Referral_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Referral_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}


* Practice files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Practice_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Practice_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}


* Patient files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Patient_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Patient_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}




* Immunisation files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002"
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002"
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  "002" "003"
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Immunisation_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Immunisation_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}



* Consultation files 
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Consultation_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Consultation_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}


* Clinical files
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" "023" "024" "025" "026" "027" "028" "029"
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019" "020" "021" "022" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" "005"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Clinical_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Clinical_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}


* Additional files 
********************************************************************************
foreach chno in "ch1" "ch3" {
	foreach partno in "1" "2" {
		if "`chno'"== "ch1" &  "`partno'"=="1" { 
			local filelist "001" "002" "003" "004" "005" 
		}
		if "`chno'"== "ch1" &  "`partno'"=="2" { 
			local filelist "001" "002" "003" "004" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="1" { 
			local filelist "001" 
		}
		if "`chno'"== "ch3" &  "`partno'"=="2" { 
			local filelist "001"  
		}
		foreach fileno in "`filelist'" {	
			if "`chno'" == "ch1" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_`chno'_`partno'_Extract_Additional_`fileno'.dta"
			}
			if "`chno'" == "ch3" {
				local filename "$Rawdatdir\stata\data_gold_2021_08\20_000228_`chno'_part`partno'_extract\20_000228_patid_`chno'_`partno'_Extract_Additional_`fileno'.dta"
			}
			capture erase "`filename'" 
		}	
	}
}




********************************************************************************
log close
