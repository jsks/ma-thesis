#' Summarise posterior distribution
#'
#' Calculates quantile intervals from a posterior distribution
#' represented either by a NumericMatrix where rows are posterior
#' draws or extracted directly from a `stanfit` object.
#'
#' @param x NumericMatrix or `stanfit` object
#' @param ... Arguments passed to methods
#'
#' @details By default, `post_summarise` will calculate 68% and 95%
#'     quantile intervals in addition to the posterior median.
#'
#' @export
post_summarise <- function(x, ...)
    UseMethod("post_summarise", x)

#' @export
post_summarise.matrix <- function(x,
                                  fn = partial(stats::quantile, probs = c(0.025, 0.5, 0.975)),
                                  ...) {
    df <- apply(x, 2, fn) %>% t %>% as.data.frame
    rownames(df) <- NULL
    df$parameter <- colnames(x)

    df
}

#' @export
post_summarise.CmdStanMCMC <- function(x, pars = NULL, ...) {
    if (is.null(pars))
        stop("Expected at least one parameter to extract from CmdStanMCMC")

    m <- as.matrix(x, pars)
    post_summarise.matrix(m, ...)
}

#' @export
as.matrix.CmdStanMCMC <- function(x, pars = NULL, ...) {
    if (is.null(pars))
        stop("Expected at least one parameter to extract from CmdStanMCMC")

    # This is memoised by cmdstanr
    draws <- x$draws()

    v <- dimnames(draws)$variable
    idx <- sapply(pars, function(p) {
        re <- paste0('^', p, '(\\[.*\\])?$')
        grep(re, v)
    }) %>% unlist
    output <- draws[,, idx]

    new_dims <- c(dim(output)[1] * dim(output)[2], dim(output)[3])
    dim(output) <- new_dims

    colnames(output) <- v[idx]
    output
}
