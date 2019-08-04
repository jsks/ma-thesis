data {
  // Factor model
  int J;
  int D;
  matrix[J, D] manifest_obs;
  matrix[J, D] manifest_se;

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

parameters {
  // Factor model
  matrix[J, D] manifest_raw;

  vector[J] theta;
  vector<lower=0>[D] lambda;
  vector<lower=0, upper=pi()/2>[D] psi_unif;

  // Onset regression
  real intercept;

  // Control vars + state_capacity * theta interaction
  vector[M+3] beta;

  vector[n_countries] raw_country;
  vector[n_years] raw_year;
  real<lower=0, upper=pi()/2> sigma_unif[2];
}

transformed parameters {
  matrix[J, D] manifest_est;
  vector<lower=0>[D] psi;

  vector[N] theta_state_capacity;
  vector[n_countries] Z_country;
  vector[n_years] Z_year;
  real<lower=0> sigma[2];

  // psi ~ HalfCauchy(0, 1)
  psi = tan(psi_unif);

  // manifest_est ~ Normal(lambda * theta, psi)
  for (d in 1:D)
    manifest_est[, d] = lambda[d] * theta + psi[d] * manifest_raw[, d];

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

  for (d in 1:D)
    manifest_raw[, d] ~ std_normal();

  for (d in 1:D)
    manifest_obs[, d] ~ normal(manifest_est[, d], manifest_se[, d]);

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
