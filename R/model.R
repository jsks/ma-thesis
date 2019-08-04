#!/usr/bin/env Rscript

suppressMessages(library(dplyr))
suppressMessages(library(rstan))
suppressMessages(library(thesis.utils))

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

load("data/prepped_data.RData")

manifests <- select(constraints.df, one_of(constraint_vars)) %>%
    data.matrix

manifests_sd <- select(constraints.df, one_of(paste0(constraint_vars, "_sd"))) %>%
    data.matrix

for (i in 1:ncol(manifests)) {
    manifests_sd[, i] <- manifests_sd[, i] / sd(manifests[, i])
    manifests[, i] <- normalize(manifests[, i])
}

stopifnot(nrow(manifests) == nrow(manifests_sd),
          ncol(manifests) == ncol(manifests_sd))

X <- select(final.df, gdpgro, pop_density, meanelev, rlvt_groups_count,
            neighbour_conflict, peace_yrs) %>%
    mutate(gdpgro = normalize(gdpgro),
           pop_density = log(pop_density) %>% normalize,
           meanelev = log(meanelev) %>% normalize,
           lpeace_yrs = log(peace_yrs + 1) %>% normalize) %>%
    select(-peace_yrs) %>%
    data.matrix

data <- list(J = nrow(manifests),
             D = ncol(manifests),
             manifest_obs = manifests,
             manifest_se = manifests_sd,
             N = nrow(X),
             M = ncol(X),
             X = X,
             state_capacity = log(final.df$cgdppc) %>% normalize,
             exec_idx = final.df$reduced_idx,
             n_countries = n_distinct(final.df$country_name),
             n_years = n_distinct(final.df$year),
             country_id = to_idx(final.df$country_name),
             year_id = to_idx(final.df$year),
             y = final.df$lepisode_onset)
str(data)
stopifnot(!anyNA(data))

fit <- stan("stan/model.stan", data = data,
            init = list(list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs)),
            include = F, pars = c("manifest_raw", "manifest_est", "psi_unif",
                                  "sigma_unif", "raw_country", "raw_year", "nu",
                                  "eta", "theta_state_capacity"))

saveRDS(fit, "posteriors/fit.rds")
