test_that("post_summarise", {
    # This is a pretty contrived example
    m <- matrix(1:100, 100, 1)
    out <- data.frame(`2.5%` = 3.475,
                      `16%` = 16.84,
                      `50%` = 50.5,
                      `84%` = 84.16,
                      `97.5%` = 97.525,
                      check.names = F)

    expect_equal(post_summarise(m), out)

    out$par <- "A"
    expect_equal(post_summarise(m, names = "A"), out)

    out <- data.frame(`10%` = 10.9, `90%` = 90.1, check.names = F)
    expect_equal(post_summarise(m, probs = c(.10, .9)), out)
    expect_error(post_summarise(matrix()))
})
