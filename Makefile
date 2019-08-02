data      := data
raw       := $(data)/raw
vdem_post := $(raw)/vdem_post
post      := posteriors

all: $(post)/fit.rds
.PHONY: build clean watch_sync watch_pdf

build:
	docker pull jsks/conflict_onset:latest

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

gam: $(data)/gam_model.rds

paper.pdf: paper.Rmd
	Rscript -e "rmarkdown::render('paper.Rmd')"

watch_sync:
	fswatch -o . | xargs -n1 -I{} scripts/sync.sh

watch_pdf:
	fswatch -o paper.Rmd | xargs -n1 -I{} make paper.pdf

clean:
	rm -rf $(data)/*.rds $(data)/*.RData
