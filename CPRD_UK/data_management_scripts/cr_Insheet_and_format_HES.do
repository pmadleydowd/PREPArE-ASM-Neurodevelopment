log using "$Logdir\LOG_cr_Insheet_and_format_HES.txt", text replace
******************************************************************************
* Author: 		Paul Madley-Dowd
* Date: 		01 November 2021
* Description:  Insheet and format all linked HES data
* Notes: 		For mappings in HES see https://digital.nhs.uk/data-and-information/data-tools-and-services/data-services/hospital-episode-statistics/hospital-episode-statistics-data-dictionary	
********************************************************************************
* Notes on major updates (Date - description):
* 
********************************************************************************
* Contents
********************************************************************************
* 1 - Set up environment 
** HES APC **
* 2 - HES diagnosis 
* 3 - HES episodes 
* 4 - HES hospitalisations
* 5 - HES maternity 
* 6 - HES patient
* 7 - HES procedures

** HES A&E **
* 8 - HES A&E attendance 
* 9 - HES A&E diagnosis 
* 10 - HES A&E pathway 
* 11 - HES A&E patient
* 12 - HES A&E treatment 

** HES OP ** 
* 13 - HES OP appointment
* 14 - HES OP clinical 
* 15 - HES OP patient 

********************************************************************************
* 1 - Set up environment 
********************************************************************************
global Rawlinked "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Data\data_linked\20_000228_request2\Results\GOLD_linked\Final"

global Statalinked "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\20_000228\Analysis\rawdatafiles\stata\data_linked" 

********************************************************************************
* 2 - HES diagnosis 
********************************************************************************
import delim using "$Rawlinked\hes_diagnosis_epi_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen epistart_num = date(epistart, "DMY")
format %td epistart_num

*Label variables
label variable patid "patient id"
label variable spno "Number uniquely identifying a hospitalisation"
label variable epikey "Episode key uniquely identifying an episode of care"
label variable epistart "Start date of episode of care"
label variable epistart_num "Start date of episode of care (numeric)"
label variable icd "An ICD10 diagnosis code in XXX or XXX.X format"
label variable icdx "5th/6th characters of the ICD code (if available)"
label variable d_order "Ordering of diagnosis code in episode"

compress
save "$Statalinked\20_000228_hes_diagnosis_epi", replace

********************************************************************************
* 3 - HES episodes 
********************************************************************************
import delim using "$Rawlinked\hes_episodes_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen epistart_num = date(epistart, "DMY")
gen admidate_num = date(admidate, "DMY")
format %td epistart_num admidate_num

*Label variables
label variable patid "patient id"
label variable spno "Number uniquely identifying a hospitalisation"
label variable epikey "Episode key uniquely identifying an episode of care"
label variable epistart "Start date of episode of care"
label variable epistart_num "Start date of episode of care (numeric)"
label variable eorder "Order of episode within spell"
label variable admidate "Date of admission"
label variable admidate_num "Date of admission (numeric)"

compress
save "$Statalinked\20_000228_hes_episodes", replace

********************************************************************************
* 4 - HES hospitalisations
********************************************************************************
import delim using "$Rawlinked\hes_hospital_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen admidate_num = date(admidate, "DMY")
format %td admidate_num

*Label variables
label variable patid "patient id"
label variable spno "Number uniquely identifying a hospitalisation"
label variable admidate "Date of admission"
label variable admidate_num "Date of admission (numeric)"
label variable duration "Duration of hospitalisation spell in days"

compress
save "$Statalinked\20_000228_hes_hospital", replace

********************************************************************************
* 5 - HES maternity 
********************************************************************************
import delim using "$Rawlinked\hes_maternity_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen epistart_num = date(epistart, "DMY")
gen epiend_num = date(epiend, "DMY")
gen anasdate_num = date(anasdate, "DMY")
format %td epistart_num epiend_num anasdate_num

* format variables 
encode numbaby, gen(numbaby_num)
recode numbaby_num (7=-3) (8=-2) (9=-1) 
label define lb_numbaby /* 
*/ 1  "One" /*  
*/ 2  "Two"  /*
*/ 3  "Three"  /*
*/ 4  "Four"  /*
*/ 5  "Five"  /*
*/ 6  "Six or more" /* 
*/ -3  "" /* Not in data dictionary
*/ -2  "Not known (submitted value)" /*  
*/ -1  "Not known (derived in HES where the field is null)" 
label values numbaby_num lb_numbaby

label define lb_neocare /*
*/ 0 "Normal care" 		/* care given by the mother or mother substitute, with medical and neonatal nursing advice if needed  
*/ 1 "Special care" 	/* care given in a special nursery, transitional care ward or postnatal ward, which provides care and treatment exceeding normal routine care. Some aspects of special care can be undertaken by a mother supervised by qualified nursing staff. Special nursing care includes support for and education of the infant's parents  
*/ 2  "Level 2 intensive care" /* (high dependency intensive care): care given in an intensive or special care nursery, which provides continuous skilled supervision by qualified and specially trained nursing staff who may care for more babies than in level 1 intensive care. Care includes support for the infant's parents  
*/ 3  "Level 1 intensive care" /* (maximal intensive care): care given in an intensive or special care nursery, which provides continuous skilled supervision by qualified and specially trained nursing and medical staff. Care includes support for the infant's parents  
/* 4 "" */ Not in data dictionary
*/ 8  "Not applicable" 	/* the episode of care does not involve a neonate at any time  
*/ 9  "Not known" 		// the episode of care involves a neonate and is finished but no data has been entered this constitutes a validation error. Alternatively the episode involves a neonate but is unfinished, therefore no data need be present
label values neocare lb_neocare

encode birordr, gen(birordr_num)
recode birordr_num (8=-3) (9=-2) (10=-1) 
label define lb_birordr /* 
*/ -1 "Not known (derived in HES where the field is null)" /* 
*/ -2 "Not known (submitted value)" /*
*/ -3 "Not applicable"
label values birordr_num lb_birordr

label define lb_birstat /*
*/ 1 "Live" /*  
*/ 2 "Still birth: ante-partum" /*  
*/ 3 "Still birth: intra-partum"  /* 
*/ 4 "Still birth: indeterminate"  /*
*/ 9 "Not known" 
label values birstat lb_birstat

label define lb_biresus /* 
*/ 1 "Positive pressure nil, drugs nil" /*  
*/ 2 "Positive pressure nil, drugs administered" /* 
*/ 3 "Positive pressure by mask, drugs nil" /*  
*/ 4 "Positive pressure by mask, drugs administered" /*  
*/ 5 "Positive pressure by endotracheal tube, drugs nil" /*  
*/ 6 "Positive pressure by endotracheal tube, drugs administered" /*  
*/ 8 "Not applicable (e.g. stillborn, where no method of resuscitation was attempted)" /*
*/ 9 "Not known"
label values biresus lb_biresus

recode birweit (9999=-1) (0/9=10) (7001/9998=7000) // data dictionary specifies values betwee 10g and 6999g - HF to check whether this recoding is sensible - could also recode 0 to a not known value
label define lb_birweit /*
*/ 7000 "7000g or more" /* 601 between 7000 and 9998 
*/ 10 "10 g or less" /* 4378 with value 0; 97 between 1-9 ,
*/ -1 "Not known" // 784,420 have a value of 9999 indicating birthweight not known
label values birweit lb_birweit

encode delmeth, gen(delmeth_num)
recode delmeth_num (11=-1) (1=0) (2=1) (3=2) (4=3) (5=4) (6=5) (7=6) (8=7) (9=8) (10=9)
label define lb_delmeth /*
*/ 0 "Spontaneous vertex" /* (normal vaginal delivery, occipitoanterior)  
*/ 1 "Spontaneous other cephalic" /* (cephalic vaginal delivery with abnormal presentation of head at delivery, without instruments, with or without manipulation)  
*/ 2 "Low forceps, not breech" /* including forceps delivery not otherwise specified (forceps, low application, without manipulation)  
*/ 3 "Other forceps, not breech" /* including high forceps and mid forceps (forceps with manipulation)  
*/ 4 "Ventouse, vacuum extraction" /* 
*/ 5 "Breech, including partial breech extraction" /* (spontaneous delivery assisted or unspecified)  
*/ 6 "Breech" /*
*/ 7 "Elective caesarean section" /*
*/ 8 "Emergency caesarean section" /*
*/ 9 "Other" /*
*/ -1 "Not known"
label values delmeth_num lb_delmeth

label define lb_delonset /*
*/ 1 "Spontaneous" /* the onset of regular contractions whether or not preceded by spontaneous rupture of the membranes  
*/ 2 "Any caesarean section" /* carried out immediately following the onset of labour, when the decision was made before labour  
*/ 3 "Surgical induction by amniotomy" /*  
*/ 4 "Medical induction" /*, including the administration of agents either orally, intravenously or intravaginally with the intention of initiating labour  
*/ 5 "Combination of surgical induction and medical induction" /*  
*/ 8 "Not applicable" /*
*/ 9 "Not known: validation error" 
label values delonset lb_delonset

recode gestat (99=-1) (1/9=-2)  
label define lb_gestat /*
*/ -1 "Not known: a validation error" /* 934,498
*/ -2 "Gestational age less than 10 weeks" // 471 with gestational age below 10 weeks
label values gestat lb_gestat

recode numpreg (99=-1)
label define lb_numpreg -1 "Not known"
label values numpreg lb_numpreg

*hes maternity var cleaning
*Delonset: Method to iduce labour
lab var delonset  "Method used to induce (initiate) labour, rather than to accelerate it" 
lab define delonset 1 "Spontaneous" ///
2 "Any CS carried out immed following onset of labour, when decision made before labour" ///
3 "Surgical induction by amniotomy" ///
4 "Medical induction (orally/intravenously/intravaginally)" ///
5 "Combination of surgical and medical induction" ///
8 "Not applicable (from 1996-97 onwards)" ///
9 "Not known: validation error"
lab val delonset delonset

*Label variables
label variable patid "patient id"
label variable spno "Number uniquely identifying a hospitalisation"
label variable epikey "Episode key uniquely identifying an episode of care"
label variable epistart "Date of start of episode"
label variable epistart_num "Start date of episode of care (numeric)"
label variable epiend "Date of end of episode"
label variable epiend_num "Date of end of episode (numeric)"
label variable eorder "Order of episode within spell"
label variable epidur "Duration of episode in days"
label variable numbaby "Number of babies delivered at the end of a single pregnancy"
label variable numbaby_num "Number of babies delivered at the end of a single pregnancy (numeric)"
label variable numtailb "Number of baby tails"
label variable matordr "Order of birth"
label variable neocare "Neonatal level of care"
label variable anasdate "First antenatal assessment date"
label variable anasdate_num "First antenatal assessment date (numeric)"
label variable birordr "The position in the sequence of births"
label variable birordr_num "The position in the sequence of births (numeric)"
label variable birstat "Indicates whether the baby was born alive or dead (still birth)"
label variable biresus "Identifies resuscitation method used to get the baby breathing"
label variable sexbaby "Sex of baby"
label variable birweit "Weight of the baby in grams immediately after birth"
label variable delmeth "Method used to deliver a baby that is a registrable birth"
label variable delmeth_num "Method used to deliver a baby that is a registrable birth (numeric)"
label variable delonset "Method used to induce (initiate) labour, rather than to accelerate it"
label variable gestat "Length of gestation - number of completed weeks of gestation"
label variable numpreg "Number of previous pregnancies that resulted in a registered birth (live or still born)"
label variable antedur "Antenatal days of stay"
label variable postdur "Postnatal days of stay"

order patid* spno* epikey* epistart* epiend* eorder* epidur* numbaby* numtailb* matordr* neocare* anasdate* birordr* birstat* biresus* sexbaby* birweit* delmeth* delonset* gestat* numpreg* antedur* postdur*

compress
save "$Statalinked\20_000228_hes_maternity", replace


********************************************************************************
* 6 - HES patient
********************************************************************************
import delim using "$Rawlinked\hes_patient_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
label variable patid "patient id"
label variable pracid "Practice id"
label variable gen_ethnicity "Ethnicity derived from HES data (including Admitted patient care, Outpatient, A&E, PROMs and DID) "

compress
save "$Statalinked\20_000228_hes_patient", replace

********************************************************************************
* 7 - HES procedures
********************************************************************************
import delim using "$Rawlinked\hes_procedures_epi_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen epistart_num = date(epistart, "DMY")
gen admidate_num = date(admidate, "DMY")
gen evdate_num = date(evdate, "DMY")
format %td epistart_num admidate_num evdate_num

*Label variables
label variable patid "patient id"
label variable spno "Number uniquely identifying a hospitalisation"
label variable epikey "Episode key uniquely identifying an episode of care"
label variable admidate "Date of admission"
label variable admidate_num "Date of admission (numeric)"
label variable epistart "Date of start of episode"
label variable epistart_num "Start date of episode of care (numeric)"
label variable opcs "An OPCS 4 procedure code"
label variable evdate "Date of operation / procedure"
label variable evdate_num "Date of operation / procedure (numeric)"
label variable p_order "Ordering of OPCS code in episode, within range 1-24"

compress
save "$Statalinked\20_000228_hes_procedures", replace



********************************************************************************
* 8 - HES A&E attendance 
********************************************************************************
import delim using "$Rawlinked\hesae_attendance_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen arrivaldate_num = date(arrivaldate, "DMY")
format %td arrivaldate_num

* Label variables
label variable patid "patient id"
label variable aekey "Record identifier (unique in combination with patid)"
label variable arrivaldate "The arrival date of a patient in the A&E department"
label variable arrivaldate_num "The arrival date of a patient in the A&E department (numeric)"
label variable aepatgroup "The reason for an A&E episode" 
label variable aeattendcat "Initial or follow-up attendance at a particular A&E department"
label variable aedepttype "Classification of A&E department type according to the activity carried out"
label variable ethnos "Ethnic category recorded at attendance"

* format variables
label define lb_aepatgroup 10 "Road traffic accident" 20 "Assault" 30 "Deliberate self-harm" 40 "Sports injury" 50 "Firework injury" 60 "Other accident"  70 "Brought in dead" 80 "Other than above" 99 "Not known"
label values aepatgroup lb_aepatgroup 

label define lb_aeattendcat  1 "First A&E attendance" 2 "Follow-up A&E attendance - planned" 3 "Follow-up A&E attendance - unplanned" 9 "Not known"
label values aeattendcat lb_aeattendcat


/* NOTE: aedepttype format 
	1 - "Emergency departments are a consultant led 24-hour service with full resuscitation facilities and designated accommodation for the reception of accident and emergency patients" 
	2 - "Consultant-led mono specialty accident and emergency service (e.g. ophthalmology, dental) with designated accommodation for the reception of patients" 
	3 - "Other type of A&E/minor injury activity with designated accommodation for the reception of accident and emergency patients. The department may be doctor led or nurse led and treats at least minor injuries and illnesses and can be routinely accessed without appointment. A service mainly or entirely appointment based (for example a GP practice or outpatient clinic) is excluded even though it may treat a number of patients with minor illness or injury. Excludes NHS walk-in centres"  
	4 - "NHS walk-in centres" 
	9 - "Not known"
	
	5 - present in dataset but not found within data dictionary
*/
label define lb_aedepttype 1 "Emergency departments are a consultant led 24-hour service with full resuscitation facilities and designated accommodation for the reception of accident and emergency patients" 2 "Specialty A&E service (e.g. ophthalmology, dental)" 3 "Other type of A&E/minor injury activity"  4 "NHS walk-in centres" 99 "Not known"
label values aedepttype lb_aedepttype

compress
save "$Statalinked\20_000228_hesae_attendance", replace

********************************************************************************
* 9 - HES A&E diagnosis 
********************************************************************************
import delim using "$Rawlinked\hesae_diagnosis_20_000228_request2_DM.txt", clear

* Label variables
label variable patid "patient id"
label variable aekey "Record identifier (unique in combination with patid)"
label variable diag "A&E diagnosis" // A&E diagnosis - 6 characters. A 6-character code made up of diagnosis condition (n2), sub-analysis (n1), anatomical area (n2) and anatomical side (an1). Only certain diagnoses contain a sub-analysis
label variable diag2 "A&E diagnosis condition" //  Includes the diagnosis condition (n2) of the 6-character diagnosis code
label variable diag3 "A&E diagnosis diagnosis and sub-analysis" //  Includes diagnosis (n2) and the sub-analysis (n1) of the 6-character diagnosis code. If no sub-analysis has been provided, or is not applicable, then the 2-character description is displayed if available.
label variable diagscheme "Coding scheme in use"
label variable diag_order "Ordering of diagnosis at attendance, within range 1-12"


compress
save "$Statalinked\20_000228_hesae_diagnosis", replace

********************************************************************************
* 10 - HES A&E pathway 
********************************************************************************
import delim using "$Rawlinked\hesae_pathway_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen rttperstart_num = date(rttperstart, "DMY")
gen rttperend_num = date(rttperend, "DMY")
format %td rttperstart_num rttperend_num

* Label variables
label variable patid "patient id"
label variable aekey "Record identifier (unique in combination with patid)"
label variable rttperstart "The start date, for the referral to treatment perio"
label variable rttperstart_num "The start date, for the referral to treatment perio (numeric)"
label variable rttperend "The end date, for the referral to treatment period"
label variable rttperend_num "The end date, for the referral to treatment period (numeric)"

compress
save "$Statalinked\20_000228_hesae_pathway", replace



********************************************************************************
* 11 - HES A&E patient
********************************************************************************
import delim using "$Rawlinked\hesae_patient_20_000228_request2_DM.txt", clear

* Label variables
label variable patid "Patient id"
label variable pracid "Practice id"
label variable gen_hesid "Unique key for patient across all linked HES datasets"
label variable n_patid_hes "Number of individuals in CPRD GOLD assigned the same gen_hesid"
label variable gen_ethnicity "Patient's ethnicity derived from all HES data"

compress
save "$Statalinked\20_000228_hesae_patient", replace



********************************************************************************
* 12 - HES A&E treatment 
********************************************************************************
import delim using "$Rawlinked\hesae_treatment_20_000228_request2_DM.txt", clear

* Label variables
label variable patid "Patient id"
label variable aekey "Record identifier (unique in combination with patid)"
label variable treat "Treatment code" // A&E Treatment - 6 characters. Treatment code made up of treatment (n2), sub-analysis (n1) and a local use section (up to an3)
label variable treat2 "Treatment (n2) of the 6-character treatment code" // A&E Treatment - 2 characters. Consists of treatment (n2) of the 6-character treatment code
label variable treat3 "Treatment (n2) and sub-analysis (n1) of treatment code" // A&E Treatment - 3 characters. Consists of treatment (n2) and the sub-analysis (n1) of the 6-character treatment code. If no sub-analysis has been provided, or is not applicable, then the 2-character description is displayed if available
label variable treat_order "Ordering of treatment at attendance, within range 1-12"

compress
save "$Statalinked\20_000228_hesae_treatment", replace


********************************************************************************
* 13 - HES OP appointment
********************************************************************************
import delim using "$Rawlinked\hesop_appointment_20_000228_request2_DM.txt", clear

* Generate numeric versions of date variables
gen apptdate_num = date(apptdate, "DMY")
format %td apptdate_num 

* Label variables
label variable patid "Patient id"
label variable attendkey "Record identifier (unique in combination with patid)"
label variable ethnos "Ethnic category as recorded at appointment"
label variable apptdate "Appointment date"
label variable apptdate_num "Appointment date (numeric)"
label variable attended "Attended or did not attend"

* format variable 
label define lb_attended /*
*/ 2 "Appointment cancelled by, or on behalf of, the patient" /*
*/ 3 "Did not attend - no advance warning given"  /*
*/ 4 "Appointment cancelled or postponed by the Health Care Provider" /* 
*/ 5 "Seen, having attended on time or, if late, before the relevant care professional was ready to see the patient"  /*
*/ 6 "Arrived late, after the relevant care professional was ready to see the patient, but was seen" /*
*/ 7 "Did not attend - patient arrived late and could not be seen" /*
*/ 9 "Not known"
label values attended lb_attended


compress
save "$Statalinked\20_000228_hesop_appointment", replace



********************************************************************************
* 14 - HES OP clinical 
********************************************************************************
import delim using "$Rawlinked\hesop_clinical_20_000228_request2_DM.txt", clear

* Label variables
label variable patid "Patient id"
label variable attendkey "Record identifier (unique in combination with patid)"
label variable diag_01 "Primary diagnosis"
label variable diag_02 "Secondary diagnosis"
label variable diag_03 "Secondary diagnosis"
label variable diag_04 "Secondary diagnosis"
label variable diag_05 "Secondary diagnosis"
label variable diag_06 "Secondary diagnosis"
label variable diag_07 "Secondary diagnosis"
label variable diag_08 "Secondary diagnosis"
label variable diag_09 "Secondary diagnosis"
label variable diag_10 "Secondary diagnosis"
label variable diag_11 "Secondary diagnosis"
label variable diag_12 "Secondary diagnosis"
label variable opertn_01 "Main (i.e. most resource intensive) operation"
label variable opertn_02 "Secondary operation/procedure"
label variable opertn_03 "Secondary operation/procedure"
label variable opertn_04 "Secondary operation/procedure"
label variable opertn_05 "Secondary operation/procedure"
label variable opertn_06 "Secondary operation/procedure"
label variable opertn_07 "Secondary operation/procedure"
label variable opertn_08 "Secondary operation/procedure"
label variable opertn_09 "Secondary operation/procedure"
label variable opertn_10 "Secondary operation/procedure"
label variable opertn_11 "Secondary operation/procedure"
label variable opertn_12 "Secondary operation/procedure"
label variable opertn_13 "Secondary operation/procedure"
label variable opertn_14 "Secondary operation/procedure"
label variable opertn_15 "Secondary operation/procedure"
label variable opertn_16 "Secondary operation/procedure"
label variable opertn_17 "Secondary operation/procedure"
label variable opertn_18 "Secondary operation/procedure"
label variable opertn_19 "Secondary operation/procedure"
label variable opertn_20 "Secondary operation/procedure"
label variable opertn_21 "Secondary operation/procedure"
label variable opertn_22 "Secondary operation/procedure"
label variable opertn_23 "Secondary operation/procedure"
label variable opertn_24 "Secondary operation/procedure"
label variable operstat "Operation status code" 
label variable tretspef "Treatment speciality" 
label variable mainspef "Main speciality"


* format variables
replace tretspef = "999" if tretspef==""
replace tretspef = "1000" if tretspef=="&"
destring tretspef, replace
label define lb_tretspef /*
*/ 100   "General Surgery Service" /*
*/ 101   "Urology Service" /*
*/ 102   "Transplant Surgery Service (From 1 April 2004)" /*
*/ 103   "Breast Surgery Service (From 1 April 2004)" /*
*/ 104   "Colorectal Surgery Service (From 1 April 2004)" /*
*/ 105   "Hepatobiliary and Pancreatic Surgery Service (From 1 April 2004)"  /*
*/ 106   "Upper Gastrointestinal Surgery Service (From 1 April 2004)"  /*
*/ 107   "Vascular Surgery Service (From 1 April 2004)" /*
*/ 108   "Spinal Surgery Service (From April 2013)" /*
*/ 109   "Bariatric Surgery Service (From 1 April 2021)" /*
*/ 110   "Trauma and Orthopaedic Service" /*
*/ 111   "Orthopaedic Service (From 1 April 2021)" /*
*/ 113   "Endocrine Surgery Service (From 1 April 2021)" /*
*/ 115   "Trauma Surgery Service (From 1 April 2021)" /*
*/ 120   "Ear Nose and Throat Service" /*
*/ 130   "Ophthalmology Service" /*
*/ 140   "Oral Surgery Service" /*
*/ 141   "Restorative Dentistry Service" /*
*/ 142   "Paediatric Dentistry Service (From 1999-2000)" /*
*/ 143   "Orthodontic Service" /*
*/ 144   "Maxillofacial Surgery Service (From 1 April 2004)" /*
*/ 145   "Oral and Maxillofacial Surgery Service (From 1 April 2021)" /*
*/ 150   "Neurosurgical Service" /*
*/ 160   "Plastic Surgery Service" /*
*/ 161   "Burns Care Service (From 1 April 2004)" /* 
*/ 170   "Cardiothoracic Surgery Service" /*
*/ 171   "Paediatric Surgery Service" /*
*/ 172   "Cardiac Surgery Service (From 1 April 2004)" /*
*/ 173   "Thoracic Surgery Service (From 1 April 2004)" /*
*/ 174   "Cardiothoracic Transplantation Service (From 1 April 2004)" /* 
*/ 180   "Emergency Medicine Service" /*
*/ 190   "Anaesthetic Service" /*
*/ 191   "Pain Management Service (From 1998-99)" /*
*/ 192   "Intensive Care Medicine Service (From 1 April 2004)" /*
*/ 200   "Aviation and Space Medicine Service (From 1 April 2021)" /*
*/ 211   "Paediatric Urology Service (From 2006-07)" /*
*/ 212   "Paediatric Transplantation Surgery Service (From 2006-07)" /*
*/ 213   "Paediatric Gastrointestinal Surgery Service (From 2006-07)" /*
*/ 214   "Paediatric Trauma and Orthopaedic Service (From 2006-07)" /*
*/ 215   "Paediatric Ear Nose and Throat Service (From 2006-07)" /*
*/ 216   "Paediatric Ophthalmology Service (From 2006-07)" /*
*/ 217   "Paediatric Oral and Maxillofacial Surgery Service (From 2006-07)" /*
*/ 218   "Paediatric Neurosurgery Service (From 2006-07)" /*
*/ 219   "Paediatric Plastic Surgery Service (From 2006-07)" /*
*/ 220   "Paediatric Burns Care Service (From 2006-07)" /*
*/ 221   "Paediatric Cardiac Surgery Service (From 2006-07)" /*
*/ 222   "Paediatric Thoracic Surgery Service (From 2006-07)" /*
*/ 223   "Paediatric Epilepsy Service (From April 2013)" /*
*/ 230   "Paediatric Clinical Pharmacology Service (From 1 April 2021)" /*
*/ 240   "Paediatric Palliative Medicine Service (From 1 April 2021)" /*
*/ 241   "Paediatric Pain Management Service (From 2006-07)" /*
*/ 242   "Paediatric Intensive Care Service (From 2006-07)" /*
*/ 250   "Paediatric Hepatology Service (From 1 April 2021)" /*
*/ 251   "Paediatric Gastroenterology Service (From 2006-07)" /* 
*/ 252   "Paediatric Endocrinology Service (From 2006-07)" /*
*/ 253   "Paediatric Clinical Haematology Service (From 2006-07)" /*
*/ 254   "Paediatric Audio Vestibular Medicine Service (From 2006-07)" /*
*/ 255   "Paediatric Clinical Immunology and Allergy Service (From 2006-07)" /*
*/ 256   "Paediatric Infectious Diseases Service (From 2006-07)" /*
*/ 257   "Paediatric Dermatology Service (From 2006-07)" /*
*/ 258   "Paediatric Respiratory Medicine Service (From 2006-07)" /*
*/ 259   "Paediatric Nephrology Service (From 2006-07)" /*
*/ 260   "Paediatric Medical Oncology Service (From 2006-07)" /*
*/ 261   "Paediatric Inherited Metabolic Medicine Service (From 2006-07)" /*
*/ 262   "Paediatric Rheumatology Service (From 2006-07)" /*
*/ 263   "Paediatric Diabetes Service (From 1 April 2004)" /*
*/ 264   "Paediatric Cystic Fibrosis Service (From 1 April 2004)" /*
*/ 270   "Paediatric Emergency Medicine Service (From 1 April 2021)" /*
*/ 280   "Paediatric Interventional Radiology Service (From 2006-07)" /*
*/ 290   "Community Paediatric Service (From 2006-07)" /*
*/ 291   "Paediatric Neurodisability Service (From 2006-07)" /*
*/ 300   "General Internal Medicine Service" /*
*/ 301   "Gastroenterology Service" /*
*/ 302   "Endocrinology Service" /*
*/ 303   "Clinical Haematology Service" /*
*/ 304   "Clinical Physiology Service (From 2008-09)" /*
*/ 305   "Clinical Pharmacology Service" /*
*/ 306   "Hepatology Service (From 1 April 2004)" /*
*/ 307   "Diabetes Service (From 1 April 2004)" /*
*/ 308   "Blood and Marrow Transplantation Service (From 1 April 2004)" /*
*/ 309   "Haemophilia Service (From 1 April 2004)" /*
*/ 310   "Audio Vestibular Medicine Service" /*
*/ 311   "Clinical Genetics Service" /*
*/ 313   "Clinical Immunology and Allergy Service (From 1991-92)" /*
*/ 314   "Rehabilitation Medicine Service (From 1991-92)" /*
*/ 315   "Palliative Medicine Service" /*
*/ 316   "Clinical Immunology Service (From 1 April 2004)" /*
*/ 317   "Allergy Service (From 1 April 2004)" /*
*/ 318   "Intermediate Care Service (From 1 April 2004)" /*
*/ 319   "Respite Care Service (From 1 April 2004)" /*
*/ 320   "Cardiology Service" /*
*/ 321   "Paediatric Cardiology Service (From 1 April 2004)" /*
*/ 322   "Clinical Microbiology Service (From 1 April 2004)" /*
*/ 323   "Spinal Injuries Service (From 2006-07)" /*
*/ 324   "Anticoagulant Service (From 1 April 2004)" /*
*/ 325   "Sport and Exercise Medicine Service (From 1 April 2004)" /*
*/ 326   "Acute Internal Medicine Service (From 1 April 2021)" /*
*/ 327   "Cardiac Rehabilitation Service (From 1 April 2004)" /*
*/ 328   "Stroke Medicine Service (From 1 April 2004)" /*
*/ 329   "Transient Ischaemic Attack Service (From 1 April 2004)" /*
*/ 330   "Dermatology Service" /*
*/ 331   "Congenital Heart Disease Service (From April 2013)" /*
*/ 333   "Rare Disease Service (From 1 April 2021)" /*
*/ 335   "Inherited Metabolic Medicine Service (From 1 April 2021)" /*
*/ 340   "Respiratory Medicine Service" /*
*/ 341   "Respiratory Physiology Service (From 1 April 2004)" /*
*/ 342   "Pulmonary Rehabilitation Service (From 1 April 2004)" /*
*/ 343   "Adult Cystic Fibrosis Service (From 1 April 2004)" /*
*/ 344   "Complex Specialised Rehabilitation Service (From April 2013)" /*
*/ 345   "Specialist Rehabilitation Service (From April 2013)" /*
*/ 346   "Local Specialist Rehabilitation Service (From April 2013)" /*
*/ 347   "Sleep Medicine Service (From 1 April 2021)" /*
*/ 348   "Post-COVID-19 Syndrome Service (From 1 April 2021)" /*
*/ 350   "Infectious Diseases Service" /*
*/ 352   "Tropical Medicine Service (From 1 April 2004)" /*
*/ 360   "Genitourinary Medicine Service" /*
*/ 361   "Renal Medicine Service" /*
*/ 370   "Medical Oncology Service" /*
*/ 371   "Nuclear Medicine Service (From 2008-09)" /*
*/ 400   "Neurology Service" /*
*/ 401   "Clinical Neurophysiology Service (From 2008-09)" /*
*/ 410   "Rheumatology Service" /*
*/ 420   "Paediatric Service" /*
*/ 421   "Paediatric Neurology Service" /*
*/ 422   "Neonatal Critical Care Service (From 1 April 2004)" /*
*/ 424   "Well Baby Service (From 1 April 2004)" /*
*/ 430   "Elderly Medicine Service" /*
*/ 431   "Orthogeriatric Medicine Service (From 1 April 2021)" /*
*/ 450   "Dental Medicine Service (From 1990-91)" /*
*/ 451   "Special Care Dentistry Service (From 1 April 2021)" /*
*/ 460   "Medical Ophthalmology Service (From 1993-94)" /*
*/ 461   "Ophthalmic and Vision Science Service (From 1 April 2021)" /*
*/ 501   "Obstetrics Service" /*
*/ 502   "Gynaecology Service" /*
*/ 503   "Gynaecological Oncology Service (From 1 April 2004)" /*
*/ 504   "Community Sexual and Reproductive Health Service (From 1 April 2021)" /*
*/ 505   "Fetal Medicine Service (From 1 April 2021)" /*
*/ 560   "Midwifery Service (From October 1995)" /*
*/ 650   "Physiotherapy Service (From 2006-07)" /*
*/ 651   "Occupational Therapy Service (From 2006-07)" /*
*/ 652   "Speech and Language Therapy Service (From 2006-07)" /*
*/ 653   "Podiatry Service (From 2006-07)" /*
*/ 654   "Dietetics Service (From 2006-07)" /*
*/ 655   "Orthoptics Service (From 2006-07)" /*
*/ 656   "Clinical Psychology Service (From 2006-07)" /*
*/ 657   "Prosthetics Service (From 1 April 2004)" /*
*/ 658   "Orthotics Service (From 1 April 2004)" /*
*/ 659   "Dramatherapy Service (From 1 April 2004)" /*
*/ 660   "Art Therapy Service (From 1 April 2004)" /*
*/ 661   "Music Therapy Service (From 1 April 2004)" /*
*/ 662   "Optometry Service (From 1 April 2004)" /*
*/ 663   "Podiatric Surgery Service (From April 2013)" /*
*/ 670   "Urological Physiology Service (From 1 April 2021)" /*
*/ 673   "Vascular Physiology Service (From 1 April 2021)" /*
*/ 675   "Cardiac Physiology Service (From 1 April 2021)" /*
*/ 677   "Gastrointestinal Physiology Service (From 1 April 2021)" /*
*/ 700   "Learning Disability Service" /*
*/ 710   "Adult Mental Health Service" /*
*/ 711   "Child and Adolescent Psychiatry Service" /*
*/ 712   "Forensic Psychiatry Service" /*
*/ 713   "Medical Psychotherapy Service" /*
*/ 715   "Old Age Psychiatry Service (From 1990-91)" /*
*/ 720   "Eating Disorders Service (From 2006-07)" /*
*/ 721   "Addiction Service (From 2006-07)" /*
*/ 722   "Liaison Psychiatry Service (From 2006-07)" /*
*/ 723   "Psychiatric Intensive Care Service (From 2006-07)" /*
*/ 724   "Perinatal Mental Health Service (From 2006-07)" /*
*/ 725   "Mental Health Recovery and Rehabilitation Service (From April 2013)" /*
*/ 726   "Mental Health Dual Diagnosis Service (From April 2013)" /*
*/ 727   "Dementia Assessment Service (From April 2013)" /*
*/ 730   "Neuropsychiatry Service (From 1 April 2021)" /*
*/ 800   "Clinical Oncology Service" /*
*/ 811   "Interventional Radiology Service (From 1 April 2004)" /*
*/ 812   "Diagnostic Imaging Service (From 2008-09)" /*
*/ 822   "Chemical Pathology Service" /*
*/ 834   "Medical Virology Service (From 1 April 2004)" /*
*/ 840   "Audiology Service (From 2008-09)" /*
*/ 920   "Diabetic Education Service (From April 2013)" /*
*/ 999   "Other Maternity Event" /*
*/ 1000  "Not known"
label values tretspef lb_tretspef

replace mainspef = "999" if mainspef==""
replace mainspef = "1000" if mainspef=="&"
destring mainspef, replace
label define lb_mainspef /*
*/ 100  "General Surgery" /*
*/ 101  "Urology" /*
*/ 107  "Vascular Surgery (Introduced 1 April 2021)" /*
*/ 110  "Trauma and Orthopaedics" /*
*/ 120  "Ear Nose and Throat" /*
*/ 130  "Ophthalmology" /*
*/ 140  "Oral Surgery" /*
*/ 141  "Restorative Dentistry" /* 
*/ 142  "Paediatric Dentistry" /*
*/ 143  "Orthodontics" /*
*/ 145  "Oral and Maxillofacial Surgery" /*
*/ 146  "Endodontics" /*
*/ 147  "Periodontics" /*
*/ 148  "Prosthodontics" /*
*/ 149  "Surgical Dentistry" /*
*/ 150  "Neurosurgery" /*
*/ 160  "Plastic Surgery" /*
*/ 170  "Cardiothoracic Surgery" /*
*/ 171  "Paediatric Surgery" /*
*/ 191  "Pain Management (Retired 1 April 2004)" /*
*/ 180  "Emergency Medicine" /*
*/ 190  "Anaesthetics" /*
*/ 192  "Intensive Care Medicine" /*
*/ 200  "Aviation and Space Medicine (Introduced 1 April 2021)" /*
*/ 300  "General Internal Medicine" /*
*/ 301  "Gastroenterology" /*
*/ 302  "Endocrinology and Diabetes" /*
*/ 303  "Clinical Haematology" /*
*/ 304  "Clinical Physiology" /*
*/ 305  "Clinical Pharmacology" /*
*/ 310  "Audio Vestibular Medicine" /*
*/ 311  "Clinical Genetics" /*
*/ 312  "Clinical Cytogenetics and Molecular Genetics (Retired 1 April 2010). National Code 312 is retained for consultants qualified in this Main Specialty prior to 1 April 2010" /*
*/ 313  "Clinical Immunology" /*
*/ 314  "Rehabilitation Medicine" /*
*/ 315  "Palliative Medicine" /*
*/ 317  "Allergy (Introduced 1 April 2021)" /*
*/ 320  "Cardiology" /*
*/ 321  "Paediatric Cardiology" /*
*/ 325  "Sport and Exercise Medicine" /*
*/ 326  "Acute Internal Medicine" /*
*/ 330  "Dermatology" /*
*/ 340  "Respiratory Medicine" /*
*/ 350  "Infectious Diseases" /*
*/ 352  "Tropical Medicine" /*
*/ 360  "Genitourinary Medicine" /*
*/ 361  "Renal Medicine" /*
*/ 370  "Medical Oncology" /*
*/ 371  "Nuclear Medicine" /*
*/ 400  "Neurology" /*
*/ 401  "Clinical Neurophysiology" /*
*/ 410  "Rheumatology" /*
*/ 420  "Paediatrics" /*
*/ 421  "Paediatric Neurology" /*
*/ 430  "Geriatric Medicine" /*
*/ 450  "Dental Medicine" /*
*/ 451  "Special Care Dentistry" /*
*/ 501  "Obstetrics" /*
*/ 502  "Gynaecology" /*
*/ 504  "Community Sexual and Reproductive Health" /*
*/ 510  "Antenatal Clinic (Retired 1 April 2004)" /*
*/ 520  "Postnatal Clinic (Retired 1 April 2004)" /*
*/ 560  "Midwifery" /*
*/ 600  "General Medical Practice" /*
*/ 601  "General Dental Practice" /*
*/ 610  "Maternity Function (Retired 1 April 2004)" /*
*/ 620  "Other than Maternity (Retired 1 April 2004)" /*
*/ 700  "Learning Disability" /*
*/ 710  "Adult Mental Illness" /*
*/ 711  "Child and Adolescent Psychiatry" /*
*/ 712  "Forensic Psychiatry" /*
*/ 713  "Medical Psychotherapy" /*
*/ 715  "Old Age Psychiatry" /*
*/ 800  "Clinical Oncology" /*
*/ 810  "Radiology" /*
*/ 820  "General Pathology" /*
*/ 821  "Blood Transfusion" /*
*/ 822  "Chemical Pathology" /*
*/ 823  "Haematology" /*
*/ 824  "Histopathology" /*
*/ 830  "Immunopathology" /*
*/ 831  "Medical Microbiology and Virology" /*
*/ 832  "Neuropathology (Retired 1 April 2004)" /*
*/ 833  "Medical Microbiology" /*
*/ 834  "Medical Virology" /*
*/ 900  "Community Medicine" /*
*/ 901  "Occupational Medicine" /*
*/ 902  "Community Health Services Dental" /*
*/ 903  "Public Health Medicine" /*
*/ 904  "Public Health Dental" /*
*/ 950  "Nursing" /*
*/ 960  "Allied Health Professional" /*
*/ 990  "Joint Consultant Clinics (Retired 1 April 2004)" /*
*/ 199  "Non-UK Provider - Specialty Function Not Known, Treatment Mainly Surgical" /*
*/ 460  "Medical Ophthalmology" /*
*/ 499  "Non-UK Provider - Specialty Function Not Known, Treatment Mainly Medical" /*
*/ 999  "Other Maternity Event" /*
*/ 1000 "Not Known" 
label values mainspef lb_mainspef 



compress
save "$Statalinked\20_000228_hesop_clinical", replace



********************************************************************************
* 15 - HES OP patient 
********************************************************************************
import delim using "$Rawlinked\hesop_patient_20_000228_request2_DM.txt", clear

* label variables
label variable patid "Patient id"
label variable pracid "Practice id"
label variable gen_ethnicity "Patient's ethnicity derived from all HES data"

compress
save "$Statalinked\20_000228_hesop_patient", replace


********************************************************************************
log close