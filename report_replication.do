********************************** Replication of the report **********************************
/*
********************************** Instructions **************************************

	Objective of this dofile: reproduce all data-based statements in
	"A comment on 'Tracking the Reorganizations of MVPA Opportunities During the
	Transition From French Secondary School to University: A Longitudinal Study'"
	(Voorintholt, 2026), using the authors' deposited data (Derigny et al., 2025):
	Data_DAP.xlsx from https://doi.org/10.5281/zenodo.15595425

	How to run: put Data_DAP.xlsx in a subfolder original/, create the empty
	subfolders data/ and output/, cd into the folder that contains them, and run
	this dofile (Stata 19). Runtime: about 15 minutes (mixed models).

	Note: pmvpa is stored as a proportion (0.066 = 6.6%). gender is coded F/M;
	as in the article's gender results, F = girls (58) and M = boys (26).
	Nothing below lists participant labels or individual age/BMI values.

	Outline of this dofile:
		a) Set up the data (as deposited, zero-filled grid, wide format)
		b) Section 2: computational reproducibility
		c) Missing opportunities entered as 0% MVPA
		d) Table C: Table 3 refitted, zero-filled vs observed rows
		e) Table D: Table 2 p-values vs candidate tests
		f) Table E: Table 2 printed means and Delta vs data; printed SDs
		g) Gender gaps at T0 and announced interaction tests
		h) Choice of units in the second ANOVA
		i) Table 1 tests (Welch vs paired)
		j) Table F: Table 3 against the overall ratio, FDR-consistent intervals
		k) ICCs
		l) Opportunity rows vs the overall row
		m) BMI details in the dataset
		n) Minor issues (Figure 1, gender counts, power, transport)
*/

clear all
set more off
set linesize 255
capture log close
log using "output/report_replication.log", replace text

********************************************************************************
*a) Set up the data
********************************************************************************

* data as deposited (1,546 rows)
import excel "original/Data_DAP.xlsx", sheet("Feuil1") firstrow clear
encode subject, gen(sid)
encode gender, gen(sex)                                            // 1 = F (girls), 2 = M (boys)
encode opportunity, gen(opp)                                       // 14 levels, "overall" = 8
encode opportunity if opportunity != "overall", gen(opp13)         // 13 opportunities
gen period = (time == "T1")                                        // 0 = T0, 1 = T1
save "data/raw.dta", replace

* zero-filled grid as in the authors' code (R lines 9-21): every participant x wave x
* opportunity, unrecorded cells get minutes, MVPA minutes and ratio 0
import excel "original/Data_DAP.xlsx", sheet("Feuil1") firstrow clear
fillin subject time opportunity
tab _fillin if opportunity != "overall"                            // 806 added cells
replace pmvpa = 0 if _fillin
replace mvpa  = 0 if _fillin
replace time2 = 0 if _fillin
bysort subject (gender): replace gender = gender[_N] if gender == ""
bysort subject time (age): replace age = age[1] if missing(age)
bysort subject time (BMI): replace BMI = BMI[1] if missing(BMI)
drop _fillin
encode subject, gen(sid)
encode gender, gen(sex)
encode opportunity, gen(opp)
encode opportunity if opportunity != "overall", gen(opp13)
gen period = (time == "T1")
egen unit = group(subject opportunity)                             // participant x opportunity
save "data/full.dta", replace

* wide format: one row per participant x opportunity, T0 and T1 side by side
keep subject sex opportunity time pmvpa mvpa time2 age BMI
replace time = "_" + time
reshape wide pmvpa mvpa time2 age BMI, i(subject opportunity) j(time) string
save "data/wide.dta", replace

********************************************************************************
*b) Section 2: computational reproducibility
********************************************************************************

* overall MVPA ratio per wave: 6.60% (T0) and 6.28% (T1)
use "data/full.dta", clear
tabstat pmvpa if opportunity == "overall", by(period) stat(mean sd n) format(%9.4f)

* first ANOVA (time x gender, overall rows): gender F(1,82) = 10.29, p = .0019;
* time F = 1.11, p = .296; time x gender in the same table (see g)
anova pmvpa sex / sid|sex period sex#period if opportunity == "overall", sequential
* printed "partial" eta2 for gender (0.074) is the generalized eta2; partial = 0.112
display "generalized eta2 gender = " e(ss_1) / (e(ss_1) + e(ss_2) + e(rss))
display "partial eta2 gender     = " e(ss_1) / (e(ss_1) + e(ss_2))

* second ANOVA as published (participant x opportunity as unit, 14 levels):
* opportunity F = 27.99, gender F(1,1148) = 5.55, p = .018, opportunity x gender F = 0.91;
* three-way term in the same table (see g)
anova pmvpa opp sex opp#sex / sid|opp#sex period period#opp period#sex period#opp#sex, sequential
* post-hoc T0 - T1 per opportunity (used in Table D, section e)
contrast a.period@opp, effects
matrix PH = r(table)'

* Table 3 as published: each opportunity vs the unweighted mean of the 13 (effect
* contrasts), per wave; reference = 7.09% (T0) and 5.11% (T1); printed CIs = Bonferroni.
* The FDR-adjusted p-values are computed in section d.
forvalues w = 0/1 {
	mixed pmvpa i.opp13 if period == `w' & opportunity != "overall" || sid:, reml dfmethod(satterthwaite)
	margins, asbalanced                                            // reference mean
	contrast g.opp13, effects small mcompare(bonferroni)           // estimates and printed CIs
}

* within-gender T1 - T0 changes (points): boys PE -14.2, recess -6.98, supervised -9.1;
* girls PE -11.2, recess -8.3
use "data/wide.dta", clear
gen change = 100 * (pmvpa_T1 - pmvpa_T0)
table opportunity sex if inlist(opportunity, "physical_education", "recess", "supervised_leisure"), statistic(mean change) nformat(%6.2f)

* Table 1 age change: SD 0.153 in the data (printed 1.53)
gen age_change = age_T1 - age_T0
summarize age_change if opportunity == "overall"

* gender gaps at T0 as the authors' code specifies them (emmeans/pairs, R lines 201-202),
* random-intercept equivalent of the second ANOVA; boys minus girls, Tukey over 6 pairs:
* PE +3.4 (Tukey p = .35), recess +1.5 (p = .89), supervised leisure +7.7 (p = .001)
use "data/full.dta", clear
mixed pmvpa i.opp##i.sex##i.period || unit:, reml dfmethod(satterthwaite)
contrast r.sex@opp#period, effects small
matrix G = r(table)
* T0 of opportunity k is column 2k-1: PE = 17, recess = 19, supervised leisure = 25
display "PE gap T0         = " 100*G[1,17] "  p = " G[4,17] "  Tukey p = " 1 - tukeyprob(4, G[7,17], abs(G[3,17])*sqrt(2))
display "recess gap T0     = " 100*G[1,19] "  p = " G[4,19] "  Tukey p = " 1 - tukeyprob(4, G[7,19], abs(G[3,19])*sqrt(2))
display "supervised gap T0 = " 100*G[1,25] "  p = " G[4,25] "  Tukey p = " 1 - tukeyprob(4, G[7,25], abs(G[3,25])*sqrt(2))

* Figure 1: the plotted variable is a proportion (about 0.066 / 0.063), so ticks
* labelled 0.50 / 0.75 under "MVPA ratio (%)" are off by a factor of 10
tabstat pmvpa if opportunity == "overall", by(period) stat(mean semean) format(%9.4f)

********************************************************************************
*c) Missing opportunities entered as 0% MVPA
********************************************************************************
use "data/raw.dta", clear

* 84 x 2 x 13 = 2,184 cells; rows in the workbook (no duplicates) -> 806 missing
duplicates report subject time opportunity
count if opportunity != "overall"
display "missing cells = " 84*2*13 - r(N)

* 35 rows with 0 minutes (ratio stored as 0), mostly housework (7) and PE (6)
tab opportunity if time2 == 0 & opportunity != "overall"

* PE among participants recording PE time: n 55 / 15, ratio 24.1% / 20.5%, Welch p = .36
ttest pmvpa if opportunity == "physical_education" & time2 > 0, by(period) unequal
* PE after zero-filling: 15.8% / 3.7%
use "data/full.dta", clear
ttest pmvpa if opportunity == "physical_education", by(period) unequal

********************************************************************************
*d) Table C: Table 3 refitted, zero-filled vs observed rows
********************************************************************************
* same model as Table 3; zero-filled = published; observed = data rows with
* minutes > 0. est in points; p_fdr = Benjamini-Hochberg over the 13 opportunities.
* Classification changes: 4 of 13 at T0, 8 of 13 at T1; PE at T1 -1.45 -> +10.66.
foreach d in full raw {
	forvalues w = 0/1 {
		use "data/`d'.dta", clear
		drop if time2 == 0 & "`d'" == "raw"
		mixed pmvpa i.opp13 if period == `w' & opportunity != "overall" || sid:, reml dfmethod(satterthwaite)
		contrast g.opp13, effects small
		matrix T = r(table)'
		drop _all
		svmat T, names(col)
		gen opp13 = _n
		label values opp13 opp13
		gen est = 100 * b
		sort pvalue
		gen p_fdr = min(pvalue * _N / _n, 1)
		gsort -pvalue
		replace p_fdr = min(p_fdr, p_fdr[_n-1]) if _n > 1
		sort opp13
		display _newline "Table C: data = `d', wave = `w' (0 = T0, 1 = T1)"
		list opp13 est p_fdr, noobs separator(0)
	}
}

********************************************************************************
*e) Table D: Table 2 p-values vs candidate tests
********************************************************************************
* printed values typed in from Table 2 (p = 0 means "< .001")
clear
input str20 opportunity opp pr_p pr_t pr_df
"autonomous_leisure"  1 0.04 1.328 164.44
"home"                2 0.54 1.384 162.12
"homework"            3 0.14 1.489  91.78
"housework"           4 0.63 0.669 148.24
"job"                 5 0.43 2.089 100.09
"meal"                6 0.75 0.458 166.12
"others"              7 0.04 2.321 150.45
"physical_education"  9 0    5.808 132.04
"recess"             10 0    6.333 151.77
"relax"              11 0.99 0.499 150.98
"school"             12 0.92 0.103 140.42
"supervised_leisure" 13 0    1.954 165.28
"transport"          14 0.13 1.239 150.13
end
gen p_implied = 2 * ttail(pr_df, abs(pr_t))                       // p from printed t and df
gen p_posthoc = el(PH, opp, 4)                                     // post-hoc contrast, section b
tempfile printed
save `printed'

* Welch, zero-filled (as t.test in the authors' script)
use "data/full.dta", clear
drop if opportunity == "overall"
statsby p_welch = r(p), by(opportunity) clear nodots: ttest pmvpa, by(period) unequal
tempfile welch
save `welch'

* paired, zero-filled (as stated in the Methods)
use "data/wide.dta", clear
drop if opportunity == "overall"
statsby p_paired = r(p), by(opportunity) clear nodots: ttest pmvpa_T1 == pmvpa_T0
tempfile paired
save `paired'

* observed rows (minutes > 0): unpaired T1 - T0 difference in points, Welch p
use "data/raw.dta", clear
drop if opportunity == "overall" | time2 == 0
statsby d_obs = (100*(r(mu_2) - r(mu_1))) p_obs = r(p), by(opportunity) clear nodots: ttest pmvpa, by(period) unequal

merge 1:1 opportunity using `printed', nogen
merge 1:1 opportunity using `welch', nogen
merge 1:1 opportunity using `paired', nogen
format p_* pr_p %6.3f
format d_obs %6.2f
display _newline "Table D"
list opportunity pr_p p_implied p_welch p_paired p_posthoc d_obs p_obs, noobs separator(0)
* printed p matches the post-hoc contrast in 11 of 13 rows (not autonomous leisure,
* homework) and its own t and df in 4 of 13 rows
count if abs(p_posthoc - pr_p) <= 0.005 | (pr_p == 0 & p_posthoc < 0.001)
count if abs(p_implied - pr_p) <= 0.005 | (pr_p == 0 & p_implied < 0.001)

********************************************************************************
*f) Table E: Table 2 printed means and Delta vs data; printed SDs
********************************************************************************
* data: mean MVPA % per wave, raw mean change, gender-balanced change
* (average of girls' and boys' change, what the post-hoc contrasts estimate)
use "data/wide.dta", clear
gen T0 = 100 * pmvpa_T0
gen T1 = 100 * pmvpa_T1
gen change = T1 - T0
preserve
collapse (mean) change, by(opportunity sex)
reshape wide change, i(opportunity) j(sex)
gen balanced = (change1 + change2) / 2
keep opportunity balanced
tempfile bal
save `bal'
restore
collapse (mean) T0 T1 raw = change, by(opportunity)
merge 1:1 opportunity using `bal', nogen
tempfile data
save `data'

* printed values typed in from Table 2
clear
input str20 opportunity pr_T0 pr_T1 pr_delta
"overall"              6.6   6.3  -0.3
"autonomous_leisure"   7.1   9.1   2.0
"home"                 5.7   4.7  -0.95
"homework"             4.6   2.3  -2.3
"housework"            1.9   1.4  -0.48
"job"                  0.4   1.5   1.1
"meal"                 2.8   2.3  -0.42
"physical_education"  15.6   3.7 -11.9
"recess"              11.2   3.3  -7.9
"relax"                3.5   3.3  -0.13
"school"               4.2   4.2  -0.05
"supervised_leisure"  12.6   8.6  -5.6
"transport"           15.8  13.4  -2.1
"others"               2.2   4.7   2.8
end
merge 1:1 opportunity using `data', nogen
gen pr_T1_minus_T0 = pr_T1 - pr_T0
format T0 T1 raw balanced pr_T1_minus_T0 %6.2f
display _newline "Table E"
list opportunity pr_T0 T0 pr_T1 T1 pr_delta pr_T1_minus_T0 raw balanced, noobs separator(0)

* printed SDs a tenth of the data: overall T0/T1 0.22/0.26 (data 2.17/2.62),
* homework T0 1.4 (data 14.0), PE T1 0.95 (data 9.50)
use "data/wide.dta", clear
gen T0 = 100 * pmvpa_T0
gen T1 = 100 * pmvpa_T1
tabstat T0 T1 if opportunity == "overall", stat(sd) format(%6.2f)
tabstat T0 if opportunity == "homework", stat(sd) format(%6.2f)
tabstat T1 if opportunity == "physical_education", stat(sd) format(%6.2f)

********************************************************************************
*g) Gender gaps at T0 and announced interaction tests
********************************************************************************
* gaps: see section b (code-specified post-hoc comparisons)
use "data/full.dta", clear
* time x gender, first ANOVA: sex#period row (p = .40)
anova pmvpa sex / sid|sex period sex#period if opportunity == "overall", sequential
* time x gender x opportunity, second ANOVA: period#opp#sex row (p = .56)
anova pmvpa opp sex opp#sex / sid|opp#sex period period#opp period#sex period#opp#sex, sequential

********************************************************************************
*h) Choice of units in the second ANOVA
********************************************************************************
* participants as units (random intercepts for participant and participant x
* opportunity), 13 opportunities
use "data/full.dta", clear
drop if opportunity == "overall"
mixed pmvpa i.sex##i.period##i.opp13 || sid: || unit:, reml dfmethod(satterthwaite)
contrast sex, small
contrast opp13, small
contrast period#opp13, small
contrast sex#opp13, small
contrast r.sex, effects small                                      // gender gap (boys - girls)

* gender gap with the published structure (14 levels): 0.97 points
use "data/full.dta", clear
mixed pmvpa i.sex##i.period##i.opp || sid: || unit:, reml dfmethod(satterthwaite)
contrast r.sex, effects small

* observed rows only (no zero-filled cells): gap 2.23 points, p = .007
use "data/raw.dta", clear
drop if opportunity == "overall"
egen unit = group(sid opp13)
mixed pmvpa i.sex##i.period##i.opp13 || sid: || unit:, reml dfmethod(satterthwaite)
contrast r.sex, effects small

********************************************************************************
*i) Table 1 tests (Welch vs paired)
********************************************************************************
* as printed (Welch, R lines 83-85): BMI t = -0.61, df = 165.37, p = .54;
* wear time t = 1.30, df = 155.57, p = .19
use "data/full.dta", clear
keep if opportunity == "overall"
ttest BMI, by(period) unequal
ttest time2, by(period) unequal

* paired (as stated in the Methods): BMI t(83) = 2.57, p = .012; wear time p = .15
use "data/wide.dta", clear
keep if opportunity == "overall"
ttest BMI_T1 == BMI_T0
ttest time2_T1 == time2_T0

* printed effect sizes are paired Cohen's d (mean change / SD of change): 0.28, 0.16
gen bmi_change  = BMI_T1 - BMI_T0
gen wear_change = time2_T1 - time2_T0
tabstat bmi_change wear_change, stat(mean sd) format(%9.3f)

********************************************************************************
*j) Table F: Table 3 against the overall ratio, FDR-consistent intervals
********************************************************************************
* "overall" rows added as reference level (ib8.opp), so each estimate is the
* opportunity's ratio minus the overall ratio. Data: full = zero-filled,
* raw = observed rows with minutes > 0.
foreach d in full raw {
	forvalues w = 0/1 {
		use "data/`d'.dta", clear
		drop if time2 == 0 & "`d'" == "raw"
		mixed pmvpa ib8.opp if period == `w' || sid:, reml dfmethod(satterthwaite)
		contrast r.opp, effects small
		matrix T = r(table)'
		drop _all
		svmat T, names(col)
		gen k = _n
		gen opp = cond(k < 8, k, k + 1)                            // skip "overall" (8)
		label values opp opp
		sort pvalue
		gen p_fdr = min(pvalue * _N / _n, 1)
		gsort -pvalue
		replace p_fdr = min(p_fdr, p_fdr[_n-1]) if _n > 1
		egen R = total(p_fdr < 0.05)
		gen est = 100 * b
		gen lo  = 100 * (b - invttail(df, R*0.05/26) * se)
		gen hi  = 100 * (b + invttail(df, R*0.05/26) * se)
		sort opp
		display _newline "Table F: data = `d', wave = `w' (0 = T0, 1 = T1)"
		list opp est lo hi p_fdr, noobs separator(0)
	}
}

********************************************************************************
*k) ICCs
********************************************************************************
* reported "school/university" ICCs 0.011 / 0.039 equal the participant ICCs of the
* Table 3 models (0.0107 / 0.0388); the workbook has no school or university column
use "data/full.dta", clear
forvalues w = 0/1 {
	qui mixed pmvpa i.opp13 if period == `w' & opportunity != "overall" || sid:, reml
	estat icc
}
describe using "data/raw.dta" // no school or uni identifiers in raw data

********************************************************************************
*l) Opportunity rows vs the overall row
********************************************************************************
* per participant-wave, sum the 13 opportunity rows (rows as deposited)
use "data/raw.dta", clear
bysort subject time: egen minutes_13 = total(cond(opportunity != "overall", time2, 0))
bysort subject time: egen mvpa_13    = total(cond(opportunity != "overall", mvpa, 0))
keep if opportunity == "overall"                                   // 168 participant-waves
count if minutes_13 > 1.01 * time2                                 // 22 exceed overall by > 1%
count if abs(mvpa_13 - mvpa) < 0.001                               // MVPA minutes equal in 2
count if time2 < 2400                                              // 1 below 2,400 minutes
summarize time2                                                    // minimum 1,420

* stored overall ratio = own MVPA / minutes (0 differences); vs the time-weighted
* ratio of the 13 rows, sum(MVPA min) / sum(min): differs > 0.1 points in 139
gen ratio_own = mvpa / time2
gen ratio_13  = mvpa_13 / minutes_13
count if abs(100 * (pmvpa - ratio_own)) > 0.01 // stored overall ratio does equal its own MVPA minutes / total minutes
count if abs(100 * (pmvpa - ratio_13))  > 0.1

********************************************************************************
*m) BMI details in the dataset
********************************************************************************
* combinations of gender, age and BMI at T0 that occur once (all 84; 72 with BMI
* rounded to one decimal) - counts only
use "data/raw.dta", clear
keep if opportunity == "overall" & time == "T0"
duplicates tag gender age BMI, gen(dup)
count if dup == 0
gen BMI1 = round(BMI, 0.1)
duplicates tag gender age BMI1, gen(dup1)
count if dup1 == 0
* distribution of BMI at T0 (outliers at either end; no values printed)
tab BMI1 if time == "T0"

* BMI identical at T0 and T1 for 16 participants
use "data/wide.dta", clear
keep if opportunity == "overall"
count if BMI_T1 == BMI_T0

********************************************************************************
*n) Minor issues
********************************************************************************
use "data/full.dta", clear

* Figure 1 prints p = 0.38: the Welch test of the overall ratio (R line 111), p = .384;
* the text's p = .296 is the first ANOVA's time effect (section b)
ttest pmvpa if opportunity == "overall", by(period) unequal

* gender counts in the workbook: 58 F, 26 M (Table 1 prints 58 boys, 26 girls)
tab gender if opportunity == "overall" & time == "T0"

* power: 71 needed for a one-sided paired test at dz = 0.30; 90 two-sided; power 0.776 at n = 84
power onemean 0 0.3, sd(1) power(0.8) onesided
power onemean 0 0.3, sd(1) power(0.8)
power onemean 0 0.3, sd(1) n(84)

* overall change: -0.32 points, 95% CI -0.93 to +0.29 (paired); a decline of
* 0.93 points is 14% of the baseline 6.6%
use "data/wide.dta", clear
keep if opportunity == "overall"
replace pmvpa_T0 = 100 * pmvpa_T0
replace pmvpa_T1 = 100 * pmvpa_T1
ttest pmvpa_T1 == pmvpa_T0
display "largest decline in the CI as % of the baseline = " 100 * 0.93 / 6.6

* transport: ratio 15.6% -> 13.4%, Welch p = .22 (zero-filled)
use "data/full.dta", clear
ttest pmvpa if opportunity == "transport", by(period) unequal
* transport's share of the MVPA minutes recorded in the 13 opportunities: 14.8% -> 19.1%
use "data/raw.dta", clear
drop if opportunity == "overall"
collapse (sum) mvpa, by(period opportunity)
bysort period: egen total = total(mvpa)
gen share = 100 * mvpa / total
list period share if opportunity == "transport", noobs

log close
