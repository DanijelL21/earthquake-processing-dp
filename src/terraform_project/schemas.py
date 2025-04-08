from typing import Iterator, Optional

from pydantic import BaseModel


class MetadataObj(BaseModel):
    generated: Optional[int]
    url: Optional[str]
    title: Optional[str]
    status: Optional[int]
    api: Optional[str]
    count: Optional[int]

    class Config:
        extra = "allow"


class GeometryObj(BaseModel):
    type: str
    coordinates: list[float]


class FeaturesObj(BaseModel):
    type: str
    properties: Optional[dict]
    geometry: GeometryObj
    id: Optional[str]


class EarthquakeData(BaseModel):
    generated: int
    properties: Optional[dict]
    geometry_type: str
    geometry_coordinates: list[float]
    bbox: Optional[list[float]]


class EarthquakeGeoJSON(BaseModel):
    type: str
    metadata: MetadataObj
    features: list[FeaturesObj]
    bbox: Optional[list[float]]

    class Config:
        extra = "allow"

    def parse_earthquake_data(self) -> Iterator[EarthquakeData]:
        if self.features:
            for feature in self.features:
                record = {
                    "generated": self.metadata.generated,
                    "properties": feature.properties,
                    "geometry_type": feature.geometry.type,
                    "geometry_coordinates": feature.geometry.coordinates,
                    "bbox": self.bbox,
                }

                yield EarthquakeData.parse_obj(record)
        else:
            return iter([])
