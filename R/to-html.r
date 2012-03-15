to_html <- function(x, ...) {
  UseMethod("to_html", x)
}

# Parse a complete Rd file
to_html.Rd_doc <- function(x, ...) {
  tags <- vapply(x, tag, FUN.VALUE = character(1))
  get_tags <- function(tag) x[tags == tag]
  get_tag <- function(tag) {
    if (tag %in% tags) {
      x[[which(tags == tag)]]
    }
  }
  
  # Remove line breaks between sections
  line_breaks <- tags == "TEXT"
  x <- x[!line_breaks]
  tags <- tags[!line_breaks]

  out <- list()

  # Capture name, title and aliasess
  out$name <- to_html(get_tag("name"))
  out$title <- to_html(get_tag("title"))
  out$aliases <- vapply(get_tags("alias"), to_html, character(1))
  out$keywords <- vapply(get_tags("keyword"), to_html, character(1))

  out$usage <- to_html(get_tag("usage"))
  out$arguments <- to_html(get_tag("arguments"))
  out$author <- to_html(get_tag("author"))

  out$seealso <- to_html(get_tag("seealso"))
  out$examples <- to_html(get_tag("examples"))
  
  # Everything else stays in original order, and becomes a list of sections.
  sections <- x[!(tags %in% c("name", "title", "alias", "keyword",
    "usage", "author", "seealso", "arguments", "examples"))]
  out$sections <- to_html(sections, topic = out$name)
  
  out
}

# A list of elements should stay as a list
to_html.list <- function(x, ...) {
  lapply(x, to_html)
}

# Elements that don't return anything ----------------------------------------

to_html.NULL <- function(x, ...) character(0)
to_html.COMMENT <- function(x, ...) character(0)
to_html.dontshow <- function(x, ...) character(0)
to_html.testonly <- function(x, ...) character(0)

# Various types of text ------------------------------------------------------

# All components inside a text string should be collapsed into a single string
to_html.TEXT <- function(x, ...) {
  str_c(unlist(to_html.list(x)), collapse = "")
  # Also need to do html escaping here and in to_html.RCODE
}

# If it's a character vector, we've got to the leaves of the tree
to_html.character <- function(x, ...) x

to_html.name <- function(x, ...) to_html(x[[1]])
to_html.title <- function(x, ...) to_html.TEXT(x)
to_html.usage <- function(x, ...) str_trim(to_html.TEXT(x))
to_html.alias <- function(x, ...) unlist(to_html.list(x))
to_html.keyword <- function(x, ...) unlist(to_html.list(x))
to_html.seealso <- function(x, ...) to_html.TEXT(x)


# Sections get a element called text and an element called content, which
# contains a list of paragraphs.
to_html.details <- function(x, ...) parse_section(x, "Details")
to_html.description <- function(x, ...) parse_section(x, "Description")
to_html.value <- function(x, ...) parse_section(x, "Value")
to_html.author <- function(x, ...) parse_section(x, "Authors")
to_html.references <- function(x, ...) parse_section(x, "References")
to_html.section <- function(x, ...) parse_section(x[[2]], to_html(x[[1]]))

parse_section <- function(x, title) {
  text <- to_html.TEXT(x)
  paras <- str_trim(str_split(text, "\\n\\n")[[1]])
  
  list(title = title, contents = paras)
}

# Examples ------------------------------------------------------------------

#' @importFrom evaluate evaluate
to_html.examples <- function(x, topic = "unknown", ...) {
  text <- to_html.TEXT(x)
  expr <- evaluate(text, globalenv())
  
  replay_html(expr, path_prefix = str_c(topic, "-"))
}

# Arguments ------------------------------------------------------------------

to_html.arguments <- function(x, ...) {
  items <- Filter(function(x) tag(x) == "item", x)  
  to_html(items)
}

to_html.item <- function(x, ...) {
  # If no subelements, then is an item from a itemise or enumerate, and 
  # is dealt with those methods
  if (length(x) == 0) return()
  
  list(name = to_html(x[[1]]), description = to_html.TEXT(x[[2]]))
}

# Equations ------------------------------------------------------------------

to_html.eqn <- function(x, ...) {
  stopifnot(length(x) <= 2)
  ascii_rep <- x[[length(x)]]
  
  str_c("<code class = 'eq'>", to_html.list(ascii_rep), "</code>")
}

to_html.deqn <- function(x, ...) {
  stopifnot(length(x) <= 2)
  ascii_rep <- x[[length(x)]]
  
  str_c("<pre class = 'eq'>", to_html.list(ascii_rep), "</code>")
}

# Links ----------------------------------------------------------------------
to_html.url <- function(x, ...) {
  stopifnot(length(x) == 1)
  str_c("<a href = '", x[[1]], "'>", x[[1]], "</a>")
}
to_html.href <- function(x, ...) {
  stopifnot(length(x) == 2)
  str_c("<a href = '", x[[1]], "'>", x[[2]], "</a>")
}
to_html.email <- function(x, ...) {
  stopifnot(length(x) == 2)
  str_c("<a href='mailto:", x[[1]], "'>", x[[2]], "</a>")
}

to_html.link <- function(x, ...) {
  stopifnot(length(x) == 1)

  opt <- attr(x, "Rd_option")
  if (is.null(opt)) {
    str_c("<a href='", x[[1]], ".html'>", x[[1]], "</a>")
  } else if (str_sub(opt, 1, 1) == "=") {
    topic <- str_sub(opt, 2, -1)
    
    str_c("<a href='", topic, ".html'>", x[[1]], "</a>")
  } else {
    str_c("<a href='http://www.inside-r.org/r-doc/", opt, "/", x[[1]], ">", 
      x[[1]], "</a>")
  }

}

# Miscellaneous --------------------------------------------------------------

# First element of enc is the encoded version (second is the ascii version)
to_html.enc <- function(x, ...) {
  to_html(x[[1]])
}

to_html.dontrun <- function(x, ...) {
  str_c(
    "## <strong>Not run</strong>:", 
    str_replace_all(to_html.TEXT(x), "\n", "\n#"), 
    "## <strong>End(Not run)</strong>"
  )
}

to_html.special <- function(x, ...) {
  txt <- to_html.TEXT(x)
  # replace '<' and '>' with html markings avoid browser misinterpretation
  txt <- str_replace_all(txt, "<", "&#60;")
  txt <- str_replace_all(txt, ">", "&#62;")
  txt <- str_replace_all(txt, "\\\\dots", "...")

  stupid <- unlist(str_match_all(txt, "\\\\[a-zA-Z]*"))
  for (i in seq_len(length(stupid))) {
    message("Uknown tag (", stupid[i], ") found in 'special' tag")
  }
  
  str_c("<em>", txt, "</em>")
}

to_html.method <- function(x, ...) {
  to_html(x[[2]])
}
to_html.S3method <- to_html.method
to_html.S4method <- to_html.method

# Conditionals and Sexprs ----------------------------------------------------

to_html.Sexpr <- function(x, ...) {
  expr <- eval(parse(text = x[[1]]), globalenv())

  con <- textConnection(expr)
  on.exit(close(con))
  rd <- parse_Rd(con, fragment = TRUE)
  
  to_html(rd)
}

to_html.if <- function(x, ...) {
  if (x[[1]] != "html") return()
  x[[2]]
}

to_html.ifelse <- function(x, ...) {
  if (x[[1]] == "html") x[[2]] else x[[3]]
}

# Tables ---------------------------------------------------------------------

to_html.tabular <- function(tabular) {
  #' make all alignements into left, right or center
  alignments <- unlist(str_split(tabular[[1]][[1]], ""))
  alignments <- alignments[nchar(alignments) > 0]
  #' remove line markings
  alignments <- alignments[alignments != "|"]
  alignments <- c("r" = "right", "l" = "left", "c" = "center")[alignments]
  
  rows <- tabular[[2]]
  column <- 1
  output <- character(length(rows))
  
  # Go through each item and reconstruct it if it is not a tab or carriage return
  # (Really need strategy that works like list: break into rows and then
  # columns)
  for (i in seq_along(rows)) {
    row_tag <- tag(rows[[i]])

    if (row_tag == "\\tab") {
      column <- column + 1
      output[i] <- str_c("</td><td align='", alignments[column], "'>")
    } else if (row_tag == "\\cr") {
      output[i] <- str_c("</td></tr><tr><td align='", alignments[1], "'>")
      column <- 1
    } else {
      output[i] <- to_html(rows[[i]])
    }
  }
  
  output[1] <- str_c("<table><tr><td align='", alignments[1], "'>", output[1])
  output[length(rows)] <- str_c(output[length(rows)], "</td></tr></table>")

  str_c(output, collapse = "")
}

# List -----------------------------------------------------------------------

to_html.itemize <- function(x, ...) {
  str_c("<ul>\n", parse_items(x), "</ul>\n")
}
to_html.enumerate <- function(x, ...) {
  str_c("<ol>\n", parse_items(x), "</ol>\n")
}

parse_items <- function(rd) {
  separator <- vapply(rd, function(x) tag(x) == "item", 
    FUN.VALUE = logical(1))
  
  group <- cumsum(separator)

  items <- split(rd, group)
  li <- vapply(items, function(x) str_c("<li>", to_html.TEXT(x), "</li>\n"),
    FUN.VALUE = character(1))
  
  str_c(li, collapse = "")
}

# Simple tags that need minimal processing -----------------------------------

to_html.Rd <- function(x, ...) {
  tag <- tag(x)
  
  if (is.null(tag)) {
    to_html.TEXT(x)
  } else if (!is.null(tag) && tag %in% names(simple_tags)) {
    # If we can process tag with just prefix & suffix, do so
    html <- simple_tags[[tag]]
    str_c(html[1], to_html.TEXT(x), html[2])
  } else {
    # Otherwise we don't know about this tag
    message("Unknown tag: ", tag)
    to_html.TEXT(x)
  }
}

simple_tags <- list(
  "acronym" =      c('<acronym>','</acronym>'),
  "bold" =         c("<b>", "</b>"),
  "cite" =         c("<cite>", "</cite>"),
  "code" =         c("<code>", "</code>"),
  "command" =      c("<code>", "</code>"),
  "cr" =           c("<br >", ""),
  "describe" =     c("<span class='describe'>", "</span>"),
  "dfn" =          c("<dfn>", "</dfn>"),
  "donttest" =     c("", ""),
  "dots" =         c("&#x2026;", ""),
  "dquote" =       c("&#147;", "&#148;"),
  "dQuote" =       c("&#147;", "&#148;"),
  "emph" =         c("<em>", "</em>"),
  "env" =          c('<span class = "env">', '</span>'),
  "file" =         c('&#145;<span class = "file">', '</span>&#146;'),
  "item" =         c("<li>", "</li>"),
  "kbd" =          c("<kbd>", "</kbd>"),
  "ldots" =        c("...", ""),
  "option" =       c('<span class = "option">',"</span>"),
  "out" =          c("", ""),
  "pkg" =          c('<span class = "pkg">',"</span>"),
  "preformatted" = c("<pre>","</pre>"),
  "R" =            c('<span style="R">R</span>', ""),
  "samp" =         c('<span class = "samp">',"</span>"),
  "sQuote" =       c("&#145;","&#146;"),
  "strong" =       c("<strong>", "</strong>"),
  "text" =         c("<p>", "</p>"),
  "var" =          c("<var>", "</var>"),
  "verb" =         c("<code>", "</code>"),

  "RCODE" =        c("", ""),
  "VERB" =         c("", ""),
  "LIST" =         c("<ul>", "</ul>")
)
