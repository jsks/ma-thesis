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
  //int<lower=1> n_peace_yrs;
  int<lower=1, upper=n_countries> country_id[N];
  int<lower=1, upper=n_years> year_id[N];
  //int<lower=1, upper=n_peace_yrs> peace_yr_id[N];

  //real peace_yrs[n_peace_yrs];

  int<lower=0, upper=1> y[N];
}

parameters {
  // Factor model
  matrix[J, D] manifest_raw;

  vector[J] theta;
  vector[D] gamma;
  vector<lower=0>[D] lambda;
  vector<lower=0, upper=pi()/2>[D] psi_unif;

  // Onset regression
  real intercept;

  // Control vars + state_capacity * theta interaction
  vector[M+3] beta;

  vector[n_countries] raw_country;
  vector[n_years] raw_year;
  real<lower=0, upper=pi()/2> sigma_unif[2];

  /*real<lower=0> rho;
  real<lower=0> alpha;
  real<lower=0> tau;
  vector[n_peace_yrs] nu;*/
}

transformed parameters {
  matrix[J, D] manifest_est;
  vector<lower=0>[D] psi;

  vector[N] theta_state_capacity;
  //  vector[n_peace_yrs] f;
  vector[n_countries] Z_country;
  vector[n_years] Z_year;
  real<lower=0> sigma[2];

  // psi ~ HalfCauchy(0, 2.5)
  psi = 2.5 * tan(psi_unif);

  // manifest_est ~ Normal(gamma + lambda * theta, psi)
  for (d in 1:D)
    manifest_est[, d] = gamma[d] + lambda[d] * theta + psi[d] * manifest_raw[, d];

  // Gaussian process
  /*{
    matrix[n_peace_yrs, n_peace_yrs] cov;
    matrix[n_peace_yrs, n_peace_yrs] L_cov;

    cov = cov_exp_quad(peace_yrs, alpha, rho) +
      diag_matrix(rep_vector(square(tau), n_peace_yrs));
    L_cov = cholesky_decompose(cov);
    f = L_cov * nu;
    }*/

  // Interaction term
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
  gamma ~ std_normal();

  for (d in 1:D)
    manifest_raw[, d] ~ std_normal();

  for (d in 1:D)
    manifest_obs[, d] ~ normal(manifest_est[, d], manifest_se[, d]);

  // Onset regression
  intercept ~ normal(0, 5);
  beta ~ normal(0, 2.5);

  raw_country ~ std_normal();
  raw_year ~ std_normal();

  /*rho ~ inv_gamma(5, 5);
  alpha ~ std_normal();
  tau ~ std_normal();
  nu ~ std_normal();*/

  y ~ bernoulli_logit(X * beta[4:] +
                      beta[1] * theta[exec_idx] +
                      beta[2] * state_capacity +
                      beta[3] * theta_state_capacity +
                      intercept +
                      Z_country[country_id] +
                      Z_year[year_id]);
                      //f[peace_yr_id]);
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
    //f[peace_yr_id];

  for (i in 1:N)
    log_lik[i] = bernoulli_logit_lpmf(y[i] | eta[i]);

  p_hat = inv_logit(eta);
}
