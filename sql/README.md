# Extracted n8n PostgreSQL queries

SQL is copied from the public-safe n8n workflow for review. **Not a standalone migration or deployment**. Queries use n8n-supplied placeholders and expect specific PostgreSQL tables. Some queries mutate or delete data; do not run against a production database. In the public workflow, seed/cleanup nodes are disabled.
