#!/usr/bin/env Rscript

suppressMessages(library(dplyr))
suppressMessages(library(rstan))

source("R/functions.R")

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

load("data/prepped_data.RData")

manifests <- select(constraints.df, one_of(constraint_vars)) %>% data.matrix
manifests_sd <- select(constraints.df, one_of(paste0(constraint_vars, "_sd"))) %>%
    data.matrix

stopifnot(nrow(manifests) == nrow(manifests_sd),
          ncol(manifests) == ncol(manifests_sd))

X <- select(final.df, e_migdpgro, pop_density, meanelev, rlvt_groups_count,
            neighbour_conflict, peace_yrs) %>%
    mutate(e_migdpgro = normalize(e_migdpgro),
           pop_density = log(pop_density) %>% normalize,
           meanelev = log(meanelev) %>% normalize,
           lpeace_yrs = log(peace_yrs + 1) %>% normalize)

data <- list(J = nrow(manifests),
             D = ncol(manifests),
             manifest_obs = manifests,
             manifest_se = manifests_sd,
             N = nrow(X),
             M = ncol(X),
             X = X,
             state_capacity = normalize(final.df$e_migdppcln),
             exec_idx = final.df$reduced_idx,
             n_countries = n_distinct(final.df$country_name),
             n_years = n_distinct(final.df$year),
             #n_peace_yrs = n_distinct(final.df$peace_yrs),
             country_id = to_idx(final.df$country_name),
             year_id = to_idx(final.df$year),
             #peace_yr_id = to_idx(final.df$peace_yrs),
             #peace_yrs = unique(final.df$peace_yrs) %>% sort,
             y = final.df$lepisode_onset)
str(data)
stopifnot(!anyNA(data))

fit <- stan("stan/model.stan", data = data,
            init = list(list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs)),
            pars = c("theta", "gamma", "lambda", "psi", "alpha", "beta",
                     "Z_country", "sigma"),
            control = list(adapt_delta = 0.9, max_treedepth = 12))

saveRDS(fit, "posteriors/fit.rds")
