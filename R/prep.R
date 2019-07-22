#!/usr/bin/env Rscript

suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(magrittr))

fn <- function(f) {
    print(f)

    df <- fread(f, skip = 1, header = F)
    v <- apply(df[, -1], 2, min, na.rm = T)

    list(mean = mean(v), sd = sd(v))
}

variables <- c("v2lginvstp", "v2lgfunds", "v2lgqstexp")
re <- paste0(variables, collapse = "|")

files <- list.files("./data/vdem_posteriors", re, full.names = T)
stopifnot(length(files) == 3)

min.df <- lapply(files, fn) %>%
    bind_rows %>%
    mutate(variable = variables)

###
# Grab gap years and country-years where lg is missing from full V-Dem
# dataset.
vdem <- readRDS("data/merged_data.rds") %>%
    select(country_name, year, v2lgbicam, matches(re),
           -matches("codehigh|codelow"))

print(colnames(vdem))

for (v2 in variables) {
    vdem[[v2]] <- ifelse(vdem$v2lgbicam == 0,
                         min.df$mean[min.df$variable == v2],
                         vdem[[v2]])

    vdem[[paste0(v2, "_sd")]] <- ifelse(vdem$v2lgbicam == 0,
                                       min.df$sd[min.df$variable == v2],
                                       vdem[[paste0(v2, "_sd")]])
}

# TODO: gaps
final.df <- na.omit(vdem) %>%
    mutate(s = paste(v2lgqstexp, v2lginvstp, v2lgfunds)) %>%
    group_by(country_name) %>%
    mutate(idx = rle(s) %>% { rep(.$values, .$lengths) }) %>%
    group_by(idx, add = T) %>%
    filter(year == min(year)) %>%
    ungroup

manifests <- select(final.df, one_of(variables)) %>% data.matrix
manifests_sd <- select(final.df, one_of(paste0(variables, "_sd"))) %>%
    data.matrix

data <- list(N = nrow(manifests),
             J = length(variables),
             X_obs = manifests,
             X_se = manifests_sd)

save(data, final.df, file = "data/prepped_data.RData")
