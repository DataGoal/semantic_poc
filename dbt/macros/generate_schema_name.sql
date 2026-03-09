{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
      Force all models into the target schema specified in dbt_project.yml
      or the profile. This avoids CREATE SCHEMA issues since we use the
      existing schema: development.dev_cf_ebi_semantic_poc
    #}
    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}
