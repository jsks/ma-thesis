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

lg_vars <- grep("^v2lg", constraint_vars, value = T)
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
    select(country_name, year, lonset, lepisode_onset, peace_yrs,
           one_of(constraint_vars), one_of(paste0(constraint_vars, "_sd")),
           e_migdppcln, e_migdpgro, pop_density, meanelev, ongoing,
           rlvt_groups_count, neighbour_conflict) %>%
    filter_at(constraint_vars, all_vars(!is.na(.))) %>%
    mutate(s = do.call(paste, lapply(c("country_name", constraint_vars), as.symbol)),
           reduced_idx = collapse_changes(s)) %>%
    select(-s)

constraints.df <- select(final.df, country_name, year, reduced_idx,
                         one_of(constraint_vars),
                         one_of(paste0(constraint_vars, "_sd"))) %>%
    group_by(country_name, reduced_idx) %>%
    filter(year == min(year)) %>%
    ungroup

final.df %<>% na.omit

setdiff(unique(merged.df$country_name), final.df$country_name) %>%
    paste(collapse = "; ") %>%
    sprintf("Lost due to missingness: %s", .)

info(final.df)
save(constraint_vars, final.df, constraints.df,
     file = "data/prepped_data.RData")
