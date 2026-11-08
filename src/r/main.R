# Part 4: a self-contained R Titanic workflow using binomial logistic regression.
suppressPackageStartupMessages({
  library(stats)
  library(utils)
  library(jsonlite)
  library(digest)
})

script_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
if (is.na(script_file)) script_file <- "src/r/main.R"
SCRIPT_DIR <- dirname(normalizePath(script_file, mustWork = TRUE))
PROJECT_ROOT <- dirname(dirname(SCRIPT_DIR))
NUMERIC <- c("Age", "LogFare", "FamilySize")
CATEGORICAL <- c("Pclass", "Sex", "Embarked")
FEATURES <- c(NUMERIC, CATEGORICAL)
MODEL_FORMULA <- Survived ~ Age + LogFare + FamilySize + Pclass + Sex + Embarked
SEED <- 42L

read_titanic <- function(data_dir) {
  required <- c("PassengerId", "Pclass", "Sex", "Age", "SibSp", "Parch", "Fare", "Embarked")
  frames <- lapply(c("train.csv", "test.csv"), function(name) {
    path <- file.path(data_dir, name)
    if (!file.exists(path)) {
      stop("Missing ", path, ". Download Titanic train.csv and test.csv; see README.")
    }
    data <- read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"),
                     strip.white = TRUE, check.names = FALSE)
    columns <- c(required, if (name == "train.csv") "Survived")
    missing <- setdiff(columns, names(data))
    if (length(missing)) stop(name, " is missing Titanic columns: ", paste(missing, collapse = ", "))
    if (!nrow(data)) stop(name, " has no passengers.")
    for (column in c("PassengerId", "Pclass", "Age", "SibSp", "Parch", "Fare")) {
      values <- suppressWarnings(as.numeric(data[[column]]))
      if (any(is.na(values) & !is.na(data[[column]])) ||
          any(is.infinite(values)) || any(values < 0, na.rm = TRUE)) {
        stop(name, ": ", column, " must contain finite, nonnegative numbers or missing values.")
      }
      data[[column]] <- values
    }
    ids <- data$PassengerId
    if (anyNA(ids) || anyDuplicated(ids) || any(ids %% 1 != 0) || any(ids <= 0)) {
      stop(name, ": PassengerId must be unique, positive, nonmissing integers.")
    }
    if (any(!is.na(data$Pclass) & !data$Pclass %in% 1:3)) stop(name, ": invalid Pclass.")
    data
  })
  train <- frames[[1]]
  test <- frames[[2]]
  if (!all(train$Survived %in% 0:1) || length(unique(train$Survived)) != 2L) {
    stop("train.csv: Survived must contain both binary classes 0 and 1.")
  }
  train$Survived <- as.integer(train$Survived)
  if (length(intersect(train$PassengerId, test$PassengerId))) {
    stop("train.csv and test.csv contain overlapping PassengerId values.")
  }
  list(train = train, test = test)
}

make_features <- function(data) {
  data.frame(Age = data$Age, LogFare = log1p(data$Fare),
             FamilySize = data$SibSp + data$Parch + 1,
             Pclass = as.character(data$Pclass), Sex = as.character(data$Sex),
             Embarked = as.character(data$Embarked), stringsAsFactors = FALSE)
}

most_common <- function(values) {
  counts <- table(values)
  if (!length(counts)) stop("Cannot find a mode in an entirely missing column.")
  names(counts)[which.max(counts)]
}

fit_preprocessing <- function(features) {
  medians <- vapply(features[NUMERIC], median, numeric(1), na.rm = TRUE)
  if (any(!is.finite(medians))) stop("Cannot fit medians: a numeric column is entirely missing.")
  modes <- vapply(features[CATEGORICAL], most_common, character(1))
  levels <- lapply(features[CATEGORICAL], function(x) sort(unique(x[!is.na(x)])))
  if (any(lengths(levels) < 2L)) stop("Each categorical fitting column needs at least two levels.")
  list(medians = medians, modes = modes, levels = levels)
}

apply_preprocessing <- function(features, fitted, label = NULL) {
  result <- features
  for (column in NUMERIC) {
    missing <- is.na(result[[column]])
    result[[column]][missing] <- fitted$medians[[column]]
    if (!is.null(label)) cat(label, column, ": filled", sum(missing), "missing values.\n")
  }
  for (column in CATEGORICAL) {
    missing <- is.na(result[[column]])
    unknown <- !missing & !result[[column]] %in% fitted$levels[[column]]
    result[[column]][missing | unknown] <- fitted$modes[[column]]
    result[[column]] <- factor(result[[column]], levels = fitted$levels[[column]])
    if (!is.null(label)) {
      cat(label, column, ": filled", sum(missing), "missing and", sum(unknown),
          "unseen values with the fitting-set mode.\n")
    }
  }
  result
}

validation_indices <- function(target) {
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(SEED)
  groups <- split(seq_along(target), target)
  if (any(lengths(groups) < 2L)) stop("At least two labeled rows per class are needed for a split.")
  sort(unlist(lapply(groups, function(rows) sample(rows, ceiling(length(rows) * 0.2))),
              use.names = FALSE))
}

fit_model <- function(features, target) {
  model <- glm(MODEL_FORMULA, data = data.frame(features, Survived = target),
               family = binomial(link = "logit"), na.action = na.fail,
               singular.ok = FALSE, control = glm.control(maxit = 100))
  if (!model$converged) stop("Logistic regression did not converge.")
  model
}

predict_labels <- function(model, features) {
  probability <- predict(model, newdata = features, type = "response")
  if (length(probability) != nrow(features) || any(!is.finite(probability))) {
    stop("Model did not return one finite probability for every passenger.")
  }
  as.integer(probability >= 0.5)
}

matching_kaggle_score <- function(submission_path, record_path) {
  if (!file.exists(record_path)) return(NULL)
  record <- fromJSON(record_path)
  if (is.null(record) || !identical(digest(file = submission_path, algo = "sha256"),
                                   record$submission_sha256)) return(NULL)
  record
}

print_preprocessing <- function(fitted, label) {
  cat(label, "numeric medians:\n")
  print(fitted$medians)
  cat(label, "category modes and learned levels:\n")
  print(fitted$modes)
  print(fitted$levels)
}

run <- function(data_dir, output_dir, score_path = file.path(SCRIPT_DIR, "kaggle_score.json")) {
  cat("Part 4: Titanic survival prediction in R\n", R.version.string, "\n")
  cat("jsonlite", as.character(packageVersion("jsonlite")), "; digest",
      as.character(packageVersion("digest")), "\n")
  data <- read_titanic(data_dir)
  train <- data$train
  test <- data$test
  cat("\n[13-14] Loaded train.csv:", nrow(train), "rows; test.csv:", nrow(test), "rows.\n")
  cat("Input checks passed: Titanic schema, binary labels, disjoint passenger IDs.\n")
  cat("Training missing values by column:\n"); print(colSums(is.na(train)))
  cat("Test missing values by column:\n"); print(colSums(is.na(test)))
  cat("Numeric training summary:\n"); print(summary(train[c("Age", "Fare", "SibSp", "Parch")]))
  cat("Survival counts (0 = died, 1 = survived):\n"); print(table(train$Survived))
  cat("Descriptive survival rates by sex and class:\n")
  print(aggregate(Survived ~ Sex + Pclass, data = train, FUN = mean))

  cat("\n[14] Feature changes:\n",
      "- FamilySize = SibSp + Parch + 1 replaces the separate family counts.\n",
      "- LogFare = log(1 + Fare) reduces fare skew and supports zero fares.\n",
      "- Pclass, Sex and Embarked become categorical factors with treatment contrasts.\n",
      "- Age, LogFare and FamilySize use fitting-set median imputation.\n",
      "- Missing/unseen categories use the fitting-set mode and learned factor levels.\n",
      "- No rows dropped. PassengerId, Name, Ticket and Cabin are excluded.\n",
      "- Survived is the target only. No statistics are learned from validation/test rows.\n",
      "- Numeric predictors retain their units; no scaling or regularization is applied.\n", sep = "")
  features <- make_features(train)
  test_features <- make_features(test)
  cat("Engineered feature preview:\n"); print(head(features))
  valid <- validation_indices(train$Survived)
  fitting <- setdiff(seq_len(nrow(train)), valid)
  preprocessing <- fit_preprocessing(features[fitting, ])
  cat("\n[15-16] Stratified split:", length(fitting), "fitting /", length(valid),
      "validation rows; R seed", SEED, ".\n")
  print_preprocessing(preprocessing, "Split model")
  x_fit <- apply_preprocessing(features[fitting, ], preprocessing, "Fitting")
  x_valid <- apply_preprocessing(features[valid, ], preprocessing, "Validation")
  cat("Unpenalized binomial logistic regression; logit link; probability threshold 0.5.\n")
  print(MODEL_FORMULA)
  model <- fit_model(x_fit, train$Survived[fitting])
  cat("Fitting-model coefficients:\n"); print(coef(model))
  fit_accuracy <- mean(predict_labels(model, x_fit) == train$Survived[fitting])
  validation_predictions <- predict_labels(model, x_valid)
  valid_accuracy <- mean(validation_predictions == train$Survived[valid])
  baseline <- mean(train$Survived[valid] == as.integer(most_common(train$Survived[fitting])))
  confusion <- table(True = factor(train$Survived[valid], levels = 0:1),
                     Predicted = factor(validation_predictions, levels = 0:1))
  cat(sprintf("Training-split accuracy: %.4f (%.2f%%)\n", fit_accuracy, 100 * fit_accuracy))
  cat(sprintf("Held-out validation accuracy: %.4f (%.2f%%)\n", valid_accuracy, 100 * valid_accuracy))
  cat(sprintf("Validation majority-class baseline: %.4f (%.2f%%)\n", baseline, 100 * baseline))
  cat("Validation confusion matrix (rows=true 0/1, columns=predicted 0/1):\n"); print(confusion)

  cat("\n[17] Refit preprocessing and logistic regression on all labeled training rows.\n")
  final_preprocessing <- fit_preprocessing(features)
  print_preprocessing(final_preprocessing, "Final model")
  x_all <- apply_preprocessing(features, final_preprocessing, "Full training")
  x_test <- apply_preprocessing(test_features, final_preprocessing, "Official test")
  final_model <- fit_model(x_all, train$Survived)
  training_accuracy <- mean(predict_labels(final_model, x_all) == train$Survived)
  cat(sprintf("Full-training accuracy: %.4f (%.2f%%); in-sample, not unseen-data performance.\n",
              training_accuracy, 100 * training_accuracy))
  submission <- data.frame(PassengerId = test$PassengerId,
                           Survived = predict_labels(final_model, x_test))
  cat("Predicted all", nrow(submission), "test passengers in original row order.\n")
  cat("Prediction counts:\n"); print(table(submission$Survived))
  cat("Prediction preview:\n"); print(head(submission, 10))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  submission_path <- file.path(output_dir, "submission.csv")
  write.table(submission, submission_path, sep = ",", row.names = FALSE, quote = FALSE, eol = "\n")
  write.csv(data.frame(PassengerId = train$PassengerId[valid],
                       Survived = train$Survived[valid], Predicted = validation_predictions),
            file.path(output_dir, "validation_predictions.csv"), row.names = FALSE)

  cat("\n[18] Official test accuracy is unavailable locally: Kaggle test.csv has no labels.\n",
      "The held-out validation score above is not the official test score.\n",
      "gender_submission.csv is an example baseline, not ground truth; it is never used.\n", sep = "")
  if ("Survived" %in% names(test)) cat("Unexpected test Survived column ignored: not official ground truth.\n")
  record <- matching_kaggle_score(submission_path, score_path)
  if (is.null(record)) {
    cat("No matching recorded Kaggle score. Upload submission.csv to Kaggle for evaluation.\n")
  } else {
    cat(sprintf("Verified Kaggle public test score: %.5f (%.3f%%).\n",
                record$public_score, 100 * record$public_score))
    cat("Previously submitted at", record$submitted_at, "; this CSV's SHA-256 matches.\n")
    cat("External score recorded from Kaggle, not recalculated locally.\nSource:", record$source, "\n")
  }
  metrics <- list(
    random_state = SEED, validation_fraction = 0.2,
    train_rows = nrow(train), fit_rows = length(fitting), validation_rows = length(valid),
    test_rows = nrow(test), training_split_accuracy = fit_accuracy,
    validation_accuracy = valid_accuracy, validation_majority_baseline = baseline,
    validation_confusion_matrix = matrix(as.integer(confusion), nrow = 2L),
    full_training_accuracy = training_accuracy, official_test_accuracy = NULL,
    official_test_accuracy_note = "Kaggle withholds test labels; local evaluation is unavailable.",
    kaggle_public_accuracy = record$public_score, kaggle_submission = record,
    submission_sha256 = digest(file = submission_path, algo = "sha256"),
    features = FEATURES, input_sha256 = list(
      train.csv = digest(file = file.path(data_dir, "train.csv"), algo = "sha256"),
      test.csv = digest(file = file.path(data_dir, "test.csv"), algo = "sha256"))
  )
  write_json(metrics, file.path(output_dir, "metrics.json"), pretty = TRUE,
             auto_unbox = TRUE, null = "null", digits = NA, matrix = "rowmajor")
  cat("\nSaved", submission_path, "(PassengerId,Survived; no row names).\n")
  cat("Saved validation_predictions.csv and metrics.json in", output_dir, "\n")
  cat("Part 4 run completed successfully.\n")
  invisible(metrics)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--help" %in% args) {
    cat("Usage: Rscript --vanilla main.R [--data-dir DIR] [--output-dir DIR]\n")
    return(invisible(NULL))
  }
  settings <- list("--data-dir" = file.path(PROJECT_ROOT, "src", "data"),
                   "--output-dir" = file.path(PROJECT_ROOT, "outputs", "r"))
  if (length(args) %% 2 != 0) stop("Each command-line option needs a path; use --help.")
  for (i in seq_len(length(args) / 2)) {
    key <- args[2 * i - 1]
    if (!key %in% names(settings)) stop("Unknown option: ", key)
    settings[[key]] <- args[2 * i]
  }
  run(settings[["--data-dir"]], settings[["--output-dir"]])
}

if (sys.nframe() == 0L) {
  tryCatch(main(), error = function(e) {
    message("Error: ", conditionMessage(e))
    quit(status = 1L)
  })
}
