data      := data
raw       := $(data)/datasets
post      := posteriors

all: $(post)/fit.rds
.PHONY: build clean watch

build:
	DOCKER_BUILDKIT=1 docker build -t jsks/conflict_onset:latest .

$(data)/merged_data.rds: $(raw)/V-Dem-CY-Full+Others-v9.rds \
							$(raw)/ucdp-prio-acd-181 \
							R/merge.R
	Rscript R/merge.R

# TODO: Add dep on vdem posteriors
$(data)/prepped_data.RData: $(data)/merged_data.rds \
							R/prep.R
	Rscript R/prep.R

$(post)/fit.rds: $(data)/prepped_data.RData \
					R/model.R
	@mkdir -p $(post)
	Rscript R/model.R

$(data)/summarised_post.rds: $(post)/fit.rds \
								R/summarise.R
	Rscript R/summarise.R

paper.pdf: paper.Rmd
	Rscript -e "rmarkdown::render('paper.Rmd')"

watch:
	fswatch -o paper.Rmd | xargs -n1 -I{} make

clean:
	rm -rf $(data)/*.rds $(data)/*.RData
