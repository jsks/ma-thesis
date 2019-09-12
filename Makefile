data      := data
raw       := $(data)/raw
vdem_post := $(raw)/vdem_post
post      := posteriors

all: $(post)/fit.rds
.PHONY: clean watch_sync watch_pdf

$(data)/neighbours.rds: $(raw)/cshapes_0.6/cshapes.* \
				R/geo.R
	Rscript R/geo.R

$(data)/merged_data.rds: $(raw)/V-Dem-CY-Full+Others-v9.rds \
				$(raw)/ucdp-prio-acd-181 \
				$(data)/neighbours.rds \
				R/merge.R
	Rscript R/merge.R

$(data)/prepped_data.RData: $(data)/merged_data.rds \
				$(vdem_post)/v2lgfunds.80000.Z.sample.csv \
				$(vdem_post)/v2lginvstp.10000.Z.sample.csv \
				$(vdem_post)/v2lgqstexp.40000.Z.sample.csv \
				$(vdem_post)/v2lgoppart.20000.Z.sample.csv \
				R/prep.R
	Rscript R/prep.R

$(post)/fit.rds: $(data)/prepped_data.RData \
			R/model.R stan/model.stan
	@mkdir -p $(post)
	Rscript R/model.R

$(data)/summarised_post.rds: $(post)/fit.rds \
				R/summarise.R
	Rscript R/summarise.R

$(data)/gam_model.rds: $(data)/prepped_data.RData \
			R/gam.R
	Rscript R/gam.R

$(post)/fa.rds: $(data)/prepped_data.RData
	Rscript R/fa.R

fa: $(post)/fa.rds

paper.pdf: paper.Rmd assets/stan.xml
	Rscript -e "rmarkdown::render('paper.Rmd')"

paper.html: paper.Rmd assets/stan.xml
	Rscript -e "rmarkdown::render('paper.Rmd', output_format = 'html_document')"

watch_sync:
	fswatch --event Updated --event Removed -roe .git . | xargs -n1 -I{} scripts/sync.sh

watch_pdf:
	fswatch --event Updated -oe .git paper.Rmd | xargs -n1 -I{} make paper.pdf

clean:
	rm -rf R/thesis.utils.Rcheck R/thesis.utils_*.tar.gz \
		$(data)/*.rds $(data)/*.RData \
		paper.html paper.pdf
