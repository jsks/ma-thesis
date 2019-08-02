FROM r-base:3.6.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgdal-dev \
        libudunits2-dev \
        pandoc \
        pandoc-citeproc \
        texlive-latex-recommended \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.R
COPY .R /root/.R

RUN install2.r -e data.table dplyr loo readxl rmarkdown rstan sf tidyr

RUN mkdir /proj
WORKDIR /proj

CMD ["R"]
