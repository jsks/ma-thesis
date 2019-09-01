#' Summarise posterior distribution
#'
#' Calculates quantile intervals from a posterior distribution
#' represented either by a NumericMatrix where rows are posterior
#' draws or extracted directly from a `stanfit` object.
#'
#' @param x NumericMatrix or `stanfit` object
#' @param par.names Optional CharacterVector identifying the columns from
#'     the stanfit matrix.
#' @param col.names Optional named CharacterVector replacing the
#'     default column names specified by the vector names with the
#'     given vector elements. Note: default column names are according
#'     to [quantile()], *i.e.* as percentage intervals.
#' @param probs Quantile probabilities to use when summarising `x`
#' @param ... Arguments passed to methods
#'
#' @details By default, `post_summarise` will calculate 68% and 95%
#'     quantile intervals in addition to the posterior median.
#'
#' @examples
#' m <- matrix(c(rnorm(100), rnorm(100, 10, 5)), 100, 2)
#' post_summarise(m)
#'
#' post_summarise(m, probs = c(0.2, 0.8),
#'                col.names = c(`20%` = "codelow", `80%` = "codehigh"))
#'
#' @export
post_summarise <- function(x,
                           par.names = NULL,
                           col.names = NULL,
                           probs = c(0.025, 0.16, 0.5, 0.84, 0.975), ...)
    UseMethod("post_summarise")

#' @describeIn post_summarise Method for a NumericMatrix extracted
#'     from `stanfit` object
#' @export
post_summarise.matrix <- function(x,
                                  par.names = NULL,
                                  col.names = NULL,
                                  probs = c(0.025, 0.16, 0.5, 0.84, 0.975), ...) {
    if (anyNA(x))
        stop("NA's in posterior matrix")

    df <- apply(x, 2, stats::quantile, probs = probs) %>% t %>% as.data.frame
    rownames(df) <- NULL

    df$parameter <- if (is.null(par.names)) colnames(x) else par.names

    # Remember kids, safety first.
    if (!is.null(col.names)) {
        if (is.null(names(col.names)))
            stop("Missing match labels for `col.names`")

        v <- col.names[match(colnames(df), names(col.names))]
        colnames(df) <- ifelse(is.na(v), colnames(df), v)
    }

    df
}

#' @param pars Parameters to extract from the given stanfit object
#'
#' @describeIn post_summarise Method for stanfit objects
#' @export
post_summarise.stanfit <- function(x,
                                   par.names = NULL,
                                   col.names = NULL,
                                   probs = c(0.025, 0.16, 0.5, 0.84, 0.975),
                                   pars = NULL,
                                   ...) {
    if (is.null(pars))
        stop("Expected at least one parameter to extract from stanfit")

    m <- as.matrix(x, pars = pars)
    post_summarise.matrix(m, par.names, col.names, probs)
}
