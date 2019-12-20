# Master's Thesis

Code repository hosting replication files for the analysis of
executive constraints and civil conflict onset.

## Dependencies

The following raw data sources are required. For copyright reasons
they are not distributed in this repository and need to be downloaded
manually and placed in the following locations:

- [CShapes 0.6]() (`./data/raw/cshapes_0.6/cshapes.*`)
- [GROWup]() (`./data/raw/growup/data.csv`)
- [Maddison 2018]() (`./data/raw/mpd2018.xlsx`)
- [NMC 5.0]() (`./data/raw/NMC_5_0/NMC_5_0.csv`)
- [UCDP v19.1]() (`./data/raw/UcdpPrioConflict_v19_1.rds`)
- [V-Dem CY-Full v9]() (`./data/raw/V-Dem-CY-Full+Others-v9.rds`)

The full replication pipeline is designed to be run from a `docker`
container.  A pre-built image as used in the latest version of the
manuscript is available at
[dockerhub](https://hub.docker.com/repository/docker/jsks/conflict_onset)
and will be downloaded automatically when running the pipeline.

Alternatively, the image can be built from scratch using the following
script:

```sh
# Creates an image tagged as jsks/conflict_onset:<git tag>
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

Any arguments to `run.sh` will be passed to `make`, the taskrunner for
the underlying pipeline (example: dry-run with make, `scripts/run.sh
-n`). For replication purposes `make` should not be accessed directly;
however, there are several convenience rules defined for development
workflows that can be listed with `make help`.

By default, `make` will invoke recipes serially and all `stan` models
are run with **4 chains** in parallel.

In addition to the pdf manuscript, the full posteriors will be saved
as `./posteriors/fit.rds`.

## License

This project is licensed under a [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

![](https://i.creativecommons.org/l/by-sa/4.0/88x31.png)
