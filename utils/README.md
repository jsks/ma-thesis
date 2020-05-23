# `extract` - Stan Posterior Utility

Simple program that extracts parameters from `cmdstan` posterior output files
and concatenates the results to stdout.

Parameters are specified using POSIX extended regex syntax.

The program can be quickly compiled using `make`. A short help message is
available using the `-h` argument.

```sh
make
./extract -h
```

### Example

Assuming four chains have been sampled for a model with at least two
parameters, `alpha` and `beta`, with the output saved as `samples_<chain
number>.csv`. Both parameters can be extracted using a simple regex and
outputed to the file `alpha_beta.csv` with the following command:

```sh
# Grab only the first 10 lines for the alpha and beta columns
./extract -s '^alpha|^beta' -n 10 samples_*.csv > alpha_beta.csv
```

