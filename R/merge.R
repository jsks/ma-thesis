#!/usr/bin/env Rscript
#
# R script merging together V-Dem democracy data, UN population
# statistics, GROWup geographic data, and UCDP conflict data.
####

library(data.table)
library(dplyr)
library(magrittr)
library(readxl)
library(tidyr)
library(thesis.utils)

###
# V-Dem - Democracy data
vdem <- readRDS("data/raw/V-Dem-CY-Full+Others-v9.rds") %>%
    select(-matches("_ord|_mean|_nr|_\\d*$"), -matches("^e_")) %>%
    filter(year >= 1945)

# This isn't the independence date for most countries, but take
# advantage of the fact that our dataset is censored from ~1950
# onwards meaning that we'll get the right year for post-colonial,
# post-soviet, etc etc
independence <- select(vdem, country_name, year, v2svindep) %>%
    arrange(country_name, year) %>%
    group_by(country_name) %>%
    summarise(independence = first(year[v2svindep == 1]))

vdem %<>%
    left_join(independence, by = "country_name") %>%
    mutate(independence = ifelse(year == independence, 1, 0))

sprintf("Started with %d countries and %d rows from V-Dem",
        n_distinct(vdem$country_id), nrow(vdem))

###
# COW - CINC
nmc <- fread("data/raw/NMC_5_0/NMC_5_0.csv", data.table = F) %>%
    filter(year >= 1945)

# Why are there duplicates in this file?!
cow <- fread("refs/cow_countries.csv", data.table = F) %>%
    distinct(CCode, StateNme)

nmc %<>% left_join(cow, by = c("ccode" = "CCode")) %>%
    select(ccode, year, cinc, COWname = StateNme)

filter(nmc, !ccode %in% vdem$COWcode) %>%
    distinct(COWname) %$%
    paste(COWname, collapse = "; ") %>%
    sprintf("COW countries missing from V-Dem: %s", .)

vdem %<>% left_join(nmc, by = c("COWcode" = "ccode", "year"))

###
# Penn World Tables
pwt.df <- read_xlsx("data/raw/pwt91.xlsx", sheet = 3) %>%
    filter(!is.na(rgdpe)) %>%
    mutate(country =
               case_when(country == "Bolivia (Plurinational State of)" ~ "Bolivia",
                         grepl("Ivoire", country) ~ "Ivory Coast",
                         country == "D.R. of the Congo" ~ "Democratic Republic of the Congo",
                         country == "Congo" ~ "Republic of the Congo",
                         country == "Cabo Verde" ~ "Cape Verde",
                         country == "Gambia" ~ "The Gambia",
                         country == "China, Hong Kong SAR" ~ "Hong Kong",
                         country == "Iran (Islamic Republic of)" ~ "Iran",
                         country == "Republic of Korea" ~ "South Korea",
                         country == "Lao People's DR" ~ "Laos",
                         country == "Republic of Moldova" ~ "Moldova",
                         country == "North Macedonia" ~ "Macedonia",
                         country == "Myanmar" ~ "Burma/Myanmar",
                         country == "Russian Federation" ~ "Russia",
                         country == "Eswatini" ~ "Swaziland",
                         country == "Syrian Arab Republic" ~ "Syria",
                         country == "U.R. of Tanzania: Mainland" ~ "Tanzania",
                         country == "United States" ~ "United States of America",
                         country == "Venezuela (Bolivarian Republic of)" ~ "Venezuela",
                         country == "Viet Nam" ~ "Vietnam",
                         T ~ country)) %>%
    select(country_name = country, year, rgdpe, pop) %>%
    mutate(rgdpepc = rgdpe / pop) %>%
    arrange(country_name, year) %>%
    group_by(country_name, idx = consecutive(year)) %>%
    mutate(rgdpepc_gro = (rgdpepc / lag(rgdpepc) - 1)) %>%
    ungroup %>%
    select(-idx)

setdiff(vdem$country_name, pwt.df$country_name) %>%
    unique %>%
    paste(collapse = "; ") %>%
    sprintf("V-Dem countries missing from PWT: %s", .)

vdem %<>% left_join(pwt.df, by = c("country_name", "year"))

###
# Add GW codes to merged dataset. GW are modified COW codes, which are
# already merged into V-Dem, and UCDP uses a slightly modified version
# of GW. Awesome.
ctable <- fread("refs/ucdp_countries.csv", data.table = F) %>%
    select(country_name, gwid = code, start_year = start, end_year = end) %>%
    mutate(end_year = ifelse(is.na(end_year), 2017, end_year))

# Drop smaller countries/territories which will eventually have high
# missingess
vdem %<>%
    filter(!country_name %in% c("Hong Kong", "Palestine/British Mandate",
                                "Palestine/Gaza", "Palestine/West Bank",
                                "Sao Tome and Principe", "Seychelles",
                                "Somaliland", "Vanuatu", "Zanzibar")) %>%
    mutate(gwid = case_when(country_name == "Germany" ~ 260L,
                            country_name == "German Democratic Republic" ~ 265L,
                            country_name == "Yemen" ~ 678L,
                            country_name == "Serbia" & year >= 2006 ~ 340L,
                            T ~ COWcode)) %>%
    group_by(country_name) %>%
    fill(gwid, .direction = "up") %>%
    ungroup

vdem <- select(ctable, -country_name) %>% right_join(vdem, by = "gwid")

stopifnot(!anyNA(vdem$gwid), vdem$gwid %in% ctable$gwid)

###
# UCDP - Armed Conflict
#
# Right off the bat, we'll lose Brunei and Cameroon - 1960 since V-Dem
# doesn't code them.
acd <- readRDS("data/raw/UcdpPrioConflict_v19_1.rds")

# Civil conflict + extrasystemic (colonial/imperial wars)
# conflict_id = 418 is the United States vs Al Qaeda starting in 2001
# --- why isn't extrasystemic??
civil <- filter(acd, type_of_conflict %in% c(1, 3, 4), conflict_id != 418) %>%
    mutate(gwno_a = as.character(gwno_a)) %>%
    separate_rows(gwno_a, sep = ",") %>%
    mutate(gwno_a = as.integer(gwno_a))

missing <- filter(ctable, gwid %in% setdiff(civil$gwno_a, vdem$gwid))
if (nrow(missing) > 0) {
    missing %$%
        paste(country_name, collapse = "; ") %>%
        sprintf("UCDP countries missing from merged: %s", .)
}

counts.df <- group_by(civil, gwno_a, year) %>%
    summarise(n_conflicts = n(),
              intensity = max(intensity_level),
              type_of_conflict = max(type_of_conflict)) %>%
    ungroup

neighbours.df <- readRDS("data/neighbours.rds") %>%
    inner_join(counts.df, by = c("neighbour_gwid" = "gwno_a", "year")) %>%
    group_by(gwid, year) %>%
    summarise(n_neighbour_conflicts = sum(n_conflicts),
              neighbour_intensity = max(intensity),
              neighbour_type_conflict = max(type_of_conflict)) %>%
    ungroup

full_counts.df <- full_join(counts.df, neighbours.df,
                            by = c("gwno_a" = "gwid", "year"))

###
# Find conflict onsets
find_onset <- function(df, vars) {
    group_by_at(df, c("gwno_a", vars)) %>%
        summarise(onset = 1, year = min(year)) %>%
        ungroup %>%
        distinct(gwno_a, year, .keep_all = T) %>%
        select(gwno_a, year, onset)
}

civil %<>% filter(type_of_conflict %in% 3:4)

# Episode onsets - all conflicts
episode_ucdp <- find_onset(civil, c("conflict_id", "start_date2")) %>%
    rename(episode_onset = onset)

# Episode onsets - high intensity
episode_major_ucdp <- filter(civil, intensity_level == 2) %>%
    find_onset(c("conflict_id", "start_date2")) %>%
    rename(major_onset = onset)

# Episode onsets - cumulative intensity
episode_cum_ucdp <- filter(civil, cumulative_intensity == 1) %>%
    find_onset(c("conflict_id", "start_date2")) %>%
    rename(cum_onset = onset)

ucdp <- list(episode_ucdp, episode_major_ucdp, episode_cum_ucdp) %>%
    Reduce(partial(full_join, by = c("gwno_a", "year")), .)

merged.df <- left_join(vdem, ucdp, by = c("gwid" = "gwno_a", "year")) %>%
    left_join(full_counts.df, by = c("gwid" = "gwno_a", "year")) %>%
    mutate(ongoing = ifelse(is.na(intensity), 0, 1),
           major_ongoing = ifelse(is.na(intensity) | intensity == 1, 0, 1),
           neighbour_conflict = ifelse(is.na(n_neighbour_conflicts), 0, 1),
           episode_onset = ifelse(is.na(episode_onset), 0, 1),
           major_onset = ifelse(is.na(major_onset), 0, 1),
           cum_onset = ifelse(is.na(cum_onset), 0, 1))

# Calculate number of peace years since last ongoing civil conflict or
# independence. For countries censored due to start date, start
# counting from the end of WW2. Even for countries not directly
# involved in WW2, it was a significant international event that
# reshaped the world order with domestic consequences for everyone.
#
# The result is essentially the peaceyears count from GROWup with a
# few exceptions, including extrasystemic colonial wars for
# independence spilling over past independence and which are then
# included in ongoing counts of conflict (ex: Indonesia).
merged.df %<>%
    filter(year >= start_year, year <= end_year) %>%
    arrange(country_name, year) %>%
    group_by(country_name, idx = consecutive(year)) %>%
    mutate(peace_yrs = calc_peace_yrs(year, ongoing)) %>%
    ungroup %>%
    select(-idx)

stopifnot(!is.na(merged.df$country_name))

###
# GROWUP - Area, elevation, and ethnic group data
#
# Technically coded at the beginnning of the year versus the end of
# the year in V-Dem...
growup <- fread("./data/raw/growup/data.csv", data.table = F) %>%
    select(gwid = countries_gwid, country_name = countryname, year,
           onset_ko_flag, area_sqkm, meanelev, rlvt_groups_count,
           discrimpop, incidence_flag, peaceyears)

filter(growup, !gwid %in% merged.df$gwid) %$%
    unique(country_name) %>%
    paste(collapse = "; ") %>%
    sprintf("GROWup countries missing from merged dataset: %s", .)

merged.df <- select(growup, -country_name) %>%
    right_join(merged.df, by = c("gwid", "year")) %>%
    group_by(country_name) %>%
    fill("area_sqkm", "meanelev", "rlvt_groups_count", .direction = "up") %>%
    ungroup %>%
    mutate(pop_density = 1000 * pop / area_sqkm)

assert_cy(merged.df)

breaks <- group_by(merged.df, country_name) %>%
    filter(any(consecutive(year) != 1))

if (nrow(breaks) > 0) {
    distinct(breaks, country_name) %$%
        paste(country_name, collapse = "; ") %>%
        sprintf("Non-consecutive country-years: %s", .) %>%
        stop(call. = F)
}

dbg_info(merged.df)

###
# Save, save, save!
saveRDS(merged.df, "data/merged_data.rds")
