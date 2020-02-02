SHELL = /bin/bash
ROOT  = $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

manuscript := paper.Rmd

cmdstan    ?= cmdstan
seed       ?= 101010

num_chains := 4
id         := $(shell seq $(num_chains))

samples = $(foreach x, $(id), $(post)/%/samples-chain_$(x).csv)

define get_id
$(shell grep -Po '\d+[.]csv' <<< $(1) | sed 's/.csv//')
endef

blue  := \033[01;34m
grey  := \033[00;37m
reset := \033[0m

data    := data
raw     := $(data)/raw
post    := posteriors

ml      := $(wildcard models/*)
results := $(ml:models/%.json=$(post)/%/combined_posteriors.csv.gz)

all: paper.pdf ## Default rule: paper.pdf
.PHONY: bash clean manuscript_dependencies help watch_sync watch_pdf wc
.SECONDARY:

###
# Convenience rules for development workflow
bash: ## Drop into bash. Only useful to launch interactive shell in container.
	@bash

help:
	@egrep '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "$(blue)%-15s $(grey)%s$(reset)\n", $$1, $$2 }'

clean: ## Remove all generated files, excluding model output
	rm -rf R/thesis.utils.Rcheck R/thesis.utils_*.tar.gz \
		$(data)/*.rds $(data)/*.RData *.html *.pdf *.tex *.log \
		stan/model stan/model.o

watch_sync: ## Autosync project files to host 'gce'
	@fswatch --event Updated --event Removed -roe .git . | \
		xargs -n1 -I{} scripts/sync.sh

watch_pdf: ## Autobuild PDF in a container instance
	@export CLEANUP=1; \
		fswatch --event Updated -oe .git $(manuscript) | \
		xargs -n1 -I{} scripts/run.sh paper.pdf

wc: ## Rough estimate of word count
	@# All text except codeblocks, toc, appendix, and bibliography
	@sed -e '/^```/,/^```/d' -e '/Appendices/,$$d' $(manuscript) | \
		pandoc --quiet --from markdown --to plain | \
		wc -w | \
		sed 's/^[[:space:]]*/word count: /'

# Records R package versions from the latest run into the csv file
# 'Rdependencies.csv'
Rdependencies.csv:
	Rscript R/deps.R

###
# Data Prep
$(data)/neighbours.rds: $(raw)/cshapes_0.6/cshapes.* R/geo.R
	Rscript R/geo.R

$(data)/merged_data.rds: $(raw)/V-Dem-CY-Full+Others-v9.rds \
				$(raw)/NMC_5_0/NMC_5_0.csv \
				$(raw)/pwt91.xlsx \
				$(raw)/mpd2018.xlsx \
				$(raw)/UcdpPrioConflict_v19_1.rds \
				$(raw)/growup/data.csv \
				$(data)/neighbours.rds \
				refs/cow_countries.csv \
				refs/ucdp_countries.csv \
				R/merge.R
	Rscript R/merge.R

$(data)/prepped_data.RData: $(data)/merged_data.rds R/transform.R
	Rscript R/transform.R

###
# Implicit rules for model runs
stan/model: stan/model.stan
	cd $(cmdstan) && $(MAKE) $(ROOT)/stan/model

$(post)/%/data.json: R/model_data.R models/%.json $(data)/prepped_data.RData
	@mkdir -p $(@D)
	Rscript R/model_data.R models/$*.json

$(post)/sim/data.json: R/sim_data.R
	@mkdir -p $(@D)
	Rscript R/sim_data.R

# Generate an implicit rules for each chain for sampling
define cmdstan-rule
$(post)/%/samples-chain_$(1).csv: $(post)/%/data.json stan/model
	stan/model sample id=$$(call get_id,$$@) \
		random seed=$$$$(( $$(seed) + $$(call get_id,$$@) - 1)) \
		data file=$$< output file=$$@
endef
$(foreach x, $(id), $(eval $(call cmdstan-rule,$(x))))

$(post)/%/fa_posteriors.csv.gz \
	$(post)/%/reg_posteriors.csv.gz \
	$(post)/%/err_posteriors.csv.gz: $(samples)
	$(cmdstan)/bin/diagnose $^
	sh scripts/concat.sh -o $(@D) $^
	@tar --remove-files --zstd -cf $(@D)/stan_output.tar.zst $^

###
# Summarised posteriors from simulated data run
$(post)/sim/simulated_summary.RData: R/summarise_sim.R \
					$(post)/sim/combined_posteriors.csv.gz
	Rscript R/summarise_sim.R

###
# Build final manuscript
manuscript_dependencies: $(manuscript) \
	library.bib \
	assets/stan.xml \
	Rdependencies.csv \
	$(post)/sim/simulated_summary.RData

%.pdf: manuscript_dependencies
	Rscript -e "rmarkdown::render('$(manuscript)', output_file = '$@')"

%.html: manuscript_dependencies
	Rscript -e "rmarkdown::render('$(manuscript)', 'html_document', '$@')"
