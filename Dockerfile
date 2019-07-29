FROM r-base:3.6.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pandoc \
        pandoc-citeproc \
        texlive-latex-recommended \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.R
COPY .R /root/.R

RUN install2.r -e data.table dplyr readxl rmarkdown rstan tidyr

RUN mkdir /proj
WORKDIR /proj

CMD ["R"]
