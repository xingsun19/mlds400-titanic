# mlds400-titanic

Northwestern University MLDS 400, Homework 3: Titanic survival prediction using
**Python, R, and Docker**. Both implementations explore the official data, fit
logistic regression, evaluate a held-out validation set, and generate Kaggle
predictions. All required analysis steps and results are printed to the terminal.

**Use `main` for the final submission.** This repository uses `main` as the default
branch; it serves the same role as `master` in the assignment. `develop` and the
working branches preserve the development and pull request history.

## Run the project in four steps

You need Git, a running Docker engine, and a Kaggle account to download the data.
**Local Python, R, or a virtual environment is not required for the Docker runs.**
The first build needs internet access to download base images and packages;
subsequent runs use the built images and local data.

Docker Desktop should be running on Windows/macOS, or Docker Engine on Linux.
On this Mac, Docker uses Colima; start it with `colima start` if needed.
`docker version` must show both client and server information before proceeding.
See the [Colima setup instructions](https://github.com/abiosoft/colima#installation)
if using that option.

### 1. Clone the final branch

Open a terminal and run:

```bash
git clone --branch main https://github.com/xingsun19/mlds400-titanic.git
cd mlds400-titanic
docker version
```

Run **all subsequent commands from this repository root**, where `README.md`
is located. If using GitHub Desktop, clone the same URL, select **Current Branch
→ main**, and open a terminal in that repository.

### 2. Download the official Titanic data

1. Open the [Titanic data page](https://www.kaggle.com/competitions/titanic/data).
2. Sign in to Kaggle. If needed, review and accept the competition rules yourself.
3. Select **Download all files → Download as zip**.
4. Extract `titanic.zip` and put `train.csv` and `test.csv` directly in `src/data/`.

If the ZIP was saved to your Downloads folder, macOS/Linux users can run:

```bash
mkdir -p src/data
unzip -n "$HOME/Downloads/titanic.zip" -d src/data
```

On Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force src/data | Out-Null
Expand-Archive -Path "$HOME/Downloads/titanic.zip" -DestinationPath src/data
```

If your browser used a different download location or filename, adjust the ZIP
path. If the files are already present, skip extraction. Do not leave the CSVs
inside an additional `titanic/` subdirectory. The expected files are:

```text
src/data/train.csv             # 891 passengers; includes Survived
src/data/test.csv              # 418 passengers; no Survived column
src/data/gender_submission.csv # Optional example, never treated as true labels
```

Other competitions also use the name `train.csv`; download **Titanic**, not
House Prices. Both scripts check the required columns, training labels, and
passenger IDs. The dataset is deliberately absent from Git and from the images.
The scripts do not download data or require Kaggle credentials at runtime.

### 3. Build and run Python

macOS/Linux:

```bash
mkdir -p outputs/python
docker build -t mlds400-titanic-python:part3 src/python
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,source="$(pwd)/src/data",target=/data,readonly \
  --mount type=bind,source="$(pwd)/outputs/python",target=/outputs \
  mlds400-titanic-python:part3
```

Windows PowerShell with Docker Desktop using Linux containers:

```powershell
New-Item -ItemType Directory -Force outputs/python | Out-Null
docker build -t mlds400-titanic-python:part3 src/python
docker run --rm `
  --mount "type=bind,source=$((Get-Location).Path)/src/data,target=/data,readonly" `
  --mount "type=bind,source=$((Get-Location).Path)/outputs/python,target=/outputs" `
  mlds400-titanic-python:part3
```

Wait for `Part 3 run completed successfully.` in the terminal. The image uses
Python 3.13 and the exact dependency versions in `src/python/requirements.txt`.
The Docker build context is `src/python/`, not the repository root.

### 4. Build and run R

macOS/Linux:

```bash
mkdir -p outputs/r
docker build -t mlds400-titanic-r:part4 src/r
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,source="$(pwd)/src/data",target=/data,readonly \
  --mount type=bind,source="$(pwd)/outputs/r",target=/outputs \
  mlds400-titanic-r:part4
```

Windows PowerShell with Docker Desktop using Linux containers:

```powershell
New-Item -ItemType Directory -Force outputs/r | Out-Null
docker build -t mlds400-titanic-r:part4 src/r
docker run --rm `
  --mount "type=bind,source=$((Get-Location).Path)/src/data,target=/data,readonly" `
  --mount "type=bind,source=$((Get-Location).Path)/outputs/r,target=/outputs" `
  mlds400-titanic-r:part4
```

Wait for `Part 4 run completed successfully.` R reads the same data directly and
runs independently of Python. Its image pins R **4.5.3** by multi-architecture
digest. `install_packages.R` installs **jsonlite 2.0.0** and **digest 0.6.37**,
using CRAN's archive when needed, and verifies their versions. `stats` and
`utils` ship with R. The build context is `src/r/`.

Both containers run as unprivileged users. On macOS/Linux, `--user` matches your
host UID/GID so saved files belong to you. The input mount is read-only. `--rm`
removes each stopped container while leaving results in the host's `outputs/`.
These image tags identify assignment parts and are the same tags used in the
verified commands; they can be built directly from the final `main` branch.

## Results and generated files

Each script prints dataset dimensions, missing values, descriptive statistics,
feature changes, fitted preprocessing values, model settings, training and
validation accuracy, a confusion matrix, test predictions, and score status.
The grader can inspect these terminal outputs for questions 14–18 without
opening either analysis script.

| Metric | Python | R |
| --- | --- | --- |
| Full-training accuracy | 82.94% | 79.91% |
| Held-out validation accuracy | 83.80% | 82.68% |
| Recorded Kaggle public test score | 0.76555 | 0.76315 |

The two validation sets contain different passengers, so their percentages are
not a controlled comparison. Kaggle scores are from actual completed submissions
on November 8, 2026. Official test labels are withheld; local test accuracy is
therefore `null`. Each script shows its recorded external score only when the
new prediction file matches the previously scored CSV's SHA-256 hash. Neither
script substitutes `gender_submission.csv` for true labels or contacts Kaggle
while running. Model-specific details follow below.

Each language writes three files:

| File | Contents |
| --- | --- |
| `outputs/python/submission.csv` and `outputs/r/submission.csv` | 418 predictions with exactly `PassengerId,Survived`, in official test row order |
| `outputs/python/validation_predictions.csv` and `outputs/r/validation_predictions.csv` | Held-out passenger IDs, known labels, and model predictions |
| `outputs/python/metrics.json` and `outputs/r/metrics.json` | Accuracies, split sizes, confusion matrix, seed, input/output hashes, and any matching recorded score |

Repeated runs replace these files in the mounted output directory. All generated
results and downloaded data remain local and are ignored by Git. To obtain a
new Kaggle score after changing a model, submit its new `submission.csv` using
**Submit Prediction** on the competition page.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Docker cannot connect to its daemon | Start Docker Desktop, or run `colima start` on a Mac using Colima; retry `docker version`. |
| `bind source path does not exist` | Run from the repository root and create `src/data/` plus the appropriate `outputs/` directory before `docker run`. |
| `Missing /data/train.csv` or `test.csv` | Extract the official CSVs directly into `src/data/` and include the data mount shown above. |
| Missing Titanic columns or overlapping passenger IDs | Confirm that both files came from the official Titanic ZIP; do not substitute unrelated or copied training files. |
| Permission denied while saving results | On macOS/Linux, retain the `--user` option and choose an output directory you own. On Docker Desktop, ensure the project folder is shared with Docker. |
| Base-image or package download fails | Check internet access, then rerun the build. Completed dependency layers can be reused. |
| No matching recorded Kaggle score | Predictions differ from the recorded submission; upload this new CSV for a new score. Validation metrics remain available locally. |
| Local Python/R reports missing packages | Use the optional installation commands below, or use Docker without local language installations. |

## Optional local execution and checks

Docker is sufficient for grading. These commands support development or running
checks directly on your computer.

### Python environment and local run

Use Python **3.13**, from the repository root on macOS/Linux:

```bash
python3.13 -m venv .venv
.venv/bin/python -m pip install -r src/python/requirements.txt
.venv/bin/python -m pip check
.venv/bin/python src/python/check_environment.py
.venv/bin/python src/python/main.py
.venv/bin/python -m unittest discover -s src/python -p 'test_*.py' -v
```

On Windows, create the environment with `py -3.13 -m venv .venv` and replace
`.venv/bin/python` with `.venv\Scripts\python.exe` in the remaining commands.
The same requirements file pins direct and runtime dependencies locally and in
Docker. Recreate environments on each computer; `.venv/` stays out of Git.

The Part 2 environment check also runs without Titanic data in the built image:

```bash
docker run --rm mlds400-titanic-python:part3 python check_environment.py
```

It uses four synthetic rows to verify CSV parsing, numerical operations, and
model fitting; it is not the Titanic analysis. Five Python regression tests
cover preprocessing isolation, missing/unseen categories, target/ID exclusion,
output ordering and metrics, stale external scores, and invalid inputs.

### R environment and local run

With R **4.5.3** installed:

```bash
Rscript --vanilla src/r/install_packages.R
Rscript --vanilla src/r/main.R
Rscript --vanilla src/r/test_main.R
```

The installer skips packages already installed at the pinned versions. Local
source installation requires an R compilation toolchain; Docker includes it.
Six R regression checks cover training-only preprocessing, missing/unseen values,
outcome/ID exclusion, a deterministic disjoint split, CSV/JSON outputs, stale
external scores, and invalid input handling. They can run without Titanic data
inside the built image:

```bash
docker run --rm mlds400-titanic-r:part4 Rscript --vanilla test_main.R
```

Both scripts locate their default data/output directories relative to their
source files. Custom paths are supported from the repository root:

```bash
.venv/bin/python src/python/main.py --data-dir src/data --output-dir outputs/python
Rscript --vanilla src/r/main.R --data-dir src/data --output-dir outputs/r
```

The documented Docker workflows were verified on macOS Apple Silicon with
Colima (Linux ARM64), using the official CSVs. Each language's local and Docker
outputs matched byte for byte. Windows PowerShell commands are provided but
were not executed on this Mac. Synthetic regression fixtures test software
behavior; the reported model accuracies use real Titanic data.

## Python model and evaluation

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

## R model and evaluation

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

## Repository structure

```text
mlds400-titanic/
├── .gitignore
├── README.md
├── outputs/                    # Generated locally; ignored by Git
│   ├── python/
│   └── r/
└── src/
    ├── data/                   # Downloaded locally; ignored by Git
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

All source code lives in `src/`. Git does not track empty directories, so create
`src/data/` and the output folders after cloning. Each `.dockerignore` allows
only the source/configuration files needed for that image.

## Assignment and Git workflow

| Part | Delivered work |
| --- | --- |
| 1 | Public repository, `main`/`develop`/working branches, Git ignore rules, and initial PRs |
| 2 | Pinned Python requirements, Docker environment, smoke check, and optional local virtual environment |
| 3 | Python analysis, logistic regression, validation, predictions, Docker verification, and PR to `develop` |
| 4 | Independent R analysis, package installer, Docker image, evaluation, and PR to `develop` |
| 5 | Final reproducible README and the `develop → main` submission PR |

The branch history is retained for inspection:

- `main`: final submission branch (the assignment's `master` equivalent).
- `develop`: integration branch for completed parts.
- `feature/titanic`: Part 1 working branch.
- `codex/part2-environment`: Part 2 environment work.
- `codex/part3-python-model`: Part 3 Python model.
- `codex/part4-r-model`: Part 4 R model.
- `codex/part5-final-readme`: final README preparation.

Working branches are integrated through pull requests into `develop`. Part 5
submits the complete project through a final `develop → main` pull request.
See the repository's [pull request history](https://github.com/xingsun19/mlds400-titanic/pulls?q=is%3Apr).

To inspect tracked files and ignore rules from the repository root:

```bash
git branch -a
git check-ignore -v src/data/train.csv src/data/test.csv outputs/python/submission.csv outputs/r/submission.csv .venv/pyvenv.cfg .DS_Store
git ls-files
```

The tracked-file list contains source and documentation, with no downloaded
datasets, generated predictions, credentials, or virtual environments.
