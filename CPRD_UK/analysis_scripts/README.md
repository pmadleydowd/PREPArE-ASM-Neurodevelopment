Paul Madley-Dowd - 2024 - Post revision 2

The following describes the scripts used to analyse CPRD data.

Global script
1) global.do defines the global macros used to set the directories in each script

Derivation script
2) cr_NDD_dat.do creates final derivations to the datasets before use in analysis scripts

Analysis scripts
3) an_NDD_Table1_descriptives.do creates a table of descriptive statistics
4) an_PRIM_survival_by_ASM.do runs the primary analyses
5) an_SEC_survival_stratified_by_indication.do runs secondary analyses stratified by indication
6) an_SENS_survival_by_ASM.do runs sensitivity analyses
7) an_CAUSINF_activecomparator.do runs models where lamotrigine is used as the reference category
8) an_CAUSINF_discordant_siblings.do runs sibling analyses 