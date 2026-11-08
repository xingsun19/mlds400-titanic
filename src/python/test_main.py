"""Regression checks use synthetic passengers, never the private Kaggle labels."""

from contextlib import redirect_stdout
from io import StringIO
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

import numpy as np
import pandas as pd

from main import build_model, load_data, make_features, matching_kaggle_score, run


def passengers(count=40, first_id=1):
    return pd.DataFrame({
        "PassengerId": range(first_id, first_id + count),
        "Pclass": [1, 3] * (count // 2),
        "Name": ["Example, Miss. A", "Example, Mr. B"] * (count // 2),
        "Sex": ["female", "male"] * (count // 2),
        "Age": [20.0, 40.0] * (count // 2),
        "SibSp": [0, 1] * (count // 2), "Parch": 0,
        "Fare": [50.0, 10.0] * (count // 2), "Embarked": "S",
        "Survived": [1, 0] * (count // 2),
    })


class TitanicTests(unittest.TestCase):
    def test_preprocessing_does_not_learn_from_prediction_rows(self):
        train = passengers()
        model = build_model().fit(make_features(train), train["Survived"])
        prep = model.named_steps["preprocess"]
        numeric = prep.named_transformers_["numeric"]
        before = numeric.named_steps["impute"].statistics_.copy()
        test = passengers(4, 100).drop(columns="Survived")
        test["Age"] = [np.nan, 10000, np.nan, 10000]
        test["Fare"] = np.nan
        test["Embarked"] = ["unseen-port", np.nan, "S", "S"]
        probability = model.predict_proba(make_features(test))
        np.testing.assert_array_equal(before, numeric.named_steps["impute"].statistics_)
        self.assertEqual(before[0], 30.0)
        self.assertTrue(np.isfinite(probability).all())
        np.testing.assert_allclose(probability.sum(axis=1), 1)

    def test_target_and_id_cannot_affect_features(self):
        train = passengers()
        original = make_features(train)
        train["Survived"] = 1 - train["Survived"]
        train["PassengerId"] += 1000
        pd.testing.assert_frame_equal(original, make_features(train))

    def test_end_to_end_preserves_ids_and_does_not_invent_test_accuracy(self):
        with TemporaryDirectory() as directory:
            data = Path(directory)
            passengers().to_csv(data / "train.csv", index=False)
            test = passengers(4, 100).drop(columns="Survived").iloc[::-1]
            test.to_csv(data / "test.csv", index=False)
            # A misleading sample submission must never become ground truth.
            test[["PassengerId"]].assign(Survived=0).to_csv(
                data / "gender_submission.csv", index=False
            )
            output = data / "results"
            with redirect_stdout(StringIO()):
                metrics = run(data, output)
            saved = pd.read_csv(output / "submission.csv")
            self.assertEqual(saved.columns.tolist(), ["PassengerId", "Survived"])
            self.assertEqual(saved["PassengerId"].tolist(), test["PassengerId"].tolist())
            self.assertTrue(saved["Survived"].isin([0, 1]).all())
            self.assertIsNone(metrics["official_test_accuracy"])
            self.assertIsNone(metrics["kaggle_public_accuracy"])
            validation = pd.read_csv(output / "validation_predictions.csv")
            self.assertEqual((validation.Survived == validation.Predicted).mean(),
                             metrics["validation_accuracy"])

    def test_external_score_is_not_reused_for_changed_predictions(self):
        with TemporaryDirectory() as directory:
            record_path = Path(directory) / "score.json"
            csv = b"PassengerId,Survived\n100,1\n"
            self.assertIsNone(matching_kaggle_score(csv, record_path))
            record_path.write_text(json.dumps({
                "submission_sha256": hashlib.sha256(csv).hexdigest(), "public_score": 0.75
            }))
            self.assertEqual(matching_kaggle_score(csv, record_path)["public_score"], 0.75)
            self.assertIsNone(matching_kaggle_score(csv.replace(b"100,1", b"100,0"), record_path))

    def test_input_errors_are_actionable(self):
        with TemporaryDirectory() as directory:
            data = Path(directory)
            with self.assertRaisesRegex(ValueError, "Missing.*train.csv"):
                load_data(data)
            pd.DataFrame({"Id": [1], "SalePrice": [200000]}).to_csv(
                data / "train.csv", index=False
            )
            with self.assertRaisesRegex(ValueError, "missing Titanic columns"):
                load_data(data)
            passengers().to_csv(data / "train.csv", index=False)
            passengers(4).drop(columns="Survived").to_csv(data / "test.csv", index=False)
            with self.assertRaisesRegex(ValueError, "overlapping PassengerId"):
                load_data(data)


if __name__ == "__main__":
    unittest.main()
