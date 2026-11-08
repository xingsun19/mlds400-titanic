# Small synthetic fixtures test software behavior, not Titanic model quality.
test_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
source(file.path(dirname(normalizePath(test_file)), "main.R"))

passengers <- function(n = 160L, first_id = 1L) {
  set.seed(123)
  data.frame(PassengerId = seq.int(first_id, length.out = n),
             Pclass = sample(1:3, n, replace = TRUE),
             Sex = sample(c("female", "male"), n, replace = TRUE),
             Age = sample(18:75, n, replace = TRUE),
             Fare = runif(n, 2, 100), SibSp = sample(0:3, n, replace = TRUE),
             Parch = sample(0:2, n, replace = TRUE),
             Embarked = sample(c("S", "C", "Q"), n, replace = TRUE),
             Survived = sample(0:1, n, replace = TRUE))
}

expect_error <- function(expr, pattern) {
  message <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  stopifnot(!is.null(message), grepl(pattern, message))
}

run_tests <- function() {
  train <- passengers()
  features <- make_features(train)
  fitted <- fit_preprocessing(features)
  before <- fitted
  changed <- features[1:4, ]
  changed$Age <- c(NA, 10000, NA, 10000)
  changed$Embarked <- c("unseen-port", NA, "S", "S")
  transformed <- apply_preprocessing(changed, fitted)
  stopifnot(identical(before, fitted), transformed$Age[1] == median(train$Age),
            !anyNA(transformed),
            all(as.character(transformed$Embarked[1:2]) == fitted$modes[["Embarked"]]),
            !"unseen-port" %in% levels(transformed$Embarked))
  model <- fit_model(apply_preprocessing(features, fitted), train$Survived)
  stopifnot(length(predict_labels(model, transformed)) == 4L)
  cat("PASS: preprocessing learns only fitting values; missing/unseen values can be predicted.\n")

  train$Survived <- 1L - train$Survived
  train$PassengerId <- train$PassengerId + 1000
  stopifnot(identical(features, make_features(train)))
  cat("PASS: outcomes and IDs cannot enter model features.\n")

  valid <- validation_indices(train$Survived)
  stopifnot(identical(valid, validation_indices(train$Survived)), !anyDuplicated(valid),
            length(unique(train$Survived[valid])) == 2L,
            length(unique(train$Survived[-valid])) == 2L,
            length(intersect(valid, setdiff(seq_len(nrow(train)), valid))) == 0L)
  cat("PASS: stratified validation is deterministic and disjoint.\n")

  directory <- tempfile("titanic-r-test-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  write.csv(train, file.path(directory, "train.csv"), row.names = FALSE)
  test <- passengers(10, 10001)[10:1, ]
  test$Survived <- NULL
  test$Age[1] <- NA
  test$Fare[2] <- NA
  write.csv(test, file.path(directory, "test.csv"), row.names = FALSE)
  write.csv(data.frame(PassengerId = test$PassengerId, Survived = 0),
            file.path(directory, "gender_submission.csv"), row.names = FALSE)
  output <- file.path(directory, "results")
  invisible(capture.output(metrics <- run(directory, output)))
  saved <- read.csv(file.path(output, "submission.csv"))
  validation <- read.csv(file.path(output, "validation_predictions.csv"))
  stopifnot(identical(names(saved), c("PassengerId", "Survived")),
            identical(saved$PassengerId, test$PassengerId), all(saved$Survived %in% 0:1),
            is.null(metrics$official_test_accuracy), is.null(metrics$kaggle_public_accuracy),
            metrics$validation_accuracy == mean(validation$Survived == validation$Predicted))
  saved_metrics <- fromJSON(file.path(output, "metrics.json"))
  stopifnot(identical(dim(saved_metrics$validation_confusion_matrix), c(2L, 2L)),
            sum(saved_metrics$validation_confusion_matrix) == nrow(validation))
  cat("PASS: CSV order/schema, JSON confusion matrix, and honest evaluation survive a full run.\n")

  score <- file.path(directory, "score.json")
  submission <- file.path(output, "submission.csv")
  stopifnot(is.null(matching_kaggle_score(submission, score)))
  write_json(list(submission_sha256 = digest(file = submission, algo = "sha256"),
                  public_score = 0.75), score, auto_unbox = TRUE)
  stopifnot(matching_kaggle_score(submission, score)$public_score == 0.75)
  cat("\n", file = submission, append = TRUE)
  stopifnot(is.null(matching_kaggle_score(submission, score)))
  cat("PASS: external scores are shown only for the exact scored file.\n")

  expect_error(read_titanic(file.path(directory, "missing")), "Missing.*train.csv")
  write.csv(data.frame(Id = 1, SalePrice = 200000), file.path(directory, "train.csv"), row.names = FALSE)
  expect_error(read_titanic(directory), "missing Titanic columns")
  write.csv(train, file.path(directory, "train.csv"), row.names = FALSE)
  test$PassengerId[1] <- train$PassengerId[1]
  write.csv(test, file.path(directory, "test.csv"), row.names = FALSE)
  expect_error(read_titanic(directory), "overlapping PassengerId")
  cat("PASS: missing data, wrong datasets, and overlapping IDs have actionable errors.\n")
  cat("All 6 R regression checks passed.\n")
}

run_tests()
