set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just --list

sb-up *ARGS:
  ./tools/sb_up_v0.sh {{ARGS}}

sb-bootstrap-skills *ARGS:
  ./tools/sb_bootstrap_skills_v0.sh {{ARGS}}

sb-doctor *ARGS:
  ./tools/sb_doctor_v0.sh {{ARGS}}

