#' Determine duplicated country-years
#'
#' Assert that there are no duplicated country-years in the given
#' DataFrame.
#'
#' @param df DataFrame
#'
#' @return If there are duplicated country-years in the given data
#'     frame, `assert_cy` will throw an error listing the offending
#'     countries. Otherwise, `NULL` is returned.
#'
#' @export
assert_cy <- function(df) {
    counts <- dplyr::count(df, country_name, year) %>%
        dplyr::filter(n > 1)

    if (nrow(counts) > 0) {
        dplyr::distinct(counts, country_name) %$%
            paste(country_name, collapse = "; ") %>%
            sprintf("Duplicated country-years: %s", .) %>%
            stop(call. = F)
    }
}


#' Merging stats
#'
#' Extremely simply debugging function that does nothing more than
#' simply print out the number of conflicts, countries, and
#' country-years in a given data frame. Completely useless for any
#' generic task.
#'
#' @param df DataFrame
#'
#' @export
dbg_info <- function(df, onset_col = "episode_onset") {
    if (!onset_col %in% colnames(df))
        sprintf("Can't find dependent variable: %s", onset_col) %>%
            stop(call. = F)

    msg <- sprintf("%d target onsets, %d countries, %s country-years",
                   sum(df[, onset_col], na.rm = T),
                   dplyr::n_distinct(df$country_name),
                   prettyNum(nrow(df), big.mark = ","))

    print(msg)
}
