#!/usr/bin/env Rscript
#
# Generates a translation table between V-Dem country_id and gwno
# (Gleditsch-Ward).
###

library(dplyr)
library(magrittr)

# TODO: update country_unit table with 2018
utable <- readRDS("refs/vdem-country_unit.rds")
ctable <- readRDS("refs/vdem-country_table.rds") %>%
    rename(vdem_id = country_id)

# http://privatewww.essex.ac.uk/~ksg/data/iisystem.dat
gwno <- read.table("refs/iisystem.dat", sep = "\t", quote = "",
                  fileEncoding = "latin1", stringsAsFactors = F)

# http://privatewww.essex.ac.uk/~ksg/data/microstatessystem.dat
gwno_micro <- read.table("refs/microstatessystem.dat", sep = "\t",
                        quote = "", fileEncoding = "latin1",
                        stringsAsFactors = F)

gwno %<>% rbind(gwno_micro)
colnames(gwno) <- c("gwno", "gwno_text_id", "name", "gwno_start", "gwno_end")

gwno %<>% mutate(gwno_start = as.Date(gwno_start, format = "%d:%m:%Y"),
              gwno_end = as.Date(gwno_end, format = "%d:%m:%Y"),
              name = ifelse(grepl("Cote", name), "Cote D'Ivoire", name))

check <- . %>% filter(is.na(vdem_id)) %>% select(-vdem_id, -gwno_text_id)
to_year <- . %>% format("%Y") %>% as.numeric

ctable.merge <- select(ctable, name, vdem_id)

# Try first to match based on name, excluding the alternative gwno
# names in parantheses
ttable <- mutate(gwno, name = sub("\\(.*$", "", name) %>% trimws) %>%
    left_join(ctable.merge, by = "name")

# Preserve the original gwno names for later checking
ttable$name <- gwno$name

# The fun part, manually assign. We're currently dropping
# Austria-Hungary since we code them separately.
ttable %<>%
    mutate(vdem_id = case_when(name == "United States of America" ~ 20,
                               name == "Surinam" ~ 4,
                               name == "German Federal Republic" ~ 77,
                               name == "Württemberg" ~ 355,
                               name == "Mecklenburg-Schwerin" ~ 360,
                               name == "Czechoslovakia" ~ 157,
                               name == "Italy/Sardinia" ~ 82,
                               name == "Bosnia-Herzegovina" ~ 150,
                               name == "Rumania" ~ 190,
                               name == "Cote D'Ivoire" ~ 64,
                               name == "Congo" ~ 112, # Republic of Congo
                               name == "Tanzania/Tanganyika" ~ 47,
                               name == "Yemen, People's Republic of" ~ 23,
                               name == "Kyrgyz Republic" ~ 122,
                               name == "Korea, People's Republic of" ~ 41,
                               name == "Korea, Republic of" ~ 42,
                               name == "Myanmar (Burma)" ~ 10,
                               name == "Antigua & Barbuda" ~ 143,
                               name == "São Tomé and Principe" ~ 196,
                               name == "Federated States of Micronesia" ~ 181,
                               name == "Samoa/Western Samoa" ~ 194,
                               name == "East Timor" ~ 74,
                               T ~ vdem_id))

filter(ctable, !vdem_id %in% ttable$vdem_id, !grepl("\\*", name)) %>%
    nrow %>%
    sprintf("Lost %d rows from ctable", .)

filter(ttable, is.na(vdem_id)) %>%
    nrow %>%
    sprintf("Lost %d rows from gwno", .)

# By this point we should be mostly missing historical countries, plus
# Abkhazia and South Ossetia. The latter two aren't coded by V-Dem and
# the others won't be included in our analysis.
check(ttable)

print("Saving direct translation table")
write.csv(ttable, "refs/vdem_gwno_table.csv", na = "", row.names = F)

###
# We need a mergeable country-year table so we can restrict the years
# to only where vdem is coded. Start by setting the end_date to
# present and then exploding our `ttable`.
print("[WARN] Setting end date to 2018")
ttable %<>%
    mutate(gwno_end = case_when(gwno_end == "2012-12-31" ~ as.Date("2018-12-31"),
                                T ~ gwno_end))

explode <- function(df) {
    start <- df$gwno_start
    end <- df$gwno_end

    if (format(start, "%m-%d") != "-12-31")
        start <- paste0(to_year(start), "-12-31") %>% as.Date

    dates <- seq(start, end, by = "year")
    dates <- unique(c(df$gwno_start, df$gwno_end, dates)) %>% sort

    out <- df[rep(1, length(dates)), c("vdem_id", "gwno", "name")]
    out$dates <- dates

    out
}

ll <- lapply(1:nrow(ttable), function(i) explode(ttable[i, ]))
gwno_utable <- bind_rows(ll)

# For now we'll only be using V-Dem CY
gwno_utable.cy <- gwno_utable %>%
    mutate(year = format(dates, "%Y") %>% as.numeric) %>%
    distinct(gwno, year, .keep_all = T) %>%
    select(-dates)

# Finally, this will give use the gwno code and the V-Dem country
# coding units.
final.df <- select(utable, country_id, year, country_text_id) %>%
    left_join(gwno_utable.cy, by = c("country_id" = "vdem_id", "year")) %>%
    filter(!is.na(gwno))

sprintf("Ended with %d countries and %s total country-years",
        n_distinct(final.df$country_id),
        prettyNum(nrow(final.df), big.mark = ","))

print("Saving country-year unit table")
write.csv(final.df, "refs/vdem_gwno_units.csv", row.names = F)
