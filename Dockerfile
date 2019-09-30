FROM r-base:3.6.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgdal-dev \
        libopenblas-base \
        libopenblas-dev \
        libudunits2-dev \
        pandoc \
        pandoc-citeproc \
        texlive-latex-recommended \
        texlive-fonts-recommended \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.R
COPY .R /root/.R
COPY .Rprofile /root/.Rprofile

RUN install2.r -e data.table dplyr loo readxl rmarkdown rstan sf testthat tidyr \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

RUN mkdir -p /proj/thesis.utils/
COPY R/thesis.utils /proj/thesis.utils/

WORKDIR /proj

RUN R CMD build thesis.utils \
    && R CMD check thesis.utils_*.tar.gz \
    && R CMD INSTALL thesis.utils_*.tar.gz \
    && rm -rf thesis.utils*

# Compile stan models with "-march=native"
RUN sed -i -r 's/(x86-64|generic)/native/g' /root/.R/Makevars
CMD ["R"]
