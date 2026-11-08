# mlds400-titanic

Northwestern University MLDS 400, Homework 3: Titanic survival prediction using
Python, R, and Docker.

This repository currently contains the **Part 1 GitHub setup**. The Python and R
models, dependencies, and Docker instructions will be added in later parts of the
assignment. There is no model to run yet.

## Repository structure

```text
mlds400-titanic/
├── .gitignore
├── README.md
└── src/
    ├── .gitkeep
    └── data/       # Local only; ignored by Git
```

All project code will live in `src/`. The empty `.gitkeep` file keeps `src/` in Git
until source files are added. Git does not track empty directories, and
`src/data/` is deliberately ignored, so create that directory after cloning.
Do not commit or upload the dataset.

## Local setup

### GitHub Desktop and a text editor

1. In GitHub Desktop, select **File → Clone Repository → URL**.
2. Enter `https://github.com/xingsun19/mlds400-titanic.git` and choose a local path.
3. Select **Clone**. If the repository is already cloned, use
   **File → Add Local Repository** to select the existing folder instead.
4. Open the repository folder in a text editor, such as Visual Studio Code.
5. Open a terminal in the repository folder and run `mkdir -p src/data`.

### Terminal alternative

With Git installed, run these commands in a terminal (macOS, Linux, or Git Bash
on Windows):

```bash
git clone https://github.com/xingsun19/mlds400-titanic.git
cd mlds400-titanic
mkdir -p src/data
```

No dataset or Python/R dependencies are needed for Part 1. In the later data
steps, place the Kaggle Titanic `train.csv` and `test.csv` files in `src/data/`.

## Branch and pull request workflow

- `main`: completed work ready for submission.
- `develop`: integration branch for the assignment.
- `feature/titanic`: working branch based on the same starting commit as `develop`.

Part 1 changes follow this pull request sequence:

```text
feature/titanic → develop → main
```

Each pull request includes a summary of the changes and the checks performed.
Keep these branches available so the assignment workflow can be inspected.
For subsequent parts, update `develop` and create a new working branch from it
before making changes.

## Verify the setup

Run from the repository root:

```bash
git branch -a
git check-ignore -v src/data/train.csv src/data/test.csv .DS_Store
git ls-files
```

The branch list should include `main`, `develop`, and `feature/titanic` (some may
appear under `remotes/origin/`). The ignore check should show a matching rule for
each sample path, even before the files are downloaded. The tracked-file list
should contain the project files and no dataset files.
