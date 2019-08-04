#!/usr/bin/env Rscript

library(caTools)
library(dplyr)
library(lavaan)
library(mgcv)
library(thesis.utils)

load("data/prepped_data.RData")

manifests <- select(final.df, one_of(constraint_vars)) %>% data.matrix

ml <- "exec_constraints =~ v2lginvstp + v2lgfunds + v2lgqstexp + v2lgoppart +
                           v2juhcind + v2juncind + v2juhccomp + v2jucomp +
                           v2exrescon + v2lgotovst"
lfit <- cfa(ml, data = manifests, meanstructure = T, std.lv = T)
summary(lfit, standardized = T, ci = T)

final.df$exec_constraints <- lavPredict(lfit)[, 1]

input.df <- select(final.df, lepisode_onset, country_name, year,
                   exec_constraints, cgdppc, gdpgro,
                   pop_density, meanelev, rlvt_groups_count,
                   neighbour_conflict, peace_yrs, ongoing) %>%
    mutate(pop_density = log(pop_density) %>% normalize,
           exec_constraints = normalize(exec_constraints),
           cgdppc = log(cgdppc) %>% normalize,
           gdpgro = normalize(gdpgro),
           meanelev = normalize(meanelev),
           country_name = as.factor(country_name),
           lpeace_yrs = log(peace_yrs + 1),
           year_fac = as.factor(year))

info(input.df)
ml <- gam(lepisode_onset ~ exec_constraints * cgdppc + gdpgro +
              pop_density + meanelev + rlvt_groups_count +
              neighbour_conflict + lpeace_yrs + s(country_name, bs = "re") +
              s(year_fac, bs = "re"),
          data = input.df, family = "binomial")

print("Model finished!")
saveRDS(ml, "data/gam_model.rds")
