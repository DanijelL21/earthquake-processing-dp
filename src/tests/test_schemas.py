import json
import os

import pytest

from earthquake_processing.schemas import EarthquakeGeoJSON


@pytest.fixture
def sample_earthquake_data():
    samples_dir = os.path.join(os.path.dirname(__file__), "samples")
    with open(f"{samples_dir}/eartquake_data.json", "r") as sample_file:
        return json.load(sample_file)


@pytest.fixture
def sample_parsed_earthquake_data():
    samples_dir = os.path.join(os.path.dirname(__file__), "samples")
    with open(f"{samples_dir}/parsed_eartquake_data.json", "r") as sample_file:
        return json.load(sample_file)


def test_parse_earthquake_data(
    sample_earthquake_data, sample_parsed_earthquake_data
):
    earthquake_data = EarthquakeGeoJSON.parse_obj(sample_earthquake_data)

    response = next(earthquake_data.parse_earthquake_data())
    assert response.dict() == sample_parsed_earthquake_data
