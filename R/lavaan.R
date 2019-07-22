#!/usr/bin/env Rscript

library(dplyr)
library(lavaan)

load("data/prepped_data.RData")

ml <- "lg_constraints =~ v2lgfunds + v2lginvstp + v2gqstexp"
fit <- cfa(ml, data = data$X_obs, std.lv = T)
summary(fit, standardized = T)

theta <- lavPredict(fit)

final.df$theta <- lavPredict(fit)

filter(final.df, country_name %in% c("Syria", "India", "Sweden", "Russia")) %>%
    ggplot(aes(year, theta, col = country_name)) +
    geom_point() +
    geom_line()
