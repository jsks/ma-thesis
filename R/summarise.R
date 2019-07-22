#!/usr/bin/env Rscript

library(dplyr)
library(ggplot2)
library(rstan)

env <- readRDS("data/prepped_data.rds")
fit <- readRDS("posteriors/fit.rds")

check_hmc_diagnostics(fit)

theta <- as.matrix(fit, pars = "theta") %>%
    apply(2, quantile, probs = c(0.25, 0.5, 0.75)) %>%
    t %>%
    as.data.frame %>%
    rename(theta_codelow = `25%`,
           theta = `50%`,
           theta_codehigh = `75%`) %>%
    mutate(country_name = env$country_year$country_name,
           year = env$country_year$year)

saveRDS(theta, "data/summarised_post.rds")
