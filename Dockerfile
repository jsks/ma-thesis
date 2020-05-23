FROM r-base:3.6.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        jq \
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
        texlive-plain-generic \
        zstd \
    && rm -rf /var/lib/apt/lists/*

RUN wget 'https://github.com/jgm/pandoc/releases/download/2.9.1.1/pandoc-2.9.1.1-1-amd64.deb' \
    && dpkg -i pandoc-2.9.1.1-1-amd64.deb \
    && rm pandoc-2.9.1.1-1-amd64.deb

RUN mkdir -p /root/.R /root/utils /root/bin
COPY .R /root/.R

RUN install2.r -n -1 -e corrplot data.table dplyr extraDistr ggplot2 gridExtra ggthemes jsonlite \
        kableExtra loo precrec readxl rmarkdown R.utils sf testthat tidyr \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

RUN wget 'https://github.com/stan-dev/cmdstan/releases/download/v2.23.0/cmdstan-2.23.0.tar.gz' \
    && mkdir -p cmdstan \
    && tar -xvzf cmdstan-2.23.0.tar.gz --strip 1 -C cmdstan \
    && cd cmdstan && make build -j4 && cd ../ \
    && rm cmdstan-2.23.0.tar.gz

# Commandline tool to process cmdstan posteriors files
COPY utils /root/utils
RUN cd /root/utils \
    && make test \
    && make clean all \
    && mv extract /root/bin

RUN mkdir -p /proj/thesis.utils/
COPY R/thesis.utils /proj/thesis.utils/

WORKDIR /proj

RUN R CMD build thesis.utils \
    && R CMD check thesis.utils_*.tar.gz \
    && R CMD INSTALL thesis.utils_*.tar.gz \
    && rm -rf thesis.utils*

CMD ["R"]
