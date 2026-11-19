# Replication_I4R_Sports
Supporting code for "A comment on 'Tracking the Reorganizations of MVPA Opportunities During the Transition From French Secondary School to University: A Longitudinal Study'" by Lieke Voorintholt, November 2026.

## Original article and data

- Original article: Derigny, T., Schnitzler, C., Gandrieau, J., Mekkaoui, L., &
  Potdevin, F. (2025). Tracking the reorganizations of MVPA opportunities during
  the transition from French secondary school to university: A longitudinal
  study. *Research Quarterly for Exercise and Sport*.
  https://doi.org/10.1080/02701367.2025.2603519
- Data and code deposited by the authors (Zenodo, CC BY 4.0):
  https://doi.org/10.5281/zenodo.15595425

The authors' data are **not** included in this repository. Download
`Data_DAP.xlsx` from the auhors' Zenodo link above.

## Contents

- `report_replication.do`: reproduces (Stata 19) all of my report's data-based statements in the order they appear.

## How to run

1. Create a project folder with the subfolders `original/`, `data/` and `output/`.
2. Put `Data_DAP.xlsx` from the Zenodo record in `original/`.
3. In Stata, change the working directory to the project folder (e.g. cd "C:/path/project-folder") and run `do report_replication.do`.

The do-file writes intermediate datasets to `data/` and the log to
`output/report_replication.log`. Runtime is about 15 minutes, mostly for the
mixed models. No user-written packages are needed.
