#!/usr/bin/env Rscript

library(caTools)
library(dplyr)
library(lavaan)
library(mgcv)

source("R/functions.R")

load("data/prepped_data.RData")

manifests <- select(final.df, one_of(constraint_vars)) %>% data.matrix

ml <- "exec_constraints =~ v2lginvstp + v2lgfunds + v2lgqstexp + v2lgoppart +
                           v2juhcind + v2juncind + v2juhccomp + v2jucomp +
                           v2exrescon + v2lgotovst"
lfit <- cfa(ml, data = manifests, meanstructure = T, std.lv = T)
summary(lfit, standardized = T, ci = T)

final.df$exec_constraints <- lavPredict(lfit)[, 1]

input.df <- select(final.df, lepisode_onset, country_name, year,
                   exec_constraints, e_migdppcln, e_migdpgro,
                   meanelev, area_sqkm, un_pop, rlvt_groups_count,
                   neighbour_conflict, peace_yrs, ongoing) %>%
    mutate(pop_density = log(1000 * un_pop / area_sqkm) %>% normalize,
           exec_constraints = normalize(exec_constraints),
           e_migdppcln = normalize(e_migdppcln),
           e_migdpgro = normalize(e_migdpgro),
           meanelev = normalize(meanelev),
           country_name = as.factor(country_name),
           lpeace_yrs = log(peace_yrs + 1),
           peace_yrs = normalize(peace_yrs),
           year_fac = as.factor(year),
           year = normalize(year)) %>%
    na.omit

info(input.df)
ml <- gam(lepisode_onset ~ exec_constraints * e_migdppcln + e_migdpgro +
              pop_density + meanelev + rlvt_groups_count +
              neighbour_conflict + s(country_name, bs = "re") +
              s(year_fac, bs = "re") + s(peace_yrs, bs = "gp"),
          data = input.df, family = "binomial")

saveRDS(ml, "data/gam_model.rds")
