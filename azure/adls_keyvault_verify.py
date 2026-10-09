"""MVP verification: Entra login -> Key Vault secret -> ADLS Gen2 read/write.

Run only after creating the short-lived container SAS stored as `rba-adls-sas`.
No keys or SAS tokens are printed or stored in this project.
"""
import os
from datetime import datetime, timezone

from azure.core.exceptions import AzureError
from azure.identity import InteractiveBrowserCredential
from azure.keyvault.secrets import SecretClient
from azure.storage.filedatalake import DataLakeServiceClient

STORAGE_ACCOUNT = "rbafxdata2026ty"
FILE_SYSTEM = "rba-data"
SOURCE_PATH = "landing/f11.1-data.csv"
SECRET_NAME = "rba-adls-sas"


def main():
    vault_url = os.environ.get("AZURE_KEY_VAULT_URL", "").strip()
    if not vault_url.startswith("https://") or ".vault.azure.net" not in vault_url:
        raise SystemExit(
            "Set AZURE_KEY_VAULT_URL to the vault's URI (Azure Portal > Key Vault > Overview)."
        )

    tenant_id = os.environ.get("AZURE_TENANT_ID") or None
    print("1/4 Signing in to Microsoft Entra ID...")
    credential = InteractiveBrowserCredential(tenant_id=tenant_id)

    try:
        vault = SecretClient(vault_url=vault_url, credential=credential)
        sas = vault.get_secret(SECRET_NAME).value
        if not sas or "sig=" not in sas.lower():
            raise RuntimeError("Secret exists but does not look like an Azure SAS token")
        print("2/4 Key Vault secret retrieved: PASS (value hidden)")

        storage = DataLakeServiceClient(
            account_url=f"https://{STORAGE_ACCOUNT}.dfs.core.windows.net",
            credential=sas.lstrip("?"),
        )
        files = storage.get_file_system_client(FILE_SYSTEM)

        raw = files.get_file_client(SOURCE_PATH).download_file().readall()
        # A locally downloaded CSV may contain a UTF-8 BOM or blank lines,
        # which should not invalidate an otherwise genuine RBA data file.
        csv_text = raw.decode("utf-8-sig", errors="replace").lstrip()
        looks_like_rba = (
            csv_text.startswith("F11.1")
            and "Series ID," in csv_text[:16000]
        )
        if not looks_like_rba:
            # Only print structural diagnostics; do not output file content,
            # storage URLs, SAS credentials or any Key Vault secret.
            raise RuntimeError(
                "ADLS file downloaded, but RBA CSV header validation failed. "
                f"bytes={len(raw)}; "
                f"utf8_bom={raw.startswith(bytes.fromhex('efbbbf'))}; "
                f"F11.1_near_start={'F11.1' in csv_text[:512]}; "
                f"Series_ID_present={'Series ID,' in csv_text[:16000]}. "
                "Check that landing/f11.1-data.csv is the original RBA CSV."
            )
        print(f"3/4 ADLS Gen2 RBA CSV read: PASS ({len(raw):,} bytes)")

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        proof_path = f"landing/sdk-proof-{timestamp}.txt"
        proof_content = b"Key Vault SAS -> Azure ADLS Gen2 Python SDK: verified\n"
        proof_file = files.get_file_client(proof_path)
        proof_file.upload_data(proof_content, overwrite=True)
        assert proof_file.download_file().readall() == proof_content
        print(f"4/4 ADLS Gen2 write and read-back: PASS ({proof_path})")
        print("MVP RESULT: PASS")
    except AzureError as exc:
        # Do not print full service exception bodies or signed request URLs.
        status = getattr(exc, "status_code", None)
        code = getattr(exc, "error_code", None)
        raise SystemExit(
            f"Azure request failed: {type(exc).__name__}; HTTP={status}; code={code}. "
            "Do not share SAS tokens or signed URLs."
        ) from None
    finally:
        credential.close()


if __name__ == "__main__":
    main()