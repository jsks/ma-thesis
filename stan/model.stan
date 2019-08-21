data {
  // Factor model
  int J;
  int J_missing;
  int J_obs;
  int<lower=1, upper=J> missing_idx[J_missing];
  int<lower=1, upper=J> obs_idx[J_obs];
  int lg_D;
  int nonlg_D;

  matrix[J_obs, lg_D] lg;
  matrix[J_obs, lg_D] lg_se;
  matrix[J, nonlg_D] nonlg;
  matrix[J, nonlg_D] nonlg_se;

  int<lower=1, upper=lg_D> lgotovst_idx;
  int<lower=0, upper=1> lgbicam[J];

  // Conflict onset regression
  int N;
  int M;
  matrix[N, M] X;
  vector[N] state_capacity;
  int<lower=1, upper=N> exec_idx[N];

  int<lower=1> n_countries;
  int<lower=1> n_years;
  int<lower=1, upper=n_countries> country_id[N];
  int<lower=1, upper=n_years> year_id[N];

  int<lower=0, upper=1> y[N];
}

transformed data {
  int D = lg_D + nonlg_D;
}

parameters {
  // Factor model
  matrix[J_obs, lg_D] lg_est;
  matrix[J, nonlg_D] nonlg_est;
  matrix[J_missing, lg_D] lg_missing;

  vector[J] theta;
  vector<lower=0>[D] lambda;
  vector<lower=0, upper=pi()/2>[D] psi_unif;
  vector[D] gamma;

  real alpha;
  real<lower=0> delta;

  // Onset regression
  real intercept;

  // Control vars + state_capacity * theta interaction
  vector[M+3] beta;

  vector[n_countries] raw_country;
  vector[n_years] raw_year;
  real<lower=0, upper=pi()/2> sigma_unif[2];
}

transformed parameters {
  vector<lower=0>[D] psi;
  vector[J] nu;

  vector[N] theta_state_capacity;
  vector[n_countries] Z_country;
  vector[n_years] Z_year;
  real<lower=0> sigma[2];

  // lgbicam ~ bernoulli_logit(eta + delta * theta)
  nu = alpha + delta * theta;

  // psi ~ HalfCauchy(0, 1)
  psi = tan(psi_unif);

  // Interaction term b/w exec constraints & state cap
  theta_state_capacity = theta[exec_idx] .* state_capacity;

  // sigma ~ HalfCauchy(0, 1)
  sigma = tan(sigma_unif);

  // Z_country ~ Normal(0, sigma[1])
  Z_country = raw_country * sigma[1];

  // Z_year ~ Normal(0, sigma[2])
  Z_year = raw_year * sigma[2];
}

model {
  // Factor model
  theta ~ std_normal();
  lambda ~ lognormal(0, 1);
  gamma ~ normal(0, 5);

  alpha ~ normal(0, 5);
  delta ~ normal(0, 2.5);

  lgbicam ~ bernoulli_logit(nu);

  for (i in 1:lg_D) {
    lg[, i] ~ normal(lg_est[, i], lg_se[, i]);
    lg_missing[, i] ~ std_normal();

    if (i == lgotovst_idx) {
      lg_est[, i] ~ normal(gamma[i] + lambda[i] * theta[obs_idx], psi[i]);
      lg_missing[, i] ~ normal(gamma[i] + lambda[i] * theta[missing_idx], psi[i]);
    } else {
      lg_est[, i] ~ normal(gamma[i] + lambda[i] * nu[obs_idx], psi[i]);
      lg_missing[, i] ~ normal(gamma[i] + lambda[i] * nu[missing_idx], psi[i]);
    }
  }

  for (i in 1:nonlg_D) {
    nonlg[, i] ~ normal(nonlg_est[, i], nonlg_se[, i]);
    nonlg_est[, i] ~ normal(gamma[i + lg_D] + lambda[i + lg_D] * theta,
                        psi[i + lg_D]);
  }

  // Onset regression
  intercept ~ normal(0, 5);
  beta ~ normal(0, 2.5);

  raw_country ~ std_normal();
  raw_year ~ std_normal();

  y ~ bernoulli_logit(X * beta[4:] +
                      beta[1] * theta[exec_idx] +
                      beta[2] * state_capacity +
                      beta[3] * theta_state_capacity +
                      intercept +
                      Z_country[country_id] +
                      Z_year[year_id]);
}

generated quantities {
  vector[N] eta;
  vector[N] log_lik;
  vector[N] p_hat;

  eta = X * beta[4:] +
    beta[1] * theta[exec_idx] +
    beta[2] * state_capacity +
    beta[3] * theta_state_capacity +
    intercept +
    Z_country[country_id] +
    Z_year[year_id];

  for (i in 1:N)
    log_lik[i] = bernoulli_logit_lpmf(y[i] | eta[i]);

  p_hat = inv_logit(eta);
}
