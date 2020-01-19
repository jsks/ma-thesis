FROM r-base:3.6.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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

RUN install2.r -e data.table dplyr extraDistr ggplot2 gridExtra jsonlite \
        loo readxl rmarkdown R.utils sf testthat tidyr \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

RUN wget 'https://github.com/stan-dev/cmdstan/releases/download/v2.21.0/cmdstan-2.21.0.tar.gz' \
    && mkdir -p cmdstan \
    && tar -xvzf cmdstan-2.21.0.tar.gz --strip 1 -C cmdstan \
    && cd cmdstan; make build -j4; cd ../ \
    && rm cmdstan-2.21.0.tar.gz

RUN mkdir -p /proj /root/.R
COPY .R /root/.R
COPY .Rprofile /root/

WORKDIR /proj

RUN mkdir -p /proj/thesis.utils/
COPY R/thesis.utils /proj/thesis.utils/

RUN R CMD build thesis.utils \
    && R CMD check thesis.utils_*.tar.gz \
    && R CMD INSTALL thesis.utils_*.tar.gz \
    && rm -rf thesis.utils*

CMD ["R"]
