import json
import os
from unittest.mock import Mock

import pytest

from terraform_project.common import get_earthquake_data
from terraform_project.schemas import EarthquakeGeoJSON


@pytest.fixture
def sample_earthquake_data():
    samples_dir = os.path.join(os.path.dirname(__file__), "samples")
    with open(f"{samples_dir}/eartquake_data.json", "r") as sample_file:
        return json.load(sample_file)


def test_get_earthquake_data(mocker, sample_earthquake_data):
    mock_post = mocker.patch("requests.get")

    mock_response = Mock()
    mock_response.json.return_value = sample_earthquake_data
    mock_response.status_code = 200
    mock_post.return_value = mock_response

    response = get_earthquake_data("https://dummy.api/earthquakes", hours=1)

    parsed_obj = EarthquakeGeoJSON.parse_obj(sample_earthquake_data)

    assert response == parsed_obj
