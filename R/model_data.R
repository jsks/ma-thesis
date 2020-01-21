#!/usr/bin/env Rscript
#
# Model script
###

suppressMessages(library(dplyr))
suppressMessages(library(jsonlite))
suppressMessages(library(thesis.utils))


load("data/prepped_data.RData")

final.df %<>%
    select(country_name, year, lepisode_onset, peace_yrs, reduced_idx,
           rgdpepc, rgdpepc_gro, pop_density, meanelev, rlvt_groups_count,
           neighbour_conflict, peace_yrs, ongoing) %>%
    na.omit
dbg_info(final.df)

saveRDS(final.df, "posteriors/model/final.rds")

###
# Control variables
X <- final.df %>%
    select(-country_name, -year, -lepisode_onset, -reduced_idx) %>%
    data.matrix

lg_present <- lgbicam == 1
print(colnames(lg_mm$obs))

###
# Final stan input list
data <- list(
    # Latent Factor Model
    J = nrow(nonlg_mm$obs),
    J_missing = sum(!lg_present),
    J_obs = sum(lg_present),
    missing_idx = which(!lg_present),
    obs_idx = which(lg_present),
    lg_D = ncol(lg_mm[[1]]),
    nonlg_D = ncol(nonlg_mm[[1]]),
    lg = lg_mm$obs,
    lg_se = lg_mm$se,
    nonlg = nonlg_mm$obs,
    nonlg_se = nonlg_mm$se,
    lgotovst_idx = which(colnames(lg_mm$obs) == "v2lgotovst"),
    lgbicam = lgbicam,

    # Onset regression
    N = nrow(X),
    M = ncol(X),
    X = X,
    interaction_idx = which(colnames(X) == "rgdpepc"),
    exec_idx = final.df$reduced_idx,
    n_countries = n_distinct(final.df$country_name),
    n_years = n_distinct(final.df$year),
    country_id = to_idx(final.df$country_name),
    year_id = to_idx(final.df$year),
    y = final.df$lepisode_onset
)

str(data)
stopifnot(!sapply(data, anyNA))

write_json(data, "posteriors/model/data.json", auto_unbox = T)
