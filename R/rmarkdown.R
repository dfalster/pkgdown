#' Render RMarkdown document in a fresh session
#'
#' @noRd
render_rmarkdown <- function(input, output, ..., quiet = TRUE) {

  if (!file_exists(input)) {
    stop("Can't find ", src_path(input), call. = FALSE)
  }

  args <- list(
    input = input,
    output_file = path_file(output),
    output_dir = path_dir(output),
    intermediates_dir = tempdir(),
    encoding = "UTF-8",
    envir = globalenv(),
    ...,
    quiet = quiet
  )

  path <- callr::r_safe(
    function(...) rmarkdown::render(...),
    args = args,
    show = !quiet
  )

  # Copy over images needed by the document
  ext <- rmarkdown::find_external_resources(input, "UTF-8")
  ext_path <- ext$path[ext$web]
  file_copy(
    path(path_dir(input), ext_path),
    path(path_dir(output), ext_path),
    overwrite = TRUE
  )

  path
}
