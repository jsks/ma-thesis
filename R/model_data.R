#!/usr/bin/env Rscript
#
# Model script
###

library(docopt)
library(dplyr)
library(jsonlite)
library(thesis.utils)

doc <- "usage: ./model_data.R <schema>"
args <- docopt(doc)

stopifnot(file.exists(args$schema))

load("data/prepped_data.RData")
schema <- read_json(args$schema, simplifyVector = T)

final.df %<>%
    select(schema$outcome, country_name, year, reduced_idx,
           one_of(schema$predictors)) %>%
    na.omit
dbg_info(final.df)

###
# Control variables
X <- final.df %>%
    select(-country_name, -year, -matches("onset"), -reduced_idx) %>%
    mutate_if(Negate(is.ordinal), normalize) %>%
    data.matrix

if (schema$interaction != "") {
    interaction_idx <- which(colnames(X) == schema$interaction)
    stopifnot(length(interaction_idx) == 1)
} else {
    interaction_idx <- 0
}

file.path("posteriors", schema$name, "input.RData") %>%
    save.image

###
# Final stan input list
data <- list(
    # Latent Factor Model
    J = nrow(nonlg_mm$obs),
    J_missing = sum(!lgbicam == 1),
    J_obs = sum(lgbicam == 1),
    missing_idx = which(!lgbicam == 1),
    obs_idx = which(lgbicam == 1),
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
    interaction_idx = interaction_idx,
    exec_idx = final.df$reduced_idx,
    n_countries = n_distinct(final.df$country_name),
    n_years = n_distinct(final.df$year),
    country_id = to_idx(final.df$country_name),
    year_id = to_idx(final.df$year),
    y = final.df[[schema$outcome]]
)

str(data)
stopifnot(!sapply(data, anyNA))

file.path("posteriors", schema$name, "data.json") %>%
    write_json(data, ., auto_unbox = T)
