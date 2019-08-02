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

source("R/functions.R")

###
# V-Dem - Democracy data
#
# Recorded gaps in V-Dem DS are super annoying to deal with. Since
# contemporary countries have no more than one, unify everything into
# a single gapstart/gapend to make things easier when we later
# calculate peace years.
vdem <- readRDS("data/raw/V-Dem-CY-Full+Others-v9.rds") %>%
    select(-matches("_osp|_ord|_mean|_nr|_\\d*$")) %>%
    filter(year >= 1946) %>%
    group_by(country_id) %>%
    mutate(gapstart = ifelse(is.na(gapstart1) & is.na(gapstart2) & is.na(gapstart3),
                             NA,
                             max(gapstart1, gapstart2, gapstart3, na.rm = T)),
           gapend = ifelse(is.na(gapend1) & is.na(gapend2) & is.na(gapend3),
                           NA,
                           max(gapend1, gapend2, gapend3, na.rm = T)))

sprintf("Started with %d countries and %d rows from V-Dem",
        n_distinct(vdem$country_id), nrow(vdem))

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
civil <- filter(acd, type_of_conflict %in% c(1, 3, 4), conflict_id != 418) %>%
    mutate(gwno_loc = as.character(gwno_loc)) %>%
    separate_rows(gwno_loc, sep = ",") %>%
    mutate(gwno_loc = as.integer(gwno_loc))

filter(ctable, gwid %in% setdiff(civil$gwno_loc, vdem$gwid)) %$%
    paste(country_name, collapse = "; ") %>%
    sprintf("UCDP countries missing from merged: %s", .)

# TODO: include interstate conflict?
counts.df <- group_by(civil, gwno_loc, year) %>%
    summarise(n_conflicts = n(), intensity = max(intensity_level))

# Also inherit conflict counts from parent country for newly
# independent countries. We inherit based on the territory location of
# the conflict. This won't affect our `ongoing` variable in the final
# dataset, but it will change our peace_yrs calculation, for example:
# Eritrea, Namibia etc etc, which would otherwise have inflated
# counts.
inherited.df <- civil %>%
    mutate(territory_gwno = ctable$gwid[match(territory_name, ctable$country_name)]) %>%
    filter(!is.na(territory_gwno) & gwno_loc != territory_gwno) %>%
    group_by(territory_gwno, year) %>%
    summarise(n_conflicts = n(), intensity = max(intensity_level)) %>%
    rename(gwno_loc = territory_gwno)

counts.df %<>% bind_rows(inherited.df) %>%
    group_by(gwno_loc, year) %>%
    summarise(n_conflicts = sum(n_conflicts), intensity = max(intensity))

neighbours.df <- readRDS("data/neighbours.rds") %>%
    inner_join(counts.df, by = c("neighbour_gwid" = "gwno_loc", "year")) %>%
    group_by(gwid, year) %>%
    summarise(n_neighbour_conflicts = sum(n_conflicts),
              neighbour_intensity = max(intensity))

full_counts.df <- full_join(counts.df, neighbours.df,
                            by = c("gwno_loc" = "gwid", "year"))

# Episode onsets
episode_ucdp <- group_by(civil, gwno_loc, conflict_id, start_date2) %>%
    summarise(episode_onset = 1,
              year = min(year),
              start_prec2 = ifelse(first(start_prec2) %in% 6:7, 1, 0),
              gwno_a = first(gwno_a),
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
           episode_onset = ifelse(is.na(episode_onset), 0, 1),
           lonset = lead(onset),
           lonset_intensity = lead(onset_intensity),
           lepisode_onset = lead(episode_onset),
           lepisode_intensity = lead(episode_intensity))

# Calculate number of peace years since last ongoing civil conflict or
# V-Dem codingstart/gapend. For countries censored due to start date,
# start counting from the end of WW2. Even for countries not directly
# involved in WW2, it was a significant international event that
# reshaped the world order with domestic consequences for everyone.
#
# Note, peace years are calculated based on V-Dem countries, which
# means that gwid changes are not recorded as changes in the
# fundamental status of a country. This only affects Serbia in 2006
# and Czech Republic in 1993.
#
# This end result is essentially the peaceyears calculated by GROWup,
# with the exception of newly independent countries that inherited the
# conflict counts based on territory location (ex: Eritrea). We'll
# also merge in GROWups peaceyears count which simply starts at zero
# when a country enters that dataset.
merged.df %<>%
    arrange(country_name, year) %>%
    group_by(country_name) %>%
    mutate(first_year = pmax(1945, codingstart_contemp, gapend + 1, na.rm = T),
           peace_yrs = {
        year - year[locf_idx(ongoing)] %>% { ifelse(is.na(.), first_year, .) } - 1
    } %>% pmax(0)) %>%
    ungroup

stopifnot(!is.na(merged.df$country_name))

###
# Restrict our dataset to independent country-years (i.e. where the
# state is sovereign) and between 1950 - 2017, the lower bound set by
# our population data.
#
# We'll also include one year prior to independence so that we can
# also have the start year into our model, thereby accounting for
# conflicts that immediately break out (V-Dem generally codes most
# colonies + former communist states prior to independence).
merged.df %<>% filter(year >= pmax(1950, start_year), year <= end_year)

###
# Population data
pop.df <- read_xlsx("data/raw/WPP2019_POP_F01_1_TOTAL_POPULATION_BOTH_SEXES.xlsx",
                    sheet = 1, skip = 16) %>%
    select(country_name = `Region, subregion, country or area *`,
           code = `Country code`, Type, matches("\\d{4}")) %>%
    gather(year, un_pop, -country_name, -code, -Type) %>%
    filter(Type == "Country") %>%
    mutate(un_pop = as.numeric(un_pop),
           year = as.integer(year))

# Unfortunately, we don't have ISO codes in vdem so manually conform
# the country names
pop.df %<>%
    mutate(country_name =
               case_when(grepl("Bolivia", country_name) ~ "Bolivia",
                         grepl("Hong Kong", country_name) ~ "Hong Kong",
                         grepl("Iran", country_name) ~ "Iran",
                         grepl("Moldova", country_name) ~ "Moldova",
                         grepl("Macedonia", country_name) ~ "Macedonia",
                         grepl("Russia", country_name) ~ "Russia",
                         grepl("Syria", country_name) ~ "Syria",
                         grepl("Taiwan", country_name) ~ "Taiwan",
                         grepl("Tanzania", country_name) ~ "Tanzania",
                         grepl("Venezuela", country_name) ~ "Venezuela",
                         country_name == "Dem. People's Republic of Korea" ~ "North Korea",
                         country_name == "Republic of Korea" ~ "South Korea",
                         country_name == "Cabo Verde" ~ "Cape Verde",
                         country_name == "Côte d'Ivoire" ~ "Ivory Coast",
                         country_name == "Congo" ~ "Republic of the Congo",
                         country_name == "Czechia" ~ "Czech Republic",
                         country_name == "Gambia" ~ "The Gambia",
                         country_name == "Lao People's Democratic Republic" ~ "Laos",
                         country_name == "Myanmar" ~ "Burma/Myanmar",
                         country_name == "Eswatini" ~ "Swaziland",
                         country_name == "Viet Nam" ~ "Vietnam",
                         T ~ country_name))

dropped <- setdiff(merged.df$country_name, pop.df$country_name) %>% unique
sprintf("V-Dem countries missing from UN data: %s",
        paste(dropped, collapse = "; "))

merged.df %<>% filter(!country_name %in% dropped) %>%
    left_join(pop.df, by = c("country_name", "year"))

stopifnot(!anyNA(merged.df$un_pop))

sprintf("After merging UN population data, %d countries and %d rows",
        n_distinct(merged.df$country_id), nrow(merged.df))

###
# Area & elevation data grom GROWup, technically coded at the
# beginning of the year versus the end of the year in V-Dem.
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
    mutate(pop_density = 1000 * un_pop / area_sqkm)

stopifnot(!anyNA(merged.df$area_sqkm))

sprintf("After merging GROWup, %d countries and %d rows",
        n_distinct(merged.df$country_id), nrow(merged.df))

###
# Save, save, save!
saveRDS(merged.df, "data/merged_data.rds")

sprintf("Final: %d conflicts, %d episodes, %d countries, %s country-years",
        sum(merged.df$lonset, na.rm = T),
        sum(merged.df$lepisode_onset, na.rm = T),
        n_distinct(merged.df$country_name),
        prettyNum(nrow(merged.df), big.mark = ","))
