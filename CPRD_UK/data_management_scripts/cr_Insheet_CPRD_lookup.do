log using "$Logdir\LOG_cr_Insheet_CPRD_lookup.txt", text replace
********************************************************************************
* do file author:	Paul Madley-Dowd
* Date: 			28 October 2021
* Description: 		Create .dta files of CPRD lookup files
* Notes: 			
********************************************************************************
* Notes on major updates (Date - description):
* 
********************************************************************************
* Contents
********************************************************************************
* 1 - Read in lookup files as stata files and save

********************************************************************************
* 1 - Read in lookup files as stata files and save
********************************************************************************
foreach filenam in batchnumber bnfcodes common_dosages entity medical packtype product scoremethod {
    import delim using "$Rawdatdir/documentation/Lookups_2021_09/`filenam'.txt", clear
	save "$Rawdatdir/documentation\Lookups_2021_09/`filenam'.dta", replace
}


foreach filenam in AAR ABO ADT ADV AFD AGC AMA ASL ATT BMO BPR CAP CEN CER CHS COD COS COT CST CTT CUF CVD CYX DAS DBS DEP DIE EPI EPM EXE FIT FPR GLA GMP HPS IMC IME IMM IMT INP ISI IST KIN LAC LAT LEG LIV LMP LNG LOC MAR MBO N_A NCO OPR P_A P_N PBP PEX PFD PHR PMR POC POP POS PRE PRG PSM RCT RDB REF RES RFT RIN ROL SED SEV SEX SIN SOU SPE SUM TOF TQU TRA TYP URG VIS Y_N YND{ 
	import delim using "$Rawdatdir\documentation\Lookups_2021_09\TXTFILES/`filenam'.txt", clear
	save "$Rawdatdir\documentation\Lookups_2021_09\TXTFILES/`filenam'.dta", replace
}
********************************************************************************
log close