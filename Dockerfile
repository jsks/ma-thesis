FROM r-base:3.6.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pandoc \
        pandoc-citeproc \
        texlive-latex-recommended \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.R
COPY .R /root/.R

Run Rscript -e "install.packages(c('data.table', 'dplyr', 'rmarkdown', 'rstan'))"

RUN mkdir /proj
WORKDIR /proj

CMD ["R"]
