#!/usr/bin/env Rscript

suppressMessages(library(dplyr))
suppressMessages(library(sf))

source("R/functions.R")

cshapes <- st_read("data/raw/cshapes_0.6/cshapes.shp") %>%
    select(country_name = CNTRY_NAME, gwid = GWCODE,
           start_year = GWSYEAR, end_year = GWEYEAR) %>%
    mutate(country_name = as.character(country_name),
           end_year = ifelse(end_year == 2016, 2017, end_year)) %>%
    filter(gwid != -1)

neighbours.ll <- st_intersects(cshapes)
ll <- lapply(seq_along(neighbours.ll), function(i) {
    v <- neighbours.ll[[i]]
    if (length(v) == 0)
        return(NULL)

    data.frame(country_name = cshapes$country_name[i],
               gwid = cshapes$gwid[i],
               neighbour = cshapes$country_name[v],
               neighbour_gwid = cshapes$gwid[v],
               start_year = cshapes$start_year[i],
               end_year = cshapes$end_year[v],
               stringsAsFactors = F)
})

neighbours.df <- bind_rows(ll) %>%
    filter(country_name != neighbour, start_year <= end_year) %>%
    explode %>%
    distinct(country_name, gwid, neighbour, neighbour_gwid, year)

saveRDS(neighbours.df, "data/neighbours.rds")