# ============================================================
# Replicate Table 2, Panel B (5-fold): Partially Linear DML
# Paper: Double/Debiased Machine Learning for Treatment and
#        Structural Parameters (Chernozhukov et al., 2018)
# Outcome:   net_tfa
# Treatment: e401
# Columns: Lasso, Reg. Tree, Forest, Boosting, Neural Net, Ensemble, Best
#
# KEY FIX vs. prior version:
#   Lasso now uses the same rich polynomial + interaction feature
#   matrix (xl) as the original 401K.R code. Tree-based methods
#   keep the raw 9 covariates (xx), matching the paper exactly.
# ============================================================

# -----------------------------
# 0. Install / load packages
# -----------------------------
pkgs <- c(
  "DoubleML",
  "data.table",
  "glmnet",
  "rpart",
  "randomForest",
  "gbm",
  "nnet",
  "matrixStats"
)

missing_pkgs <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing_pkgs) > 0) {
  install.packages(missing_pkgs, dependencies = TRUE,
                   repos = "https://cloud.r-project.org")
}
invisible(lapply(pkgs, library, character.only = TRUE))

# -----------------------------
# 1. Load data
# -----------------------------
data <- readRDS("temp/clean_data.rds")

# -----------------------------
# 2. Define outcome, treatment, covariates
# -----------------------------
y_var  <- "net_tfa"
d_var  <- "e401"
x_vars <- c("age", "inc", "educ", "fsize", "marr", "twoearn", "db", "pira", "hown")

vars_needed <- c(y_var, d_var, x_vars)
data <- data[complete.cases(data[, vars_needed]), vars_needed]

Y <- data[[y_var]]
D <- data[[d_var]]
X <- data[, x_vars]   # raw 9 covariates  → for tree-based methods

# Rich feature matrix for penalised linear methods (Lasso)
# Matches xl in the original 401K.R exactly:
#   poly(age,6) + poly(inc,8) + poly(educ,4) + poly(fsize,2) +
#   binary vars, all pairwise interactions
make_xl <- function(df) {
  model.matrix(
    ~ (poly(age,  4, raw = TRUE) +
         poly(inc,  4, raw = TRUE) +
         poly(educ, 3, raw = TRUE) +
         poly(fsize,2, raw = TRUE) +
         marr + twoearn + db + pira + hown)^2 - 1,
    data = df
  )
}

XL <- make_xl(data)   # rich feature matrix → for Lasso

cat("N observations :", nrow(data), "\n")
cat("N covariates (raw)  :", length(x_vars), "\n")
cat("N features (Lasso xl):", ncol(XL), "\n")
cat("Mean net_tfa :", round(mean(Y), 2), "\n")
cat("SD   net_tfa :", round(sd(Y),   2), "\n\n")

# -----------------------------
# 3. Settings
# -----------------------------
set.seed(1211)   # same seed as original 401K.R

# n_rep <- 2   # fast test
n_rep   <- 100
n_folds <- 5

methods <- c("Lasso", "Reg. Tree", "Forest", "Boosting",
             "Neural Net", "Ensemble", "Best")

# -----------------------------
# 4. ML helper functions
# -----------------------------

# ---- Lasso: uses rich xl feature matrix ----
fit_predict_lasso <- function(XL_train, y_train, XL_test) {
  fit  <- glmnet::cv.glmnet(XL_train, y_train, alpha = 1, nfolds = 3)
  pred <- as.numeric(predict(fit, newx = XL_test, s = "lambda.min"))
  return(pred)
}

# ---- Tree-based methods: use raw X ----
fit_predict_tree <- function(X_train, y_train, X_test) {
  train_df <- data.frame(y = y_train, X_train)
  fit  <- rpart::rpart(y ~ ., data = train_df, method = "anova")
  pred <- as.numeric(predict(fit, newdata = X_test))
  return(pred)
}

fit_predict_forest <- function(X_train, y_train, X_test) {
  train_df <- data.frame(y = y_train, X_train)
  fit  <- randomForest::randomForest(y ~ ., data = train_df,
                                     ntree = 500, nodesize = 5,
                                     na.action = na.omit, replace = TRUE)
  pred <- as.numeric(predict(fit, newdata = X_test))
  return(pred)
}

fit_predict_boosting <- function(X_train, y_train, X_test) {
  train_df <- data.frame(y = y_train, X_train)
  fit  <- gbm::gbm(
    y ~ .,
    data              = train_df,
    distribution      = "gaussian",
    n.trees           = 500,       # reduced from 1000
    interaction.depth = 2,
    shrinkage         = 0.01,
    bag.fraction      = 0.5,
    train.fraction    = 1.0,
    cv.folds          = 0,         # KEY FIX: no internal CV (was 5)
    verbose           = FALSE
  )
  pred <- as.numeric(predict(fit, newdata = X_test, n.trees = 500))
  return(pred)
}

# ---- Neural net: scale inputs & outputs, use raw X ----
fit_predict_nnet <- function(X_train, y_train, X_test) {
  X_train_mat <- scale(as.matrix(X_train))
  center      <- attr(X_train_mat, "scaled:center")
  scale_vals  <- attr(X_train_mat, "scaled:scale")
  scale_vals[scale_vals == 0] <- 1
  X_test_mat  <- scale(as.matrix(X_test), center = center, scale = scale_vals)
  
  y_mean   <- mean(y_train)
  y_sd     <- sd(y_train);  if (is.na(y_sd) || y_sd == 0) y_sd <- 1
  y_scaled <- (y_train - y_mean) / y_sd
  
  train_df <- data.frame(y = y_scaled, X_train_mat)
  test_df  <- data.frame(X_test_mat)
  
  fit <- nnet::nnet(y ~ ., data = train_df,
                    size = 8, decay = 0.01, maxit = 1000,
                    linout = TRUE, trace = FALSE, MaxNWts = 10000)
  
  pred_scaled <- as.numeric(predict(fit, newdata = test_df))
  return(pred_scaled * y_sd + y_mean)
}

# -----------------------------
# 5. Core DML-PLR function (one sample split)
# -----------------------------
estimate_dml_plr <- function(Y, D, X, XL, n_folds = 5) {
  
  n           <- length(Y)
  base_methods <- c("Lasso", "Reg. Tree", "Forest", "Boosting", "Neural Net")
  
  # Random fold assignment
  fold_id <- sample(rep(1:n_folds, length.out = n))
  
  l_hat <- matrix(NA_real_, nrow = n, ncol = length(base_methods),
                  dimnames = list(NULL, base_methods))
  m_hat <- matrix(NA_real_, nrow = n, ncol = length(base_methods),
                  dimnames = list(NULL, base_methods))
  
  for (fold in 1:n_folds) {
    train_idx <- which(fold_id != fold)
    test_idx  <- which(fold_id == fold)
    
    X_tr  <- X[train_idx, , drop = FALSE]
    X_te  <- X[test_idx,  , drop = FALSE]
    XL_tr <- XL[train_idx, , drop = FALSE]
    XL_te <- XL[test_idx,  , drop = FALSE]
    Y_tr  <- Y[train_idx];  D_tr <- D[train_idx]
    
    # Lasso uses rich xl features
    t0 <- proc.time()["elapsed"]
    l_hat[test_idx, "Lasso"] <- fit_predict_lasso(XL_tr, Y_tr, XL_te)
    m_hat[test_idx, "Lasso"] <- fit_predict_lasso(XL_tr, D_tr, XL_te)
    if (exists("r") && r == 1) cat(sprintf("    fold %d  Lasso:      %.1fs\n", fold, proc.time()["elapsed"] - t0))
    
    # Tree-based + nnet use raw X
    for (method in c("Reg. Tree", "Forest", "Boosting", "Neural Net")) {
      fn <- switch(method,
                   "Reg. Tree"  = fit_predict_tree,
                   "Forest"     = fit_predict_forest,
                   "Boosting"   = fit_predict_boosting,
                   "Neural Net" = fit_predict_nnet)
      t0 <- proc.time()["elapsed"]
      l_hat[test_idx, method] <- fn(X_tr, Y_tr, X_te)
      m_hat[test_idx, method] <- fn(X_tr, D_tr, X_te)
      if (exists("r") && r == 1) cat(sprintf("    fold %d  %-12s %.1fs\n", fold, method, proc.time()["elapsed"] - t0))
    }
  }
  
  # Ensemble = simple average of base learner nuisance predictions
  l_hat <- cbind(l_hat, Ensemble = rowMeans(l_hat))
  m_hat <- cbind(m_hat, Ensemble = rowMeans(m_hat))
  
  # Best = base learner with lowest combined out-of-fold MSE
  base_cols <- base_methods   # exclude Ensemble when picking best
  mse_y     <- colMeans((Y - l_hat[, base_cols, drop = FALSE])^2)
  mse_d     <- colMeans((D - m_hat[, base_cols, drop = FALSE])^2)
  best_col  <- names(which.min(mse_y + mse_d))
  
  l_hat <- cbind(l_hat, Best = l_hat[, best_col])
  m_hat <- cbind(m_hat, Best = m_hat[, best_col])
  
  all_cols <- c(base_methods, "Ensemble", "Best")
  theta    <- setNames(rep(NA_real_, length(all_cols)), all_cols)
  se       <- setNames(rep(NA_real_, length(all_cols)), all_cols)
  
  for (col in all_cols) {
    y_tilde   <- Y - l_hat[, col]
    d_tilde   <- D - m_hat[, col]
    theta_hat <- sum(d_tilde * y_tilde) / sum(d_tilde^2)
    residual  <- y_tilde - theta_hat * d_tilde
    psi       <- d_tilde * residual
    se_hat    <- sqrt(mean(psi^2) / (mean(d_tilde^2)^2) / n)
    theta[col] <- theta_hat
    se[col]    <- se_hat
  }
  
  list(theta = theta, se = se, best_method = best_col)
}

# -----------------------------
# 6. Run 100 repeated splits
# -----------------------------

# Helper: format seconds as "Xh Ym Zs" or "Ym Zs" or just "Zs"
format_time <- function(secs) {
  secs <- round(secs)
  h <- secs %/% 3600
  m <- (secs %% 3600) %/% 60
  s <- secs %% 60
  if (h > 0)      sprintf("%dh %02dm %02ds", h, m, s)
  else if (m > 0) sprintf("%dm %02ds", m, s)
  else            sprintf("%ds", s)
}
theta_mat <- matrix(NA_real_, nrow = n_rep, ncol = length(methods),
                    dimnames = list(NULL, methods))
se_mat    <- matrix(NA_real_, nrow = n_rep, ncol = length(methods),
                    dimnames = list(NULL, methods))
best_methods_vec <- character(n_rep)

cat("Running", n_rep, "repetitions with", n_folds,
    "folds each. This will take a while.\n\n")

total_start <- proc.time()["elapsed"]

for (r in 1:n_rep) {
  rep_start <- proc.time()["elapsed"]
  
  fit_r <- estimate_dml_plr(Y = Y, D = D, X = X, XL = XL, n_folds = n_folds)
  theta_mat[r, ]      <- fit_r$theta[methods]
  se_mat[r, ]         <- fit_r$se[methods]
  best_methods_vec[r] <- fit_r$best_method
  
  rep_elapsed  <- proc.time()["elapsed"] - rep_start
  total_elapsed <- proc.time()["elapsed"] - total_start
  avg_per_rep  <- total_elapsed / r
  remaining    <- avg_per_rep * (n_rep - r)
  
  # Print every rep for the first 5, then every 10
  if (r <= 5 || r %% 10 == 0) {
    cat(sprintf(
      "  Rep %3d/%d | rep time: %5.1fs | elapsed: %s | ETA: %s\n",
      r, n_rep,
      rep_elapsed,
      format_time(total_elapsed),
      format_time(remaining)
    ))
  }
}

total_time <- proc.time()["elapsed"] - total_start
cat(sprintf("\nDone. Total time: %s\n\n", format_time(total_time)))

# -----------------------------
# 7. Aggregate results (same logic as original 401K.R)
# -----------------------------
# Row 1: Median ATE across splits
med_theta <- matrixStats::colMedians(theta_mat, na.rm = TRUE)

# Row 2: Adjusted SE = median of sqrt(se^2 + (theta - median_theta)^2)
#   This is the [bracket] row in Table 2 — accounts for split variability
adj_se_mat  <- sqrt(se_mat^2 +
                      sweep(theta_mat, 2, med_theta)^2)
med_adj_se  <- matrixStats::colMedians(adj_se_mat, na.rm = TRUE)

# Row 3: Median within-split SE
#   This is the (paren) row in Table 2
med_se      <- matrixStats::colMedians(se_mat, na.rm = TRUE)

result <- rbind(
  "ATE (5-fold)"  = round(med_theta,  0),
  "[Adjusted SE]" = round(med_adj_se, 0),
  "(Median SE)"   = round(med_se,     0)
)

# -----------------------------
# 8. Print formatted table
# -----------------------------
cat("\n=============================================================\n")
cat(" Table 2  Panel B: Partially Linear Model  |  5-fold DML\n")
cat("=============================================================\n\n")

formatted <- result
formatted["[Adjusted SE]", ] <- paste0("[", formatted["[Adjusted SE]", ], "]")
formatted["(Median SE)",   ] <- paste0("(", formatted["(Median SE)",   ], ")")
print(formatted, quote = FALSE)

cat("\n--- Paper targets for comparison ---\n")
paper <- rbind(
  "ATE (5-fold)"  = c(8187, 8871, 9247, 9110, 9038, 9166, 9215),
  "[Adjusted SE]" = c(1558, 1418, 1328, 1328, 1355, 1310, 1312),
  "(Median SE)"   = c(1298, 1358, 1295, 1314, 1322, 1299, 1294)
)
colnames(paper) <- methods
paper_fmt <- paper
paper_fmt["[Adjusted SE]", ] <- paste0("[", paper_fmt["[Adjusted SE]", ], "]")
paper_fmt["(Median SE)",   ] <- paste0("(", paper_fmt["(Median SE)",   ], ")")
print(paper_fmt, quote = FALSE)

cat("\n--- Best learner frequency across", n_rep, "repetitions ---\n")
print(table(best_methods_vec))

# -----------------------------
# 9. Save output
# -----------------------------
write.csv(result,     "output/tables/table2_panelB_5fold_full_results.csv")
write.csv(theta_mat,  "output/tables/table2_panelB_5fold_theta_by_rep.csv")
write.csv(se_mat,     "output/tables/table2_panelB_5fold_se_by_rep.csv")

cat("\nSaved:\n")
cat("  table2_panelB_5fold_full_results.csv\n")
cat("  table2_panelB_5fold_theta_by_rep.csv\n")
cat("  table2_panelB_5fold_se_by_rep.csv\n")

write_latex_table <- function(result, outpath) {

  paper_ate <- c(8187, 8871, 9247, 9110, 9038, 9166, 9215)
  paper_adj <- c(1558, 1418, 1328, 1328, 1355, 1310, 1312)
  paper_se  <- c(1298, 1358, 1295, 1314, 1322, 1299, 1294)

  fmt_row <- function(vals) paste(vals, collapse = " & ")

  rep_ate <- result["ATE (5-fold)",  ]
  rep_adj <- result["[Adjusted SE]", ]
  rep_se  <- result["(Median SE)",   ]

  lines <- c(
    "% This file is auto-generated by code/analysis.R — do not edit by hand.",
    "\\begin{table}[h]",
    "\\centering",
    "\\caption{Replication of Table~2, Panel~B (5-Fold): Estimated ATE of 401(k)",
    "         Eligibility on Net Financial Assets (Partially Linear DML).}",
    "\\label{tab:main}",
    "\\begin{tabular}{lccccccc}",
    "\\toprule",
    " & Lasso & Reg.\\ Tree & Forest & Boosting & Neural Net & Ensemble & Best \\\\",
    "\\midrule",
    "\\multicolumn{8}{l}{\\textit{Panel A: Paper targets (Chernozhukov et al., 2018)}} \\\\",
    paste("ATE       &", fmt_row(paper_ate), "\\\\"),
    paste("          &", fmt_row(paste0("[", paper_adj, "]")), "\\\\"),
    paste("          &", fmt_row(paste0("(", paper_se,  ")")), "\\\\"),
    "\\midrule",
    "\\multicolumn{8}{l}{\\textit{Panel B: This replication}} \\\\",
    paste("ATE       &", fmt_row(rep_ate), "\\\\"),
    paste("          &", fmt_row(paste0("[", rep_adj, "]")), "\\\\"),
    paste("          &", fmt_row(paste0("(", rep_se,  ")")), "\\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}"
  )

  writeLines(lines, outpath)
  cat("LaTeX table written to:", outpath, "\n")
}

# Call it — adjust path to match your directory structure
write_latex_table(
  result  = result,   # the 3-row matrix produced earlier in the script
  outpath = "~/GSE 552/DML Replication/output/tables/main_result.tex"
)

# Console summary for the grader
cat("\n==========================================\n")
cat(" Replication Result vs. Paper\n")
cat("==========================================\n")
methods_print <- c("Lasso", "Forest", "Boosting", "Ensemble")
paper_ate     <- c(8187,    9247,     9110,        9166)
for (i in seq_along(methods_print)) {
  m    <- methods_print[i]
  rep  <- round(result["ATE (5-fold)", m], 0)
  diff <- rep - paper_ate[i]
  cat(sprintf("  %-12s  paper: %5d   ours: %5d   diff: %+d\n",
              m, paper_ate[i], rep, diff))
}
cat("==========================================\n")