

cap prog drop pr_getallbmirecords
program define pr_getallbmirecords

syntax, patientfile(string) clinicalfile(string) additionalfile(string) 

*PUT UNDERSCORES BEFORE THE GENERATED VAR NAMES
*THIS SHOULD START WITH A ROW PP FILE CONTAINING PATID
noi di
noi di in yellow _dup(5) "*"
noi di in yellow "Summary of key BMI decisions/algorithm :""
*Summary of key decisions implemented in this file
set linesize 200
noi di in yellow "*- drop if age < 16
noi di in yellow "*- from age 16 , decided to allow heights to carry forward if missing (see an_growthbt16and21.log)"
noi di in yellow "*- drop if 3+ measurements on the same day"
noi di in yellow "*- if 2 mmts on same day: drop if >5cm (ht)/1kg (wt) diff, otherwise take the mean"
noi di in yellow "*- initial pass, drop weights less than 2kg, heights less than 2kg"
noi di in yellow "*- later, drops weights < 20kg, heights less than 4 or more than 7 feet "
noi di in yellow "*- fills in missing heights using LOCF or if no previous, first future ht mmt"
noi di in yellow "*- calculates a version of bmi directly from ht and wt"
noi di in yellow "*- drops bmis <5 or >200 (but if GPRD and calculated version differ, and one is in the range 10-100, uses the sensible one)"
noi di in yellow "*- in general, prioritises calculated bmi, and only uses GPRD version if cannot be calculated (as no ht mmt available at all)"
noi di in yellow "*- drops records after end of f-up (tod or lcd) but keeps those < start of fup (uts or crd)"
noi di 
noi di in yellow _dup(120) "*"
noi di in yellow "BMI LOG INFO"
noi di in yellow _dup(120) "*"

keep patid

noi di "Loading weight/bmi (entity==13) and height (entity==14) records from additional file and merging in patient data"

merge 1:m patid using "`clinicalfile'", keep(match master) keepusing(eventdate_num medcode adid) nogen
drop if adid==0
drop if adid==.
merge 1:1 patid adid using "`additionalfile'", keep(match master) keepusing(enttype data1 data3) nogen
merge m:1 patid using "`patientfile'", keep(match master) nogen keepusing(yob)
keep if enttype==13|enttype==14
drop if eventdate_num==.
destring data1, replace 
destring data3, replace 

cou 
noi di "Number of records of height or weight/bmi imported = " r(N)

noi di "Approximate date of birth as 15th June on the year of birth, to calculate age at mmt..."
gen ageatmmt = (eventdate_num - mdy(6, 15, yob))/365.25
noi di "... dropping record if aged <16 yrs at measurement"
noi drop if ageatmmt<16

sort patid eventdate_num enttype data1

*Drop implausible heights and weights (less than a newborn, min 2kg, 40cm)
noi di "Dropping records where weight < 2kg or height < 40cm"
noi drop if enttype==13 & data1<2
noi drop if enttype==14 & data1<.4

*Drop duplicate heights or weights on the same day or (for heights) if duplicated in m then cm
noi di "Dropping duplicate heights or weights on the same day (or duplicate heights where one in m one in cm"
noi by patid eventdate_num enttype: drop if data1==data1[_n-1]
noi by patid eventdate_num enttype: drop if data1>=99*data1[_n-1] & data1<=101*data1[_n-1] & enttype==14

*Drop if >2 ht or wt mmts on the same day
noi di "Drop records where 3+ measurements on the same day"
noi by patid eventdate_num enttype: drop if _N>2

datacheck _N==1, by(patid eventdate_num enttype) nol flag
*Deal with remaining with >1 mmt on same day
*If 2, and within 5cm (ht) or 1kg (wt), take the average, otherwise drop all
noi di "Dealing with 2 different mmts on the same day..."
by patid eventdate_num enttype: gen diff=data1-data1[_n-1] if _n==2 & _c==1
by patid eventdate_num enttype: replace diff=diff[2]  if _n==1 & _N==2 & _c==1
noi di "... if 2 weights >1kg difference, drop both"
noi drop if diff>1 & diff<. & enttype==13 & _c==1
noi di "... if 2 heights >5cm difference, drop both"
noi drop if diff>.05 & diff<. & enttype==14 & _c==1
noi di "For the remainder, take the mean of the 2 mmts and keep 1 record"
drop diff
by patid eventdate_num enttype: egen data1av = mean(data1) if _c==1
noi replace data1 = data1av if _c==1 
by patid eventdate_num enttype: egen data3av = mean(data3) if _c==1
noi replace data3 = data3av if _c==1 
drop data1av data3av
by patid eventdate_num enttype: drop if _n>1 & _c==1

drop _contra
noi di "Now we have max one height and/or one weight record per patient on any given date..."
by patid eventdate_num enttype: assert _N==1

noi di "...reshaping wide to create one record per patient per mmt date, with weight and/or bmi and/or height..."
by patid eventdate_num: replace data3 = data3[1] if data3==. & enttype==14

keep patid eventdate_num enttype data1 data3 ageatmmt

reshape wide data1, i(patid eventdate_num) j(enttype)

rename data113 weight
rename data114 height
rename data3 bmi

noi di "Dealing with missing heights"

*Replicate the GPRD height policy (i.e. take the last one, or the first one for records pre- first height)
*Note all records under 16 are already dropped so no probs about using <16 heights

gen ageatlastht = ageatmmt if height<.
by patid: replace ageatlastht = ageatlastht[_n-1] if height==. & ageatlastht[_n-1]<.
noi di "Filling in missing heights"
cou if height==. & ageatlastht<.
local tottofill = r(N)
cou if weight<.
local totalwtrecords = r(N)
noi di "Total number of records containing a weight : " `totalwtrecords'
cou if weight<. & height==.
local totmissinght = r(N)
noi di "Total number of records containing a weight but no height: " r(N) " (" %3.1f 100*`totmissinght'/`totalwtrecords' "%)"
cou if weight<. & height==. & ageatlastht<.
local tottofill = r(N)
noi di "Number of missing heights to be filled by locf (i.e. where a previous height was recorded): " `tottofill' " (" %3.1f 100*`tottofill'/`totmissinght' "% of those missing)"
cou if weight<. & height==. & ageatmmt>21 & ageatlastht<18
noi di "Number of missing heights aged over 21 where the last height was age<18: " r(N) " (" %3.1f 100*r(N)/`tottofill' "% of those being filled)"

noi di "Filling in the heights with LOCF regardless of age..."
noi by patid: replace height = height[_n-1] if height==. & height[_n-1]<.

by patid: gen cumht = sum(height) if height<.
by patid: egen firstht = min(cumht)
cou if weight<. & height==. & firstht<.
noi di "Number of missing heights that can be filled in using a future measurement: " r(N) " (" %3.1f 100*r(N)/`totmissinght' "% further of the original number missing)" 
noi di "Filling in heights with future height..."
noi replace height = firstht if height==.
drop cumht firstht 
cou if weight<. & height==.
local remainingnoheight=r(N)
noi di "This leaves " r(N) " (" %3.1f 100*r(N)/`totalwtrecords' "%) weight records with no height available at all..."
cou if height==. & bmi<.
noi di "...however " r(N) " (" %3.1f 100*r(N)/`remainingnoheight' "%) of these do have a bmi entered"

noi di "Dropping height-only records as of no further use"
noi drop if height<. & weight==. & bmi==.

noi di "Now cleaning data to remove apparent errors where possible"

noi di "If height is apparently in cm then convert to m (i.e. if the recorded height would correspond to 4-7ft in cm)"
noi replace height = height/100 if height>121 & height<214 /*i.e. between 4 and 7 ft in cm*/
noi di "Calculate bmi from weight and height, and compare with GPRD bmi field..."
gen bmi_calc=weight/(height^2)
gen discrep=bmi-bmi_calc
*Note GPRD seem to round down the 1st DP regardless
gen discreprnd=bmi-(floor(bmi_calc*10)/10)
replace discreprnd=0 if discreprnd<0.0001
replace discreprnd=0 if abs(discrep)<0.0001


*If one sensible, one silly, take the sensible one
noi di "If GPRD bmi is silly (<200 or <5) then replace with missing, and same for the calculated version..."
noi replace bmi=. if (bmi>200|bmi<5) 
noi replace bmi_calc=. if (bmi_calc>200|bmi_calc<5) 

noi di ".. and now drop records where both GPRD bmi field amd calculated field are missing (which therefore also drops the silly ones)"
noi drop if bmi==. & bmi_calc==. /*useless records*/

*Drop record if height <4ft or >7ft 
noi di "Drop records where height recorded is <4 of >7ft"
noi drop if height<1.21
noi drop if height>2.14 & height<.

egen wtcat = cut(weight), at(0(1)25 30(5)100 1000)
noi di "Weight distribution - note the peak between 10 and 20 - suggests recorded in stones?"
noi tab wtcat /*note the peak between 10 and 20 - stones?*/
noi di "Drop if weight<=20 as likely to be recorded in stones or error"
noi drop if weight<=20 /*I think these have mostly been recorded in stones*/

*Use calculated version where poss as no weird rounding 
noi di "Prioritise calculated bmi (from wt/ht) as the one to use (preferable as GPRD version always appears to be rounded down)...  "
noi di "...but fill in missing values in the calculated BMI, with GPRD BMI where it is available"
noi replace bmi_calc=bmi if bmi_calc==.

egen bmicat = cut(bmi_calc), at(0 5 6 7 8 9 10 11 12 13 14 15 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200)
noi di "Distribution of BMI records (before considering fup dates etc); note truncated at 5 and 200 by above processing, but may wish to restrict more in analysis...e.g. to 3 sds from mean?"
noi tab bmicat

drop bmi bmicat discrep* wtcat 
rename bmi_calc bmi

noi di "Total patients with at least one record"
noi codebook patid

rename eventdate_num dobmi

sort patid dobmi

*keep patid dobmi bmi 

compress

noi di in yellow _dup(120) "*"

end

*To use, e.g.:
*use $Datadir/cr_cohortU, clear
*pr_getallbmirecords, patientfile($Rawdata/patient_extract_bphfull_1) clinicalfile($Rawdata/clinical_extract_bphfull_1.dta) additionalfile($Rawdata/additional_extract_bphfull_1.dta)

