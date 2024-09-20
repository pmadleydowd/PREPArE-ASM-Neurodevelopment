 /****************************************************************************
DO FILE 2: CREATE ETHICITY CATEGORIES AND ATTACH TO DENOMINATOR FILE
*****************************************************************************/
 
/****************************************************************************
**CREATE FILE OF ALL ETHNICITY CODES IN CLINICAL FILE IN WHOLE CPRD POPULATION
*****************************************************************************/
use "$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Clinical_Files", clear 
keep patid medcode enttype adid eventdate_num sysdate_num
merge m:1 medcode using "$Codelsdir\codelist_ethnicity_gold.dta" 
keep if _merge==3
save "$Datadir\Derived_data\CPRD\interim_ethnicity_codes", replace 


**drop NZ codes /*New Zealand*/
gen nzsubstr=substr(readcode,1,2)
tab nzsubstr
br nz readterm if nzsubstr=="9T"
drop if nzsubstr=="9T" //5,604 deleted*

*drop true duplicates n=3,635 events
duplicates drop

**turn sysdate format into years - note system date more complete than eventdate
gen sysyear=year(sysdate)
sum sysyear //1996-2014

**tag people with the same ethnicity recorded in the same year
duplicates tag patid sysyear readcode, gen(duplicate)
tab duplicate if duplicate>0


lab var duplicate "duplicate ethnicity recorded in the same year"

**gen indicators for obs of ethnicity per patient
sort patid eventdate
bysort patid: gen count=[_n]
bysort patid: gen total=[_N]
sum count total


gen totalobs=total
recode totalobs (2/5=2) (6/10=3) (11/max=3), gen(obsgroup)
label define obsgroup 1"1" 2"2-5" 3"6-57"
label values obsgroup obsgroup
tab obsgroup

**ADD UP ETHNICITIES
bysort patid eth5: gen eth5count=[_N]
bysort patid eth16: gen eth16count=[_N]
tab eth5count
tab eth16count

gen white5count=eth5count if eth5==0
gen sa5count=eth5count if eth5==1
gen black5count=eth5count if eth5==2
gen other5count=eth5count if eth5==3
gen mixed5count=eth5count if eth5==4
gen notstated5count=eth5count if eth5==5

tab white5count if count==1
tab white5count if count==total


gen british16count=eth16count if eth16==1
gen irish16count=eth16count if eth16==2
gen otherwhite16count=eth16count if eth16==3
gen whitecarib16count=eth16count if eth16==4
gen whiteaf16count=eth16count if eth16==5
gen whiteasian16count=eth16count if eth16==6
gen othermixed16count=eth16count if eth16==7
gen indian16count=eth16count if eth16==8
gen pak16count=eth16count if eth16==9
gen bangla16count=eth16count if eth16==10
gen otherasian16count=eth16count if eth16==11
gen carib16count=eth16count if eth16==12
gen african16count=eth16count if eth16==13
gen otherblack16count=eth16count if eth16==14
gen chinese16count=eth16count if eth16==15
gen other16count=eth16count if eth16==16
gen notstated16count=eth16count if eth16==17

**MAKE COUNTS CONSTANT

local p  "white sa black other mixed notstated"
foreach i of local p {
sort patid count
replace `i'5count=`i'5count[_n-1] if `i'5count[_n]==. & `i'5count[_n-1]!=. & patid[_n]==patid[_n-1] & totalobs>1
gsort patid -count
replace `i'5count=`i'5count[_n-1] if `i'5count[_n]==. & `i'5count[_n-1]!=. & patid[_n]==patid[_n-1] & totalobs>1
}

local p "british irish otherwhite whitecarib whiteaf whiteasian othermixed indian pak bangla otherasian carib african otherblack chinese other notstated"
foreach i of local p {
sort patid count
replace `i'16count=`i'16count[_n-1] if `i'16count[_n]==. & `i'16count[_n-1]!=. & patid[_n]==patid[_n-1] & totalobs>1
gsort patid -count
replace `i'16count=`i'16count[_n-1] if `i'16count[_n]==. & `i'16count[_n-1]!=. & patid[_n]==patid[_n-1] & totalobs>1
}



**DUMMY FOR WHETHER ONLY ETHNICITY IS NOT STATED
gen notstatedonly=0
replace notstatedonly=1 if white5count==. & sa5count==. & black5count==. & other5count==. & mixed5count==. & notstated5count!=. 

**MAKE CONSTANT
sort patid count
replace notstatedonly=notstatedonly[_n-1] if notstatedonly[_n]==0 & notstatedonly[_n-1]!=0 & patid[_n]==patid[_n-1] & totalobs>1
gsort patid -count
replace notstatedonly=notstatedonly[_n-1] if notstatedonly[_n]==0 & notstatedonly[_n-1]!=0 & patid[_n]==patid[_n-1] & totalobs>1
sort patid count

gen enter=1 if count==1
gen exit=1 if count==total
tab enter exit
tab notstatedonly if enter==1, missing
tab notstatedonly if exit==1, missing

/*notstatedon |
         ly |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  4,248,350       93.18       93.18
          1 |    310,879        6.82      100.00
------------+-----------------------------------
      Total |  4,559,229      100.00

*/


**MOST COMMON ETHNICITY EXCLUDING NOT STATED


egen eth5max=rowmax(white5count sa5count black5count other5count mixed5count)
tab eth5max

egen eth16max=rowmax(british16count irish16count otherwhite16count whitecarib16count whiteaf16count whiteasian16count othermixed16count indian16count pak16count bangla16count otherasian16count carib16count african16count otherblack16count chinese16count other16count) 
tab eth16max


**ETH 5
gen mostcommoneth5=eth5 if eth5max==totalobs // give most common eth a value if a person only had 1 ethnicity recorded in all observations
replace mostcommoneth5=eth5 if totalobs==1   //makes mostcomoneth==eth if a person only has 1 observation
replace mostcommoneth5=0 if eth5max==white5count & eth5max!=.
replace mostcommoneth5=1 if eth5max==sa5count & eth5max!=.
replace mostcommoneth5=2 if eth5max==black5count & eth5max!=.
replace mostcommoneth5=3 if eth5max==other5count & eth5max!=.
replace mostcommoneth5=4 if eth5max==mixed5count & eth5max!=.
replace mostcommoneth5=5 if notstatedonly==1
label values mostcommoneth5 eth5

tab mostcommoneth5 if enter==1
tab mostcommoneth5 if exit==1

/*ostcommone |
        th5 |      Freq.     Percent        Cum.
------------+-----------------------------------
      White |  3,350,728       78.86       78.86
South Asian |    254,301        5.98       84.84
      Black |    166,283        3.91       88.76
      Other |    119,129        2.80       91.56
      Mixed |     66,637        1.57       93.13
 Not Stated |    292,003        6.87      100.00
------------+-----------------------------------
      Total |  4,249,081      100.00
*/

**PEOPLE WITH 2 ETHNICITIES THAT ARE EQUALLY MOST COMMON- exclude not stated
**this creates a dummy which is equal to 1 if 2 ethnicities are equally common, but only 1 has been coded as being "mostcommoneth5"
gen equallycommon5=0
replace equallycommon5=1 if eth5max==white5count & mostcommoneth!=0 & totalobs!=1 & notstatedonly==0
replace equallycommon5=1 if eth5max==sa5count & mostcommoneth!=1 & totalobs!=1 & notstatedonly==0
replace equallycommon5=1 if eth5max==black5count & mostcommoneth!=2 & totalobs!=1 & notstatedonly==0
replace equallycommon5=1 if eth5max==other5count & mostcommoneth!=3 & totalobs!=1 & notstatedonly==0
replace equallycommon5=1 if eth5max==mixed5count & mostcommoneth!=4 & totalobs!=1 & notstatedonly==0
tab equallycommon5

/*quallycomm |
        on5 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  5,054,866       98.86       98.86
          1 |     58,086        1.14      100.00
------------+-----------------------------------
      Total |  5,112,952      100.00
*/

**update mostcommoneth to separate those with equally common ethnicities
replace mostcommoneth5=6 if equallycommon5==1  & notstatedonly==0

**ETH 16
gen  mostcommoneth16=eth16 if eth16max==totalobs // give most common eth a value if a person only had 1 ethnicity recorded in all observations
replace mostcommoneth16=eth16 if totalobs==1   //makes mostcomoneth==eth if a person only has 1 observation
replace mostcommoneth16=1 if eth16max==british16count & eth16max!=.
replace mostcommoneth16=2 if eth16max==irish16count & eth16max!=.
replace mostcommoneth16=3 if eth16max==otherwhite16count & eth16max!=.
replace mostcommoneth16=4 if eth16max==whitecarib16count & eth16max!=.
replace mostcommoneth16=5 if eth16max==whiteaf16count & eth16max!=.
replace mostcommoneth16=6 if eth16max==whiteasian16count & eth16max!=.
replace mostcommoneth16=7 if eth16max==othermixed16count & eth16max!=.
replace mostcommoneth16=8 if eth16max==indian16count & eth16max!=.
replace mostcommoneth16=9 if eth16max==pak16count & eth16max!=.
replace mostcommoneth16=10 if eth16max==bangla16count & eth16max!=.
replace mostcommoneth16=11 if eth16max==otherasian16count & eth16max!=.
replace mostcommoneth16=12 if eth16max==carib16count & eth16max!=.
replace mostcommoneth16=13 if eth16max==african16count & eth16max!=.
replace mostcommoneth16=14 if eth16max==otherblack16count & eth16max!=.
replace mostcommoneth16=15 if eth16max==chinese16count & eth16max!=.
replace mostcommoneth16=16 if eth16max==other16count & eth16max!=.
replace mostcommoneth16=17 if notstatedonly==1
label values mostcommoneth16 eth16

tab mostcommoneth16 if enter==1
tab mostcommoneth16 if exit==1

/*   mostcommoneth16 |      Freq.     Percent        Cum.
--------------------------+-----------------------------------
                  British |  2,633,433       61.98       61.98
                    Irish |     38,142        0.90       62.87
              Other White |    678,583       15.97       78.84
White and Black Caribbean |     11,999        0.28       79.13
  White and Black African |      9,751        0.23       79.36
          White and Asian |     11,631        0.27       79.63
              Other Mixed |     27,402        0.64       80.27
                   Indian |     96,551        2.27       82.55
                Pakistani |     56,084        1.32       83.87
              Bangladeshi |     19,676        0.46       84.33
              Other Asian |     83,327        1.96       86.29
                Caribbean |     31,150        0.73       87.02
                  African |     90,308        2.13       89.15
              Other Black |     47,744        1.12       90.27
                  Chinese |     29,867        0.70       90.98
       Other ethnic group |     91,430        2.15       93.13
               Not Stated |    292,003        6.87      100.00
--------------------------+-----------------------------------
                    Total |  4,249,081      100.00
*/

**PEOPLE WITH 2 ETHNICITIES THAT ARE EQUALLY MOST COMMON- exclude not stated
**this creates a dummy which is equal to 1 if 2 ethnicities are equally common, but only 1 has been coded as being "mostcommoneth16"
gen equallycommon16=0
replace equallycommon16=1 if eth16max==british16count & mostcommoneth16!=1 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==irish16count & mostcommoneth16!=2 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==otherwhite16count & mostcommoneth16!=3 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==whitecarib16count & mostcommoneth16!=4 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==whiteaf16count & mostcommoneth16!=5 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==whiteasian16count & mostcommoneth16!=6 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==othermixed16count & mostcommoneth16!=7 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==indian16count & mostcommoneth16!=8 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==pak16count & mostcommoneth16!=9 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==bangla16count & mostcommoneth16!=10 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==otherasian16count & mostcommoneth16!=11 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==carib16count & mostcommoneth16!=12 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==african16count & mostcommoneth16!=13 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==otherblack16count & mostcommoneth16!=14 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==chinese16count & mostcommoneth16!=15 & totalobs!=1 & notstatedonly==0
replace equallycommon16=1 if eth16max==other16count & mostcommoneth16!=16 & totalobs!=1 & notstatedonly==0
tab equallycommon16

/*equallycomm |
       on16 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  4,921,168       96.25       96.25
          1 |    191,784        3.75      100.00
------------+-----------------------------------
      Total |  5,112,952      100.00

*/

**update mostcommoneth to separate those with equally common ethnicities
replace mostcommoneth16=18 if equallycommon16==1 & notstatedonly==0

label define eth5 6"equally common", add
label define eth16 18"equally common", add
*bro patid count eth5 mostcommoneth5 notstatedonly if equallycommon5==1
bro patid count eth16 mostcommoneth16 notstatedonly if equallycommon16==1
compress




**ETHNICITY
**patients with valid ethnicity ever recorded
gen anyethever=0
replace anyethever=1 if eth16==.
tab anyethever //100% as these are only patients with ethncity codes-need to make this variable 0 when attached to denominator population


**patients with valid ethnicity ever recorded
gen validethever=0
replace validethever=1 if eth16!=17
replace validethever=0 if eth16==.
tab validethever

/*validetheve |
          r |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    414,103        8.10        8.10
          1 |  4,698,849       91.90      100.00
------------+-----------------------------------
      Total |  5,112,952      100.00
*/

*make ethever constant within patients
sort patid count
replace anyethever=anyethever[_n-1] if anyethever[_n]==0 & anyethever[_n-1]==1 & patid[_n]==patid[_n-1]
replace validethever=validethever[_n-1] if validethever[_n]==0 & validethever[_n-1]==1 & patid[_n]==patid[_n-1]
gsort patid -count
replace anyethever=anyethever[_n-1] if anyethever[_n]==0 & anyethever[_n-1]==1 & patid[_n]==patid[_n-1]
replace validethever=validethever[_n-1] if validethever[_n]==0 & validethever[_n-1]==1 & patid[_n]==patid[_n-1]
sort patid count
replace anyethever=0 if anyethever==.
replace validethever=0 if validethever==.

**count of valid ethnicities recorded
gen validethcount=1 if eth16!=17 & eth16!=.
replace validethcount=0 if eth16==17 | eth16==.

sort patid count
replace validethcount=validethcount[_n]+validethcount[_n-1] if patid[_n]==patid[_n-1]


**total number of ethnicities recorded (including multiple recordings of the same ethnicity)
gen totalvalideth=validethcount if exit==1
tab totalvalideth

*make totaleth constant for each patient
sort patid count
replace totalvalideth=totalvalideth[_n-1] if totalvalideth[_n]==. & totalvalideth[_n-1]!=. & patid[_n]==patid[_n-1]
gsort patid -count
replace totalvalideth=totalvalideth[_n-1] if totalvalideth[_n]==. & totalvalideth[_n-1]!=. & patid[_n]==patid[_n-1]
sort patid count


*dummy for multiple ethnicities excluding not stated
gen morethanoneeth=0 if totalvalideth<=1
replace morethanoneeth=1 if totalvalideth>1
tab morethanoneeth


/*morethanone |
        eth |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  3,737,331       73.10       73.10
          1 |  1,375,621       26.90      100.00
------------+-----------------------------------
      Total |  5,112,952      100.00
*/

**GEN VARIABLE FOR THE FIRST YEAR ETH WAS RECORDED- using frd
sort patid count
gen firstyear=year(eventdate) if count==1
destring firstyear, replace
sum firstyear //1905-2015

replace firstyear=firstyear[_n-1] if patid[_n]==patid[_n-1] & [_n]!=1 

*are ethnicities matching
*do not give unknown ethnicity a unique counter
sort patid eth16 count
gen uniqueeth=0
replace uniqueeth=1 if eth16[_n]!=eth16[_n-1] & patid[_n]==patid[_n-1] & eth16[_n]!=17 & eth16[_n-1]!=17
replace uniqueeth = 1 if patid[_n]>patid[_n-1]
replace uniqueeth=0 if eth16==17
tab uniqueeth

/* uniqueeth |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,035,088       20.24       20.24
          1 |  4,077,864       79.76      100.00
------------+-----------------------------------
      Total |  5,112,952      100.00
*/

*count unique ethnicities 
**EXCLUDE UNKNOWN
sort patid  count
replace uniqueeth=uniqueeth[_n]+uniqueeth[_n-1] if patid[_n]==patid[_n-1] & uniqueeth[_n]!=. & uniqueeth[_n-1]!=. & count!=1 
gsort patid -count
sum uniqueeth //people have up to a maximum of 12 different ethnicities

sort patid eth16 uniqueeth
replace uniqueeth=uniqueeth[_n-1] if uniqueeth[_n]==. & uniqueeth[_n-1]!=. & patid[_n]==patid[_n-1]

*ethsum gives the number of different ethnic groups recorded
*totaluniqueeth gives the number of ethnicities recorded per patient- excluding duplicates

*count of unique ethnicities per patient
sort patid uniqueeth
bysort patid: gen totaluniqueeth = uniqueeth[_N] 
tab totaluniqueeth if enter==1
tab totaluniqueeth if exit==1

**dummy for yes no to having multiple unique ethnicities
**UNKNOWN Ethnicity is excluded from all counts
gen sameeth=1 if totaluniqueeth==1
replace sameeth=0 if totaluniqueeth>1
tab sameeth if enter==1
tab sameeth if exit==1

/* sameeth |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    117,313        2.96        2.96
          1 |  3,839,764       97.04      100.00
------------+-----------------------------------
      Total |  3,957,077      100.00
*/

**indicator for whether all of the ethnicities fall under the same high level group
**ethnicity which is unknown is ignored
*ie/ if a person has 3 ethnicities, white, british and unknown, then they are considered to have matching eth5
sort patid count
gen eth5same=1 if enter==1
replace eth5same=1 if eth5[_n]==eth5[_n-1] & patid[_n]==patid[_n-1]
replace eth5same=1 if eth5==5
tab eth5same, missing

*if any eth5same values are missing- then replace as 0 and make constant
replace eth5same=0 if eth5same==.
replace eth5same=eth5same[_n-1] if eth5same[_n-1]==0 & patid[_n]==patid[_n-1]
gsort patid -count
replace eth5same=eth5same[_n-1] if eth5same[_n-1]==0 & patid[_n]==patid[_n-1]
sort patid count

tab eth5same if enter==1
tab eth5same if exit==1


sort patid count
gen eth16same=1 if enter==1
replace eth16same=1 if eth16[_n]==eth16[_n-1] & patid[_n]==patid[_n-1]
replace eth16same=1 if eth16==17
tab eth16same, missing

*if any eth5same values are missing- then replace as 0 and make constant
replace eth16same=0 if eth16same==.
replace eth16same=eth16same[_n-1] if eth16same[_n-1]==0 & patid[_n]==patid[_n-1]
gsort patid -count
replace eth16same=eth16same[_n-1] if eth16same[_n-1]==0 & patid[_n]==patid[_n-1]
sort patid count

tab eth16same if enter==1
tab eth16same if exit==1


*FIXED VARIABLE FOR LATEST ETH
gsort patid -eventdate
gen latesteth=readcode 
gen latestdesc=readterm 
gen latesteth16=eth16 
gen latesteth5=eth5

replace latesteth=latesteth[_n-1] if patid[_n]==patid[_n-1] & [_n]!=1 
replace latestdesc=latestdesc[_n-1] if patid[_n]==patid[_n-1] & [_n]!=1 
replace latesteth16=latesteth16[_n-1] if patid[_n]==patid[_n-1] & [_n]!=1 
replace latesteth5=latesteth5[_n-1] if patid[_n]==patid[_n-1] & [_n]!=1 

label values latesteth16 eth16
label values latesteth5 eth5

save "$Datadir\Derived_data\CPRD\All Ethnicity GOLD CPRD.dta", replace


**MAKE PATIENT LEVEL FILE
**drop duplicate patids
use "$Rawdatdir/stata\data_gold_2021_08\collated_files\All_Patient_Files", clear

merge 1:m patid using "$Datadir\Derived_data\CPRD\All Ethnicity GOLD CPRD.dta", gen(merge2)

/*  Result                           # of obs.
    -----------------------------------------
    not matched                    11,975,076
        from master                11,975,076  (merge2==1)
        from using                          0  (merge2==2)

    matched                         5,480,181  (merge2==3)
    -----------------------------------------
*/

codebook patid //16,534,305
duplicates drop patid, force
codebook patid //16,534,305

keep patid accept latesteth16 latesteth5 mostcommon*

**MERGE WITH HES ETHNICITY
merge 1:1 patid using "$Datadir\Derived_data\HES/ethnicity_hes", nogen
codebook patid //16,548,408 -  afew people in HES are not in CPRD- keep for now.

**GEN ONE VARIABLE FOR ETHNICITY
 
gen eth5=mostcommoneth5 //main ethnicity is most common in CPRD
label values eth5 eth5
tab eth5, missing

/*  
          eth5 |      Freq.     Percent        Cum.
---------------+-----------------------------------
         White |  3,591,497       21.70       21.70
   South Asian |    269,775        1.63       23.33
         Black |    177,088        1.07       24.40
         Other |    118,505        0.72       25.12
         Mixed |     61,749        0.37       25.49
    Not Stated |    310,879        1.88       27.37
equally common |     29,736        0.18       27.55
             . | 11,989,179       72.45      100.00
---------------+-----------------------------------
         Total | 16,548,408      100.00
*/

*remove equally common group
replace eth5=latesteth5 if eth5>=5 & latesteth5!=.  //replace ethnicity with latest eth5 if mostcommoneth5 is not stated/equal/missing
tab eth5, missing

/*    eth5 |      Freq.     Percent        Cum.
---------------+-----------------------------------
         White |  3,600,071       21.75       21.75
   South Asian |    274,269        1.66       23.41
         Black |    180,625        1.09       24.50
         Other |    126,138        0.76       25.27
         Mixed |     66,885        0.40       25.67
    Not Stated |    311,241        1.88       27.55
             . | 11,989,179       72.45      100.00
---------------+-----------------------------------
         Total | 16,548,408      100.00
*/

*add HES ethnicity where missing in CPRD
replace eth5=heseth5 if eth5>4 & heseth5!=. //replace ethnicity with HES ethnicity if still missing/notstated/equal
tab eth5, missing

/* 
 eth5 |      Freq.     Percent        Cum.
---------------+-----------------------------------
         White |  6,026,404       36.42       36.42
   South Asian |    349,961        2.11       38.53
         Black |    238,429        1.44       39.97
         Other |    179,897        1.09       41.06
         Mixed |     92,500        0.56       41.62
    Not Stated |    868,549        5.25       46.87
             . |  8,792,668       53.13      100.00
---------------+-----------------------------------
         Total | 16,548,408      100.00

*/


gen eth16=mostcommoneth16 
label values eth16 eth16
replace eth16=latesteth16 if eth16>=17 & latesteth16<17  //replace ethnicity with latest eth16 if mostcommoneth5 is not stated/equal/missing
tab eth16, missing
replace eth16=heseth16 if eth16>=17 & heseth16!=. //the standard HES categories don't map to the 16 census categories (ie/ HES has White not split into British/Irish/Other White and Mixed not split into Mixed White/African White/Caribbean etc..)
tab eth16 eth5, missing
tab eth16,m

label define eth16 17"Unknown" 18"White (HES)" 19"Mixed (HES)", modify

/*     eth16 |      Freq.     Percent        Cum.
--------------------------+-----------------------------------
                  British |  2,859,801       17.28       17.28
                    Irish |     39,299        0.24       17.52
              Other White |    700,385        4.23       21.75
White and Black Caribbean |     13,364        0.08       21.83
  White and Black African |     11,190        0.07       21.90
          White and Asian |     12,905        0.08       21.98
              Other Mixed |     29,458        0.18       22.16
                   Indian |    138,878        0.84       22.99
                Pakistani |     78,364        0.47       23.47
              Bangladeshi |     26,840        0.16       23.63
              Other Asian |    105,822        0.64       24.27
                Caribbean |     51,247        0.31       24.58
                  African |    127,012        0.77       25.35
              Other Black |     60,071        0.36       25.71
                  Chinese |     45,454        0.27       25.98
       Other ethnic group |    134,623        0.81       26.80
               Unknown    |  9,661,549       58.38       85.18
              White (HES) |  2,426,522       14.66       99.85
              Mixed (HES) |     25,624        0.15      100.00
--------------------------+-----------------------------------
                    Total | 16,548,408      100.00
*/

compress
notes: this dataset includes some people in HES V10 who are not in Jul 2016 CPRD
notes

**DUMMY FOR WHETHER ETHNICITY IS DERIVED FROM CPRD OR HES
gen ethnicity_source=0
replace ethnicity_source=1 if eth5==heseth5 & mostcommoneth5==. & latesteth5==.
label define ethnicity_source 0"CPRD" 1"HES"
label values ethnicity_source ethnicity_source
replace ethnicity_source=. if eth5==.
tab ethnicity_source,m

*save "$pathShare\All patients with Ethnicity in CPRD and HES July 2016.dta", replace

keep patid accept eth5 eth16 ethnicity_source heseth5
replace eth5=heseth5 if eth5>4 & heseth5!=. //replace ethnicity with HES ethnicity if missing 14291 changes made
drop heseth5
merge 1:m patid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", keep(match) nogen
keep patid pregid eth5
save "$Datadir\Derived_data\CPRD\ethnicity_final", replace

*check: expect 99% to have ethnicity among those with live birth 2010-2016, plus eligible for HES linkage, with 85% White ethnicity
use "$Datadir\Derived_data\CPRD\ethnicity_final", clear
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_final", keep(match) nogen
merge 1:1 patid pregid using "$Datadir\Derived_data\Cohorts\pregnancy_cohort_conflicts_outcome_update.dta", keep(match) nogen
merge m:1 patid using "$Rawdatdir/stata\data_linked/linkage_eligibility_gold21", keep(match) nogen keepusing(hes_e)
tab hes_e
tab updated_outcome
gen pregyear=year(pregstart_num)
tab eth5 if pregyear>=2010 & pregyear<=2016 & outcome==1 & hes_e==1, miss

erase "$Datadir\Derived_data\CPRD\All Ethnicity GOLD CPRD.dta"
erase "$Datadir\Derived_data\CPRD\interim_ethnicity_codes.dta"

