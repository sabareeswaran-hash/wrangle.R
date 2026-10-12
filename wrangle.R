# ============================================================
# Week 3 - Data Wrangling and Preprocessing (Titanic dataset)
# Base R only: no external packages required
# ============================================================
set.seed(42)

# ---- 1. Load --------------------------------------------------
raw <- read.csv("titanic.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
cat("Dimensions:", dim(raw), "\n")
str(raw)
snapshot_before <- head(raw, 5)
write.csv(snapshot_before, "snapshot_before.csv", row.names = FALSE)

# ---- 2. Data quality assessment ------------------------------
missing_by_col <- colSums(is.na(raw))
print(missing_by_col)
pct_missing <- round(100 * missing_by_col / nrow(raw), 2)
print(pct_missing)

dup_rows   <- sum(duplicated(raw))
dup_ids    <- sum(duplicated(raw$PassengerId))
cat("Duplicate rows:", dup_rows, " Duplicate IDs:", dup_ids, "\n")
print(table(raw$Pclass, useNA = "ifany"))
print(table(raw$Survived, useNA = "ifany"))
print(table(raw$Embarked, useNA = "ifany"))
print(table(raw$Sex, useNA = "ifany"))

# Outliers via IQR rule
iqr_outliers <- function(x) {
  q <- quantile(x, c(.25, .75), na.rm = TRUE)
  iqr <- q[2] - q[1]
  sum(x < q[1] - 1.5 * iqr | x > q[2] + 1.5 * iqr, na.rm = TRUE)
}
cat("Fare IQR outliers:", iqr_outliers(raw$Fare), "\n")
cat("Age IQR outliers:",  iqr_outliers(raw$Age), "\n")
cat("Fare summary:\n"); print(summary(raw$Fare))
cat("Age summary:\n");  print(summary(raw$Age))
cat("Fare = 0 count:", sum(raw$Fare == 0, na.rm = TRUE), "\n")

# Inconsistency check: SibSp/Parch extremes
print(table(raw$SibSp))
print(table(raw$Parch))

# ---- 3. Cleaning ---------------------------------------------
df <- raw

# 3a. Correct data types
df$Survived <- factor(df$Survived, levels = c(0, 1), labels = c("No", "Yes"))
df$Pclass   <- factor(df$Pclass, levels = c(1, 2, 3), labels = c("1st", "2nd", "3rd"))
df$Sex      <- factor(df$Sex)
df$Embarked <- factor(df$Embarked)

# 3b. Extract honorific title from Name (needed for Age imputation)
df$Title <- sub(".*,\\s*([^\\.]+)\\..*", "\\1", df$Name)
df$Title <- trimws(df$Title)
print(table(df$Title))

# Group rare titles into consistent categories
rare_male   <- c("Capt", "Col", "Don", "Dr", "Major", "Rev", "Jonkheer", "Sir")
rare_female <- c("Lady", "the Countess", "Dona")
df$Title <- as.character(df$Title)
df$Title[df$Title %in% rare_male]   <- "Rare_M"
df$Title[df$Title %in% rare_female] <- "Rare_F"
df$Title[df$Title %in% c("Mlle", "Ms")] <- "Miss"
df$Title[df$Title == "Mme"] <- "Mrs"
df$Title <- factor(df$Title)
print(table(df$Title))

# 3c. Missing Age: impute with the median of Title x Pclass group
df$Age_missing <- is.na(df$Age)
grp_median <- tapply(df$Age, list(df$Title, df$Pclass), median, na.rm = TRUE)
for (i in which(is.na(df$Age))) {
  m <- grp_median[as.character(df$Title[i]), as.character(df$Pclass[i])]
  df$Age[i] <- if (is.na(m)) median(df$Age, na.rm = TRUE) else m
}
cat("Age NAs after imputation:", sum(is.na(df$Age)), "\n")

# 3d. Missing Embarked: impute with mode
mode_val <- names(which.max(table(df$Embarked)))
df$Embarked[is.na(df$Embarked)] <- mode_val
cat("Embarked imputed with mode:", mode_val, "\n")

# 3e. Cabin: high missingness (~77%), so derive informative features instead of imputing
df$HasCabin <- factor(ifelse(is.na(df$Cabin), "No", "Yes"))
df$Deck <- ifelse(is.na(df$Cabin), "Unknown", substr(df$Cabin, 1, 1))
df$Deck <- factor(df$Deck)

# 3f. Fare outliers: cap at 1st/99th percentile (winsorise) and log-transform the skew
q <- quantile(df$Fare, c(.01, .99), na.rm = TRUE)
df$Fare_capped <- pmin(pmax(df$Fare, q[1]), q[2])
df$Fare_log <- log1p(df$Fare_capped)
cat("Fare cap bounds:", round(q, 2), "\n")

# 3g. Drop identifiers/free text no longer needed
# (Ticket and Name are kept as-is in the raw file; Cabin replaced by HasCabin/Deck)

# ---- 4. Transformation ---------------------------------------
# 4a. Feature extraction
df$FamilySize <- df$SibSp + df$Parch + 1
df$IsAlone    <- factor(ifelse(df$FamilySize == 1, "Yes", "No"))
df$FarePerPerson <- df$Fare_capped / df$FamilySize
df$AgeGroup <- cut(df$Age, breaks = c(0, 12, 18, 35, 60, Inf),
                   labels = c("Child", "Teen", "Young Adult", "Adult", "Senior"),
                   right = FALSE)

# 4b. Encode categorical variables (one-hot, reference level dropped)
dummies <- model.matrix(~ Sex + Pclass + Embarked + Title - 1, data = df)
dummies <- dummies[, -1, drop = FALSE]  # drop intercept-like redundancy for clarity
colnames(dummies) <- make.names(colnames(dummies))
df <- cbind(df, as.data.frame(dummies))

# 4c. Scaling: z-score for Age and log fare; min-max for FamilySize
zscore <- function(x) (x - mean(x)) / sd(x)
minmax <- function(x) (x - min(x)) / (max(x) - min(x))
df$Age_z        <- zscore(df$Age)
df$FareLog_z    <- zscore(df$Fare_log)
df$FamilySize_mm <- minmax(df$FamilySize)

# ---- 5. Validation -------------------------------------------
cat("Remaining NAs:", sum(is.na(df[, c("Age", "Embarked", "Fare")])), "\n")
cat("Final dimensions:", dim(df), "\n")
summary(df[, c("Age", "Age_z", "Fare_capped", "FareLog_z", "FamilySize", "FamilySize_mm")])
print(table(df$Survived, df$Sex))

# ---- 6. Save outputs -----------------------------------------
snapshot_after <- head(df[, c("PassengerId", "Survived", "Pclass", "Sex", "Age", "Age_z",
                              "Title", "Embarked", "HasCabin", "Deck", "Fare_capped",
                              "Fare_log", "FamilySize", "IsAlone")], 5)
write.csv(snapshot_after, "snapshot_after.csv", row.names = FALSE)
write.csv(df, "titanic_clean.csv", row.names = FALSE)
cat("Saved titanic_clean.csv\n")
