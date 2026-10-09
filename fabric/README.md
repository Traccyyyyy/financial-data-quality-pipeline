# Fabric + Azure validation extension

Part of the same **RBA Financial Data Quality & Reconciliation Pipeline** project. The original n8n/PostgreSQL and Databricks implementations remain unchanged.

## Verified work (9 Oct 2026)

- **Microsoft Fabric Trial:** Imported/adapted the Databricks PySpark/Delta implementation to a schema-enabled Fabric Lakehouse (`rba_fx_lakehouse`, schema `dbo`). Main workflow Steps 01–13 ran successfully with 21,781 staged rows, 18,623 valid, 3,158 invalid; first-load 18,623 NEW; Delta MERGE and reconciliation PASS, persisted run SUCCESS and historical monitoring PASS.
- **Azure ADLS Gen2:** Standard/LRS with hierarchical namespace and private `rba-data/landing/f11.1-data.csv` containing the public RBA CSV.
- **Azure Key Vault + local Python SDK:** Microsoft Entra interactive login, read short-lived SAS Secret from Key Vault without hardcoding, download 140,796-byte RBA CSV from ADLS, create a separate timestamped proof file, read it back and validate bytes. Observed terminal output ended in `MVP RESULT: PASS`.
- **OneLake Shortcut:** Fabric connected to `rba-data/landing` as `rba_fx_lakehouse/Files/landing`, using **Organizational account / OAuth 2.0** (not the Key Vault SAS). Fabric PySpark read the Shortcut (`ADLS Shortcut read: PASS`, `CSV lines: 2185`) and the full ADLS-fed processing flow subsequently completed with reconciliation PASS.

## Boundaries (important)

- After the initial HTTP run, the complete Fabric Steps 01–13 workflow also ran successfully from the ADLS OneLake Shortcut. The follow-up run logged 21,781 staged, 18,623 valid, 3,158 invalid, 0 NEW, 0 CHANGED, 18,623 UNCHANGED, and count reconciliation PASS.
- The Key Vault/SAS flow was demonstrated with **local Python only**. An attempted **Fabric SAS + Key Vault Reference Shortcut** returned a stored credential error and is **not claimed to work**. The successful Fabric Shortcut uses Organizational account authentication.
- This is a personal trial/free-credit environment, **not a production deployment**, managed job, or Azure-hosted Databricks service.
- The included notebooks and Python sample are sanitized project sources. The committed Fabric notebook is now the user's ADLS-fed exported notebook, sanitized by clearing executed cell outputs, transient Fabric widget state, and workspace IDs. Source code is preserved. Reproducibility requires attaching a compatible Fabric Lakehouse and configuring the OAuth 2.0 ADLS Shortcut at `Files/landing/f11.1-data.csv`. The final Historical Monitoring code cell was exported without cell outputs; independently exported Run Registry evidence is available at `fabric/evidence/azure_lake_fabric_run_summary.json`. GitHub CI performs static checks and does not run the live Fabric or Azure services.
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
