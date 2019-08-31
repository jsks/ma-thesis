#!/usr/bin/env Rscript
#
# Model script
###

suppressMessages(library(dplyr))
suppressMessages(library(rstan))
suppressMessages(library(thesis.utils))

options(warn = 2)
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

dir.create("posteriors/summary", recursive = T, showWarnings = F)
load("data/prepped_data.RData")

###
# Control variables
X <- select(final.df, gdpgro, pop_density, meanelev, rlvt_groups_count,
            neighbour_conflict, peace_yrs) %>%
    na.omit %>%
    data.matrix

lg_present <- lgbicam == 1

###
# Final stan input list
data <- list(
    # Latent Factor Model
    J = nrow(nonlg_mm$obs),
    J_missing = sum(!lg_present),
    J_obs = sum(lg_present),
    missing_idx = which(!lg_present),
    obs_idx = which(lg_present),
    lg_D = ncol(lg_mm[[1]]),
    nonlg_D = ncol(nonlg_mm[[1]]),
    lg = lg_mm$obs,
    lg_se = lg_mm$se,
    nonlg = nonlg_mm$obs,
    nonlg_se = nonlg_mm$se,
    lgotovst_idx = which(colnames(lg_mm$obs) == "v2lgotovst"),
    lgbicam = lgbicam,

    # Onset regression
    N = nrow(X),
    M = ncol(X),
    X = X,
    state_capacity = final.df$cgdppc,
    exec_idx = final.df$reduced_idx,
    n_countries = n_distinct(final.df$country_name),
    n_years = n_distinct(final.df$year),
    country_id = to_idx(final.df$country_name),
    year_id = to_idx(final.df$year),
    y = final.df$lepisode_onset
)

str(data)
stopifnot(!sapply(data, anyNA))

init <- list(lg_est = data$lg, nonlg_est = data$nonlg)
tryCatch({
    fit <- stan("stan/model.stan", data = data, seed = 101010,
                iter = 4000, thin = 2, control = list(max_treedepth = 12),
                init = rep(list(init), 4), include = F,
                pars = c("psi_unif", "sigma_unif", "lg_est", "nonlg_est",
                         "lg_missing", "nu", "raw_country", "raw_year",
                         "eta", "theta_state_capacity"))
}, warning = function(w) {
    saveRDS(fit, "posteriors/fit_err.rds")
    stop(w)
})

print(fit, pars = c("gamma", "lambda", "psi", "alpha", "delta"))
saveRDS(fit, "posteriors/fit.rds")

###
# Summarise model output. Start with coefficients and variance
# parameters from factor model.
post_summarise(fit, pars = c("lambda", "psi", "alpha", "delta")) %>%
    saveRDS("posteriors/summary/fa_coef.rds")

# Exec constraint estimates
post_summarise(fit, pars = "theta") %>%
    mutate(country_name = constraints.df$country_name,
           year = constraints.df$year) %>%
    saveRDS("posteriors/summary/theta.rds")

post_summarise(fit, pars = "p_hat") %>%
    mutate(country_name = final.df$country_name,
           year = final.df$year) %>%
    saveRDS("posteriors/summary/predicted_probs.rds")

# Conflict regression coefficients, keep these standardized
coefficient_names <- c("exec_constraints", "state_capacity",
                       "exec*state", colnames(X))
beta <- post_summarise(fit, pars = "beta", names = coefficient_names)

saveRDS(beta, "posteriors/summary/beta.rds")
