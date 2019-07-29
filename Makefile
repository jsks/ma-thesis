data      := data
raw       := $(data)/raw
vdem_post := $(raw)/vdem_post
post      := posteriors

all: $(data)/summarised_post.rds
.PHONY: build clean watch_sync watch_pdf

build:
	docker pull jsks/conflict_onset:latest

$(data)/merged_data.rds: $(raw)/V-Dem-CY-Full+Others-v9.rds \
							$(raw)/ucdp-prio-acd-181 \
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

$(data)/lavaan_predict.rds: $(data)/prepped_data.RData \
								R/lavaan.R
	Rscript R/lavaan.R

paper.pdf: paper.Rmd
	Rscript -e "rmarkdown::render('paper.Rmd')"

watch_sync:
	fswatch -o . | xargs -n1 -I{} scripts/sync.sh

watch_pdf:
	fswatch -o paper.Rmd | xargs -n1 -I{} make paper.pdf

clean:
	rm -rf $(data)/*.rds $(data)/*.RData
