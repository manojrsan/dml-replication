.PHONY: all clean

all: paper/paper.pdf

# ------------------------------------------------------------------
# Step 1: Preprocessing
#   Reads input/sipp1991.dta, cleans data, writes to temp/
# ------------------------------------------------------------------
temp/clean_data.rds: input/sipp1991.dta code/preprocess.R
	Rscript code/preprocess.R

# ------------------------------------------------------------------
# Step 2: Analysis
#   Reads temp/clean_data.rds, runs DML, writes table to output/
# ------------------------------------------------------------------
output/tables/main_result.tex: temp/clean_data.rds code/analysis.R
	Rscript code/analysis.R

# ------------------------------------------------------------------
# Step 3: Compile paper
#   Reads paper.tex + output table; produces PDF
# ------------------------------------------------------------------
paper/paper.pdf: paper/paper.tex paper/references.bib \
                 output/tables/main_result.tex
	cd paper && pdflatex paper.tex && bibtex paper && pdflatex paper.tex && pdflatex paper.tex

# ------------------------------------------------------------------
# Clean: remove all regenerable files
# ------------------------------------------------------------------
clean:
	rm -f temp/*.rds
	rm -f output/tables/main_result.tex
	rm -f paper/paper.pdf paper/paper.aux paper/paper.log \
	      paper/paper.bbl paper/paper.blg paper/paper.out
