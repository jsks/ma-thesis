locf_idx <- function(x) {
    x[x == 1] <- which(x == 1)
    x <- cummax(x)
    is.na(x) <- x == 0
    return(x)
}

normalize <- function(x) scale(x) %>% as.vector

to_idx <- function(x, ...) factor(x, ...) %>% as.numeric

consecutive <- function(x) cumsum(c(T, diff(x) != 1))

collapse_changes <- function(x) {
    v <- rle(x)
    rep_v <- rep(v$values, v$lengths)
    to_idx(rep_v, unique(rep_v))
}

info <- function(df) {
    sprintf("%d conflicts, %d episodes, %d countries, %s country-years",
            sum(df$lonset, na.rm = T),
            sum(df$lepisode_onset, na.rm = T),
            n_distinct(df$country_name),
            prettyNum(nrow(df), big.mark = ","))
}

explode <- function(df) {
    ll <- lapply(1:nrow(df), function(i) {
        start <- df$start_year[i]
        end <- df$end_year[i]

        len <- end - start + 1
        sub.df <- df[rep(i, len), ]
        sub.df$year <- start:end

        sub.df
    })

    bind_rows(ll)
}
