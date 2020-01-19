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
post_summarise.posterior <- function(x, pars = NULL, ...) {
    if (is.null(pars))
        stop("Expected at least one parameter to extract from CmdStanMCMC")

    m <- extract(x, pars) %>% as.matrix
    post_summarise(m, ...)
}

#' @export
read_post <- function(file) {
    fit <- data.table::fread(file, data.table = F)

    b <- grepl("^[^.]+[.]", colnames(fit))
    if (any(b)) {
        colnames(fit)[b] <- sub("[.]", "[", colnames(fit)[b]) %>%
            sub("[.]", ",", .) %>%
            paste0("]")
    }

    structure(fit, class = c(class(fit), "posterior"))
}

#' @export
extract <- function(x, ...) UseMethod("extract", x)

#' @export
extract.posterior <- function(x, pars = NULL) {
    idx <- lapply(pars, function(p) {
        re <- paste0("^", p, "(\\[.*)?$")
        grep(re, colnames(x))
    }) %>% unlist %>% unique

    if (length(idx) == 0)
        data.frame()

    x[, idx, drop = F]
}
