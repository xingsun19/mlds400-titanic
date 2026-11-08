# mlds400-titanic

Northwestern University MLDS 400, Homework 3: Titanic survival prediction using
Python, R, and Docker.

This repository contains **Parts 1–4**: the GitHub workflow and complete Titanic
logistic regression analyses in Python and R, each with its own Docker image.
Both workflows also support local execution. The final submission merge is Part 5.

## Repository structure

```text
mlds400-titanic/
├── .gitignore
├── README.md
├── outputs/                    # Local generated results; ignored by Git
│   ├── python/
│   └── r/
└── src/
    ├── data/                   # Local Kaggle CSVs; ignored by Git
    ├── python/
    │   ├── .dockerignore
    │   ├── Dockerfile
    │   ├── requirements.txt
    │   ├── check_environment.py
    │   ├── kaggle_score.json
    │   ├── main.py
    │   └── test_main.py
    └── r/
        ├── .dockerignore
        ├── Dockerfile
        ├── install_packages.R
        ├── kaggle_score.json
        ├── main.R
        └── test_main.R
```

All project code lives in `src/`. Git does not track empty directories, and
`src/data/` is deliberately ignored, so create that directory after cloning.
The optional `.venv/` directory is also local only and ignored by Git. Do not
commit or upload the dataset or virtual environment.

## Local setup

### GitHub Desktop and a text editor

1. In GitHub Desktop, select **File → Clone Repository → URL**.
2. Enter `https://github.com/xingsun19/mlds400-titanic.git` and choose a local path.
3. Select **Clone**. If the repository is already cloned, use
   **File → Add Local Repository** to select the existing folder instead.
4. Select **Current Branch → develop** to use the latest assignment work.
5. Open the repository folder in a text editor, such as Visual Studio Code.
6. Open a terminal in the repository folder and run `mkdir -p src/data`.

### Terminal alternative

With Git installed, run these commands in a terminal (macOS, Linux, or Git Bash
on Windows):

```bash
git clone https://github.com/xingsun19/mlds400-titanic.git
cd mlds400-titanic
git switch develop
mkdir -p src/data
```

Parts 2–4 are on `develop`; `main` retains the completed Part 1 checkpoint
until the final submission merge.

No dataset is needed for Parts 1 and 2. Parts 3 and 4 share the official Titanic
files described below. Other Kaggle competitions also use the filename
`train.csv`; make sure you download **Titanic**, not House Prices.

## Part 2: run the Python environment with Docker

Use a running Docker engine, such as Docker Desktop, Docker Engine on Linux, or
Docker with Colima on macOS. Check that both the client and server are available:

```bash
docker version
```

On a Mac using Colima, start it with `colima start` before running Docker
commands. If you need to install it, follow the
[Colima installation instructions](https://github.com/abiosoft/colima#installation)
and install the Docker client and Buildx with Homebrew. Docker Desktop includes
these components already.

From the repository root, build the image and run the environment check:

```bash
docker build -t mlds400-titanic-python:part3 src/python
docker run --rm mlds400-titanic-python:part3 python check_environment.py
```

The first build downloads the Python base image and installs the exact versions
in `src/python/requirements.txt`. It needs internet access and may take a few
minutes. Later builds reuse cached dependencies. No local Python installation
or dataset mount is required for this Docker check.

The build context is limited to `src/python/`; `src/data/` and the root `.venv/`
are outside it. The `.dockerignore` file further limits the build inputs to the
files needed by this image. Dataset files are never copied into the image.
The container runs as an unprivileged user. The explicit command above runs
the smoke check; its default command runs the Part 3 model.

Expected output includes:

```text
Part 2: Python environment check
Python: 3.13.x
numpy: 2.3.5
pandas: 2.3.3
scikit-learn: 1.7.2
Smoke check passed: CSV parsing, numerical operations, and model fitting work.
No Titanic files were read. Titanic analysis belongs to Part 3.
```

`3.13.x` above stands for the interpreter's actual patch version. The smoke check
uses four synthetic rows created in memory to verify the libraries work
together; its output is not a Titanic model or a Titanic accuracy result.

## Part 2: optional local virtual environment

Use **Python 3.13** for local development. Run these commands from the repository
root (macOS or Linux):

```bash
python3.13 -m venv .venv
source .venv/bin/activate
python -m pip install -r src/python/requirements.txt
python -m pip check
python src/python/check_environment.py
deactivate
```

On Windows PowerShell, create the environment with `py -3.13 -m venv .venv` and
activate it with `.\.venv\Scripts\Activate.ps1`, then use the same `python`
commands. Activation is optional: on macOS/Linux you can run
`.venv/bin/python src/python/check_environment.py` directly.

The same requirements file is used locally and in Docker. It pins both direct
dependencies (NumPy, pandas, and scikit-learn) and their runtime dependencies.
Recreate the virtual environment on another computer instead of copying it.

If Docker reports that it cannot connect to its daemon, start Docker Desktop or
run `colima start`. If Python reports a missing package, confirm that you are
using `.venv/bin/python` and install the requirements into that environment.

## Part 3: download the data

1. Open the [official Titanic data page](https://www.kaggle.com/competitions/titanic/data).
2. Sign in to Kaggle. If you have not joined Titanic, review and accept its
   competition rules yourself before downloading.
3. Select **Download all files → Download as zip** and extract `titanic.zip`.
4. Place `train.csv` and `test.csv` directly inside this repository's `src/data/`.
   The optional `gender_submission.csv` is an example submission, not real labels.

On macOS/Linux, if the ZIP is in Downloads, these commands extract the files:

```bash
mkdir -p src/data
unzip -n "$HOME/Downloads/titanic.zip" -d src/data
```

The official training file has 891 rows and includes `Survived`; the test file
has 418 rows and does **not** include `Survived`. Keep all downloaded data local.
The script never needs Kaggle credentials, and the container does not download
or embed any data.

## Part 3: run with Docker

From the repository root, with Docker running and the CSV files downloaded:

```bash
mkdir -p outputs/python
docker build -t mlds400-titanic-python:part3 src/python
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,source="$(pwd)/src/data",target=/data,readonly \
  --mount type=bind,source="$(pwd)/outputs/python",target=/outputs \
  mlds400-titanic-python:part3
```

The commands above work on macOS/Linux. `--user` matches the host user's UID/GID
so generated files belong to you. The data mount is read-only; only `outputs/`
is written. `--rm` removes the stopped container and leaves the output files.
No local Python installation is required.

For Windows PowerShell with Docker Desktop running Linux containers:

```powershell
New-Item -ItemType Directory -Force outputs/python | Out-Null
docker build -t mlds400-titanic-python:part3 src/python
docker run --rm `
  --mount "type=bind,source=$((Get-Location).Path)/src/data,target=/data,readonly" `
  --mount "type=bind,source=$((Get-Location).Path)/outputs/python,target=/outputs" `
  mlds400-titanic-python:part3
```

The terminal prints the dataset dimensions, missing values, descriptive
statistics, each feature change, fitted imputation values, model settings,
training and validation accuracies, confusion matrix, and test predictions.
These outputs cover assignment questions 14–18 without opening the source code.

The script writes three local files, all ignored by Git:

| File | Contents |
| --- | --- |
| `outputs/python/submission.csv` | 418 predictions with exactly `PassengerId,Survived`, ready for Kaggle |
| `outputs/python/validation_predictions.csv` | Held-out passenger IDs, known labels, and predicted labels |
| `outputs/python/metrics.json` | Accuracies, split sizes, seed, confusion matrix, and input SHA-256 hashes |

Running again replaces these generated files in the selected output directory.
If a CSV is missing or belongs to another dataset, the script exits with a
clear error. Create both host directories before using Docker's `--mount`.

### Optional: run locally and check the code

After creating the Part 2 virtual environment:

```bash
.venv/bin/python src/python/main.py
.venv/bin/python -m unittest discover -s src/python -p 'test_*.py' -v
```

On Windows, use `.venv\Scripts\python.exe` instead of `.venv/bin/python`.
The default paths are based on the script's location, so local execution also
works from another working directory. Custom locations are supported:

```bash
.venv/bin/python src/python/main.py --data-dir src/data --output-dir outputs/python
```

The regression tests use small synthetic fixtures to check leakage,
missing values and unseen categories, prediction row order, honest reporting
of missing test labels, and invalid input handling. These fixtures are only
software tests; the results below were measured using the actual Titanic data.

### Model and evaluation

The predictors are `Age`, `Fare`, `FamilySize = SibSp + Parch + 1`, `Pclass`,
`Sex`, `Embarked`, and a title extracted from `Name`. Common equivalent titles
are combined and uncommon titles are grouped as `Rare`. Raw names, tickets,
cabins, passenger IDs, and the outcome are excluded from the predictors.

A stratified 80/20 split of `train.csv` uses seed 42: 712 fitting rows and 179
validation rows. A scikit-learn pipeline fits median imputation and scaling
for numeric columns, mode imputation and one-hot encoding for categories,
and L2-regularized logistic regression. All fitted transformations use only
the fitting subset during validation. Unseen categories are safely ignored.
The final pipeline is then refitted on all 891 labeled rows to predict `test.csv`.

Verified locally and in Docker using the pinned dependencies:

| Metric | Result | Meaning |
| --- | --- | --- |
| Training-split accuracy | 82.30% | 712 rows used to fit the validation model |
| Held-out validation accuracy | 83.80% | 150 correct out of 179 unseen labeled rows |
| Validation majority baseline | 61.45% | Predict the most common fitting-set class |
| Full-training accuracy | 82.94% | In-sample accuracy of the final model on 891 rows |
| Kaggle public test score | 0.76555 (76.555%) | Actual completed submission on November 8, 2026 |

The validation confusion matrix is `[[99, 11], [18, 51]]`, with true classes
0/1 in rows and predicted classes 0/1 in columns. Local and Docker runs produce
identical predictions and metrics. Training accuracy is optimistic; use the
held-out result to assess generalization without tuning on the validation set.

**Question 18 and the official test set:** Kaggle explicitly withholds the true
outcomes in `test.csv`, so its accuracy cannot be calculated locally.
`gender_submission.csv` is a female-survival baseline, not ground truth.
The script records `official_test_accuracy: null` for local evaluation. The
predictions have also been submitted to Kaggle: the completed submission earned
a **public score of 0.76555** on November 8, 2026. This is recorded in
`src/python/kaggle_score.json` with the submitted CSV's SHA-256 hash. When the
generated predictions match that hash, the terminal also prints this previously
verified external score and saves it as `kaggle_public_accuracy` in `metrics.json`.
If predictions change, the recorded score is not reused. The program does not
contact Kaggle or claim to recalculate hidden-label accuracy during a local run.
This public score is distinct from the held-out validation result and does not
establish any unreported private leaderboard score.
To obtain an actual competition score, select **Submit Prediction** on Kaggle,
upload `outputs/python/submission.csv`, and inspect the evaluated submission.
See the [official data description](https://www.kaggle.com/competitions/titanic/data)
and [evaluation instructions](https://www.kaggle.com/competitions/titanic/overview/evaluation).

## Part 4: run the R workflow with Docker

Use the same official `src/data/train.csv` and `src/data/test.csv` downloaded
above. R reads these files directly and runs independently of the Python code.
From the repository root, with Docker running:

```bash
mkdir -p outputs/r
docker build -t mlds400-titanic-r:part4 src/r
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,source="$(pwd)/src/data",target=/data,readonly \
  --mount type=bind,source="$(pwd)/outputs/r",target=/outputs \
  mlds400-titanic-r:part4
```

For Windows PowerShell with Docker Desktop running Linux containers:

```powershell
New-Item -ItemType Directory -Force outputs/r | Out-Null
docker build -t mlds400-titanic-r:part4 src/r
docker run --rm `
  --mount "type=bind,source=$((Get-Location).Path)/src/data,target=/data,readonly" `
  --mount "type=bind,source=$((Get-Location).Path)/outputs/r,target=/outputs" `
  mlds400-titanic-r:part4
```

No local R installation is needed for Docker. The image pins official `r-base`
**4.5.3** to a multi-architecture digest that supports both Apple Silicon and
Intel/AMD computers. `install_packages.R` installs **jsonlite 2.0.0** for JSON
and **digest 0.6.37** for file hashes from CRAN, using its archive when a pinned
release is no longer current. It checks the installed versions and stops on a
mismatch. The `stats` and `utils` packages ship with R. The first build requires
internet access; later builds reuse cached packages.

The container uses an unprivileged account. On macOS/Linux, `--user` makes the
output files belong to your host user. Data are mounted read-only and excluded
from the build context. Results go to `outputs/r/`, separately from Python:

| File | Contents |
| --- | --- |
| `outputs/r/submission.csv` | 418 R predictions, with exactly `PassengerId,Survived` |
| `outputs/r/validation_predictions.csv` | The R holdout's passenger IDs, true labels, and predictions |
| `outputs/r/metrics.json` | R accuracies, confusion matrix, split sizes, hashes, and any verified external score |

The terminal prints exploration, missing counts, transformations, fitted
imputation values and category levels, the model formula and coefficients,
training/validation metrics, test predictions, and Kaggle score status. The
container exits after finishing; generated files persist on the host. Repeated
runs replace files in the selected output directory.

### Optional: run R locally

With **R 4.5.3** installed, run from the repository root:

```bash
Rscript --vanilla src/r/install_packages.R
Rscript --vanilla src/r/main.R
Rscript --vanilla src/r/test_main.R
```

The installer skips packages already installed at the correct versions. If a
source installation is needed locally, a working R package compilation toolchain
is required; Docker already includes it. Use Docker if you do not want to set
up local compilers. Local data and output defaults are relative to the script's
location. To use different directories:

```bash
Rscript --vanilla src/r/main.R --data-dir src/data --output-dir outputs/r
```

The same regression checks can run inside the built image without Titanic data:

```bash
docker run --rm mlds400-titanic-r:part4 Rscript --vanilla test_main.R
```

Six synthetic-data checks cover training-only preprocessing, missing and unseen
categories, outcome/ID exclusion, a deterministic disjoint holdout, CSV/JSON
outputs, stale external-score rejection, and actionable input errors. Both local
and container checks passed. Actual Titanic outputs also match byte for byte
between local R and Docker.

### R model and evaluation

The R model uses `stats::glm(..., family = binomial(link = "logit"))` with
`Age`, `LogFare = log(1 + Fare)`, `FamilySize = SibSp + Parch + 1`, `Pclass`,
`Sex`, and `Embarked`. The last three are factors with treatment contrasts;
the others are numeric. `LogFare` reduces fare skew while retaining zero-fare
passengers. The model has no regularization or numeric scaling and predicts
survival when the fitted probability is at least 0.5.

The split holds out 20% of each outcome class (rounded up), using R seed 42:
712 fitting and 179 validation rows. Medians, category modes, and factor levels
are learned only from the fitting rows. Missing/unseen categories at prediction
time map to the fitting-set mode. The final preprocessing and model are refitted
on all 891 labeled passengers before producing the official test predictions.

| R metric | Result | Meaning |
| --- | --- | --- |
| Training-split accuracy | 79.49% | 712 fitting rows |
| Held-out validation accuracy | 82.68% | 148 correct out of 179 held-out rows |
| Validation majority baseline | 61.45% | Most common fitting-set class |
| Full-training accuracy | 79.91% | Final model's in-sample accuracy on 891 rows |
| Kaggle public test score | 0.76315 (76.315%) | Actual R submission completed November 8, 2026 |

The validation confusion matrix is `[[99, 11], [20, 49]]`, with true 0/1 rows
and predicted 0/1 columns. Although Python and R both use seed 42, their random
number generators produce different held-out passengers. Their validation
percentages therefore are not a controlled comparison of the two models.
The R formula also differs from Python's features and regularization.

The official `test.csv` has no labels, so locally computed test accuracy remains
`null`. R never reads `gender_submission.csv` as ground truth. The R predictions
were submitted successfully to Kaggle on November 8, 2026 and received public
score **0.76315**. This is recorded in `src/r/kaggle_score.json` and shown only when
the generated CSV matches the scored file's SHA-256 hash. This external score
is distinct from local validation and is not recomputed during the script run.

## Branch and pull request workflow

- `main`: completed work ready for submission.
- `develop`: integration branch for the assignment.
- `feature/titanic`: working branch based on the same starting commit as `develop`.
- `codex/part2-environment`: Part 2 working branch created from `develop`.
- `codex/part3-python-model`: Part 3 working branch created from `develop`.
- `codex/part4-r-model`: Part 4 working branch created from `develop`.

Part 1 changes follow this pull request sequence:

```text
feature/titanic → develop → main
```

Each pull request includes a summary of the changes and the checks performed.
Keep these branches available so the assignment workflow can be inspected.
For subsequent parts, update `develop` and create a new working branch from it
before making changes. Part 2 follows `codex/part2-environment → develop`;
Part 3 follows `codex/part3-python-model → develop`, and Part 4 follows
`codex/part4-r-model → develop`. The final merge from
`develop` to `main` is reserved for Part 5.

## Verify the setup

Run from the repository root:

```bash
git branch -a
git check-ignore -v src/data/train.csv src/data/test.csv outputs/python/submission.csv outputs/r/submission.csv .venv/pyvenv.cfg .DS_Store
git ls-files
```

The branch list should include `main`, `develop`, and `feature/titanic` (some may
appear under `remotes/origin/`). The ignore check should show a matching rule for
each sample path, even before the files are downloaded. The tracked-file list
should contain the project files and no dataset or virtual-environment files.
