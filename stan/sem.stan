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

  int<lower=0, upper=1> lgbicam[J];

  // Conflict onset regression
  int N;
  int M;
  matrix[N, M] X;

  int<lower=0, upper=M> interaction_idx;
  int<lower=1, upper=N> exec_idx[N];

  int<lower=1> n_countries;
  int<lower=1> n_years;
  int<lower=1> n_peace_yrs;

  int<lower=1, upper=n_countries> country_id[N];
  int<lower=1, upper=n_years> year_id[N];
  int<lower=1, upper=n_peace_yrs> peace_yrs_id[N];

  real<lower=0> peace_yrs[n_peace_yrs];

  int<lower=0, upper=1> y[N];
}

transformed data {
  // Total number of manifest variables in FA
  int D = lg_D + nonlg_D;

  real constant = 1e-9;

  // Number of regression coefficients. Increase by one if we include
  // an interaction term with the latent factor.
  int n_beta = interaction_idx > 0 ? M + 1 : M;
}

parameters {
  // Factor model
  matrix[J_obs, lg_D] lg_est;
  matrix[J, nonlg_D] nonlg_est;

  vector[J] theta;
  vector[D] gamma;
  vector<lower=0>[D] lambda;
  vector<lower=0>[D] psi;

  real kappa;
  real<lower=0> delta;

  // Onset regression
  real<lower=0> eta;
  real<lower=0> rho;
  vector[n_peace_yrs] raw_gp;

  real alpha;

  // Size = Control vars + theta
  vector[n_beta + 1] beta;

  vector[n_countries] raw_country;
  vector[n_years] raw_year;
  real<lower=0, upper=pi()/2> sigma_unif[2];
}

transformed parameters {
  vector[n_peace_yrs] f;

  vector[n_countries] Z_country;
  vector[n_years] Z_year;
  real<lower=0> sigma[2];

  vector[N] nu;

  // f ~ MVN(0, K)
  {
    matrix[n_peace_yrs, n_peace_yrs] K;
    matrix[n_peace_yrs, n_peace_yrs] L_K;

    K = gp_exp_quad_cov(peace_yrs, eta, rho);
    K = add_diag(K, constant);
    L_K = cholesky_decompose(K);

    f = L_K * raw_gp;
  }

  // sigma ~ HalfCauchy(0, 1)
  sigma = tan(sigma_unif);

  // Z_country ~ Normal(0, sigma[1])
  Z_country = raw_country * sigma[1];

  // Z_year ~ Normal(0, sigma[2])
  Z_year = raw_year * sigma[2];

  // Regression equation
  nu = X * beta[2:(M + 1)] +
    beta[1] * theta[exec_idx] +
    alpha +
    f[peace_yrs_id] +
    Z_country[country_id] +
    Z_year[year_id];

  if (interaction_idx > 0) {
    vector[N] interaction_term;

    interaction_term = theta[exec_idx] .* X[, interaction_idx];
    nu += beta[n_beta + 1] * interaction_term;
  }
}

model {
  // Factor model
  theta ~ std_normal();

  gamma ~ normal(0, 5);
  lambda ~ lognormal(0, 0.5);
  psi ~ weibull(5, 1);

  kappa ~ normal(0, 2.5);
  delta ~ lognormal(0, 0.5);

  // Linear predictor for presence of legislature
  lgbicam ~ bernoulli_logit(kappa + delta * theta);

  for (i in 1:lg_D) {
    lg[, i] ~ normal(lg_est[, i], lg_se[, i]);
    lg_est[, i] ~ normal(gamma[i] + lambda[i] * theta[obs_idx], psi[i]);
  }

  for (i in 1:nonlg_D) {
    nonlg[, i] ~ normal(nonlg_est[, i], nonlg_se[, i]);
    nonlg_est[, i] ~ normal(gamma[i + lg_D] + lambda[i + lg_D] * theta,
                            psi[i + lg_D]);
  }

  // Onset regression
  rho ~ inv_gamma(8.91924, 34.5805);
  eta ~ std_normal();
  raw_gp ~ std_normal();

  alpha ~ normal(0, 5);
  beta ~ normal(0, 2.5);

  raw_country ~ std_normal();
  raw_year ~ std_normal();

  y ~ bernoulli_logit(nu);
}

generated quantities {
  vector[N] log_lik;
  vector[N] p_hat;

  for (i in 1:N)
    log_lik[i] = bernoulli_logit_lpmf(y[i] | nu[i]);

  p_hat = inv_logit(nu);
}
