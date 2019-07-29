#!/usr/bin/env Rscript

suppressMessages(library(rstan))

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

load("data/prepped_data.RData")
fit <- stan("stan/model.stan", data = data,
            init = list(list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs),
                        list(manifest_est = data$manifest_obs)),
            pars = c("theta", "gamma", "lambda", "psi", "alpha", "beta",
                     "Z_country", "sigma"),
            control = list(adapt_delta = 0.9, max_treedepth = 12))

saveRDS(fit, "posteriors/fit.rds")
