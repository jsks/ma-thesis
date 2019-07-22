# syntax = docker/dockerfile:1.0-experimental
FROM r-base:3.6.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ccache \
        pandoc \
        pandoc-citeproc \
        texlive-latex-recommended \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.R /root/.ccache /root/Rcache
COPY .R /root/.R
COPY .ccache /root/.ccache

Run --mount=type=cache,target=/root/Rcache \
    Rscript -e "install.packages(c('data.table', 'dplyr', 'rmarkdown', 'rstan'))"

RUN mkdir -p /proj/thesis.utils
WORKDIR /proj

CMD ["R"]
