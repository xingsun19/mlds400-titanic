"""Part 3: explore Titanic data, fit logistic regression, and export predictions."""

import argparse
import hashlib
import json
from pathlib import Path
import platform

import numpy as np
import pandas as pd
import sklearn
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler


SEED = 42
NUMERIC = ["Age", "Fare", "FamilySize"]
CATEGORICAL = ["Pclass", "Sex", "Embarked", "Title"]
REQUIRED = ["PassengerId", "Pclass", "Name", "Sex", "Age", "SibSp", "Parch",
            "Fare", "Embarked"]
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


def load_data(data_dir):
    """Reject unrelated CSVs and overlapping IDs before fitting anything."""
    frames = []
    for name in ("train.csv", "test.csv"):
        path = data_dir / name
        if not path.is_file():
            raise ValueError(
                f"Missing {path}. Download the Kaggle Titanic ZIP and put "
                "train.csv and test.csv in the data directory (see README)."
            )
        frame = pd.read_csv(path)
        required = REQUIRED + (["Survived"] if name == "train.csv" else [])
        missing = sorted(set(required) - set(frame.columns))
        if missing:
            raise ValueError(f"{name} is missing Titanic columns: {missing}")
        if frame.empty:
            raise ValueError(f"{name} has no passengers.")
        ids = pd.to_numeric(frame["PassengerId"], errors="raise")
        if ids.isna().any() or ids.duplicated().any() or not (ids % 1 == 0).all():
            raise ValueError(f"{name}: PassengerId must be unique, nonmissing integers.")
        frame["PassengerId"] = ids.astype(int)
        for column in ["Pclass", "Age", "SibSp", "Parch", "Fare"]:
            values = pd.to_numeric(frame[column], errors="raise")
            if np.isinf(values).any() or (values.dropna() < 0).any():
                raise ValueError(f"{name}: {column} contains infinite or negative values.")
            frame[column] = values
        if not frame["Pclass"].dropna().isin([1, 2, 3]).all():
            raise ValueError(f"{name}: Pclass must be 1, 2, or 3.")
        frames.append(frame)
    train, test = frames
    if not train["Survived"].isin([0, 1]).all() or train["Survived"].nunique() != 2:
        raise ValueError("train.csv: Survived must contain both binary classes 0 and 1.")
    if set(train["PassengerId"]) & set(test["PassengerId"]):
        raise ValueError("train.csv and test.csv contain overlapping PassengerId values.")
    return train, test


def make_features(frame):
    """Row-wise transformations only: no fitted statistics or outcome information."""
    features = frame[["Age", "Fare", "Pclass", "Sex", "Embarked"]].copy()
    features["FamilySize"] = frame["SibSp"] + frame["Parch"] + 1
    title = frame["Name"].str.extract(r",\s*([^.]*)\.", expand=False).str.strip()
    title = title.replace({"Mlle": "Miss", "Ms": "Miss", "Mme": "Mrs"})
    features["Title"] = title.where(title.isin(["Mr", "Mrs", "Miss", "Master"]), "Rare")
    features["Pclass"] = features["Pclass"].map(
        lambda value: str(int(value)) if pd.notna(value) else np.nan
    )
    return features[NUMERIC + CATEGORICAL]


def build_model():
    numerical = Pipeline([
        ("impute", SimpleImputer(strategy="median", keep_empty_features=True)),
        ("scale", StandardScaler()),
    ])
    categorical = Pipeline([
        ("impute", SimpleImputer(strategy="most_frequent", keep_empty_features=True)),
        ("encode", OneHotEncoder(handle_unknown="ignore")),
    ])
    preprocess = ColumnTransformer([
        ("numeric", numerical, NUMERIC),
        ("categorical", categorical, CATEGORICAL),
    ])
    return Pipeline([
        ("preprocess", preprocess),
        ("model", LogisticRegression(max_iter=2000, random_state=SEED)),
    ])


def print_preprocessing(model, label):
    preprocess = model.named_steps["preprocess"]
    numeric = preprocess.named_transformers_["numeric"]
    categorical = preprocess.named_transformers_["categorical"]
    print(f"{label} fitted numeric medians: "
          f"{dict(zip(NUMERIC, numeric.named_steps['impute'].statistics_.tolist()))}")
    print(f"{label} fitted category modes: "
          f"{dict(zip(CATEGORICAL, categorical.named_steps['impute'].statistics_))}")
    print(f"{label} encoded feature count: {len(preprocess.get_feature_names_out())}")


def matching_kaggle_score(submission_bytes, record_path):
    """Use a previously observed external score only for the exact submitted CSV."""
    if not record_path.is_file():
        return None
    record = json.loads(record_path.read_text())
    if hashlib.sha256(submission_bytes).hexdigest() != record["submission_sha256"]:
        return None
    return record


def run(data_dir, output_dir):
    print("Part 3: Titanic survival prediction with logistic regression")
    print(f"Python {platform.python_version()}; NumPy {np.__version__}; "
          f"pandas {pd.__version__}; scikit-learn {sklearn.__version__}")
    train, test = load_data(data_dir)
    print(f"\n[13-14] Loaded train.csv: {train.shape}; test.csv: {test.shape}")
    print("Input checks passed: Titanic schema, binary training labels, disjoint IDs.")
    print("Missing values by column:")
    print(pd.DataFrame({"train": train.isna().sum(), "test": test.isna().sum()})
          .fillna("not present").to_string())
    print("\nNumeric training-data summary:")
    print(train[["Age", "Fare", "SibSp", "Parch"]].describe().round(2).to_string())
    print("\nTraining survival counts (0 = died, 1 = survived):")
    print(train["Survived"].value_counts().sort_index().to_string())
    print(f"Training survival rate: {train['Survived'].mean():.2%}")
    print("\nDescriptive survival rates by sex and passenger class:")
    print(train.groupby(["Sex", "Pclass"])["Survived"].agg(["count", "mean"])
          .round(4).to_string())

    print("\n[14] Feature changes:")
    print("- FamilySize = SibSp + Parch + 1; replaces the separate family counts.")
    print("- Title extracted from Name; Mlle/Ms -> Miss, Mme -> Mrs; other titles -> Rare.")
    print("- Pclass treated as categorical, together with Sex, Embarked and Title.")
    print("- Excluded PassengerId (identifier), raw Name/Ticket, and sparse Cabin.")
    print("- No rows dropped. Survived is the target only, never a predictor.")
    print("- Numeric missing values: training medians; numeric features standardized.")
    print("- Category missing values: training modes; one-hot encoding; unknowns ignored.")
    print("- All preprocessing is fitted inside a pipeline using the fitting subset only.")
    features = make_features(train)
    target = train["Survived"].astype(int)
    test_features = make_features(test)
    print("Engineered feature preview (training rows):")
    print(features.head().to_string(index=False))

    x_fit, x_valid, y_fit, y_valid = train_test_split(
        features, target, test_size=0.2, random_state=SEED, stratify=target
    )
    print(f"\n[15-16] Stratified split: {len(x_fit)} fitting / {len(x_valid)} validation "
          f"passengers; random_state={SEED}.")
    print("LogisticRegression: L2 regularization, C=1.0, lbfgs solver, max_iter=2000.")
    model = build_model().fit(x_fit, y_fit)
    print_preprocessing(model, "Split model")
    fit_accuracy = accuracy_score(y_fit, model.predict(x_fit))
    valid_predictions = model.predict(x_valid)
    valid_accuracy = accuracy_score(y_valid, valid_predictions)
    baseline = accuracy_score(y_valid, np.full(len(y_valid), y_fit.mode().iloc[0]))
    matrix = confusion_matrix(y_valid, valid_predictions, labels=[0, 1])
    print(f"Training-split accuracy: {fit_accuracy:.4f} ({fit_accuracy:.2%})")
    print(f"Held-out validation accuracy: {valid_accuracy:.4f} ({valid_accuracy:.2%})")
    print(f"Validation majority-class baseline: {baseline:.4f} ({baseline:.2%})")
    print("Validation confusion matrix (rows=true 0/1, columns=predicted 0/1):")
    print(matrix)

    print("\n[17] Refit a fresh pipeline on every labeled training passenger.")
    final_model = build_model().fit(features, target)
    print_preprocessing(final_model, "Final model")
    train_accuracy = accuracy_score(target, final_model.predict(features))
    print(f"Full-training accuracy: {train_accuracy:.4f} ({train_accuracy:.2%}); "
          "in-sample, not an estimate of unseen-data performance.")
    predictions = final_model.predict(test_features)
    submission = pd.DataFrame({"PassengerId": test["PassengerId"], "Survived": predictions})
    submission_bytes = submission.to_csv(index=False, lineterminator="\n").encode("utf-8")
    print(f"Predicted all {len(submission)} test passengers in original row order.")
    print("Predicted survival counts:")
    print(submission["Survived"].value_counts().sort_index().to_string())
    print("Prediction preview:")
    print(submission.head(10).to_string(index=False))

    print("\n[18] Official test accuracy: unavailable locally.")
    print("Kaggle test.csv has no ground-truth Survived column. Validation accuracy "
          "above is measured on held-out train.csv rows, not on official test.csv.")
    print("gender_submission.csv contains example predictions, NOT true labels; "
          "it is never loaded or used for evaluation.")
    print("Submit submission.csv on Kaggle to obtain its leaderboard accuracy.")
    if "Survived" in test.columns:
        print("NOTE: an unexpected test Survived column was ignored; its provenance "
              "is not the official Kaggle ground truth.")
    kaggle_record = matching_kaggle_score(
        submission_bytes, Path(__file__).with_name("kaggle_score.json")
    )
    if kaggle_record:
        print(f"Verified Kaggle public test score: {kaggle_record['public_score']:.5f} "
              f"({kaggle_record['public_score']:.3%}).")
        print(f"Previously submitted at {kaggle_record['submitted_at']}; "
              "this run's submission SHA-256 matches that scored file.")
        print("This external score is recorded from Kaggle, not recalculated locally.")
        print(f"Score source: {kaggle_record['source']}")
    else:
        print("No recorded Kaggle score matches these predictions; submit them for scoring.")

    metrics = {
        "random_state": SEED,
        "validation_fraction": 0.2,
        "train_rows": len(train), "fit_rows": len(x_fit),
        "validation_rows": len(x_valid), "test_rows": len(test),
        "training_split_accuracy": float(fit_accuracy),
        "validation_accuracy": float(valid_accuracy),
        "validation_majority_baseline": float(baseline),
        "validation_confusion_matrix": matrix.tolist(),
        "full_training_accuracy": float(train_accuracy),
        "official_test_accuracy": None,
        "official_test_accuracy_note": "No official test labels supplied by Kaggle; "
                                       "obtain leaderboard score by submitting predictions.",
        "kaggle_public_accuracy": kaggle_record["public_score"] if kaggle_record else None,
        "kaggle_submission": kaggle_record,
        "submission_sha256": hashlib.sha256(submission_bytes).hexdigest(),
        "features": NUMERIC + CATEGORICAL,
        "input_sha256": {
            name: hashlib.sha256((data_dir / name).read_bytes()).hexdigest()
            for name in ("train.csv", "test.csv")
        },
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "submission.csv").write_bytes(submission_bytes)
    pd.DataFrame({
        "PassengerId": train.loc[y_valid.index, "PassengerId"],
        "Survived": y_valid, "Predicted": valid_predictions,
    }).to_csv(output_dir / "validation_predictions.csv", index=False)
    (output_dir / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(f"\nSaved {output_dir / 'submission.csv'} (PassengerId,Survived; no index).")
    print(f"Saved validation_predictions.csv and metrics.json in {output_dir}.")
    print("Part 3 run completed successfully.")
    return metrics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=PROJECT_ROOT / "src" / "data")
    parser.add_argument("--output-dir", type=Path, default=PROJECT_ROOT / "outputs" / "python")
    args = parser.parse_args()
    try:
        run(args.data_dir, args.output_dir)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
