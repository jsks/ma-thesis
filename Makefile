SHELL = /bin/bash -o pipefail
ROOT  = $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

manuscript := paper.Rmd

cmdstan    ?= cmdstan
extract    ?= utils/extract
draws      ?= 500
seed       ?= 101010

blue       := \033[01;34m
grey       := \033[00;37m
reset      := \033[0m

data       := data
raw        := $(data)/raw
post       := posteriors

num_chains := 4
id         := $(shell seq $(num_chains))

# Stan output file per chain based on `id`
samples     = $(foreach x, $(id), $(post)/%/samples-chain_$(x).csv)

# Processed posterior files for each model
output     := reg_posteriors.csv fa_posteriors.csv \
		err_posteriors.csv extra_posteriors.csv

schemas    := $(wildcard models/*)
models     := $(schemas:models/%.json=%)
results    := $(models:%=$(post)/%/stan_output.tar.zst) \
		$(foreach x, $(models), $(output:%=$(post)/$(x)/%))

# Macro that reads in the sample files, extracts parameters based on
# given regex, and concats results into single file.
define concat
$(extract) -n $(draws) -s $(1) $^ > $@
endef

all: paper.pdf ## Default rule: paper.pdf
.PHONY: bash clean clean_all manuscript_dependencies help watch_sync watch_pdf \
	wc Rdependencies.csv
.SECONDARY:

###
# Convenience rules for development workflow
bash: ## Drop into bash. Only useful to launch interactive shell in container.
	@bash

help: ## Useless help message
	@egrep '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "$(blue)%-15s $(grey)%s$(reset)\n", $$1, $$2 }'

clean: ## Remove all generated files, excluding posteriors
	rm -rf R/thesis.utils.Rcheck R/thesis.utils_*.tar.gz \
		$(data)/*.rds $(data)/*.RData *.html *.pdf *.tex *.log \
		Rdependencies.csv stan/model stan/model.o

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
# Model runs
#
# Use cmdstan since Rstan is currently lagging behind in
# releases. This means that each stan file is compiled into a
# standalone binary and executed multiple times as separate
# "chains". The output is one csv file per chain containing 4000 draws
# for each parameter, which are then thinned and concatenated.
#
# To parameterize model runs, use macros to match each model input
# defined in a json schema ('models/') to per-chain posterior csv
# files and then per-model summarised files.
stan/%: stan/%.stan
	$(MAKE) -C $(cmdstan) $(ROOT)/stan/$*

$(post)/%/data.json: R/model_data.R models/%.json $(data)/prepped_data.RData
	@mkdir -p $(@D)
	Rscript R/model_data.R models/$*.json

# Separate data prep rule for simulated run
$(post)/sim/data.json: R/sim_data.R
	@mkdir -p $(@D)
	Rscript R/sim_data.R

# Generate implicit rules for sampling each model
define cmdstan-rule
$(post)/$(1)/samples-chain_%.csv: $(post)/$(1)/data.json stan/$(2)
	echo "[$$$$(date +'%a %d %b %y %T %z')] Started $$@" >> $$(@D)/log
	stan/$(2) id=$$* \
		data file=$$< output file=$$@ \
		random seed=$$$$(( $$(seed) + $$* - 1 )) \
		method=sample algorithm=hmc engine=nuts max_depth=12 |& \
			tee -a $$(@D)/log
endef

$(foreach x, $(schemas), \
	$(eval $(call cmdstan-rule,$(x:models/%.json=%),$(shell jq -re '.stan' < $(x)))))

# Extract parameters matching regex and concat results into a separate
# csv. This way we avoid having to load the entire posterior matrix in
# R.
$(post)/%/err_posteriors.csv: $(samples)
	$(call concat,'^lg_est[.][[:digit:]]*[.]1$$|^nonlg_est[.][[:digit:]]*[.]1$$')

$(post)/%/fa_posteriors.csv: $(samples)
	$(call concat,'^lambda|^gamma|^psi|^delta|^kappa|^theta')

$(post)/%/reg_posteriors.csv: $(samples)
	$(call concat,'^f[.]|^eta|^rho|^tau|^beta|^alpha|^sigma|^Z_')

$(post)/%/extra_posteriors.csv: $(samples)
	$(call concat,'^p_hat|^log_lik')

# Save the original output files as a compressed archive since we
# don't need them anymore
$(post)/%/stan_output.tar.zst: $(samples) | $(output:%=$(post)/\%/%)
	$(cmdstan)/bin/diagnose $^ |& tee -a $(post)/$*/log
	@tar --remove-files --zstd -cf $(@D)/stan_output.tar.zst $^

# Generate phony targets for each model so that they can be called
# directly. For example, `make -j4 full_model`.
define model-rule
.PHONY: $(1)
$(1): $(post)/$(1)/stan_output.tar.zst \
	$(output:%=$(post)/$(1)/%)
endef
$(foreach x, $(models), $(eval $(call model-rule,$(x))))

###
# Build final manuscript
manuscript_dependencies: $(manuscript) \
	library.bib \
	assets/stan.xml \
	assets/american-political-science-association.csl \
	Rdependencies.csv \
	$(results)

%.pdf: manuscript_dependencies
	Rscript -e "rmarkdown::render('$(manuscript)', output_file = '$@')"

%.html: manuscript_dependencies
	Rscript -e "rmarkdown::render('$(manuscript)', 'html_document', '$@')"
