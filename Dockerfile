FROM r-base:3.6.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        libgdal-dev \
        libopenblas-base \
        libopenblas-dev \
        libssl-dev \
        libudunits2-dev \
        lmodern \
        texlive-luatex \
        texlive-latex-extra \
        texlive-latex-recommended \
        texlive-fonts-recommended \
    && rm -rf /var/lib/apt/lists/*

RUN wget 'https://github.com/jgm/pandoc/releases/download/2.9/pandoc-2.9-1-amd64.deb' \
    && dpkg -i pandoc-2.9-1-amd64.deb \
    && rm pandoc-2.9-1-amd64.deb

RUN mkdir -p /root/.R
COPY .R /root/.R

# Unfortunately, cmdstanr is still pulling in rstan as a dependency :(
RUN install2.r -e data.table devtools dplyr extraDistr ggplot2 \
        loo readxl rmarkdown sf testthat tidyr \
    && Rscript -e "devtools::install_github('stan-dev/cmdstanr')" \
    && Rscript -e "cmdstanr::install_cmdstan()" \
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
