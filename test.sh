#!/usr/bin/env bash
cd "${0%/*}" || exit

pipenv run pytest -v src/tests/ 