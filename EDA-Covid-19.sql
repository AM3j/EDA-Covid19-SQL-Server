-- COVID-19 Data Analysis

-- Show All DataBases
Select name From sys.databases

-- Select The Right One
Use CovidProject

-- Check
Select DB_NAME()

-- Show Tables
Select Name As Table_Name From sys.tables

-- Looking at Tables
Select * From CovidProject.dbo.CovidDeaths$
Select * From CovidProject.dbo.CovidVaccinations$

-- World KPIs Using CTE
-- Total Cases, Deaths, CFR, Infection Rate, and Vaccination Rate
WITH CovidKPIs AS (
    SELECT 
        dea.continent,
        dea.location,
        MAX(CAST(dea.total_cases AS BIGINT)) AS total_cases,
        MAX(CAST(dea.total_deaths AS BIGINT)) AS total_deaths,
        MAX(CAST(dea.population AS BIGINT)) AS population,
        MAX(CAST(vac.people_fully_vaccinated AS BIGINT)) AS people_fully_vaccinated
    FROM CovidDeaths$ dea
    JOIN CovidVaccinations$ vac 
        ON dea.location = vac.location
    WHERE dea.continent IS NOT NULL
    GROUP BY dea.continent, dea.location
)

Select SUM(total_cases) as total_cases
	, SUM(total_deaths) as total_deaths
	, SUM(people_fully_vaccinated) as people_fully_vaccinated
	, SUM(population) as world_population
	, Round(Cast(SUM(total_cases) as Float)/SUM(population)*100, 2) as infection_rate
	, Round(Cast(SUM(total_deaths) as Float)/SUM(total_cases)*100, 2) as case_fatality_rate
	, Round(Cast(SUM(people_fully_vaccinated) as Float)/SUM(population)*100, 2) as full_vaccination_rate
	From CovidKPIs


--Analyze Trends 
-- Total Cases and Total Deaths Over Time by Continent
Select continent, date
	, SUM(Cast(total_cases As INT)) As total_cases
	, SUM(Cast(total_deaths As INT)) As total_deaths
	From CovidDeaths$
	Where continent Is Not Null
	Group By continent, date
	Order By continent, date 


-- Daily Case Fatality Rate(Total Deaths / Total Cases) Over Time for Each Country
Select location, date
	, SUM(Cast(total_deaths As INT)) As total_deaths
	, SUM(Cast(total_cases As INT)) As total_cases 
	,Round(SUM(Cast(total_deaths As float))/SUM(Cast(total_cases As float))*100, 2) As DCRatio
	From CovidDeaths$
	Where continent Is Not Null
	--And location = 'Saudi Arabia' -- Replace With Your Country
	Group By location, date
	Order By location, date 

-- New Cases and New Deaths Over Time for Each Country
Select location, date
	, SUM(Cast(new_cases As INT)) As new_cases
	, SUM(Cast(new_deaths As INT)) As new_deaths
	From CovidDeaths$
	Where continent Is Not Null
	--And location = 'Saudi Arabia' -- Replace With Your Country
	Group By location, date
	Order By location, date 

-- Tracks the cumulative number of vaccinations administered in each country, day by day
-- Using CTE
With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
As (
	Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
	, SUM(Cast(vac.new_vaccinations as Int)) Over ( Partition By dea.location Order by dea.location, dea.date) as RollingPeopleVaccinated
	From CovidProject..CovidVaccinations$ vac
	Join CovidProject..CovidDeaths$ dea
	On vac.location = dea.location
	and vac.date = dea.date
	where dea.continent is not Null
)
-- The query
Select *, ROUND((RollingPeopleVaccinated*100.0/Population),2) AS VaccinationRate
From PopvsVac


-- Demographic & Geographic Analysis


-- Top 3 Countries Have The Highest Total Cases Per Million
Select Top 3
	location, MAX(Cast(total_cases_per_million As Float)) As total_cases_per_million 
	From CovidDeaths$
	Where continent Is Not Null
	--And location = 'Saudi Arabia' -- Replace With Your Country
	Group By location
	Order By total_cases_per_million Desc

-- Top 3 Countries Have The Highest Total Deaths Per Million
Select Top 3
	location, MAX(Cast(total_deaths_per_million As Float)) As total_deaths_per_million
	From CovidDeaths$
	Where continent Is Not Null
	--And location = 'Saudi Arabia' -- Replace With Your Country
	Group By location
	Order By total_deaths_per_million Desc

-- Health Care

-- Hospital Patients Per Thousand vs Total Deaths Per Million
-- Do countries with more hospital beds per 1,000 people have lower death rates?
Select dea.location
	, MAX(Cast(vac.hospital_beds_per_thousand As Float)) As hospital_beds_per_thousand
	, MAX(Cast(dea.total_deaths_per_million As Float)) As total_deaths_per_million 
	From CovidDeaths$ dea Join CovidVaccinations$ vac 
	On dea.location = vac.location And dea.date = vac.date
	Where dea.continent Is Not Null
	--And location = 'Saudi Arabia' -- Replace With Your Country
	Group By dea.location
	Order By total_deaths_per_million Desc


-- Does More Vaccinations Affect New Deaths in Each Country Over Time?
Select dea.location, dea.date
	, Max(Cast(vac.total_vaccinations_per_hundred As Float)) As total_vaccinations_per_hundred
	, MAX(Cast(dea.new_deaths_smoothed_per_million As Float)) As total_deaths_per_million 
	From CovidDeaths$ dea Join CovidVaccinations$ vac 
	On dea.location = vac.location And dea.date = vac.date
	Where dea.continent Is Not Null
	And dea.location = 'United States' -- Replace With Your Country
	Group By dea.location, dea.date
	Order By dea.location, dea.date

-- Do countries with higher human_development_index have better vaccination coverage?
-- We Will Use CTE
With VacCoverge As
	( 
	Select dea.location
		, MAX(Cast(vac.human_development_index As Float)) As human_development_index
		, MAX(Cast(dea.population As Int)) As population
		, Max(Cast(vac.people_vaccinated As Int)) As people_vaccinated
		, MAX(Cast(vac.people_fully_vaccinated As Int)) As people_fully_vaccinated 
		From CovidDeaths$ dea Join CovidVaccinations$ vac 
		On dea.location = vac.location
		Where dea.continent Is Not Null
		--And dea.location = 'United States' -- Replace With Your Country
		Group By dea.location
	)

Select location, human_development_index
	, Round((Cast(people_vaccinated As float)/population)*100, 2) As FirstDoseCoverge
	, Round((Cast(people_fully_vaccinated As float)/population)*100,2) As FullDoseCoverge
	From VacCoverge
	Order By human_development_index Desc
