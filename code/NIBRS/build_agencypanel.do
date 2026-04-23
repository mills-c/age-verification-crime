* Establish directories

/* CRC Directories: Set directory to group folder 
cd "/groups/cmills6/"
global cmills6 "/groups/cmills6/"
global nibrs "${cmills6}Age Verification/NIBRS Data/"
global admin "${nibrs}Administrative Segment/"
global ucr "${cmills6}ucr_arrests_kaplan/"
*/


*Local Directories (comment out when running on CRC)
global nibrs "/Users/emilydavis/Documents/gitrepos/age-verification-crime/data/NIBRS"
global ucr "/Users/emilydavis/Documents/gitrepos/age-verification-crime/data/UCR"


*Create data set of agency characteristics from UCR
*get 2022 population by ori 
import delimited "$ucr/arrests_monthly_2022.csv", clear
*keep agency geographic characteristics that are constant
keep ori9 year population agency_name state state_abb population_group country_division fips_state_code fips_county_code fips_state_county_code fips_place_code agency_type crosswalk_agency_name census_name longitude latitude address_name address_street_line_1 address_street_line_2 address_city address_state address_zip_code
*rename ori to ori9 to match nibrs
rename ori9 ori
*keep first record by ori
bysort ori: keep if _n == 1
*save
save "$ucr/ori_characteristics_2022", replace


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

*indicator for all months
gen coverage_full =(months_total ==36)

*indicator for >9 months in each year
gen coverage_9mo =(months_2022 >=9 & months_2023 >=9 & months_2024 >=9)

*indicator for >6 months in each year
gen coverage_6mo =(months_2022 >=6 & months_2023 >=6 & months_2024 >=6)

*merge in population data
merge 1:1 ori using "$ucr/ori_characteristics_2022", keepusing(population)
drop if _merge ==2
drop _merge

preserve

**get share of agency observations with non-missing age and sex
*indicator for reporting age and gender in sex crimes data
use "$nibrs/sex_crime_offenders_2022_2024.dta", clear

*age
replace age_of_offender ="99" if age_of_offender =="over 98 years old"
replace age_of_offender ="" if age_of_offender =="unknown"
destring(age_of_offender), replace

gen age_nonmiss =(age !=.)

*sex
replace sex ="" if sex =="unknown"
gen sex_nonmiss =(sex !="")

*share of agency's observations with non missing age and sex
bysort ori: egen share_age_nonmiss =mean(age_nonmiss)
bysort ori: egen share_sex_nonmiss =mean(sex_nonmiss)

keep ori share_age_nonmiss share_sex_nonmiss
bysort ori: keep if _n == 1

tempfile nonmiss
save `nonmiss'

restore
merge 1:1 ori using `nonmiss'
drop if _merge ==2
drop _merge

save "$nibrs/agency_panel.dta", replace
