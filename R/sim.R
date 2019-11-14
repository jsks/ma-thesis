#!/usr/bin/env Rscript

library(boot)
library(dplyr)
library(extraDistr)
library(ggplot2)
library(MASS)
library(rstan)
library(thesis.utils)

options(mc.cores = parallel::detectCores())
rstan_options(auto_write = T)

set.seed(6666)

N <- 500
D <- 6

# Start with latent model
theta <- rnorm(N)

gamma <- rnorm(D, 0, 5)
lambda <- rlnorm(D, 0, 0.5)
psi <- rweibull(D, 5, 1)

# Legislative variables
eta <- rnorm(1)
delta <- rlnorm(1, 0, 0.5)

xi <- eta + delta * theta

w <- rbinom(N, 1, inv.logit(xi))
stopifnot(any(w == 1))

N_obs <- sum(w)
obs_idx <- which(w == 1)

lg <- theta[obs_idx] %*% t(lambda[1:3]) + mvrnorm(N_obs, rep(0, 3), diag(psi[1:3]))
lg <- sweep(lg, 2, gamma[1:3], `+`)

lg_err <- matrix(rgamma(N_obs * ncol(lg), 5, 5), N_obs, ncol(lg))
lg_obs <- matrix(NA, N_obs, ncol(lg))
for (i in 1:ncol(lg))
    lg_obs[, i] <- lg[, i] + rnorm(N_obs, 0, lg_err[, i])

# Non-legislative variables
nonlg <- theta %*% t(lambda[4:6]) + mvrnorm(N, rep(0, 3), diag(psi[4:6]))
nonlg <- sweep(nonlg, 2, gamma[4:6], `+`)

nonlg_err <- matrix(rgamma(N * ncol(nonlg), 5, 5), N, ncol(nonlg))
nonlg_obs <- matrix(NA, N, ncol(nonlg))
for (i in 1:ncol(nonlg))
    nonlg_obs[, i] <- nonlg[, i] + rnorm(N, 0, nonlg_err[, i])

# Conflict regression
alpha <- rnorm(1, 0, 5)
beta <- rnorm(4, 0, 2.5)

x <- rnorm(N, 0, 2)
state_capacity <- rnorm(N, 0, 3)

n_years <- 50
n_countries <- 10

sigma <- rhcauchy(2, 1)
countries <- rnorm(n_countries, 0, sigma[1])
years <- rnorm(n_years, 0, sigma[2])

cy <- expand.grid(1:n_countries, 1:n_years)
cy <- cy[sample(nrow(cy)), ]

stopifnot(nrow(cy) == N)

country_idx <- cy[, 1]
year_idx <- cy[, 2]

p <- inv.logit(alpha + beta[1] * theta + beta[2] * state_capacity +
               beta[3] * theta * state_capacity + beta[4] * x +
               years[year_idx] + countries[country_idx])

y <- rbinom(N, 1, p)
sprintf("%d simulated conflicts out of %d country-years", sum(y), N)

###
# Fit full stan model
data <- list(J = N,
             J_obs = sum(w),
             J_missing = sum(w == 0),
             obs_idx = which(w == 1),
             missing_idx = which(w == 0),
             lg_D = ncol(lg_obs),
             nonlg_D = ncol(nonlg_obs),
             lg = lg_obs,
             lg_se = lg_err,
             nonlg = nonlg_obs,
             nonlg_se = nonlg_err,
             lgotovst_idx = 0,
             lgbicam = w,
             N = N,
             M = 1,
             X = as.matrix(x),
             state_capacity = state_capacity,
             exec_idx = 1:N,
             n_countries = n_countries,
             n_years = n_years,
             country_id = country_idx,
             year_id = year_idx,
             y = y)
str(data)

fit <- stan("stan/model.stan", data = data, iter = 4000, thin = 2,
            control = list(adapt_delta = 0.95), seed = 1992, include = F,
            pars = c("psi_unif", "sigma_unif", "lg_est", "nonlg_est",
                     "raw_country", "raw_year", "nu", "theta_state_capacity"))

save.image("posteriors/simulated.RData")

print(fit, pars = c("lambda", "psi", "gamma", "delta", "alpha", "beta", "sigma"))

###
# Plot estimated quantiles vs true values
post <- as.matrix(fit, pars = c("lambda", "psi", "gamma", "delta", "eta",
                                "alpha", "beta", "sigma")) %>%
    apply(2, quantile, probs = c(0.025, 0.975)) %>%
    t %>%
    as.data.frame %>%
    rename(codelow = `2.5%`, codehigh = `97.5%`) %>%
    mutate(parameter = rownames(.),
           type = "Posterior Est")

true_values <- data.frame(parameter = c(sprintf("lambda[%d]", seq_along(lambda)),
                                        sprintf("psi[%d]", seq_along(psi)),
                                        sprintf("gamma[%d]", seq_along(gamma)),
                                        "delta",
                                        "eta",
                                        "alpha",
                                        sprintf("beta[%d]", seq_along(beta)),
                                        sprintf("sigma[%d]", seq_along(sigma))),
                          point = c(lambda, psi, gamma, delta, eta, alpha, beta, sigma),
                          type = "True Values",
                          stringsAsFactors = F)

full.df <- bind_rows(post, true_values) %>%
    mutate(type = as.factor(type))

ggplot(full.df, aes(parameter, point, color = type)) +
    geom_point() +
    geom_errorbar(aes(parameter, ymin = codelow, ymax = codehigh),
                  width = 0)

###
# Plot latent factor
latent <- as.matrix(fit, pars = "theta") %>%
    apply(2, quantile, probs = c(0.025, 0.5, 0.975)) %>%
    t %>%
    as.data.frame %>%
    rename(codelow = `2.5%`, median = `50%`, codehigh = `97.5%`) %>%
    mutate(true_value = theta) %>%
    arrange(true_value) %>%
    mutate(idx = 1:n())

ggplot(latent, aes(median, true_value)) + geom_point()

ggplot(latent, aes(idx, true_value)) +
    geom_point(col = "darkgrey") +
    geom_errorbar(aes(ymin = codelow, ymax = codehigh), alpha = 0.2, col = "darkblue")


# % correctly predicted within CI
with(latent, ifelse(true_value <= codehigh & true_value >= codelow, T, F) %>% mean)

with(latent[w == 1, ], ifelse(true_value <= codehigh & true_value >= codelow, T, F) %>% mean)
with(latent[w == 0, ], ifelse(true_value <= codehigh & true_value >= codelow, T, F) %>% mean)
