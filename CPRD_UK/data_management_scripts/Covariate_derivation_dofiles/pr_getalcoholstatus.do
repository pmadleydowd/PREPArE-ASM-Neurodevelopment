
*pr_getalcoholstatus
*Adds alcohol status to a file containing patid and an index date
*A "level" variable is required in the codelist file: it should be coded as (0=none) 1=low, 2=med, 3=high
*If there isn't one, just create one with all missing values

cap prog drop pr_getalcoholstatus
program define pr_getalcoholstatus

syntax, clinicalfile(string) additionalfile(string) alcoholcodelist(string) alcoholstatusvar(string) alcohollevelvar(string) index(string)

noi di
noi di in yellow _dup(5) "*"
noi di in yellow "Assign alcohol status/level (from either clinical, therapy or additional file),"
noi di in yellow "based on nearest status pre index date:"
noi di in yellow _dup(5) "*"

*qui{

******************************************
*PICK UP ALCOHOL INFO FROM ADDITIONAL FILE, for later
******************************************
preserve
merge 1:m patid using "`additionalfile'", keep(match master) nogen
keep if enttype==5
destring data1, replace
destring data2, replace
rename data1 status
rename data2 unitsperwk
drop data*
keep patid adid status unitsperwk pregid
drop if (status==0|status==.) & unitsperwk==.
recode status 1=1 2=0 3=2 /*to match the codes in the clinical codelist - i.e. 0=No 1=Yes 2=Ex*/
gen unitscat=unitsperwk
recode unitscat 0=0 1/14=1 15/42=2 43/10000=3
drop unitsperwk
tempfile additionalalcoholdata
save `additionalalcoholdata'
restore 

****************************************************************************************
*GET ALCOHOL TREATMENT Rx CODES and save for later
****************************************************************************************
preserve
merge 1:m patid using "$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Therapy_Files_reduced", keep(match master) nogen
merge m:1 prodcode using "$Codelsdir\treatment_alc_abuse", keep(match)
rename _merge alcoholdatamatched
bysort patid: keep if _n==1
tempfile therapyalcoholdata
save `therapyalcoholdata'
restore 
****************************************************************************************
*GET ALCOHOL STATUS FROM CODES, AND SUPPLEMENT WITH INFO FROM ADDITIONAL RETRIEVED ABOVE
****************************************************************************************
merge 1:m patid using "`clinicalfile'", keep(match master) keepusing(eventdate medcode adid) nogen

merge m:1 medcode using "`alcoholcodelist'", keepusing(`alcoholstatusvar' `alcohollevelvar') keep(match master)
drop medcode
rename _merge alcoholdatamatched

replace adid = -_n if adid==0 /*this is just to avoid the "patid adid do not uniquely identify observations in the master data" error which is caused by all the adid=0s */
merge 1:1 patid adid using `additionalalcoholdata'
replace alcoholdatamatched=3 if _merge==3
drop adid
drop _merge
merge m:1 patid using `therapyalcoholdata'
replace alcoholdatamatched=3 if _merge==3

drop _merge
replace `alcoholstatusvar'=status if `alcoholstatusvar'==.
replace `alcohollevelvar'=unitscat if `alcohollevelvar'==.
drop status unitscat
gsort patid -alcoholdatamatched eventdate
by patid: drop if alcoholdatamatched !=3 & _n>1
replace eventdate=. if alcoholdatamatched!=3



*********************************************************
*ASSIGN STATUS BASED ON INDEX DATE, USING ALGORITHM BELOW
*********************************************************
*Algorithm:
*Take the nearest status of -1y to +1month from index (best)
*then nearest up to 1y after (second best)*
*then any before (third best)
*then any after (least best)

gen _distance = eventdate-`index'
drop if _distance>gestdays
gen _priority = 1 if _distance>=0 
replace _priority = 2 if _distance<0 & _distance>=-(365*10)

gen _absdistance = abs(_distance)
sort patid _priority _absdistance 

*Patients nearest status is non-drinker, but have history of drinking, recode to ex-drinker.
by patid: egen ever_alc=sum(`alcoholstatusvar') 
by patid: replace `alcoholstatusvar' = 2 if ever_alc>0 & `alcoholstatusvar'==0

sort patid _priority _absdistance
by patid: replace `alcoholstatusvar' = `alcoholstatusvar'[1] 
by patid: replace `alcohollevelvar' = `alcohollevelvar'[1] 
drop alcoholdatamatched
by patid: keep if _n==1

***}/*end of quietly*/

end


*To use, e.g.:
*use $Datadir/cr_cohortU, clear
*pr_getalcoholstatus, clinicalfile($Rawdata/clinical_extract_bphfull_1) additionalfile($Rawdata/additional_extract_bphfull_1) alcoholcodelist($Codelists/cr_alcoholcodes) alcoholstatusvar(alcstatus) alcohollevelvar(alclevel) index(doindex)
