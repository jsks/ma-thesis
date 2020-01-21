#!/usr/bin/env Rscript

library(dplyr)
library(data.table)
library(magrittr)
library(thesis.utils)

fit <- read_post("posteriors/sim/combined_posteriors.csv.gz")
true_values <- readRDS("posteriors/sim/simulated_parameters.rds")

###
# Posterior predicted probabilities
p_hat <- extract(fit, pars = "p_hat")

###
# Model parameters
print("Summarizing model parameters")
post <- post_summarise(fit, c("lambda", "psi", "gamma", "delta",
                              "eta", "alpha", "beta", "sigma")) %>%
    rename(codelow = `2.5%`, median = `50%`, codehigh = `97.5%`) %>%
    mutate(type = "Posterior Estimate")

pars.df <- filter(true_values, !grepl("theta", parameter)) %>%
    bind_rows(post) %>%
    mutate(type = as.factor(type))

###
# Latent factor
print("Summarizing theta")
latent.df <- post_summarise(fit, pars = "theta") %>%
    rename(codelow = `2.5%`, median = `50%`, codehigh = `97.5%`)

latent.df$true_value <- filter(true_values, grepl("theta", parameter)) %$% point

save(p_hat, pars.df, latent.df, file = "posteriors/sim/simulated_summary.RData")
