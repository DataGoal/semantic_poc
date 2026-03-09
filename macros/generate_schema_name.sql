{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
      Force dbt to use the exact custom_schema_name if provided,
      instead of prepending the target schema.
      This ensures all objects land in development.dev_cf_ebi_semantic_poc.
    #}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
