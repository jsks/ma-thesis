#!/usr/bin/env Rscript

suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(magrittr))
suppressMessages(library(thesis.utils))

constraint_vars <- c("v2lginvstp", "v2lgfunds",
                     "v2lgqstexp", "v2lgoppart",
                     "v2juhcind", "v2juncind",
                     "v2juhccomp", "v2jucomp",
                     "v2exrescon", "v2lgotovst")

merged.df <- readRDS("data/merged_data.rds")
lg_vars <- grep("^v2lg", constraint_vars, value = T)

for (v2 in lg_vars) {
    merged.df[[v2]] <- ifelse(merged.df$v2lgbicam == 0,
                              Inf,
                              merged.df[[v2]])

    merged.df[[paste0(v2, "_sd")]] <- ifelse(merged.df$v2lgbicam == 0,
                                             Inf,
                                             merged.df[[paste0(v2, "_sd")]])
}

###
# Final dataset for model
final.df <- merged.df %>%
    select(country_name, year, lonset, lepisode_onset, peace_yrs,
           one_of(constraint_vars), one_of(paste0(constraint_vars, "_sd")),
           cgdppc, gdpgro, pop_density, meanelev, ongoing, v2x_horacc, v2xnp_pres,
           rlvt_groups_count, neighbour_conflict, v2lgbicam) %>%
    filter_at(constraint_vars, all_vars(!is.na(.))) %>%
    mutate(s = do.call(paste, lapply(c("country_name", constraint_vars), as.symbol)),
           reduced_idx = collapse_changes(s)) %>%
    select(-s)

constraints.df <- select(final.df, country_name, year, reduced_idx,
                         v2lgbicam, v2xnp_pres, v2x_horacc,
                         one_of(constraint_vars),
                         one_of(paste0(constraint_vars, "_sd"))) %>%
    group_by(country_name, reduced_idx) %>%
    filter(year == min(year)) %>%
    mutate(v2lgbicam = ifelse(v2lgbicam > 0, 1, 0)) %>%
    ungroup

final.df %<>% na.omit

setdiff(unique(merged.df$country_name), final.df$country_name) %>%
    paste(collapse = "; ") %>%
    sprintf("Lost due to missingness: %s", .)

dbg_info(final.df)
save(constraint_vars, final.df, constraints.df,
     file = "data/prepped_data.RData")

# Final assertion
assert_cy(final.df)
