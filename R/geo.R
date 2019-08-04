#!/usr/bin/env Rscript

suppressMessages(library(dplyr))
suppressMessages(library(sf))
suppressMessages(library(thesis.utils))

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

    # We take the start year NOT from the neighbour, but from the
    # target country. This means that we'll of course end up with
    # dyads outside of the start date for the neighbouring country. We
    # do this because we want to include colonial conflicts as
    # neighbouring conflicts (ex: Algeria <1962).
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
    explode(from = .$start_year, to = .$end_year) %>%
    rename(year = sequence) %>%
    distinct(country_name, gwid, neighbour, neighbour_gwid, year)

saveRDS(neighbours.df, "data/neighbours.rds")
