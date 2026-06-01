# Replication: Chernozhukov et al. (2018)

Replication of **Table 2, Panel B, 5-fold row** from:

> Chernozhukov, V., Chetverikov, D., Demirer, M., Duflo, E., Hansen, C.,
> Newey, W., & Robins, J. (2018). Double/Debiased Machine Learning for
> Treatment and Structural Parameters. *The Econometrics Journal*, 21(1),
> C1–C68. https://doi.org/10.1111/ectj.12097

**Target result:** The Average Treatment Effect of 401(k) eligibility on net
financial assets using the Partially Linear DML model with 5-fold cross-fitting.
The paper reports ATEs ranging from 8,187 (Lasso) to 9,247 (Random Forest).

---

## Repository Structure

```
.
├── input/               # Raw data (read-only)
│   ├── sipp1991.dta     # SIPP 1991 survey data
│   └── data_dictionary.md
├── code/
│   ├── preprocess.R     # Loads and cleans raw data → temp/
│   └── analysis.R       # Runs DML, writes table → output/
├── output/
│   └── tables/
│       └── main_result.tex   # Auto-generated LaTeX table
├── temp/                # Intermediate files (gitignored)
├── paper/
│   ├── paper.tex
│   ├── references.bib
│   └── paper.pdf
├── Makefile
├── run_all.sh
└── README.md
```

---

## Data

The data are from the 1991 Survey of Income and Program Participation (SIPP),
originally used in Abadie (2003). The file `sipp1991.dta` is available at:

https://github.com/VC2015/DMLonGitHub/blob/master/sipp1991.dta

Download it and place it in `input/sipp1991.dta` before running. The
preprocessing script (`code/preprocess.R`) reads this file directly.

---

## Prerequisites

- **R** (≥ 4.0) with packages: `haven`, `DoubleML`, `data.table`, `glmnet`,
  `rpart`, `randomForest`, `gbm`, `nnet`, `matrixStats`
- **LaTeX** (TeX Live or MacTeX) with `pdflatex`
- **Make**

Install R packages:
```r
install.packages(c("haven","DoubleML","data.table","glmnet","rpart",
                   "randomForest","gbm","nnet","matrixStats"))
```

---

## Reproducing the Paper

```bash
git clone https://github.com/manojrsan/dml-replication.git
cd dml-replication
# download sipp1991.dta into input/ (see Data section above)
make
```

> **⚠️ Runtime:** The full analysis takes approximately 3–4 hours (100 repetitions).
> To run a quick 2-rep test (~5 minutes), uncomment `n_rep <- 2` and comment out `n_rep <- 100` near the top of `code/analysis.R`.
> The final output table is committed to `output/tables/` so `paper.pdf` can be
> compiled without rerunning the analysis.

The compiled paper will be at `paper/paper.pdf`.

To rebuild from scratch:
```bash
make clean
make
```

---

## Results

| Method     | Paper ATE | Replicated ATE |
|------------|-----------|----------------|
| Lasso      | 8,187     | 9,676          |
| Reg. Tree  | 8,871     | 9,026          |
| Forest     | 9,247     | 9,269          |
| Boosting   | 9,110     | 8,983          |
| Neural Net | 9,038     | 9,213          |
| Ensemble   | 9,166     | 9,338          |


---

## Author

Mariano Sanchez — GSE 552, Vasilaky
