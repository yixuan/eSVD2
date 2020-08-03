initialize_esvd <- function(dat, family, k, nuisance_param_vec = NA, library_size_vec = NA,
                            config = initalization_default()){
 stopifnot(all(dat[!is.na(dat)] >= 0))
 
 dat <- .matrix_completion(dat, k = k)
 init_res <- .determine_initial_matrix(dat, family = family, k = k, max_val = config$max_val,
                                       tol = config$tol)
 
 if(config$method == "nndsvd"){
  nat_mat <- .initialization_nndsvd(init_res$nat_mat, k = k)
  nat_mat <- .fix_domain(nat_mat, dat, family = family, domain = init_res$domain)
  # WARNING: this might not fully fix the problem...
 } else {
   stop("config method not found")
 }

 # reparameterize
 .factorize_matrix(nat_mat, k = k, equal_covariance = T)
}

initalization_default <- function(method = "nnsvd", max_val = NA, tol = 1e-3){
 stopifnot(method %in% c("nnsvd", "sbm", "kmean_row", "kmean_column"))
 
 list(method = method, max_val = max_val, tol = tol)
}


################

#' Fill in missing values
#'
#' Uses \code{softImpute::softImpute} to fill in all the possible missing values.
#' This function enforces all the resulting entries to be non-negative.
#'
#' @param dat dataset where the \code{n} rows represent cells and \code{d} columns represent genes
#' @param k positive integer less than \code{min(c(nrow(dat), ncol(dat)))}
#'
#' @return a \code{n} by \code{p} matrix
.matrix_completion <- function(dat, k){
 if(any(is.na(dat))){
  lambda0_val <- softImpute::lambda0(dat)
  res <- softImpute::softImpute(dat, rank.max = k, lambda = min(30, lambda0_val/100))
  diag_mat <- .diag_matrix(res$d[1:k])
  pred_naive <- res$u %*% diag_mat %*% t(res$v)
  dat[which(is.na(dat))] <- pred_naive[which(is.na(dat))]
 }
 
 pmax(dat, 0)
}

#' Initialize the matrix of natural parameters
#'
#' This function first transforms each entry in \code{dat} according to the inverse function that maps
#' natural parameters to their expectation (according to \code{eSVD:::.mean_transformation}) and then
#' uses \code{eSVD:::.project_rank_feasibility} to get a rank-\code{k} approximation of this matrix
#' that lies within the domain of \code{family}
#'
#' @param dat dataset where the \code{n} rows represent cells and \code{d} columns represent genes.
#' @param k  positive integer less than \code{min(c(nrow(dat), ncol(dat)))}
#' @param family character (\code{"gaussian"}, \code{"exponential"}, \code{"poisson"}, \code{"neg_binom"},
#' or \code{"curved gaussian"})
#' @param max_val maximum magnitude of the inner product
#' @param tol numeric
#' @param ... extra arguments, such as nuisance parameters for \code{"neg_binom"}
#' or \code{"curved gaussian"} for \code{family}
#'
#' @return \code{n} by \code{p} matrix
.determine_initial_matrix <- function(dat, family, k, max_val = NA, tol = 1e-3, ...){
 stopifnot((is.na(max_val) || max_val >= 0), all(dat >= 0))
 
 domain <- .determine_domain(family, tol)
 if(!is.na(max_val)) domain <- .intersect_intervals(domain, c(-max_val, max_val))
 
 dat[which(dat <= tol)] <- tol/2
 nat_mat <- .mean_transformation(dat, family, ...)
 nat_mat <- pmax(nat_mat, domain[1])
 nat_mat <- pmin(nat_mat, domain[2])
 
 list(nat_mat = nat_mat, domain = domain)
}