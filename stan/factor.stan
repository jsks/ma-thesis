data {
  // Factor model
  int N;

  int N_missing;
  int N_obs;
  int<lower=1, upper=N> missing_idx[N_missing];
  int<lower=1, upper=N> obs_idx[N_obs];

  int lg_D;
  int nonlg_D;

  matrix[N_obs, lg_D] lg;
  matrix[N_obs, lg_D] lg_se;

  matrix[N, nonlg_D] nonlg;
  matrix[N, nonlg_D] nonlg_se;

  int<lower=1, upper=lg_D> lgotovst_idx;
  int<lower=0, upper=1> lgbicam[N];
}

transformed data {
  int D = lg_D + nonlg_D;
}

parameters {
  vector[N] theta;
  vector<lower=0>[D] lambda;
  vector<lower=0>[D] psi;
  vector[D] gamma;

  matrix[N_obs, lg_D] lg_est;
  matrix[N, nonlg_D] nonlg_est;

  matrix[N_missing, lg_D] lg_missing;

  //real mu[lg_D];
  //real<lower=0> sigma[lg_D];

  real alpha;
  real<lower=0> beta;
}

transformed parameters {
  vector[N] eta;
  eta = alpha + beta * theta;
}

model {
  // Factor model
  theta ~ std_normal();

  lambda ~ lognormal(0, 1);
  psi ~ cauchy(0, 1);
  gamma ~ normal(0, 5);

  //mu ~ std_normal();
  //sigma ~ normal(1, .5);

  alpha ~ normal(0, 5);
  beta ~ normal(0, 2.5);

  lgbicam ~ bernoulli_logit(eta);

  for (i in 1:lg_D) {
    lg[, i] ~ normal(lg_est[, i], lg_se[, i]);

    //lg[, i] ~ normal(mu[i], sigma[i]);
    //lg_missing[, i] ~ normal(mu[i], sigma[i]);
    lg_missing[, i] ~ std_normal();

    if (i == lgotovst_idx) {
      lg_est[, i] ~ normal(lambda[i] * theta[obs_idx], psi[i]);
      lg_missing[, i] ~ normal(gamma[i] + lambda[i] * theta[missing_idx], psi[i]);
    } else {
      lg_est[, i] ~ normal(lambda[i] * eta[obs_idx], psi[i]);
      lg_missing[, i] ~ normal(gamma[i] + lambda[i] * eta[missing_idx], psi[i]);
    }
  }

  for (i in 1:nonlg_D) {
    nonlg_est[, i] ~ normal(nonlg_est[, i], nonlg_se[, i]);
    nonlg_est[, i] ~ normal(gamma[i + lg_D] + lambda[i + lg_D] * theta,
                            psi[i + lg_D]);
  }
}

generated quantities {
  vector[N] nonlg_sample;
  vector[N_obs] lg_sample;

  nonlg_sample = nonlg_est[, 1];
  lg_sample = lg_est[, 1];
}
