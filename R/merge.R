#!/usr/bin/env Rscript
#
# R script merging together V-Dem democracy data, UN population
# statistics, GROWup geographic data, and UCDP conflict data.
####

suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(magrittr))
suppressMessages(library(readxl))
suppressMessages(library(tidyr))
suppressMessages(library(thesis.utils))

###
# V-Dem - Democracy data
vdem <- readRDS("data/raw/V-Dem-CY-Full+Others-v9.rds") %>%
    select(-matches("_ord|_mean|_nr|_\\d*$"), -matches("^e_")) %>%
    filter(year >= 1945)

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
# Maddison - Population & GDP
#
# This is already merged into V-Dem; however, we want to use rgdpnapc
# to calculate GDP growth rather than cgdppc. Plus, we'll also take
# population statistics since V-Dem only has WB figures.
#
# Maddison includes Serbia Federation, Czech territory, and RFSR as
# separate entites. V-Dem codes entire Yugoslavia and Czechoslovakia
# so drop the constituent republics prior to independence, Russia
# however is coded as only the socialist republic instead of the
# entire USSR.
maddison.df <- read_xlsx("data/raw/mpd2018.xlsx", sheet = 2) %>%
    filter(year > 1940,
           !(country == "Serbia" & year < 1992),
           !(country == "Former Yugoslavia" & year >= 1992),
           !(country == "Czech Republic" & year < 1992),
           !(country == "Czechoslovakia" & year >= 1992)) %>%
    mutate(country =
               case_when(country == "Bolivia (Plurinational State of)" ~ "Bolivia",
                         country == "Cabo Verde" ~ "Cape Verde",
                         country == "China, Hong Kong SAR" ~ "Hong Kong",
                         country == "Congo" ~ "Republic of the Congo",
                         country == "Côte d'Ivoire" ~ "Ivory Coast",
                         country == "Czechoslovakia" & year < 1992 ~ "Czech Republic",
                         country == "D.P.R. of Korea" ~ "North Korea",
                         country == "D.R. of the Congo" ~ "Democratic Republic of the Congo",
                         country == "Former Yugoslavia"  & year < 1992 ~ "Serbia",
                         country == "Gambia" ~ "The Gambia",
                         country == "Iran (Islamic Republic of)" ~ "Iran",
                         country == "Lao People's DR" ~ "Laos",
                         country == "Myanmar" ~ "Burma/Myanmar",
                         country == "Republic of Korea" ~ "South Korea",
                         country == "Republic of Moldova" ~ "Moldova",
                         country == "Russian Federation" ~ "Russia",
                         country == "Sudan (Former)" ~ "Sudan",
                         country == "Syrian Arab Republic" ~ "Syria",
                         country == "Taiwan, Province of China" ~ "Taiwan",
                         country == "TFYR of Macedonia" ~ "Macedonia",
                         country == "U.R. of Tanzania: Mainland" ~ "Tanzania",
                         country == "United States" ~ "United States of America",
                         country == "Venezuela (Bolivarian Republic of)" ~ "Venezuela",
                         country == "Viet Nam" ~ "Vietnam",
                         T ~ country)) %>%
    select(country_name = country, year, cgdppc, rgdpnapc, pop) %>%
    arrange(country_name, year) %>%
    group_by(country_name, consecutive(year)) %>%
    mutate(gdpgro = rgdpnapc / lag(rgdpnapc) - 1)

setdiff(vdem$country_name, maddison.df$country_name) %>%
    unique %>%
    paste(collapse = "; ") %>%
    sprintf("V-Dem countries missing from Maddison: %s", .)

vdem %<>% left_join(maddison.df, by = c("country_name", "year"))

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
    mutate(gwno_loc = as.character(gwno_loc)) %>%
    separate_rows(gwno_loc, sep = ",") %>%
    mutate(gwno_loc = as.integer(gwno_loc))

filter(ctable, gwid %in% setdiff(civil$gwno_loc, vdem$gwid)) %$%
    paste(country_name, collapse = "; ") %>%
    sprintf("UCDP countries missing from merged: %s", .)

counts.df <- group_by(civil, gwno_loc, year) %>%
    summarise(n_conflicts = n(),
              intensity = max(intensity_level),
              type_of_conflict = max(type_of_conflict))

neighbours.df <- readRDS("data/neighbours.rds") %>%
    inner_join(counts.df, by = c("neighbour_gwid" = "gwno_loc", "year")) %>%
    group_by(gwid, year) %>%
    summarise(n_neighbour_conflicts = sum(n_conflicts),
              neighbour_intensity = max(intensity),
              neighbour_type_conflict = max(type_of_conflict))

full_counts.df <- full_join(counts.df, neighbours.df,
                            by = c("gwno_loc" = "gwid", "year"))

# Episode onsets
episode_ucdp <- group_by(civil, gwno_loc, conflict_id, start_date2) %>%
    summarise(episode_onset = 1,
              year = min(year),
              start_prec2 = ifelse(first(start_prec2) %in% 6:7, 1, 0),
              episode_gwno_a = first(gwno_a),
              episode_intensity = max(intensity_level),
              episode_type = first(type_of_conflict),
              episode_incompatibility = first(incompatibility)) %>%
    ungroup %>%
    arrange(desc(episode_intensity)) %>%
    distinct(gwno_loc, year, .keep_all = T) %>%
    select(-start_date2, -conflict_id)

# Unique conflict onsets
conflict_ucdp <- group_by(civil, gwno_loc, conflict_id) %>%
    summarise(onset = 1,
              year = min(year),
              gwno_a = first(gwno_a),
              onset_intensity = max(intensity_level),
              onset_type = first(type_of_conflict),
              onset_incompatibility = first(incompatibility)) %>%
    ungroup %>%
    arrange(desc(onset_intensity)) %>%
    distinct(gwno_loc, year, .keep_all = T) %>%
    select(-conflict_id)

ucdp <- full_join(episode_ucdp, conflict_ucdp, by = c("gwno_loc", "year"))

merged.df <- left_join(vdem, ucdp, by = c("gwid" = "gwno_loc", "year")) %>%
    left_join(full_counts.df, by = c("gwid" = "gwno_loc", "year")) %>%
    mutate(ongoing = ifelse(is.na(n_conflicts), 0, 1),
           neighbour_conflict = ifelse(is.na(n_neighbour_conflicts), 0, 1),
           onset = ifelse(is.na(onset), 0, 1),
           episode_onset = ifelse(is.na(episode_onset), 0, 1))

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
    group_by(country_name) %>%
    mutate(peace_yrs = calc_peace_yrs(year, ongoing)) %>%
    ungroup

stopifnot(!is.na(merged.df$country_name))

###
# GROWUP - Area, elevation, and ethnic group data
#
# Technically coded at the beginnning of the year versus the end of
# the year in V-Dem...
growup <- fread("./data/raw/growup/data.csv", data.table = F) %>%
    select(gwid = countries_gwid, country_name = countryname, year,
           onset_ko_flag, area_sqkm, meanelev, rlvt_groups_count,
           incidence_flag, peaceyears)

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
