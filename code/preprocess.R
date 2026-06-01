# ============================================================
# Preprocessing: Load input/sipp1991.dta, select variables,
# drop incomplete cases, save analysis-ready data to temp/
# ============================================================

# 0. Packages
pkgs <- c("haven")
missing_pkgs <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing_pkgs) > 0) {
  install.packages(missing_pkgs, dependencies = TRUE,
                   repos = "https://cloud.r-project.org")
}
library(haven)

# 1. Load raw data
raw <- haven::read_dta("input/sipp1991.dta")
raw <- as.data.frame(raw)

# 2. Select variables and drop incomplete cases
vars_needed <- c("net_tfa", "e401", "age", "inc", "educ", "fsize",
                 "marr", "twoearn", "db", "pira", "hown")
data <- raw[complete.cases(raw[, vars_needed]), vars_needed]

# 3. Save to temp/
dir.create("temp", showWarnings = FALSE)
saveRDS(data, "temp/clean_data.rds")

# 4. Summary
cat("============================\n")
cat(" Preprocessing complete\n")
cat("============================\n")
cat(sprintf("N observations : %d\n",          nrow(data)))
cat(sprintf("Variables      : %s\n",          paste(names(data), collapse = ", ")))
cat(sprintf("Mean net_tfa   : %.2f\n",        mean(data$net_tfa)))
cat(sprintf("SD   net_tfa   : %.2f\n",        sd(data$net_tfa)))
cat(sprintf("Mean income    : %.2f\n",        mean(data$inc)))
cat(sprintf("Frac e401 == 1 : %.3f\n",        mean(data$e401)))
cat("Saved to       : temp/clean_data.rds\n")
