#' Generate data
#'
#' @param nat_mat An \eqn{n\times p}{n x p} matrix of natural parameters, where
#'                \eqn{n} rows represent cells and \eqn{p} columns represent genes.
#' @param family A character string, one of \code{"gaussian"}, \code{"exponential"},
#'               \code{"poisson"}, \code{"neg_binom"}, \code{"curved_gaussian"},
#'               and \code{"bernoulli"}.
#' @param nuisance_param_vec Either \code{NA} or a single numeric or a length-\eqn{p}
#'                           vector of numerics representing nuisance parameters
#'                           (for \code{family = "neg_binom"} and
#'                           \code{family = "curved_gausian"}).
#'                           It is only required if
#'                           \code{family \%in\% c("neg_binom", "curved_gaussian")}.
#' @param library_size_vec Either \code{NA} or a length-\eqn{n} vector of numerics
#' @param tol Small positive value to determine the smallest possible value in the output
#'            matrix, useful for only \code{family = "curved_gaussian"}.
#'
#' @return The generated data matrix
#' @export
generate_data <- function(
    nat_mat, family, nuisance_param_vec = NA, library_size_vec = NA, tol = 1e-3
) {
    stopifnot(
        is.matrix(nat_mat),
        family %in% c("gaussian", "curved_gaussian", "exponential", "poisson", "neg_binom", "bernoulli"),
        length(nuisance_param_vec) %in% c(1, ncol(nat_mat))
    )
    stopifnot(.check_natural_param(nat_mat, family))

    n <- nrow(nat_mat)
    library_size_vec <- .parse_library_size(library_size_vec, n)

    # library_size_vec is now a length-n vector
    dat <- .generate_values(nat_mat, family, nuisance_param_vec, library_size_vec)
    dim(dat) <- dim(nat_mat)

    if(family == "curved_gaussian" && !is.na(tol))
        dat[dat < tol] <- tol

    dat
}


#####################

.check_natural_param <- function(nat_mat, family) {
   if(family %in% c("gaussian", "poisson", "bernoulli")) return(TRUE)
   if(family %in% c("neg_binom", "exponential")) return(all(nat_mat < 0))
   if(family == "curved_gaussian") return(all(nat_mat > 0))
}

.parse_library_size <- function(library_size_vec, n) {
    stopifnot(length(library_size_vec) %in% c(1, n))

    # If any element of library_size_vec is NA, set library_size_vec=NA
    # library_size_vec=NA has the same effect as library_size_vec=rep(1, n)
    if(length(library_size_vec) > 1 && any(is.na(library_size_vec)))
    {
        warning("NA found in library_size_vec, interpreted as library_size_vec=NA")
        library_size_vec = NA
    }
    if(length(library_size_vec) == 1 && is.na(library_size_vec))
        library_size_vec = rep(1, n)
    if(length(library_size_vec) == 1 && !is.na(library_size_vec))
        library_size_vec = rep(library_size_vec, n)

    library_size_vec
}

# TODO: for now, assume length(nuisance_param_vec) == 1
.generate_values <- function(nat_mat, family, nuisance_param_vec, library_size_vec) {

    stopifnot(
        length(nuisance_param_vec) == 1
    )
    n <- length(nat_mat)
    canon_mat <- .convert_natural_to_canonical(nat_mat, family)

    if(family == "gaussian") {
        stopifnot(!is.na(nuisance_param_vec))
        # Recycle nuisance_param_vec for each column of canon_mat
        vec <- stats::rnorm(n, mean = canon_mat * library_size_vec,
                            sd = nuisance_param_vec[1])

    } else if(family == "curved_gaussian") {
        stopifnot(!is.na(nuisance_param_vec))
        vec <- stats::rnorm(n, mean = canon_mat * library_size_vec,
                            sd = canon_mat * library_size_vec / nuisance_param_vec[1])

    } else if(family == "exponential") {
        vec <- stats::rexp(n, rate = canon_mat / library_size_vec)

    } else if(family == "poisson") {
        vec <- stats::rpois(n, lambda = canon_mat * library_size_vec)

    } else if(family == "neg_binom") {
        stopifnot(!is.na(nuisance_param_vec))
        vec <- stats::rnbinom(n, size = nuisance_param_vec[1], prob = 1 - canon_mat)

    } else if(family == "bernoulli") {
        vec <- stats::rbinom(n, size = 1, prob = canon_mat)

    } else {
        stop("unknown distribution family")
    }

    vec
}
