# RESOURCES

resource "snowflake_database" "default_db" {
  name = var.sf_db_name
}

resource "snowflake_schema" "analytics_schema" {
  name     = var.sf_schema_name
  database = snowflake_database.default_db.name
}

resource "snowflake_table" "earthquake_table" {
  name     = var.sf_table_name
  database = snowflake_database.default_db.name
  schema   = var.sf_schema_name

  column {
    name = "generated"
    type = "BIGINT"
  }

  column {
    name = "properties"
    type = "VARIANT"
  }

  column {
    name = "geometry_type"
    type = "STRING"
  }

  column {
    name = "geometry_coordinates"
    type = "VARIANT"
  }

  column {
    name = "bbox"
    type = "VARIANT"
  }

  column {
    name = "ingest_date"
    type = "INT"
  }
}
