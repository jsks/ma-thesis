#' Calculate peace years
#'
#' Given a vector of years and a matching length vector of conflict
#' incidence, calculate the number of peace years since the last civil
#' conflict or the coding start, identified as the first element.
#'
#' @param years NumericVector of years
#' @param incidence NumericVector or LogicalVector of same size as
#'     `year` indicating conflict incidence
#'
#' @details This calculates the number of years of peace since either
#'     the last incidence of civil conflict or the coding start given
#'     by the first element in the `years` vector.
#'
#'     Note, peace years are calculated based on V-Dem countries,
#'     which means that gwid changes are not recorded as changes in
#'     the fundamental status of a country. This only affects Serbia
#'     in 2006 and Czech Republic in 1993.
#'
#' @examples
#' years <- 1900:1910
#' ongoing <- sample(0:1, length(years), replace = TRUE)
#'
#' calc_peace_yrs(years, ongoing)
#'
#' @export
calc_peace_yrs <- function(years, incidence) {
    if (length(years) != length(incidence))
        stop("Mismatched vector lengths", call. = F)
    else if (!identical(years, sort(years)))
        stop("Unsorted years vector", call. = F)
    else if (any(consecutive(years) != 1))
        stop("Breaks found in years vector", call. = F)

    locf_idx <- function(x) {
        x[x == 1] <- which(x == 1)
        lx <- c(NA, dplyr::lag(x)[-1] %>% cummax)
        is.na(lx) <- lx == 0

        return(lx)
    }

    x <- years[locf_idx(incidence)]
    out <- years - ifelse(is.na(x), years[1] - 1, x) - 1

    pmax(out, 0)
}

#' Normalize vector
#'
#' Simple wrapper around the default arguments to [scale()] which
#' transforms a numeric matrix according to `(x - mean(x)) / sd(x)`.
#'
#' @param x NumericVector
#'
#' @examples
#' normalize(1:10)
#'
#' @export
normalize <- function(x) (x - mean(x, na.rm = T)) / stats::sd(x, na.rm = T)

#' Create index
#'
#' Create a NumericVector of index positions from the unique
#' categories of a given vector, `x`.
#'
#' @param x Vector of any type
#' @param ... Additional arguments passed to [factor()]
#'
#' @details This is useful for one thing only: creating the input data
#'     list for Stan.
#'
#'     For partially pooled intercepts in Stan we need the index
#'     positions of each unique category associated with a given
#'     observation.
#'
#'     For example, matching a random intercept for N years involves
#'     estimating 1:N varying intercepts that need to be properly
#'     indexed in the final regression. See `stan/model.stan` and
#'     `R/model.R`.
#'
#' @return NumericVector indexing the original values of `x`.
#'
#' @examples
#' years <- rep(1900:1905, times = 2)
#' to_idx(years)
#'
#' @export
to_idx <- function(x, ...) factor(x, ...) %>% as.numeric

#' Find consecutive elements
#'
#' Given a NumericVector, return the grouping indices for consecutive
#' elements.
#'
#' @param x NumericVector
#'
#' @examples
#' consecutive(c(1900:1905, 1908:1910))
#'
#' @export
consecutive <- function(x) {
    if (anyNA(x))
        warning("NA's in given vector")

    cumsum(c(T, diff(x) != 1))
}

#' Collapse identical observations
#'
#' Given a vector of any type, return the grouping indices for
#' consecutively unchanged elements.
#'
#' @param x Vector of any type
#'
#' @examples
#' collapse_changes(c(rep(1, 3), 4, rep(3, 2)))
#'
#' @export
collapse_changes <- function(x) {
    v <- rle(x)
    rep_v <- rep(v$values, v$lengths)
    to_idx(rep_v, unique(rep_v))
}

#' Explode a data frame!
#'
#' Given a `data.frame`, repeat each row according to the inclusive
#' length of the sequence defined by `from` and `to`.
#'
#' @param df DataFrame
#' @param from NumericVector, starting value of sequence
#' @param to NumericVector, end value of sequence
#'
#' @details This is only used to expand a collapsed `data.frame` to a
#'     full country-year time series. In other words, given a
#'     `data.frame` where each row represents a range of years,
#'     `explode` will duplicate each row for each year in the range,
#'     if given as the `from` and `to` arguments.
#'
#' @return A `data.frame` with the added column, `sequence`, with the
#'     values defined by `from:to`.
#'
#' @examples
#' df <- data.frame(x = 1:3)
#' explode(df, from = rep(1, 3), to = 2:4)
#'
#' @export
explode <- function(df, from = NULL, to = NULL) {
    if (is.null(from) | is.null(to))
        stop("Missing from/to arguments", call. = F)
    else if (nrow(df) != length(from) | nrow(df) != length(to))
        stop("Length mismatch between data frame and from/to", call. = F)

    ll <- lapply(1:nrow(df), function(i) {
        start <- from[i]
        end <- to[i]

        len <- end - start + 1
        sub.df <- df[rep(i, len),, drop = F]

        # We could create `sequence.x` or `sequence.y`, but since our use case
        # for this function is so limited just throw an error since we really
        # shouldn't have this column defined from anywhere else.
        if ("sequence" %in% colnames(df))
            stop("`sequence` column already defined", call. = F)

        sub.df$sequence <- start:end
        sub.df
    })

    dplyr::bind_rows(ll)
}

#' Merging stats
#'
#' Extremely simply debugging function that does nothing more than
#' simply print out the number of conflict episodes, countries, and
#' country-years in a given data frame. Completely useless for any
#' generic task.
#'
#' @param df DataFrame
#'
#' @export
dbg_info <- function(df) {
    msg <- sprintf("%d conflict episodes, %d countries, %s country-years",
                   sum(df$lepisode_onset, na.rm = T),
                   dplyr::n_distinct(df$country_name),
                   prettyNum(nrow(df), big.mark = ","))

    print(msg)
}

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

#' Summarise posterior distribution
#'
#' Calculates quantile intervals from a posterior distribution
#' represented either by a NumericMatrix where rows represent
#' posterior draws or extracted directly from a `stanfit` object.
#'
#' @param x NumericMatrix or `stanfit` object
#' @param names Optional CharacterVector identifying the columns from
#'     the stanfit matrix.
#' @param probs Quantile probabilities to use when summarising `x`
#'
#' @examples
#' m <- matrix(c(rnorm(100), rnorm(100, 10, 5)), 100, 2)
#' post_summarise(m)
#'
#' @export
post_summarise <- function(x, names = NULL,
                           probs = c(0.025, 0.16, 0.5, 0.84, 0.975), ...)
    UseMethod("post_summarise")

#' @describeIn post_summarise Method for a NumericMatrix extracted
#'     from `stanfit` object
#' @export
post_summarise.matrix <- function(x, names = NULL,
                                  probs = c(0.025, 0.16, 0.5, 0.84, 0.975)) {
    if (!is.null(names)) {
        if (length(names) != ncol(x))
            stop("Name length mismatch")

        colnames(x) <- names
    }

    apply(x, 2, quantile, probs = probs) %>%
        t %>%
        as.data.frame %>%
        dplyr::mutate(par = colnames(x)) %>%
        rename(codelow95 = `2.5%`,
               codelow68 = `16%`,
               median = `50%`,
               codehigh68 = `84%`,
               codehigh95 = `97.5%`) %>%
        select(par, everything())
}

#' @param pars Parameters to extract from the given stanfit object
#'
#' @describeIn post_summarise Method for stanfit objects
#' @export
post_summarise.stanfit <- function(x, names = NULL,
                                   probs = c(0.025, 0.16, 0.5, 0.84, 0.975), pars) {
    m <- as.matrix(x, pars = pars)
    post_summarise.matrix(m, names, probs)
}
