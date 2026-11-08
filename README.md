# mlds400-titanic

Northwestern University MLDS 400, Homework 3: Titanic survival prediction using
Python, R, and Docker.

This repository contains the **Part 1 GitHub setup** and **Part 2 Python
environment setup**, including an optional local virtual environment and a
Docker image. The environment check runs without Titanic data. Titanic modeling
and the R container will be added in Parts 3 and 4.

## Repository structure

```text
mlds400-titanic/
├── .gitignore
├── README.md
└── src/
    ├── data/                   # Local only; ignored by Git
    └── python/
        ├── .dockerignore
        ├── Dockerfile
        ├── requirements.txt
        └── check_environment.py
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

Part 2 is on `develop`; `main` retains the completed Part 1 checkpoint until the
final submission merge.

No dataset is needed for Parts 1 and 2. In the later data steps, place the Kaggle
Titanic `train.csv` and `test.csv` files in `src/data/`.

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
docker build -t mlds400-titanic-python:part2 src/python
docker run --rm mlds400-titanic-python:part2
```

The first build downloads the Python base image and installs the exact versions
in `src/python/requirements.txt`. It needs internet access and may take a few
minutes. Later builds reuse cached dependencies. No local Python installation
or dataset mount is required for this Docker check.

The build context is limited to `src/python/`; `src/data/` and the root `.venv/`
are outside it. The `.dockerignore` file further limits the build inputs to the
three files needed by this image. Dataset files are never copied into the image.
The container runs as an unprivileged user and exits after the check.

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

## Branch and pull request workflow

- `main`: completed work ready for submission.
- `develop`: integration branch for the assignment.
- `feature/titanic`: working branch based on the same starting commit as `develop`.
- `codex/part2-environment`: Part 2 working branch created from `develop`.

Part 1 changes follow this pull request sequence:

```text
feature/titanic → develop → main
```

Each pull request includes a summary of the changes and the checks performed.
Keep these branches available so the assignment workflow can be inspected.
For subsequent parts, update `develop` and create a new working branch from it
before making changes. Part 2 follows `codex/part2-environment → develop`; the
final merge from `develop` to `main` is reserved for Part 5.

## Verify the setup

Run from the repository root:

```bash
git branch -a
git check-ignore -v src/data/train.csv src/data/test.csv .venv/pyvenv.cfg .DS_Store
git ls-files
```

The branch list should include `main`, `develop`, and `feature/titanic` (some may
appear under `remotes/origin/`). The ignore check should show a matching rule for
each sample path, even before the files are downloaded. The tracked-file list
should contain the project files and no dataset or virtual-environment files.
