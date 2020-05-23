#!/usr/bin/env Rscript
#
# ./test_data.R <test_dir>
#
# Generates fake data for testing `extract`. Precompute expected
# outputs to save time so that the input doesn't have to be
# dynamically read in for each test.
###

suppressMessages(library(dplyr))

test_dir <- commandArgs(trailingOnly = T)
if (length(test_dir) == 0)
    stop("Missing test directory argument", call. = F)

dir.create(test_dir, showWarnings = F)

small_matrix <- matrix(1:6, 2, 3)
colnames(small_matrix) <- c("alpha", "beta", "alpha_beta")

f <- file.path(test_dir, "small_matrix.csv")
write.csv(small_matrix, f, quote = F, row.names = F)

df <- as.data.frame(small_matrix)

f <- file.path(test_dir, "alpha.csv")
select(df, alpha) %>%
    write.csv(f, quote = F, row.names = F)

f <- file.path(test_dir, "alpha_beta.csv")
select(df, alpha_beta) %>%
    write.csv(f, quote = F, row.names = F)

columns <- 500
rows <- 2000

large_matrix <- matrix(rnorm(rows * columns), rows, columns)
colnames(large_matrix) <- paste0(1:columns, "_", letters)

f <- file.path(test_dir, "large_matrix.csv")
headers <- c("# Comment",
             paste0(colnames(large_matrix), collapse = ","),
             "# Trailing Comment")
writeLines(headers, f)

write.table(large_matrix, f, quote = F, sep = ",", col.names = F,
            row.names = F, append = T)

df <- as.data.frame(large_matrix)

f <- file.path(test_dir, "multiple_digit_all_rows.csv")
select(df, matches("^\\d{2,}_\\S$")) %>%
    write.csv(f, quote = F, row.names = F)

f <- file.path(test_dir, "single_digit_100_rows.csv")
select(df, matches("^\\d_\\S$")) %>%
    slice(1:100) %>%
    write.csv(f, quote = F, row.names = F)

f <- file.path(test_dir, "multiple_digits_not_a_100_rows.csv")
select(df, matches("\\d_[^a]$")) %>%
    slice(1:100) %>%
    write.csv(f, quote = F, row.names = F)
