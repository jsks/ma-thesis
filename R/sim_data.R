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
kappa <- rnorm(1, 0, 2.5)
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
rho <- rinvgamma(1, 15.5031, 78.2992);
eta <- rhnorm(1, 1)

D <- dist(1:N, diag = T, upper = T) %>% as.matrix

K <- eta^2 * exp(-0.5 * (D / rho)^2)
f <- mvrnorm(1, rep(0, N), K)

alpha <- rnorm(1, 0, 5)
beta <- rnorm(3, 0, 2.5)

X <- rnorm(N, 2, 2)

n_years <- N %/% 4L
n_countries <- 4L

sigma <- rhcauchy(2, 1)
countries <- rnorm(n_countries, 0, sigma[1])
years <- rnorm(n_years, 0, sigma[2])

cy <- expand.grid(1:n_years, 1:n_countries)
stopifnot(nrow(cy) == N)

dataset <- setNames(cy, c("year", "country")) %>%
    mutate(x = X,
           exec_idx = 1:N,
           peace_yrs = 1,
           y = 0)

country <- 0
for (i in 1:nrow(dataset)) {
    if (country != dataset$country[i] || dataset$y[i - 1] == 1) {
        country <- dataset$country[i]
        dataset$peace_yrs[i] <- 1
    } else {
        dataset$peace_yrs[i] <- dataset$peace_yrs[i - 1] + 1
    }

    p <- inv.logit(alpha +
                   beta[1] * theta[dataset$exec_idx[i]] +
                   beta[2] * dataset$x[i] +
                   beta[3] * theta[dataset$exec_idx[i]] * dataset$x[i] +
                   f[dataset$peace_yrs[i]] +
                   years[dataset$year[i]] +
                   countries[dataset$country[i]])
    dataset$y[i] <- rbinom(1, 1, p)
}

sprintf("%d simulated conflicts out of %d country-years", sum(dataset$y), N)

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

             lgbicam = w,

             N = N,
             M = 1L,
             X = dataset$x %>% data.matrix,

             interaction_idx = 1,
             exec_idx = dataset$exec_idx,

             n_countries = n_countries,
             n_years = n_years,
             n_peace_yrs = n_distinct(dataset$peace_yrs),

             country_id = dataset$country,
             year_id = dataset$year,
             peace_yrs_id = dataset$peace_yrs,

             peace_yrs = unique(dataset$peace_yrs) %>% sort,

             y = dataset$y)

str(data)
stopifnot(!sapply(data, anyNA))

write_json(data, "posteriors/sim/data.json", auto_unbox = T)

###
# Also save simulated parameters
true_values <- data.frame(parameter = c(sprintf("lambda[%d]", seq_along(lambda)),
                                        sprintf("psi[%d]", seq_along(psi)),
                                        sprintf("gamma[%d]", seq_along(gamma)),
                                        "delta",
                                        "kappa",
                                        "rho",
                                        "eta",
                                        "alpha",
                                        sprintf("beta[%d]", seq_along(beta)),
                                        sprintf("sigma[%d]", seq_along(sigma)),
                                        sprintf("theta[%d]", seq_along(theta)),
                                        sprintf("y[%d]", seq_along(dataset$y))),
                          point = c(lambda, psi, gamma, delta, kappa, rho, eta,
                                    alpha, beta, sigma, theta, dataset$y),
                          type = "True Values",
                          stringsAsFactors = F)

saveRDS(true_values, "posteriors/sim/simulated_parameters.rds")
