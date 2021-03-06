# Distribution: one-parameter Gaussian where sd = mean/scalar
# Natural parameter: m_{ij} = u_i^Tv_j
# Relation to canonical parameters: m_{ij} = 1/mu_{ij}
# Optimization problem: -log(m_{ij}) - scalar^2*a_{ij}^2*(-m_{ij}^2)/2 - scalar^2*a_{ij}*m_{ij}

.evaluate_objective.curved_gaussian <- function(
    dat, u_mat, v_mat, nuisance_param_vec, library_size_vec, ...
) {
    scalar <- nuisance_param_vec[1]

    # Check dimensions
    n <- nrow(dat)
    p <- ncol(dat)
    stopifnot(
        ncol(u_mat) == ncol(v_mat),
        nrow(u_mat) == n,
        nrow(v_mat) == p
    )

    # Compute natural parameters
    nat_mat <- tcrossprod(u_mat, v_mat)
    stopifnot(all(nat_mat > 0))

    # Only compute likelihood on non-missing data
    idx <- which(!is.na(dat))
    stopifnot(length(idx) > 0)

    nat_vals <- nat_mat[idx]
    dat_vals <- (dat / library_size_vec)[idx]
    negloglik <- -log(nat_vals) +
        scalar^2 * dat_vals^2 * nat_vals^2 / 2 -
        scalar^2 * dat_vals * nat_vals
    sum(negloglik) / n / p
}

# length(library_size) == 1 if current vector is u
# length(library_size) == n if current vector is v
.evaluate_objective_single.curved_gaussian <- function(
    current_vec, other_mat, dat_vec, nuisance_param_vec, library_size, ...
) {
    scalar <- nuisance_param_vec[1]

    stopifnot(
        length(current_vec) == ncol(other_mat),
        length(dat_vec) == nrow(other_mat)
    )

    nat_vec <- c(other_mat %*% current_vec)
    stopifnot(all(nat_vec > 0))
    idx <- which(!is.na(dat_vec))
    stopifnot(length(idx) > 0)

    nat_vals <- nat_vec[idx]
    dat_vals <- (dat_vec / library_size)[idx]
    negloglik <- -log(nat_vals) +
        scalar^2 * dat_vals^2 * nat_vals^2 / 2 -
        scalar^2 * dat_vals * nat_vals
    sum(negloglik) / length(dat_vec)
}

.gradient_vec.curved_gaussian <- function(
    current_vec, other_mat, dat_vec, nuisance_param_vec, library_size, ...
) {
    scalar <- nuisance_param_vec[1]

    stopifnot(
        length(current_vec) == ncol(other_mat),
        length(dat_vec) == nrow(other_mat)
    )

    nat_vec <- c(other_mat %*% current_vec)
    stopifnot(all(nat_vec > 0))
    idx <- which(!is.na(dat_vec))
    stopifnot(length(idx) > 0)

    nat_vals <- nat_vec[idx]
    dat_vals <- (dat_vec / library_size)[idx]
    other_vals <- other_mat[idx, , drop = FALSE]
    grad <- other_vals * (-1 / nat_vals + scalar^2 * dat_vals^2 * nat_vals -
                              scalar^2 * dat_vals)
    colSums(grad) / length(dat_vec)
}

.hessian_vec.curved_gaussian <- function(
    current_vec, other_mat, dat_vec, nuisance_param_vec, library_size, ...
) {
    scalar <- nuisance_param_vec[1]

    stopifnot(
        length(current_vec) == ncol(other_mat),
        length(dat_vec) == nrow(other_mat)
    )

    nat_vec <- c(other_mat %*% current_vec)
    stopifnot(all(nat_vec > 0))
    idx <- which(!is.na(dat_vec))
    stopifnot(length(idx) > 0)

    nat_vals <- nat_vec[idx]
    dat_vals <- (dat_vec / library_size)[idx]
    other_vals <- other_mat[idx, , drop = FALSE]

    term1 <- t(other_vals) %*% diag(1 / nat_vals^2) %*% other_vals
    term2 <- scalar^2 * t(other_vals) %*% diag(dat_vals^2) %*% other_vals

    (term1 + term2) / length(dat_vec)
}

.feasibility.curved_gaussian <- function(current_vec, other_mat, ...) {
    nat_vec <- c(other_mat %*% current_vec)
    all(nat_vec > 0)
}

.curved_gaussian <- structure(
    list(
        objfn_all = .evaluate_objective.curved_gaussian,
        objfn     = .evaluate_objective_single.curved_gaussian,
        grad      = .gradient_vec.curved_gaussian,
        hessian   = .hessian_vec.curved_gaussian,
        feas      = .feasibility.curved_gaussian
    ),
    class = "esvd_family"
)



.evaluate_objective_mat.curved_gaussian <- function(dat, nat_mat, scalar = 2, ...){
  stopifnot(all(dim(dat) == dim(nat_mat)), all(nat_mat > 0))

  n <- nrow(dat); p <- ncol(dat)
  idx <- which(!is.na(dat))

  1/(n*p) * sum(-log(nat_mat[idx]) -
        nat_mat[idx]*dat[idx]*scalar^2 +
        nat_mat[idx]^2*dat[idx]^2*scalar^2/2)
}

.gradient_mat.curved_gaussian <- function(dat, nat_mat, scalar = 2, ...){
  stopifnot(all(dim(dat) == dim(nat_mat)), all(nat_mat > 0))

  n <- nrow(dat); p <- ncol(dat)

  (-1/(nat_mat) - scalar^2*dat + scalar^2*dat^2*nat_mat)/(n*p)
}
