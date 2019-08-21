#!/usr/bin/env Rscript
#
# Model script
###

suppressMessages(library(dplyr))
suppressMessages(library(rstan))
suppressMessages(library(thesis.utils))

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

dir.create("posteriors/summary", recursive = T, showWarnings = F)

load("data/prepped_data.RData")

###
# Manifest vars for exec_constraints
lg_vars <- grep("^v2lg", constraint_vars, value = T)
nonlg_vars <- grep("^v2[^l]", constraint_vars, value = T)

prep <- function(df, vars) {
    m <- select(df, matches(paste0(vars, collapse = "|"))) %>%
        data.matrix

    obs <- m[, vars]
    se <- m[, paste0(vars, "_sd")]

    for (i in 1:ncol(obs)) {
        se[, i] <- se[, i] / sd(obs[, i])
        obs[, i] <- normalize(obs[, i])
    }

    list(obs = obs, se = se)
}

lg_present <- constraints.df$v2lgbicam == 1

nonlg_mm <- prep(constraints.df, nonlg_vars)
lg_mm <- filter(constraints.df, v2lgbicam == 1) %>%
    prep(lg_vars)

stopifnot(nrow(nonlg_mm$obs) == nrow(nonlg_mm$se),
          ncol(nonlg_mm$obs) == ncol(nonlg_mm$se))
stopifnot(nrow(lg_mm$obs) == nrow(lg_mm$se),
          ncol(lg_mm$obs) == ncol(lg_mm$se))

###
# Control variables
X <- select(final.df, gdpgro, pop_density, meanelev, rlvt_groups_count,
            neighbour_conflict, peace_yrs) %>%
    mutate(gdpgro = normalize(gdpgro),
           pop_density = log(pop_density) %>% normalize,
           meanelev = log(meanelev) %>% normalize,
           peace_yrs = log(peace_yrs + 1) %>% normalize) %>%
    data.matrix

###
# Final stan input list
data <- list(
    # Latent Factor Model
    J = nrow(constraints.df),
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
    lgbicam = constraints.df$v2lgbicam,

    # Onset regression
    N = nrow(X),
    M = ncol(X),
    X = X,
    state_capacity = log(final.df$cgdppc) %>% normalize,
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
fit <- stan("stan/model.stan", data = data, seed = 101010,
            init = rep(list(init), 4), include = F,
            control = list(max_treedepth = 15),
            pars = c("psi_unif", "sigma_unif", "lg_est", "nonlg_est",
                     "lg_missing", "nu", "raw_country", "raw_year",
                     "eta", "theta_state_capacity"))

print(fit, pars = c("lambda", "psi", "beta"))

# Check model diagnostics. Would be great if we could simply do an
# assertion with check_hmc_diagnostics...
n_divergent <- get_num_divergent(fit)
n_max_treedepth <- get_num_max_treedepth(fit)
n_bfmi <- get_low_bfmi_chains(fit) %>% length
rhat_prop <- mean(summary(fit)$summary[, "Rhat"] < 1.01)

if (n_divergent > 0 | n_max_treedepth > 0 | n_bfmi > 0 | rhat_prop < .99) {
    print("fail :(")
    saveRDS(fit, "posteriors/fit_err.rds")
} else {
    print("Model finished!")
    saveRDS(fit, "posteriors/fit.rds")
}

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
