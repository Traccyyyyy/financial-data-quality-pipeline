# Fabric + Azure validation extension

Part of the same **RBA Financial Data Quality & Reconciliation Pipeline** project. The original n8n/PostgreSQL and Databricks implementations remain unchanged.

## Verified work (9 Oct 2026)

- **Microsoft Fabric Trial:** Imported/adapted the Databricks PySpark/Delta implementation to a schema-enabled Fabric Lakehouse (`rba_fx_lakehouse`, schema `dbo`). Main workflow Steps 01–13 ran successfully with 21,781 staged rows, 18,623 valid, 3,158 invalid; first-load 18,623 NEW; Delta MERGE and reconciliation PASS, persisted run SUCCESS and historical monitoring PASS.
- **Azure ADLS Gen2:** Standard/LRS with hierarchical namespace and private `rba-data/landing/f11.1-data.csv` containing the public RBA CSV.
- **Azure Key Vault + local Python SDK:** Microsoft Entra interactive login, read short-lived SAS Secret from Key Vault without hardcoding, download 140,796-byte RBA CSV from ADLS, create a separate timestamped proof file, read it back and validate bytes. Observed terminal output ended in `MVP RESULT: PASS`.
- **OneLake Shortcut:** Fabric connected to `rba-data/landing` as `rba_fx_lakehouse/Files/landing`, using **Organizational account / OAuth 2.0** (not the Key Vault SAS). Fabric PySpark separately read the Shortcut and printed `ADLS Shortcut read: PASS` and `CSV lines: 2185`.

## Boundaries (important)

- The successful **main Fabric data processing** notebook still downloads its CSV directly from the public RBA HTTP URL. The ADLS Shortcut read was verified **in a separate Fabric cell**, not incorporated into the Step 01 source for the full 13-step workflow.
- The Key Vault/SAS flow was demonstrated with **local Python only**. An attempted **Fabric SAS + Key Vault Reference Shortcut** returned a stored credential error and is **not claimed to work**. The successful Fabric Shortcut uses Organizational account authentication.
- This is a personal trial/free-credit environment, **not a production deployment**, managed job, or Azure-hosted Databricks service.
- The included notebooks and Python sample are sanitized project sources. The Fabric notebook uses source HTTP ingestion and is a platform-adapted copy; it was run by the project owner, not in GitHub CI.
- Storage SAS tokens expire; do not publish token values, signed URLs, cloud account keys, or private screenshots. `AZURE_KEY_VAULT_URL` is configured as a local environment variable.

## Reproduce the SDK test

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r azure/requirements.txt
export AZURE_KEY_VAULT_URL="https://<your-key-vault-name>.vault.azure.net/"
python azure/adls_keyvault_verify.py
```

For Fabric: attach the existing Lakehouse as default, import `fabric/RBA_FX_Fabric_Medallion_MVP.ipynb`, and separately run `fabric/verify_adls_shortcut.ipynb` after establishing the OAuth 2.0 ADLS Shortcut.

The private Azure resource group can be deleted after preserving evidence; running the SDK test again requires valid Azure resources, roles and a fresh SAS.
