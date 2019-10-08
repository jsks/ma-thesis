data      := data
raw       := $(data)/raw
post      := posteriors

all: paper.pdf
.PHONY: clean watch_sync watch_pdf

clean:
	rm -rf R/thesis.utils.Rcheck R/thesis.utils_*.tar.gz \
		$(data)/*.rds $(data)/*.RData *.html *.pdf

watch_sync:
	fswatch --event Updated --event Removed -roe .git . | xargs -n1 -I{} scripts/sync.sh

watch_pdf:
	fswatch --event Updated -oe .git paper.Rmd | xargs -n1 -I{} make paper.pdf

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
