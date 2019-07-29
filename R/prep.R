#!/usr/bin/env Rscript

suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(magrittr))

source("R/functions.R")

constraint_vars <- c("v2lginvstp", "v2lgfunds", "v2lgqstexp", "v2lgoppart",
                     "v2juhcind", "v2juncind", "v2juhccomp", "v2jucomp",
                     "v2exrescon", "v2lgotovst")

merged.df <- readRDS("data/merged_data.rds")

###
# Where lg variables are missing due to v2lgbicam == 0 (ie no
# legislature), fill in with minimum values from posteriors.
fn <- function(f) {
    print(f)

    df <- fread(f, skip = 1, header = F)
    v <- apply(df[, -1], 2, min, na.rm = T)

    list(mean = mean(v), sd = sd(v))
}

lg_vars<- c("v2lginvstp", "v2lgfunds", "v2lgqstexp", "v2lgoppart")
re <- paste0(lg_vars, collapse = "|")

files <- list.files("./data/raw/vdem_post", re, full.names = T)
stopifnot(length(files) == length(lg_vars))

min.df <- lapply(files, fn) %>%
    bind_rows %>%
    mutate(variable = lg_vars)

for (v2 in lg_vars) {
    merged.df[[v2]] <- ifelse(merged.df$v2lgbicam == 0,
                         min.df$mean[min.df$variable == v2],
                         merged.df[[v2]])

    merged.df[[paste0(v2, "_sd")]] <- ifelse(merged.df$v2lgbicam == 0,
                                       min.df$sd[min.df$variable == v2],
                                       merged.df[[paste0(v2, "_sd")]])
}

###
# Final dataset for model
final.df <- merged.df %>%
    select(country_name, year, lepisode_onset, one_of(constraint_vars),
           one_of(paste0(constraint_vars, "_sd")), e_migdppcln,
           un_pop, area_sqkm, meanelev) %>%
    na.omit %>%
    filter_at(constraint_vars, all_vars(!is.na(.))) %>%
    mutate(s = do.call(paste, lapply(constraint_vars, as.symbol))) %>%
    group_by(country_name) %>%
    mutate(reduced_idx = rle(s) %>% { rep(.$values, .$lengths) } %>% to_idx) %>%
    ungroup

constraints.df <- select(final.df, country_name, year, reduced_idx,
                         one_of(constraint_vars),
                         one_of(paste0(constraint_vars, "_sd"))) %>%
    group_by(country_name, reduced_idx) %>%
    filter(year == min(year)) %>%
    ungroup

manifests <- select(constraints.df, one_of(constraint_vars)) %>% data.matrix
manifests_sd <- select(constraints.df, one_of(paste0(constraint_vars, "_sd"))) %>%
    data.matrix

X <- select(final.df, e_migdppcln, un_pop, area_sqkm, meanelev) %>%
    mutate(e_migdppcln = normalize(e_migdppcln),
           un_pop = log(un_pop) %>% normalize,
           area_sqkm = log(area_sqkm) %>% normalize,
           meanelev = log(meanelev) %>% normalize) %>%
    data.matrix

stopifnot(nrow(manifests) == nrow(manifests_sd),
          ncol(manifests) == ncol(manifests_sd))

data <- list(N = nrow(manifests),
             J = length(constraint_vars),
             manifest_obs = manifests,
             manifest_se = manifests_sd,
             T = nrow(X),
             I = ncol(X),
             X = X,
             exec_idx = final.df$reduced_idx,
             n_countries = n_distinct(final.df$country_name),
             country_id = as.factor(final.df$country_name) %>% as.numeric,
             y = final.df$lepisode_onset)
str(data)

save(data, final.df, file = "data/prepped_data.RData")
