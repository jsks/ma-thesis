data      := data
raw       := $(data)/raw
post      := posteriors

all: paper.pdf ## Default rule: paper.pdf
.PHONY: clean watch_sync watch_pdf

help:
	@egrep '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' '{ printf "\033[01;34m%-15s \033[00;37m%s\033[0m\n", $$1, $$2 }'

clean: ## Remove all generated files excluding model output
	rm -rf R/thesis.utils.Rcheck R/thesis.utils_*.tar.gz \
		$(data)/*.rds $(data)/*.RData *.html *.pdf

watch_sync: ## Autosync proj files to host 'gce'
	@fswatch --event Updated --event Removed -roe .git . | \
		xargs -n1 -I{} scripts/sync.sh

watch_pdf: ## Autobuild PDF in a container instance
	@export CLEANUP=1; \
		fswatch --event Updated -oe .git paper.Rmd | \
		xargs -n1 -I{} scripts/run.sh paper.pdf

$(data)/neighbours.rds: $(raw)/cshapes_0.6/cshapes.* R/geo.R
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

%.pdf: paper.Rmd assets/stan.xml
	Rscript -e "rmarkdown::render('$<', output_file = '$@')"

%.html: paper.Rmd assets/sakura.css assets/stan.xml
	Rscript -e "rmarkdown::render('$<', 'html_document', '$@')"
