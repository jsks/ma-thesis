#!/usr/bin/env Rscript
#
# ./test_data.R <test_dir>
#
# Generates fake data for testing `extract`. Precompute expected
# outputs to save time so that the input doesn't have to be
# dynamically read in for each test.
###

suppressMessages(library(docopt))

doc <- "usage: ./test_data.R <test_dir>"
args <- docopt(doc)
test_dir <- args$test_dir

dir.create(test_dir, showWarnings = F)

small_matrix <- matrix(1:6, 2, 3)
colnames(small_matrix) <- c("alpha", "beta", "alpha_beta")

f <- file.path(test_dir, "small_matrix.csv")
write.csv(small_matrix, f, quote = F, row.names = F)

df <- as.data.frame(small_matrix)

f <- file.path(test_dir, "alpha.csv")
write.csv(small_matrix[, "alpha", drop = F], f, quote = F, row.names = F)

f <- file.path(test_dir, "alpha_beta.csv")
write.csv(small_matrix[, "alpha_beta", drop = F], f, quote = F, row.names = F)

columns <- 100000
rows <- 5

large_matrix <- matrix(rnorm(rows * columns), rows, columns)
colnames(large_matrix) <- paste0(1:columns, "_", letters)

f <- file.path(test_dir, "large_matrix.csv")
headers <- c("# Comment",
             paste0(colnames(large_matrix), collapse = ","),
             "# Trailing Comment")
writeLines(headers, f)

write.table(large_matrix, f, quote = F, sep = ",", col.names = F,
            row.names = F, append = T)

f <- file.path(test_dir, "multiple_digit_a.csv")
b <- grepl("^\\d{2,}_a$", colnames(large_matrix))
write.csv(large_matrix[, b], f, quote = F, row.names = F)

f <- file.path(test_dir, "single_digit_2_rows.csv")
b <- grepl("^\\d_\\S$", colnames(large_matrix))
write.csv(large_matrix[1:2, b], f, quote = F, row.names = F)

f <- file.path(test_dir, "multiple_digits_not_1.csv")
b <- substring(colnames(large_matrix), 1, 1) != 1
write.csv(large_matrix[, b], f, quote = F, row.names = F)
