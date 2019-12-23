manuscript := paper.Rmd

data := data
raw  := $(data)/raw
refs := refs
post := posteriors

blue  := \033[01;34m
grey  := \033[00;37m
reset := \033[0m

all: paper.pdf ## Default rule: paper.pdf
.PHONY: bash clean help watch_sync watch_pdf wc

bash: ## Drop into bash. Only useful with run.sh to launch interactive shell in container.
	@bash

help:
	@egrep '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "$(blue)%-15s $(grey)%s$(reset)\n", $$1, $$2 }'

clean: ## Remove all generated files, excluding model output
	rm -rf R/thesis.utils.Rcheck R/thesis.utils_*.tar.gz \
		$(data)/*.rds $(data)/*.RData *.html *.pdf

watch_sync: ## Autosync project files to host 'gce'
	@fswatch --event Updated --event Removed -roe .git . | \
		xargs -n1 -I{} scripts/sync.sh

watch_pdf: ## Autobuild PDF in a container instance
	@export CLEANUP=1; \
		fswatch --event Updated -oe .git $(manuscript) | \
		xargs -n1 -I{} scripts/run.sh paper.pdf

wc: ## Rough estimate of word count
	@# All text except codeblocks, toc, appendix, and bibliography
	@sed -e '/^```/,/^```/d' -e '/Appendix/,$$d' $(manuscript) | \
		pandoc --quiet --from markdown --to plain | \
		wc -w | \
		sed 's/^[[:space:]]*/word count: /'

# Records R package versions from the latest run into the csv file
# 'Rdependencies.csv'
Rdependencies.csv:
	Rscript R/deps.R

$(data)/neighbours.rds: $(raw)/cshapes_0.6/cshapes.* R/geo.R | Rdependencies.csv
	Rscript R/geo.R

$(data)/merged_data.rds: $(raw)/V-Dem-CY-Full+Others-v9.rds \
				$(raw)/NMC_5_0/NMC_5_0.csv \
				$(raw)/mpd2018.xlsx \
				$(raw)/UcdpPrioConflict_v19_1.rds \
				$(raw)/growup/data.csv \
				$(data)/neighbours.rds \
				$(refs)/cow_countries.csv \
				$(refs)/ucdp_countries.csv \
				R/merge.R
	Rscript R/merge.R

$(data)/prepped_data.RData: $(data)/merged_data.rds R/transform.R
	Rscript R/transform.R

$(post)/fit.rds: $(data)/prepped_data.RData R/model.R stan/model.stan
	@mkdir -p $(post)
	Rscript R/model.R

%.pdf: $(manuscript) library.bib assets/stan.xml
	Rscript -e "rmarkdown::render('$<', output_file = '$@')"

%.html: $(manuscript) library.bib assets/sakura.css assets/stan.xml
	Rscript -e "rmarkdown::render('$<', 'html_document', '$@')"
