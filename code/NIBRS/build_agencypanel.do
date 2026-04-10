* Establish directories

/* CRC Directories: Set directory to group folder 
cd "/groups/cmills6/"
global cmills6 "/groups/cmills6/"
global nibrs "${cmills6}Age Verification/NIBRS Data/"
global admin "${nibrs}Administrative Segment/"
*/


*Local Directories (comment out when running on CRC)
global nibrs "/Users/emilydavis/Documents/gitrepos/age-verification-crime/data/NIBRS"


/* Create incidents_by_agency_month.dta
use "${admin}nibrs_administrative_segment_2022.dta", replace
forvalues y=2023/2024 {
	append using "${admin}nibrs_administrative_segment_`y'.dta", force
}
drop if state=="guam"
gen dmodate = date(incident_date, "YMD")
format dmodate %td 
gen modate = mofd(dmodate)
format modate %tm 
gen month = month(dmodate)
egen incident_id = group(unique_incident_id)
collapse (count) incident_id, by(state ori modate) 
save "${nibrs}incidents_by_agency_month.dta", replace 
*/

use "$nibrs/incidents_by_agency_month.dta", clear

*get years
gen year = year(dofm(modate))
gen month = month(dofm(modate))

*indicator for years
forvalues x =2022/2024{
	gen yr_`x' =(year ==`x')
}

*for counts
gen n =1

*number of months per agency
bysort ori: egen months_total =sum(n)

*number of months per year per agency
forvalues x=2022/2024 {
	bysort ori: egen months_`x' =sum(yr_`x')
}

*drop intermediate vars and get one observation per agency
keep ori state months_*
bysort ori: keep if _n == 1

egen mean_monthsperyr = mean(months_2022 months_2023 months_2024)

*indicator for all months
gen coverage_full =(months_total ==36)

*indicator for >9 months in each year
gen coverage_9mo =(months_2022 >=9 & months_2023 >=9 & months_2024 >=9)

*indicator for >6 months in each year
gen coverage_6mo =(months_2022 >=6 & months_2023 >=6 & months_2024 >=6)

save "$nibrs/agency_panel.dta", replace

// Sex Crimes Data \\
*load sex crime data 
use "$nibrs/sex_crime_offenders_2022_2024.dta", clear

*get everything at the agency-month-year level

*offense categories
foreach x in porn trafficking prostitution {
	gen offense_`x' = strpos(lower(ucr_offense_code1),"`x'")>0 ///
	| strpos(lower(ucr_offense_code2),"`x'")>0 ///
	| strpos(lower(ucr_offense_code3),"`x'")>0 ///
	| strpos(lower(ucr_offense_code4),"`x'")>0 ///
	| strpos(lower(ucr_offense_code5),"`x'")>0 
}

gen offense_sex = strpos(lower(ucr_offense_code1),"sex offenses")>0 ///
	| strpos(lower(ucr_offense_code2),"sex offenses")>0 ///
	| strpos(lower(ucr_offense_code3),"sex offenses")>0 ///
	| strpos(lower(ucr_offense_code4),"sex offenses")>0 ///
	| strpos(lower(ucr_offense_code5),"sex offenses")>0

*generate indicators at the agency-level 
foreach x in porn trafficking prostitution sex {
	bysort ori: egen any_`x' =max(offense_`x')
}

foreach x in porn trafficking prostitution sex {
	bysort ori: egen num_`x' =sum(offense_`x')
}

*age
replace age_of_offender ="99" if age_of_offender =="over 98 years old"
replace age_of_offender ="" if age_of_offender =="unknown"
destring(age_of_offender), replace


*merge in panel info
merge m:1 ori using "$nibrs/agency_panel"
