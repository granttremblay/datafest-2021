#PACKAGE INSTALL

#Install the packages we need for today. 
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if(length(new.pkg)) install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

packages <- c("viridis", "glmmTMB",  "effects", "dataverse", "sf", "remotes",
              "leaflet", "mapview", "htmltools", "htmlwidgets", "tigris",   
              "lubridate", "DHARMa", "tidycensus", "tidyverse", "tidymodels")
ipak(packages)

# mapview may need to be installed from Github
# remotes::install_github("r-spatial/mapview")


#DATA DOWNLOAD

# get the digital object identifier for the Dataverse dataset
DOI <- "doi:10.7910/DVN/HIDLTK"

# retrieve the contents of the dataset
covid <- get_dataset(DOI)

#Dataset has multiple files, so let's get the files we need.
# get data file for COVID-19 cases
US_cases_file <- get_file("us_state_confirmed_case.tab", dataset = DOI)
# convert raw vector to dataframe
US_cases <- read_csv(US_cases_file)

#Reformat, clean, and more intuitively name the data
US_cases_long <- US_cases %>%
  # select columns of interest
  select(fips, NAME, POP10, matches("^\\d")) %>% 
  # rename some columns
  rename(GEOID = fips, state = NAME, pop_count_2010 = POP10) %>%
  # reshape to long format for dates
  pivot_longer(cols = grep("^\\d", colnames(.), value = TRUE), 
               names_to = "date", values_to = "cases_cum") %>%
  # create new derived time variables from dates 
  mutate(date = ymd(date), # year-month-day format
         day_of_year = yday(date),
         week_of_year = week(date),
         month = month(date)) %>% 
  group_by(state) %>% 
  # create cases counts
  mutate(cases_count = cases_cum - lag(cases_cum, default = 0),
         # tidy-up negative counts
         cases_count_pos = ifelse(cases_count < 0, 0, cases_count),
         # create cases rates
         cases_rate_100K = (cases_count_pos / pop_count_2010) * 1e5,
         cases_cum_rate_100K = (cases_cum / pop_count_2010) * 1e5)

# aggregate to weekly level (for later modeling)
US_cases_long_week <- US_cases_long %>%
  group_by(GEOID, state, week_of_year) %>%
  summarize(pop_count_2010 = mean(pop_count_2010),
            cases_count_pos = sum(cases_count_pos), 
            cases_rate_100K = sum(cases_rate_100K)) %>% 
  drop_na()

#You're ready to move over to Visualization.R