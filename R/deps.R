#!/usr/bin/env Rscript
#
# Writes out all installed R packages into a csv. Should never be
# called directly; just a quick way to list all the packages versions
# in the `conflict_onset` image.
###

df <- installed.packages(noCache = T)[, c("Package", "Version")]
write.csv(df[order(df[, "Package"]), ], "Rdependencies.csv", row.names = F)
