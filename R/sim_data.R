#!/usr/bin/env Rscript

library(boot)
library(dplyr)
library(extraDistr)
library(ggplot2)
library(jsonlite)
library(MASS)

set.seed(6666)

N <- 200L
D <- 6L

# Start with latent model
theta <- rnorm(N)

gamma <- rnorm(D, 0, 5)
lambda <- rlnorm(D, 0, 0.5)
psi <- rweibull(D, 5, 1)

# Legislative variables
kappa <- rnorm(1)
delta <- rlnorm(1, 0, 0.5)

xi <- kappa + delta * theta

w <- rbinom(N, 1, inv.logit(xi))
stopifnot(any(w == 1))

N_obs <- sum(w)
obs_idx <- which(w == 1)

# Note: psi is the standard deviation, but mvrnorm expects a
# covariance matrix
lg <- theta[obs_idx] %*% t(lambda[1:3]) + mvrnorm(N_obs, rep(0, 3), diag((psi[1:3]) ^ 2))
lg <- sweep(lg, 2, gamma[1:3], `+`)

lg_err <- matrix(rbeta(N_obs * ncol(lg), 5, 5), N_obs, ncol(lg))
lg_obs <- matrix(NA, N_obs, ncol(lg))
for (i in 1:ncol(lg))
    lg_obs[, i] <- rnorm(N_obs, lg[, i], lg_err[, i])

# Non-legislative variables
nonlg <- theta %*% t(lambda[4:6]) + mvrnorm(N, rep(0, 3), diag((psi[4:6]) ^ 2))
nonlg <- sweep(nonlg, 2, gamma[4:6], `+`)

nonlg_err <- matrix(rbeta(N * ncol(nonlg), 5, 5), N, ncol(nonlg))
nonlg_obs <- matrix(NA, N, ncol(nonlg))
for (i in 1:ncol(nonlg))
    nonlg_obs[, i] <- rnorm(N, nonlg[, i], nonlg_err[, i])

# Conflict regression
alpha <- rnorm(1, 0, 5)
beta <- rnorm(4, 0, 2.5)

X <- mvrnorm(N, c(0, 2), matrix(c(2, .5, .5, 3), 2, 2))
X <- data.frame(a = rnorm(N, 0, 2), b = rnorm(N, 0, 3))
interaction_idx  <- 2L

n_years <- N %/% 10L
n_countries <- 10L

sigma <- rhcauchy(2, 1)
countries <- rnorm(n_countries, 0, sigma[1])
years <- rnorm(n_years, 0, sigma[2])

cy <- expand.grid(1:n_countries, 1:n_years)
cy <- cy[sample(nrow(cy)), ]

stopifnot(nrow(cy) == N)

country_idx <- cy[, 1]
year_idx <- cy[, 2]

p <- inv.logit(alpha + beta[1] * theta + beta[2] * X[, 1] +
               beta[3] * X[, 2] + beta[4] * theta * X[, interaction_idx] +
               years[year_idx] + countries[country_idx])

y <- rbinom(N, 1, p)
sprintf("%d simulated conflicts out of %d country-years", sum(y), N)

###
# Generate json file for Stan
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
             lgotovst_idx = 0L,
             lgbicam = w,

             N = N,
             M = 2L,
             X = as.matrix(X),
             interaction_idx = interaction_idx,
             exec_idx = 1:N,
             n_countries = n_countries,
             n_years = n_years,
             country_id = country_idx,
             year_id = year_idx,
             y = y)

str(data)
stopifnot(!sapply(data, anyNA))

write_json(data, "posteriors/sim/data.json", auto_unbox = T)

###
# Also save simulated parameters
true_values <- data.frame(parameter = c(sprintf("lambda[%d]", seq_along(lambda)),
                                        sprintf("psi[%d]", seq_along(psi)),
                                        sprintf("gamma[%d]", seq_along(gamma)),
                                        "delta",
                                        "eta",
                                        "alpha",
                                        sprintf("beta[%d]", seq_along(beta)),
                                        sprintf("sigma[%d]", seq_along(sigma)),
                                        sprintf("theta[%d]", seq_along(theta))),
                          point = c(lambda, psi, gamma, delta, eta,
                                    alpha, beta, sigma, theta),
                          type = "True Values",
                          stringsAsFactors = F)

saveRDS(true_values, "posteriors/sim/simulated_parameters.rds")
