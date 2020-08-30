#' Posterior parameter plot
#'
#' Plots the posterior point estimate and 80 percent credible interval
#' per parameter.
#'
#' @param x Either a posterior object created using [read_post()] or a
#'     matrix where each column is a separate parameter with multiple
#'     rows per posterior draw.
#' @param pars Parameters to extract if `x` is a posterior object.
#' @param hline Draw horizontal intercept at 0.
#'
#' @return A ggplot plotting object.
#'
#' @export
plot_pars <- function(x, ...) UseMethod("plot_pars", x)

#' @export
plot_pars.matrix <- function(x, hline = F) {
    df <- post_summarise(x, probs = c(0.10, 0.5, 0.9)) %>%
        dplyr::rename(codelow = `10%`,
                      median = `50%`,
                      codehigh = `90%`) %>%
        dplyr::mutate(parameter = factor(parameter, levels = parameter))

    p <- ggplot(df, aes_(x = ~parameter, y = ~median)) +
        geom_errorbar(aes_(x = ~parameter, ymin = ~codelow, ymax = ~codehigh),
                      color = "#0072B2", width = 0, size = 1) +
        geom_point(fill = "#56B4E9", color = "#0072B2", size = 1.5, shape = 21) +
        theme_tufte() +
        theme(panel.background = element_blank(),
              axis.line = element_line(color = "black"),
              axis.text.x = element_text(angle = 45, hjust = 1),
              axis.title.x = element_blank(),
              axis.title.y = element_blank())

    if (isTRUE(hline))
        p <- p + geom_hline(yintercept = 0, alpha = 0.5,
                            color = "grey", linetype = "dotted")

    p
}

#' @export
plot_pars.posterior <- function(x, hline = F, pars = NULL) {
    if (is.null(pars))
        stop("Expected at least one parameter to extract from posterior object")

    extract(x, pars) %>%
        plot_pars.matrix(hline = hline)
}

#' Overlay parameter plots
#'
#' Given a list of posterior objects, `overlay_pars` extracts the
#' specified parameters and plots the parameter estimates (point
#' estimate + 80 percent CIs) as a single overlayed plot.
#'
#' @param ... Variable number of posterior objects
#' @param pars Parameters to extract
#' @param legend_labels Optional CharacterVector labeling each
#'     posterior object in the plot's legend.
#'
#' @export
overlay_pars <- function(pars = NULL, legend_labels = NULL, ...) {
    args <- list(...)
    if (any(sapply(args, Negate(is.posterior))))
        stop("ovelay_pars supports only posterior objects as input", call. = F)

    ll <- lapply(seq_along(args), function(i) {
        post_summarise(args[[i]], pars = pars, probs = c(0.10, 0.50, 0.90)) %>%
            dplyr::rename(codelow = `10%`, median = `50%`, codehigh = `90%`) %>%
            dplyr::mutate(parameter = factor(parameter, levels = parameter),
                          model = i)
    })

    df <- dplyr::bind_rows(ll)

    if (!is.null(legend_labels)) {
        if (length(legend_labels) != length(args))
            stop("Mismatched legend label length", call. = F)

        df$model <- factor(legend_labels[df$model], levels = legend_labels)
    } else {
        df$model <- as.factor(df$model)
    }

    df$model <- as.factor(df$model)

    ggplot(df, aes_string(x = "parameter", y = "median", color = "model")) +
        geom_point(position = position_dodge(width = 0.8), size = 1.5, shape = 21) +
        geom_errorbar(aes_string(x = "parameter", ymin = "codelow", ymax = "codehigh"),
                      width = 0, size = 1, position = position_dodge(width = 0.8)) +
        geom_hline(yintercept = 0, alpha = 0.5, color = "grey", linetype = "dotted") +
        theme_tufte() +
        scale_color_colorblind() +
        theme(panel.background = element_blank(),
              legend.title = element_blank(),
              axis.line = element_line(color = "black"),
              axis.text.x = element_text(angle = 45, hjust = 1),
              axis.title.x = element_blank(),
              axis.title.y = element_blank())
}

#' Posterior density plot
#'
#' Plots the density curves for the first `n` posterior draws from the
#' posterior matrix `m`.
#'
#' @param m Posterior matrix
#' @param n Number of posterior draws to be used
#' @param groups Grouping factor to separate observations
#'
#' @export
plot_dens <- function(m, n = 50, groups = NULL) {
    # TODO: create proper S3 methods for this function

    if (is.null(groups))
        stop("Missing grouping variable")

    df <- t(m[1:n, ]) %>% as.data.frame %>%
        mutate(id = as.factor(groups)) %>%
        tidyr::gather(iteration, value, -id)


    ggplot(df, aes(value, group = interaction(iteration, id), colour = id)) +
        stat_density(position = "identity", geom = "line",
                     n = 1024, alpha = 0.2) +
        theme_tufte() +
        scale_color_colorblind() +
        theme(panel.background = element_blank(),
              legend.position = c(0.9, 0.5),
              legend.title = element_blank(),
              axis.line = element_line(color = "black"),
              axis.title.x = element_blank(),
              axis.title.y = element_blank(),
              axis.text.y = element_blank(),
              axis.ticks.y = element_blank()) +
        coord_cartesian(expand = F)
}

#' Tie Fighter Plot
#'
#' Plots posterior intervals for each country-year for a summarised
#' parameter.
#'
#' @param df DataFrame containing `country_name`, `year`, and the
#'     summary statistics for a selected parameter (`codelow`,
#'     `median`, `codehigh`)
#'
#' @details Unlike the other plotting functions, `tfplot` does not
#'     accept as input the raw posteriors. This is because it's a
#'     relatively inflexible function that requires `country_name` and
#'     `year` to already be matched for each observation.
#'
#' @export
tfplot <- function(df) {
    # Couple of simple checks. Not too exhaustive since this is a
    # fairly narrow use function.
    expected <- c("country_name", "year", "median", "codehigh",
                  "codelow")

    if (length(d <- setdiff(expected, colnames(df))) > 0)
        sprintf("Missing columns: %s", paste(d, collapse = ", ")) %>%
            stop(call. = F)

    if (dplyr::n_distinct(df$year) != 2)
        stop("Unexpected number of unique years", call. = F)

    levels <- dplyr::filter(df, year == dplyr::last(year))
    levels <- dplyr::arrange(levels, median) %$% country_name

    df$country_name <- factor(df$country_name, levels = levels)

    ggplot(df, aes_string("country_name", "median", colour = "year")) +
        geom_errorbar(aes_string(ymax = "codehigh", ymin = "codelow"),
                      position = position_dodge(width = 0.5)) +
        theme_tufte() +
        scale_color_colorblind() +
        theme(axis.title.x = element_blank(),
              axis.title.y = element_blank(),
              legend.title = element_blank()) +
        coord_flip()
}
