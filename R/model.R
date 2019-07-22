#!/usr/bin/env Rscript

suppressMessages(library(rstan))

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

load("data/prepped_data.RData")
fit <- stan("stan/model.stan", iter = 1e4, data = data, thin = 2,
            control = list(max_treedepth = 12))

saveRDS(fit, "posteriors/fit.rds")
