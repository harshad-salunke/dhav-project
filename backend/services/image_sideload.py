"""
Sideload external product images into OUR Supabase Storage.

Why: barcode APIs return image URLs on third-party hosts (openfoodfacts.org
CDN etc.). Hot-linking them makes the catalog slow and fragile (their CDN,
their uptime, their resize rules). So when the admin APPROVES a product
request, we download the external images once and re-host them in the
`dhav-images` bucket — the catalog then serves the same fast CDN as every
other product image.

Runs at APPROVAL time (not at submission) so rejected requests never pollute
the bucket. Failures are per-image and non-fatal: an approved product with
store-owner photos can ship even if every external image is dead.
"""
import asyncio

import httpx

from services import storage

_MAX_BYTES = 2 * 1024 * 1024          # 2 MB per image — plenty for product shots
_TIMEOUT = 8.0                        # per download
_ALLOWED_TYPES = ("image/jpeg", "image/png", "image/webp", "image/gif")
_USER_AGENT = "DHAV-KiranaApp/1.0 (dhav-backend; harshadsalunke2002@gmail.com)"


async def _fetch_one(client: httpx.AsyncClient, url: str) -> tuple[bytes, str] | None:
    try:
        resp = await client.get(url, timeout=_TIMEOUT, follow_redirects=True)
        if resp.status_code != 200:
            return None
        ctype = (resp.headers.get("content-type") or "").split(";")[0].strip().lower()
        if ctype not in _ALLOWED_TYPES:
            return None
        if len(resp.content) > _MAX_BYTES or not resp.content:
            return None
        return resp.content, ctype
    except Exception:
        return None


async def sideload_images(urls: list[str], *, folder: str, max_images: int = 3) -> list[str]:
    """Download up to `max_images` external image URLs and upload each to
    Supabase Storage under `folder/`. Returns the new public URLs (possibly
    fewer than requested — bad URLs are skipped silently)."""
    urls = [u for u in (urls or []) if u][:max_images]
    if not urls:
        return []

    hosted: list[str] = []
    async with httpx.AsyncClient(headers={"User-Agent": _USER_AGENT}) as client:
        fetched = await asyncio.gather(*(_fetch_one(client, u) for u in urls))
    for item in fetched:
        if item is None:
            continue
        content, ctype = item
        try:
            up = await storage.upload_image(content, folder=folder, content_type=ctype)
            hosted.append(up["url"])
        except (storage.StorageNotConfigured, storage.StorageUploadFailed):
            continue
    return hosted
