# Master's Thesis

Code repository hosting replication files for the analysis of
executive constraints and civil conflict onset.

## Dependencies

The following raw data sources are required. For copyright reasons
they are not distributed in this repository and need to be downloaded
manually and placed in the following locations:

- [CShapes 0.6](http://nils.weidmann.ws/projects/cshapes.html) - `./data/raw/cshapes_0.6/cshapes.*`
- [GROWup](https://growup.ethz.ch/) - `./data/raw/growup/data.csv`
- [NMC 5.0](https://correlatesofwar.org/data-sets/national-material-capabilities)  - `./data/raw/NMC_5_0/NMC_5_0.csv`
- [PWT 9.1](https://www.rug.nl/ggdc/productivity/pwt/) - `./data/raw/pwt91.xlsx`
- [UCDP v19.1](https://ucdp.uu.se/downloads/) - `./data/raw/UcdpPrioConflict_v19_1.rds`
- [V-Dem CY-Full v9](https://v-dem.net) - `./data/raw/V-Dem-CY-Full+Others-v9.rds`

The full replication pipeline is designed to be run from a `docker`
container.  A pre-built image as used in the latest version of the
manuscript is available at
[dockerhub](https://hub.docker.com/repository/docker/jsks/conflict_onset)
and will be downloaded automatically when running the pipeline.

Alternatively, the image can be built from scratch using the following
script:

```sh
# Creates an image tagged as jsks/conflict_onset:latest
$ scripts/build.sh
```

## Running the pipeline

To run all included models and create the manuscript pdf, the
following script can be used:

```sh
# Launches an attached instance of `jsks/conflict_onset` with `./`
# mounted at /proj. Default output will be `./paper.pdf`.
$ scripts/run.sh
```

The `run.sh` script assumes **4** available CPU cores, meaning that
each Stan model will be invoked with a corresponding number of chains.

Note, on a Google Cloud c2-standard-4 (4 vCPUs, 16GB memory) this
takes approximately 6 hours to run.

Any arguments to `run.sh` will be passed to `make`, the taskrunner for
the underlying pipeline (example: dry-run with make, `scripts/run.sh
-n`). For replication purposes `make` should not be accessed directly
outside of docker; however, there are several convenience rules
defined for development workflows that can be listed with `make help`.

Individual models, listed as json profiles in `./models/`, can also be
run separately. For example:

```sh
$ scripts/run.sh full_model
```

Finally, for any model run the full posteriors will be saved under
`./posteriors/<model_name>`. Since the final posterior object is far
too large for most workstations, the following extracts are available
which can easily be read into R:

- `reg_posteriors.csv`: regression parameters (intercepts and betas)
- `fa_posteriors.csv`: measurement model parameters (lambda, gamma, psi, etc, etc)
- `err_posteriors.csv`: example estimated latent values from error model
- `extra_posteriors.csv`: predicted probabilities from regression and log likelihood

## License

This project is licensed under a [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

![](https://i.creativecommons.org/l/by-sa/4.0/88x31.png)
