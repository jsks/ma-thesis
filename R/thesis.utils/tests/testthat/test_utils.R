test_that("calc_peace_yrs", {
    years <- 1900:1905
    ongoing <- rep(0, 6)

    expect_identical(calc_peace_yrs(years, ongoing), c(0, 1:5))
    expect_error(calc_peace_yrs(years, ongoing[-1]),
                 "Mismatched vector lengths")

    years <- 1900:1905
    ongoing <- c(1, 0, 1, 0, 0, 0)

    expect_identical(calc_peace_yrs(years, ongoing),
                     c(0, 0, 1, 0, 1, 2))

    years <- 1900:1905
    ongoing <- c(0, 0, 0, 0, 1, 0)

    expect_identical(calc_peace_yrs(years, ongoing),
                     c(0, 1, 2, 3, 4, 0))

    years <- 1900:1909
    ongoing <- c(rep(0, 4), 1, rep(0, 5))

    expect_identical(calc_peace_yrs(years, ongoing),
                     c(0, 1:4, 0, 1:4))

    years <- c(1900, 1902:1904)
    ongoing <- rep(0, 4)

    expect_error(calc_peace_yrs(years, ongoing),
                 "Breaks found in years vector")

    years <- c(1900, 1903, 1901, 1902)
    ongoing <- rep(0, 4)

    expect_error(calc_peace_yrs(years, ongoing),
                 "Unsorted years vector")
})

test_that("normalize", {
    fn <- function(x) as.vector(scale(x))
    x <- 1:10

    expect_identical(normalize(x), fn(x))
    expect_equal(mean(normalize(x)), 0)
    expect_equal(stats::sd(normalize(x)), 1)
    expect_equal(normalize(rep(5, 5)), rep(NaN, 5))
    expect_error(suppressWarnings(normalize(letters[1:3])))

    x <- c(NA, 1:10, NA)
    expect_identical(normalize(x), fn(x))
})

test_that("to_idx", {
    years <- rep(1900:1902, 3)
    expect_identical(to_idx(years), c(1, 2, 3, 1, 2, 3, 1, 2, 3))

    years <- c(1901, 1900, 1901, 1901, 1905)
    expect_identical(to_idx(years), c(2, 1, 2, 2, 3))
    expect_identical(to_idx(years, unique(years)), c(1, 2, 1, 1, 3))

    countries <- c("SWE", "AFG", "FRA")
    expect_identical(to_idx(countries), c(3, 1, 2))
})

test_that("consecutive", {
    years <- c(1900:1903, 1905:1906)

    expect_identical(consecutive(years), c(1L, 1L, 1L, 1L, 2L, 2L))
    expect_identical(suppressWarnings(consecutive(c(1, NA, 2, 2))),
                     c(1L, rep(NA_integer_, 3L)))
    expect_warning(consecutive(c(1, NA, 2, 2)))
    expect_error(suppressWarnings(consecutive(letters[1:3])))
})

test_that("collapse_changes", {
    x <- c(rep(10, 2), rep(3, 4), 2, 1)

    expect_identical(collapse_changes(x), c(rep(1, 2), rep(2, 4), 3, 4))

    x <- c(rep("USA", 3), "SWE", rep("NOR", 2))
    expect_identical(collapse_changes(x), c(rep(1, 3), 2, 3, 3))
})

test_that("explode", {
    x <- data.frame(x = 1:3, from = rep(1, 3), to = 2:4)
    out <- data.frame(x = c(rep(1, 2), rep(2, 3), rep(3, 4)),
                      from = rep(1, 9),
                      to = c(rep(2, 2), rep(3, 3), rep(4, 4)),
                      sequence = c(1:2, 1:3, 1:4))

    expect_equal(explode(x, x$from, x$to), out)
    expect_error(explode(x))
    expect_error(explode(x, x$from, 1))

    x <- data.frame(x = c("SWE", "USA"),
                    y = 1:2,
                    from = c(1900, 1905),
                    to = c(1900, 1906),
                    stringsAsFactors = F)
    out <- data.frame(x = c("SWE", "USA", "USA"),
                      y = c(1, 2, 2),
                      from = c(1900, 1905, 1905),
                      to = c(1900, 1906, 1906),
                      sequence = c(1900, 1905, 1906),
                      stringsAsFactors = F)
    expect_equal(explode(x, x$from, x$to), out)

})
