
cap prog drop pr_getheightstatus
program define pr_getheightstatus

syntax, index(string) patientfile(string) clinicalfile(string) additionalfile(string)

noi di
noi di in yellow _dup(5) "*"
noi di in yellow "Assign Height based on nearest status to index date in the range:"
noi di in yellow "(BEST) [-365, +30] from index"
noi di in yellow "(2ND BEST) (+30, +365] from index"
noi di in yellow "(3RD BEST) (-inf,-30) from index"
noi di in yellow "(4TH BEST) (+365, +inf) from index"
noi di in yellow _dup(5) "*"

preserve
noi pr_getallbmirecords, patientfile("`patientfile'") clinicalfile("`clinicalfile'") additionalfile("`additionalfile'")
tempfile allbmirecords
save `allbmirecords'
restore

qui{

merge 1:m patid using `allbmirecords'
keep if height!=.
sort patid dobmi

*Algorithm:
*Take the nearest status of -1y to +1month from index (best)
*then nearest up to 1y after (second best)*
*then any before (third best)
*then any after (least best)

rename dobmi eventdate
gen _distance = eventdate-`index'
gen _priority = 1 if _distance>=-365 & _distance<=30
replace _priority = 2 if _distance>30 & _distance<=365
replace _priority = 3 if _distance<-365
replace _priority = 4 if _distance>365 & _distance<.
gen _absdistance = abs(_distance)
sort patid _priority _absdistance
by patid: replace height = height[1] 
drop eventdate _merge _distance _priority _absdistance

by patid: keep if _n==1

}/*end of quietly*/

end

*To use, e.g.:
*use $Datadir/cr_cohortU, clear
*pr_getbmistatus, index(doindex) patientfile($Rawdata/patient_extract_bphfull_1) clinicalfile($Rawdata/clinical_extract_bphfull_1.dta) additionalfile($Rawdata/additional_extract_bphfull_1.dta)
