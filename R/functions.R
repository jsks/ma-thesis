locf_idx <- function(x) {
    x[x == 1] <- which(x == 1)
    x <- cummax(x)
    is.na(x) <- x == 0
    return(x)
}

normalize <- function(x) scale(x) %>% as.vector

to_idx <- function(x) factor(x, levels = unique(x)) %>% as.numeric
