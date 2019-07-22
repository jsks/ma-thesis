#!/usr/bin/env Rscript

suppressMessages(library(dplyr))
suppressMessages(library(magrittr))

###
# V-Dem - Democracy data
vdem <- readRDS("data/datasets/V-Dem-CY-Full+Others-v9.rds") %>%
    select(-matches("_osp|_ord|_mean|_nr")) %>%
    filter(year >= 1946)

###
# UCDP - Armed Conflict
load("data/datasets/ucdp-prio-acd-181")

# conflict_id = 418 is the United States vs. Al Qaeda starting in 2001
acd %<>% filter(type_of_conflict %in% 3:4, conflict_id != 418) %>%
    mutate(gwno_a = as.integer(gwno_a))

# V-Dem COWcode and UCDP gwno are mostly the same except Yemen
# following reunification and Oman prior to 1960 in V-Dem. We'll also
# lose Cameroon 1960 since V-Dem doesn't code before 1961 and
# Hyderabad as V-Dem only codes India.
acd %<>% mutate(gwno_a = ifelse(gwno_a == 678 & year >= 1990, 679, gwno_a))
vdem %<>% mutate(COWcode = ifelse(country_name == "Oman", 698, COWcode))

counts.df <- group_by(acd, gwno_a, year) %>%
    summarise(conflicts = n(), intensity = max(intensity_level))

# Episode level
episode_ucdp <- group_by(acd, location, conflict_id, start_date2) %>%
    summarise(episode_onset = 1,
              year = min(year),
              start_prec2 = ifelse(first(start_prec2) %in% 6:7, 1, 0),
              gwno_a = first(gwno_a),
              episode_intensity = first(intensity_level),
              episode_type = first(type_of_conflict),
              episode_incompatibility = first(incompatibility)) %>%
    ungroup %>%
    arrange(desc(episode_intensity)) %>%
    distinct(location, year, .keep_all = T) %>%
    select(-start_date2, -conflict_id)

conflict_ucdp <- group_by(acd, location, conflict_id) %>%
    summarise(onset = 1,
              year = min(year),
              gwno_a = first(gwno_a),
              onset_intensity = first(intensity_level),
              onset_type = first(type_of_conflict),
              onset_incompatibility = first(incompatibility)) %>%
    ungroup %>%
    arrange(desc(onset_intensity)) %>%
    distinct(location, year, .keep_all = T) %>%
    select(-conflict_id)

ucdp <- full_join(episode_ucdp, conflict_ucdp,
                  by = c("location", "gwno_a", "year"))

full.df <- left_join(vdem, ucdp, by = c("COWcode" = "gwno_a", "year")) %>%
    left_join(counts.df, by = c("COWcode" = "gwno_a", "year")) %>%
    arrange(country_name, year) %>%
    group_by(country_name) %>%
    mutate(conflicts = ifelse(is.na(conflicts), 0, conflicts),
           onset = ifelse(is.na(onset), 0, 1),
           episode_onset = ifelse(is.na(episode_onset), 0, 1),
           lonset = lead(onset),
           lepisode_onset = lead(episode_onset),
           indep_yrs = pmax(year - first(year[v2svindep == 1]), 0)) %>%
    ungroup

stopifnot(!is.na(full.df$country_name))

sprintf("Fully merged: %d conflicts, %d countries, %s total country-years",
        sum(full.df$lonset, na.rm = T),
        length(unique(full.df$country_name)),
        prettyNum(nrow(full.df), big.mark = ","))

saveRDS(full.df, "data/merged_data.rds")
