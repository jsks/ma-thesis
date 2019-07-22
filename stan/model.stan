data {
  int N;
  int J;
  matrix[N, J] X_obs;
  matrix[N, J] X_se;
}

parameters {
  matrix[N, J] X_est;

  vector[N] theta;
  vector[J] gamma;
  vector<lower=0>[J] lambda;
  vector<lower=0>[J] psi;
  //vector<lower=0, upper=pi()/2>[J] psi_unif;
}

transformed parameters {
  // psi ~ cauchy(0, 1)
  //vector[J] psi = tan(psi_unif);
}

model {
  theta ~ std_normal();

  lambda ~ lognormal(0, 1);
  gamma ~ normal(0, 5);
  psi ~ gamma(2, 1);

  for (j in 1:J)
    X_obs[, j] ~ normal(X_est[, j], X_se[, j]);

  for (j in 1:J)
    X_est[, j] ~ normal(gamma[j] + lambda[j] * theta, psi[j]);
}
