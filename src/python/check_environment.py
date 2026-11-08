"""Verify the Part 2 environment using synthetic data, without Titanic files."""

from importlib.metadata import version
from io import StringIO
import platform

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression


def main() -> None:
    print("Part 2: Python environment check")
    print(f"Python: {platform.python_version()}")
    for package in ("numpy", "pandas", "scikit-learn"):
        print(f"{package}: {version(package)}")

    # Exercise CSV parsing and the compiled numerical libraries on in-memory
    # sample data. These four rows are not Titanic passenger records.
    samples = pd.read_csv(StringIO("value,target\n0,0\n1,0\n2,1\n3,1\n"))
    features = samples[["value"]]
    model = LogisticRegression(random_state=42).fit(features, samples["target"])
    probabilities = model.predict_proba(features)
    if not (
        np.isfinite(probabilities).all()
        and np.allclose(probabilities.sum(axis=1), 1.0)
    ):
        raise RuntimeError("The numerical smoke check returned invalid probabilities.")

    print("Smoke check passed: CSV parsing, numerical operations, and model fitting work.")
    print("No Titanic files were read. Titanic analysis belongs to Part 3.")


if __name__ == "__main__":
    main()
