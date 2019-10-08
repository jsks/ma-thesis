#' Parameter plot
#'
#' Plots posterior median plus 68/95 quantile intervals for the given
#' parameters.
#'
#' @param m Posterior matrix where each column is a separate parameter
#' @param labels Optional CharacterVector of x-axis labels.
#'
#' @export
plot_pars <- function(m, labels = colnames(m)) {
    df <- post_summarise(m, names = labels) %>%
        dplyr::mutate(parameter = factor(parameter, levels = parameter))
    colnames(df)[-ncol(df)] <- c("codelow95", "codelow68", "median",
                                 "codehigh68", "codehigh95")

    # TODO
    ggplot(df, aes_(x = ~parameter, y = ~median)) +
        geom_hline(yintercept = 0, alpha = 0.5, color = "grey") +
        geom_errorbar(aes_(x = ~parameter, ymin = ~codelow95, ymax = ~codehigh95),
                      color = "#0072B2", linetype = "dotted", width = 0) +
        geom_errorbar(aes_(x = ~parameter, ymin = ~codelow68, ymax = ~codehigh68),
                      color = "#0072B2", width = 0, size = 1) +
        geom_point(fill = "#56B4E9", color = "#0072B2", size = 2.5, shape = 21) +
        theme(panel.background = element_blank(),
              axis.line = element_line(color = "black"),
              axis.text.x = element_text(angle = 45, hjust = 1),
              axis.title.x = element_blank()) +
        ylab("Parameter Estimates")
}

#' @export
plot_dens <- function(m, n = 50, groups = NULL) {
    df <- t(p_hat[1:n, ]) %>%
        as.data.frame %>%
        dplyr::mutate(id = as.factor(groups)) %>%
        tidyr::gather(iteration, value, -id) %>%
        dplyr::mutate(z = paste(id, iteration))

    ggplot(df, aes_(~value, group = ~z, color = ~id)) +
        stat_density(position = "identity", geom = "line",
                     n = 1024, alpha = 0.2) +
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
