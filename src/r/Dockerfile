# Multi-architecture official R image, fixed to the tested R 4.5.3 release.
FROM r-base:4.5.3@sha256:881cf9bc036d399aafe32954e16de5bf5663d9a7aae4a68a3d87222a573a28c9

WORKDIR /app
ENV TZ=UTC

COPY install_packages.R .
RUN Rscript --vanilla install_packages.R

RUN useradd --create-home --uid 10001 appuser
COPY main.R test_main.R kaggle_score.json ./

USER appuser
CMD ["Rscript", "--vanilla", "main.R", "--data-dir", "/data", "--output-dir", "/outputs"]
