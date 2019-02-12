#!/usr/local/bin/Rscript
options(repos = c(CRAN = "https://cloud.r-project.org"))
setRepositories(ind = 1:4)
pkgs <- commandArgs(TRUE)
out <- download.packages(pkgs, ".", type = 'source', quiet = TRUE, method = "libcurl")
if(!nrow(out))
	stop(sprintf("Failed to download package %s", pkgs))
cat(out[,2])
