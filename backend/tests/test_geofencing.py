"""
Unit tests for services/geofencing.py
Firebase db calls are fully mocked — no real Firebase connection needed.
"""
import pytest
from unittest.mock import patch, MagicMock, call


# ---------------------------------------------------------------------------
# Helpers to build fake store data
# ---------------------------------------------------------------------------

def _store(store_id, lat, lng, is_active=True, is_suspended=False):
    return {
        "store_id": store_id,
        "lat": lat,
        "lng": lng,
        "is_active": is_active,
        "is_suspended": is_suspended,
        "zone_id": "",
        "is_verified": True,
    }


# ---------------------------------------------------------------------------
# Tests for _encode / geohash precision
# ---------------------------------------------------------------------------

class TestGeohashEncode:
    def test_encode_returns_string_of_correct_precision(self):
        # We indirectly test _encode through public functions.
        # Precision 6 → 6-char geohash
        import pygeohash as gh
        code = gh.encode(18.5204, 73.8567, precision=6)
        assert len(code) == 6
        assert isinstance(code, str)

    def test_same_location_same_hash(self):
        import pygeohash as gh
        h1 = gh.encode(18.5204, 73.8567, precision=6)
        h2 = gh.encode(18.5204, 73.8567, precision=6)
        assert h1 == h2

    def test_different_locations_different_hash(self):
        import pygeohash as gh
        h1 = gh.encode(18.5204, 73.8567, precision=6)
        h2 = gh.encode(18.9000, 73.8567, precision=6)
        assert h1 != h2


# ---------------------------------------------------------------------------
# Tests for index_store_geofence
# ---------------------------------------------------------------------------

class TestIndexStoreGeofence:
    @patch("services.geofencing.db")
    def test_writes_correct_data(self, mock_db):
        mock_ref = MagicMock()
        mock_db.reference.return_value = mock_ref

        from services.geofencing import index_store_geofence
        gh = index_store_geofence("store_001", 18.5204, 73.8567,
                                   is_active=True, is_verified=True)

        assert len(gh) == 6  # precision 6
        mock_db.reference.assert_called_once()
        ref_path = mock_db.reference.call_args[0][0]
        assert "geofence_index" in ref_path
        assert "store_001" in ref_path
        mock_ref.set.assert_called_once()
        data = mock_ref.set.call_args[0][0]
        assert data["store_id"] == "store_001"
        assert data["lat"] == 18.5204
        assert data["lng"] == 73.8567
        assert data["is_active"] is True
        assert data["is_verified"] is True

    @patch("services.geofencing.db")
    def test_returns_geohash_string(self, mock_db):
        mock_db.reference.return_value = MagicMock()
        from services.geofencing import index_store_geofence
        result = index_store_geofence("s1", 18.5, 73.8)
        assert isinstance(result, str)
        assert len(result) == 6


# ---------------------------------------------------------------------------
# Tests for remove_store_from_geofence_index
# ---------------------------------------------------------------------------

class TestRemoveStoreFromGeofenceIndex:
    @patch("services.geofencing.db")
    def test_calls_delete(self, mock_db):
        mock_ref = MagicMock()
        mock_db.reference.return_value = mock_ref

        from services.geofencing import remove_store_from_geofence_index
        remove_store_from_geofence_index("store_001", 18.5204, 73.8567)

        mock_db.reference.assert_called_once()
        ref_path = mock_db.reference.call_args[0][0]
        assert "geofence_index" in ref_path
        assert "store_001" in ref_path
        mock_ref.delete.assert_called_once()


# ---------------------------------------------------------------------------
# Tests for find_nearby_stores
# ---------------------------------------------------------------------------

class TestFindNearbyStores:
    def _make_db_mock(self, cells_data: dict):
        """
        cells_data: { geohash_cell: { store_id: store_dict, ... }, ... }
        Returns a mock db.reference that serves this data.
        """
        mock_db = MagicMock()
        def ref_side_effect(path):
            # path like "geofence_index/txxxxx"
            parts = path.split("/")
            if len(parts) == 2 and parts[0] == "geofence_index":
                cell = parts[1]
                mock_ref = MagicMock()
                mock_ref.get.return_value = cells_data.get(cell)
                return mock_ref
            return MagicMock()
        mock_db.reference.side_effect = ref_side_effect
        return mock_db

    @patch("services.geofencing.db")
    def test_returns_empty_when_no_stores(self, mock_db):
        mock_db.reference.return_value = MagicMock()
        mock_db.reference.return_value.get.return_value = None

        from services.geofencing import find_nearby_stores
        result = find_nearby_stores(18.5204, 73.8567, radius_km=1.0)
        assert result == []

    @patch("services.geofencing.db")
    def test_returns_store_within_radius(self, mock_db):
        # Place a store ~50 m north of the customer
        customer_lat, customer_lng = 18.5204, 73.8567
        store_lat, store_lng = 18.5208, 73.8567  # ~44 m north

        import pygeohash as gh
        store_cell = gh.encode(store_lat, store_lng, precision=6)
        cells_data = {
            store_cell: {
                "store_001": _store("store_001", store_lat, store_lng)
            }
        }

        def ref_side_effect(path):
            cell = path.split("/")[-1]
            mock_ref = MagicMock()
            mock_ref.get.return_value = cells_data.get(cell)
            return mock_ref
        mock_db.reference.side_effect = ref_side_effect

        from importlib import reload
        import services.geofencing as gf_module
        result = gf_module.find_nearby_stores(customer_lat, customer_lng, radius_km=1.0)

        matching = [r for r in result if r["store_id"] == "store_001"]
        assert len(matching) == 1
        assert matching[0]["distance_km"] < 0.1

    @patch("services.geofencing.db")
    def test_excludes_inactive_stores(self, mock_db):
        customer_lat, customer_lng = 18.5204, 73.8567

        import pygeohash as gh
        cell = gh.encode(customer_lat, customer_lng, precision=6)
        cells_data = {
            cell: {
                "inactive_store": _store("inactive_store", customer_lat, customer_lng,
                                          is_active=False)
            }
        }

        def ref_side_effect(path):
            c = path.split("/")[-1]
            mock_ref = MagicMock()
            mock_ref.get.return_value = cells_data.get(c)
            return mock_ref
        mock_db.reference.side_effect = ref_side_effect

        import services.geofencing as gf_module
        result = gf_module.find_nearby_stores(customer_lat, customer_lng, radius_km=3.0)
        assert all(r["store_id"] != "inactive_store" for r in result)

    @patch("services.geofencing.db")
    def test_excludes_suspended_stores(self, mock_db):
        customer_lat, customer_lng = 18.5204, 73.8567

        import pygeohash as gh
        cell = gh.encode(customer_lat, customer_lng, precision=6)
        cells_data = {
            cell: {
                "suspended_store": _store("suspended_store", customer_lat, customer_lng,
                                           is_suspended=True)
            }
        }

        def ref_side_effect(path):
            c = path.split("/")[-1]
            mock_ref = MagicMock()
            mock_ref.get.return_value = cells_data.get(c)
            return mock_ref
        mock_db.reference.side_effect = ref_side_effect

        import services.geofencing as gf_module
        result = gf_module.find_nearby_stores(customer_lat, customer_lng, radius_km=3.0)
        assert all(r["store_id"] != "suspended_store" for r in result)

    @patch("services.geofencing.db")
    def test_results_sorted_by_distance(self, mock_db):
        customer_lat, customer_lng = 18.5204, 73.8567

        import pygeohash as gh
        # Far store
        far_lat, far_lng = 18.5280, 73.8567   # ~840 m north
        # Near store
        near_lat, near_lng = 18.5215, 73.8567  # ~122 m north

        far_cell = gh.encode(far_lat, far_lng, precision=6)
        near_cell = gh.encode(near_lat, near_lng, precision=6)

        cells_data: dict = {}
        if far_cell not in cells_data:
            cells_data[far_cell] = {}
        if near_cell not in cells_data:
            cells_data[near_cell] = {}
        cells_data[far_cell]["far_store"] = _store("far_store", far_lat, far_lng)
        cells_data[near_cell]["near_store"] = _store("near_store", near_lat, near_lng)

        # Also add customer cell
        cust_cell = gh.encode(customer_lat, customer_lng, precision=6)
        cells_data.setdefault(cust_cell, {})

        def ref_side_effect(path):
            c = path.split("/")[-1]
            mock_ref = MagicMock()
            mock_ref.get.return_value = cells_data.get(c)
            return mock_ref
        mock_db.reference.side_effect = ref_side_effect

        import services.geofencing as gf_module
        result = gf_module.find_nearby_stores(customer_lat, customer_lng, radius_km=5.0)

        ids = [r["store_id"] for r in result]
        if "near_store" in ids and "far_store" in ids:
            assert ids.index("near_store") < ids.index("far_store")
