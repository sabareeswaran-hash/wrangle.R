# Titanic Data Wrangling and Preprocessing in R

Week 3 task for the YuvaIntern Virtual Data Science with R Apprentice Internship.

This project cleans, transforms and prepares the Titanic passenger dataset (891 passengers, 12 attributes) for analysis. Everything is written in base R, so no packages need to be installed.

## Contents

| File | Description |
|---|---|
| `wrangle.R` | Full pipeline: loading, quality checks, cleaning, feature extraction, encoding, scaling, validation |
| `Week3_Data_Wrangling_Report.docx` | Written report with explanations, code snippets and before/after snapshots |
| `titanic_clean.csv` | Cleaned output dataset (891 rows x 35 columns) |

## Requirements

- R 4.3 or later
- No additional packages required (base R only)

## Dataset

Titanic passenger data (training file). Source: the Data Science Dojo datasets repository, derived from the Kaggle "Titanic: Machine Learning from Disaster" competition.

Place `titanic.csv` in the project folder before running. The file is not modified by the script.

## How to reproduce

```bash
# from the project folder
Rscript wrangle.R > log.txt 2>&1
```

The script prints quality checks and validation results to `log.txt`, and writes:

- `snapshot_before.csv`: first five raw rows
- `snapshot_after.csv`: first five cleaned rows
- `titanic_clean.csv`: the cleaned dataset

## Pipeline summary

1. **Load**: read the CSV, treating empty fields as `NA`.
2. **Quality assessment**: missing values, duplicates, IQR outliers, inconsistent categories.
3. **Cleaning**:
   - correct data types to labelled factors
   - extract and standardise honorific titles from `Name`
   - impute `Age` with the median for each Title x Pclass group
   - impute `Embarked` with the mode
   - replace sparse `Cabin` with `HasCabin` and `Deck`
   - winsorise `Fare` at the 99th percentile and log-transform it
4. **Transformation**:
   - features: `FamilySize`, `IsAlone`, `FarePerPerson`, `AgeGroup`
   - one-hot encoding of categorical variables with reference levels
   - z-score scaling (`Age`, log-fare) and min-max scaling (`FamilySize`)
5. **Validation**: checks for remaining `NA`s, dimensions and label consistency.

## Notes

- A random seed (`set.seed(42)`) is set for reproducibility, although the current pipeline is deterministic.
- Scaling and imputation statistics are computed on the full dataset. For predictive modelling, fit them on the training split only.

## Author

Sabareeswaran M
GitHub: [github.com/sabareeswaran-hash](https://github.com/sabareeswaran-hash)
