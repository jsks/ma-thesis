#test_that("post_summarise", {
#    # This is a pretty contrived example
#    m <- matrix(1:100, 100, 1)
#    y <- data.frame(`2.5%` = 3.475,
#                    `16%` = 16.84,
#                    `50%` = 50.5,
#                    `84%` = 84.16,
#                    `97.5%` = 97.525,
#                    check.names = F)
#
#    expect_equal(post_summarise(m), y)
#
#    colnames(y)[c(1, 4)] <- c("hello", "goodbye")
#    y$parameter <- "A"
#    out <- post_summarise(m, par.names = "A",
#                          col.names = c(`2.5%` = "hello", `84%` = "goodbye"))
#
#    expect_equal(out, y)
#
#    y <- data.frame(`10%` = 10.9, `90%` = 90.1, check.names = F)
#
#    expect_equal(post_summarise(m, probs = c(.10, .9)), y)
#
#    expect_error(post_summarise(matrix()))
#    expect_error(post_summarise(m, col.names = letters[1:5]))
#    expect_error(post_summarise({ m[1, ] <- NA; m }))
#})
