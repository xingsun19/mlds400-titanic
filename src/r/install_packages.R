# stats and utils ship with R. These are the only additional runtime packages.
versions <- c(jsonlite = "2.0.0", digest = "0.6.37")
options(timeout = 180)

for (package in names(versions)) {
  expected <- versions[[package]]
  installed <- tryCatch(as.character(packageVersion(package)), error = function(e) "")
  if (installed != expected) {
    filename <- sprintf("%s_%s.tar.gz", package, expected)
    urls <- c(
      paste0("https://cloud.r-project.org/src/contrib/", filename),
      paste0("https://cloud.r-project.org/src/contrib/Archive/", package, "/", filename)
    )
    archive <- tempfile(fileext = ".tar.gz")
    downloaded <- FALSE
    for (url in urls) {
      status <- tryCatch(
        suppressWarnings(download.file(url, archive, mode = "wb", quiet = TRUE)),
        error = function(e) 1L
      )
      if (identical(status, 0L)) {
        downloaded <- TRUE
        break
      }
    }
    if (!downloaded) stop("Cannot download pinned CRAN package: ", filename)
    install.packages(archive, repos = NULL, type = "source")
    unlink(archive)
  }
  actual <- as.character(packageVersion(package))
  if (actual != expected) stop("Version mismatch for ", package, ": ", actual)
  cat(package, actual, "ready\n")
}
cat(R.version.string, "\nR dependencies verified.\n")
