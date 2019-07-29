#!/usr/bin/env Rscript

library(caTools)
library(dplyr)
library(lavaan)
library(mgcv)

source("R/functions.R")

load("data/prepped_data.RData")

ml <- "exec_constraints =~ v2lginvstp + v2lgfunds + v2lgqstexp + v2lgoppart +
                           v2juhcind + v2juncind + v2juhccomp + v2jucomp +
                           v2exrescon + v2lgotovst"
lfit <- cfa(ml, data = data$X_obs, meanstructure = T, std.lv = T)
summary(lfit, standardized = T, ci = T)

lavPredict(lfit) %>% saveRDS("data/lavaan_predict.rds")
final.df$exec_constraints <- lavPredict(lfit)[, 1]

input.df <- select(final.df, lepisode_onset, lonset,
                   country_name, year,
                   exec_constraints, e_migdppcln, pop_area, v2svindep,
                   meanelev, area_sqkm, un_pop, ongoing, peace_yrs) %>%
    filter(v2svindep == 1) %>%
    mutate(pop_area = scale(pop_area) %>% as.vector,
           un_pop = log(un_pop) %>% scale %>% as.vector,
           area_sqkm = log(area_sqkm) %>% scale %>% as.vector,
           exec_constraints = scale(exec_constraints) %>% as.vector,
           e_migdppcln = scale(e_migdppcln) %>% as.vector,
           meanelev = log(meanelev) %>% scale %>% as.vector,
           country_name = as.factor(country_name),
           year = as.factor(year)) %>%
    na.omit

ml <- gam(lepisode_onset ~ exec_constraints * e_migdppcln +
              un_pop + area_sqkm + meanelev + s(country_name, bs = "re") +
              s(year, bs = "re") + s(peace_yrs, bs = "gp"),
          data = input.df, family = "binomial")

saveRDS(ml, "data/gam_model.rds")
