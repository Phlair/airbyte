{#
    Adapter Macros for the following functions:
    - Bigquery: unnest() -> https://cloud.google.com/bigquery/docs/reference/standard-sql/arrays#flattening-arrays-and-repeated-fields
    - Snowflake: flatten() -> https://docs.snowflake.com/en/sql-reference/functions/flatten.html
    - Redshift: -> https://blog.getdbt.com/how-to-unnest-arrays-in-redshift/
    - postgres: unnest() -> https://www.postgresqltutorial.com/postgresql-array/
#}

{# unnest -------------------------------------------------     #}

{% macro unnest(array_col) -%}
  {{ adapter.dispatch('unnest')(array_col) }}
{%- endmacro %}

{% macro default__unnest(array_col) -%}
    unnest({{ array_col }})
{%- endmacro %}

{% macro bigquery__unnest(array_col) -%}
    unnest({{ array_col }})
{%- endmacro %}

{% macro postgres__unnest(array_col) -%}
    jsonb_array_elements(
        case jsonb_typeof({{ array_col }})
        when 'array' then {{ array_col }}
        else '[]' end
    )
{%- endmacro %}

{% macro redshift__unnest(array_col) -%}
    joined
{%- endmacro %}

{% macro snowflake__unnest(array_col) -%}
    table(flatten({{ array_col }}))
{%- endmacro %}

{# unnested_column_value -------------------------------------------------     #}

{% macro unnested_column_value(column_col) -%}
  {{ adapter.dispatch('unnested_column_value')(column_col) }}
{%- endmacro %}

{% macro default__unnested_column_value(column_col) -%}
    {{ column_col }}
{%- endmacro %}

{% macro snowflake__unnested_column_value(column_col) -%}
    {{ column_col }}.value
{%- endmacro %}

{% macro redshift__unnested_column_value(column_col) -%}
    _airbyte_data
{%- endmacro %}

{# unnest_cte -------------------------------------------------     #}

{% macro unnest_cte(table_name, column_col) -%}
  {{ adapter.dispatch('unnest_cte')(table_name, column_col) }}
{%- endmacro %}

{% macro default__unnest_cte(table_name, column_col) -%}{%- endmacro %}

{# -- based on https://blog.getdbt.com/how-to-unnest-arrays-in-redshift/ #}
{% macro redshift__unnest_cte(table_name, column_col) -%}
    {%- if not execute -%}
        {{ return('') }}
    {% endif %}
    {%- call statement('max_json_array_length', fetch_result=True) -%}
        with max_value as (
            select max(json_array_length({{ column_col }}, true)) as max_number_of_items
            from {{ ref(table_name) }}
        )
        select
            case when max_number_of_items is not null and max_number_of_items > 1
            then max_number_of_items
            else 1 end as max_number_of_items
        from max_value
    {%- endcall -%}
    {%- set max_length = load_result('max_json_array_length') -%}
with numbers as (
    {{dbt_utils.generate_series(max_length["data"][0][0])}}
),
joined as (
    select
        json_extract_array_element_text({{ column_col }}, numbers.generated_number::int - 1, true) as _airbyte_data
    from {{ ref(table_name) }}
    cross join numbers
    -- only generate the number of records in the cross join that corresponds
    -- to the number of items in {{ table_name }}.{{ column_col }}
    where numbers.generated_number <= json_array_length({{ column_col }}, true)
)
{%- endmacro %}
