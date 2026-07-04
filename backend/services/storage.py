"""
Supabase Storage uploads — the ONE place that talks to the storage REST API.

Used by:
  • POST /admin/upload-image          (admin catalog/category/banner images)
  • POST /stores/me/upload-image      (store-owner product photos for requests)
  • services/image_sideload.py        (barcode-API images pulled server-side)

Files land in the public `dhav-images` bucket; the returned URL is the public
CDN URL the apps store in image fields. Requires SUPABASE_SERVICE_KEY.
"""
import uuid

import httpx

from config import get_settings

BUCKET = "dhav-images"


class StorageNotConfigured(Exception):
    pass


class StorageUploadFailed(Exception):
    pass


def _ext_from(filename: str | None, content_type: str | None) -> str:
    if filename and "." in filename:
        ext = filename.rsplit(".", 1)[-1].lower()
        if ext.isalnum() and len(ext) <= 5:
            return ext
    if content_type and "/" in content_type:
        sub = content_type.split("/", 1)[1].lower()
        return {"jpeg": "jpg", "svg+xml": "svg"}.get(sub, sub) or "jpg"
    return "jpg"


async def upload_image(
    content: bytes,
    *,
    folder: str,
    filename: str | None = None,
    content_type: str | None = None,
) -> dict:
    """Upload bytes to `{folder}/{uuid}.{ext}` in the dhav-images bucket.
    Returns {"url": <public url>, "path": <bucket path>}."""
    settings = get_settings()
    if not settings.supabase_service_key:
        raise StorageNotConfigured("Supabase service key not configured")

    ext = _ext_from(filename, content_type)
    path = f"{folder}/{uuid.uuid4().hex}.{ext}"
    url = f"{settings.supabase_url}/storage/v1/object/{BUCKET}/{path}"
    headers = {
        "Authorization": f"Bearer {settings.supabase_service_key}",
        "Content-Type": content_type or "image/jpeg",
        "x-upsert": "true",
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, content=content, headers=headers)
    if resp.status_code not in (200, 201):
        raise StorageUploadFailed(f"{resp.status_code} {resp.text}")
    public_url = f"{settings.supabase_url}/storage/v1/object/public/{BUCKET}/{path}"
    return {"url": public_url, "path": path}
