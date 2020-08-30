#!/usr/bin/env Rscript

library(dplyr)
library(magrittr)
library(thesis.utils)

print("Prepping model data")
merged.df <- readRDS("data/merged_data.rds")

# Manifest variables for exec_constraints
constraint_vars <- c("v2lginvstp", "v2lgfunds", "v2lgqstexp",
                     "v2lgoppart", "v2juhcind", "v2juncind",
                     "v2juhccomp", "v2jucomp", "v2exrescon")

###
# Start by first replacing NA with Inf for v2lg* variables where
# v2lgbicam is 0 (ie the legislature is missing/suspended). We want to
# keep these obs and only drop them if one of the other manifest vars
# is missing since we want an estimate for exec constraints even when
# there's no legislature.
lg_vars <- grep("^v2lg", constraint_vars, value = T)

for (v2 in lg_vars) {
    merged.df[[v2]] <- ifelse(merged.df$v2lgbicam == 0,
                              Inf,
                              merged.df[[v2]])

    merged.df[[paste0(v2, "_sd")]] <- ifelse(merged.df$v2lgbicam == 0,
                                             Inf,
                                             merged.df[[paste0(v2, "_sd")]])
}

###
# Final dataset for model. Start by dropping country-years where we
# have missingness in our manifest variables NOT caused by lack of
# legislature (v2lgbicam) and log transforming key predictors.
final.df <- merged.df %>%
    filter_at(constraint_vars, all_vars(!is.na(.))) %>%
    arrange(country_name, year) %>%
    mutate(rgdpepc = log(rgdpepc),
           pop_density = log(pop_density),
           meanelev = log(meanelev),
           reduced_idx =
               do.call(paste, lapply(c("country_name", constraint_vars), as.symbol)) %>%
                   collapse_changes)

# Rather than lag each predictor, take the lead of the outcome and
# peace years.
final.df %<>%
    group_by(country_name, idx = consecutive(year)) %>%
    mutate(lepisode_onset = lead(episode_onset),
           lmajor_onset = lead(major_onset),
           lcum_onset = lead(cum_onset),
           lpeace_yrs = lead(peace_yrs)) %>%
    ungroup %>%
    select(-idx)

dbg_info(final.df)

###
# Create separate dataset of manifest variables and collapse changes
# so that we save time by only estimating the unique combinations.
constraints.df <- select(final.df, country_name, year, reduced_idx,
                         v2lgbicam, one_of(constraint_vars),
                         one_of(paste0(constraint_vars, "_sd"))) %>%
    group_by(country_name, reduced_idx) %>%
    filter(year == min(year)) %>%
    mutate(v2lgbicam = ifelse(v2lgbicam > 0, 1, 0)) %>%
    ungroup

prep_manifest <- function(df, vars) {
    m <- select(df, matches(paste0(vars, collapse = "|"))) %>%
        data.matrix

    obs <- m[, vars]
    se <- m[, paste0(vars, "_sd")]

    for (i in 1:ncol(obs)) {
        se[, i] <- se[, i] / sd(obs[, i])
        obs[, i] <- normalize(obs[, i])
    }

    list(obs = obs, se = se)
}

# Split b/w legislative and non-legislative vars to account for the
# different patterns of missingness from v2lgbicam
lg_vars <- grep("^v2lg", constraint_vars, value = T)
nonlg_vars <- grep("^v2[^l]", constraint_vars, value = T)

lg_mm <- filter(constraints.df, v2lgbicam == 1) %>% prep_manifest(lg_vars)
nonlg_mm <- prep_manifest(constraints.df, nonlg_vars)

stopifnot(nrow(nonlg_mm$obs) == nrow(nonlg_mm$se),
          ncol(nonlg_mm$obs) == ncol(nonlg_mm$se))
stopifnot(nrow(lg_mm$obs) == nrow(lg_mm$se),
          ncol(lg_mm$obs) == ncol(lg_mm$se))

lgbicam <- constraints.df$v2lgbicam
save(final.df, lg_mm, nonlg_mm, lgbicam, file = "data/prepped_data.RData")
