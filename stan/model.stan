data {
  // Factor model
  int N;
  int J;
  matrix[N, J] manifest_obs;
  matrix[N, J] manifest_se;

  // Conflict onset regression
  int T;
  int I;
  matrix[T, I] X;
  int<lower=1, upper=N> exec_idx[T];

  int<lower=1> n_countries;
  int<lower=1, upper=n_countries> country_id[T];

  int<lower=0, upper=1> y[T];
}

parameters {
  // Factor model
  matrix[N, J] manifest_raw;

  vector[N] theta;
  vector[J] gamma;
  vector<lower=0>[J] lambda;
  vector<lower=0, upper=pi()/2>[J] psi_unif;

  // Onset regression
  real alpha;
  vector[I+1] beta;

  vector[n_countries] raw_country;
  real<lower=0, upper=pi()/2> sigma_unif;
}

transformed parameters {
  matrix[N, J] manifest_est;
  vector<lower=0>[J] psi;

  vector[T] eta;
  vector[n_countries] Z_country;
  real<lower=0> sigma;

  psi = 2.5 * tan(psi_unif);

  for (j in 1:J)
    manifest_est[, j] = gamma[j] + lambda[j] * theta + psi[j] * manifest_raw[, j];

  sigma = tan(sigma_unif);
  Z_country = raw_country * sigma;

  eta = X * beta[2:] + beta[1] * theta[exec_idx] +
        alpha + Z_country[country_id];
}

model {
  // Factor model
  theta ~ std_normal();

  lambda ~ lognormal(0, 1);
  gamma ~ normal(0, 5);

  for (j in 1:J)
    manifest_raw[, j] ~ std_normal();

  for (j in 1:J)
    manifest_obs[, j] ~ normal(manifest_est[, j], manifest_se[, j]);

  // Onset regression
  alpha ~ normal(0, 5);
  beta ~ normal(0, 2.5);

  raw_country ~ std_normal();

  y ~ bernoulli_logit(eta);
}
