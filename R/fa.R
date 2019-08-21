#!/usr/bin/env Rscript

suppressMessages(library(dplyr))
suppressMessages(library(rstan))
suppressMessages(library(thesis.utils))

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

load("data/prepped_data.RData")

lg_vars <- c("v2lginvstp", "v2lgfunds", "v2lgqstexp", "v2lgoppart", "v2lgotovst")
nonlg_vars <- c("v2juhcind", "v2juncind", "v2juhccomp", "v2jucomp",
                "v2exrescon")

lg_obs <- filter(constraints.df, v2lgbicam == 1) %>%
    select(one_of(lg_vars)) %>%
    data.matrix

lg_se <- filter(constraints.df, v2lgbicam == 1) %>%
    select(one_of(paste0(lg_vars, "_sd"))) %>%
    data.matrix

#for (i in 1:ncol(lg_obs)) {
#    lg_se[, i]  <- lg_se[, i] / sd(lg_obs[, i])
#    lg_obs[, i]  <- normalize(lg_obs[, i])
#}


nonlg_obs <- select(constraints.df, one_of(nonlg_vars)) %>%
    data.matrix

nonlg_se <- select(constraints.df, one_of(paste0(nonlg_vars, "_sd"))) %>%
    data.matrix

#for (i in 1:ncol(nonlg_obs)) {
#    nonlg_se[, i]  <- nonlg_se[, i] / sd(nonlg_obs[, i])
#    nonlg_obs[, i]  <- normalize(nonlg_obs[, i])
#}

lg_present <- constraints.df$v2lgbicam == 1

data <- list(N = nrow(constraints.df),
             lg_D = ncol(lg_obs),
             nonlg_D = ncol(nonlg_obs),
             lg = lg_obs,
             lg_se = lg_se,
             nonlg = nonlg_obs,
             nonlg_se = nonlg_se,
             lgotovst_idx = which(colnames(lg_obs) == "v2lgotovst"),
             lgbicam = constraints.df$v2lgbicam,
             N_missing = sum(!lg_present),
             N_obs = sum(lg_present),
             missing_idx = which(!lg_present),
             obs_idx = which(lg_present))

str(data)

init <- list(lg_est = data$lg, nonlg_est = data$nonlg)

fit <- stan("stan/factor.stan", data = data, init = rep(list(init), 4),
            include = F, pars = c("eta", "lg_est", "lg_est_scaled",
                                  "nonlg_est", "nonlg_est_scaled"))
saveRDS(fit, "posteriors/fa.rds")

print(fit, pars = c("lambda", "psi", "alpha", "beta"))
