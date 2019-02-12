#!/usr/local/bin/Rscript
DESCRIPTION <- commandArgs(TRUE)
DIRNAME <- dirname(DESCRIPTION)
options(repos = c(CRAN = "https://cloud.r-project.org"))
setRepositories(ind = 1:4)
info <- as.list(read.dcf(DESCRIPTION)[1,])
names(info) <- tolower(names(info))

# Install R packages
pkgs <- c("curl", "jsonlite", "remotes")
needs_install <- is.na(match(pkgs, row.names(installed.packages())))
if(any(needs_install)){
	install.packages(pkgs[needs_install], quiet = TRUE)
}
if(nchar(Sys.getenv("AUTOBREW_CHECK"))){
	update(remotes::dev_package_deps(DIRNAME, dependencies = TRUE), quiet = TRUE)
} else {
	update(remotes::dev_package_deps(DIRNAME), quiet = TRUE)
}

# Finds homebrew build dependencies for a package
url <- paste0("https://sysreqs.r-hub.io/pkg/", info$package)
res <- jsonlite::fromJSON(url, simplifyVector = FALSE)

# Also check raw SysRequirements
if(length(info$systemrequirements)){
  url <- paste0("https://sysreqs.r-hub.io/map/", curl::curl_escape(info$systemrequirements))
  res <- c(res, jsonlite::fromJSON(url, simplifyVector = FALSE))
}

deps <- unique(unlist(lapply(res, function(x){x[[1]]$platforms$OSX})))
writeLines(paste(deps, collapse = " "), file.path(DIRNAME, "PKG_DEPS"))
