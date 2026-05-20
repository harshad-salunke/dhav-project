"""
Unit tests for services/penalties.py
All Firebase db calls and FCM notifications are mocked.
"""
import pytest
from unittest.mock import patch, MagicMock, call
from utils.helpers import now_ms


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _make_store(strike_count=0, total_strikes=0, is_suspended=False,
                suspension_end_date=None, is_active=True, fcm_token="tok_abc",
                lat=18.5204, lng=73.8567):
    return {
        "store_id": "store_001",
        "strike_count": strike_count,
        "total_strikes": total_strikes,
        "is_suspended": is_suspended,
        "suspension_end_date": suspension_end_date,
        "is_active": is_active,
        "fcm_token": fcm_token,
        "location": {"lat": lat, "lng": lng},
    }


# ---------------------------------------------------------------------------
# process_store_failure
# ---------------------------------------------------------------------------

class TestProcessStoreFailure:
    @patch("services.penalties.send_store_suspended")
    @patch("services.penalties.send_strike_warning")
    @patch("services.penalties.remove_store_from_geofence_index")
    @patch("services.penalties.db")
    def test_first_strike_sends_warning(self, mock_db, mock_geo, mock_warn, mock_susp):
        store = _make_store(strike_count=0, total_strikes=0)
        store_ref = MagicMock()
        strike_ref = MagicMock()

        def ref_side_effect(path):
            if path.startswith("stores/store_001"):
                return store_ref
            return strike_ref
        mock_db.reference.side_effect = ref_side_effect
        store_ref.get.return_value = store

        from services.penalties import process_store_failure
        process_store_failure("store_001", "order_001", "missed")

        store_ref.update.assert_called_once()
        updated = store_ref.update.call_args[0][0]
        assert updated["strike_count"] == 1
        assert updated["total_strikes"] == 1
        mock_warn.assert_called_once_with("tok_abc", 1, "order_001")
        mock_susp.assert_not_called()
        mock_geo.assert_not_called()  # no suspension yet

    @patch("services.penalties.send_store_suspended")
    @patch("services.penalties.send_strike_warning")
    @patch("services.penalties.remove_store_from_geofence_index")
    @patch("services.penalties.db")
    def test_third_strike_triggers_suspension(self, mock_db, mock_geo, mock_warn, mock_susp):
        # strike_count=2, total_strikes=2 → next hit → strike_count=3 → suspend
        store = _make_store(strike_count=2, total_strikes=2)
        store_ref = MagicMock()
        strike_ref = MagicMock()

        def ref_side_effect(path):
            if path.startswith("stores/store_001"):
                return store_ref
            return strike_ref
        mock_db.reference.side_effect = ref_side_effect
        store_ref.get.return_value = store

        from services.penalties import process_store_failure
        process_store_failure("store_001", "order_002", "timeout")

        updated = store_ref.update.call_args[0][0]
        assert updated["is_suspended"] is True
        assert updated["strike_count"] == 0   # reset on suspension
        assert updated["total_strikes"] == 3
        assert "suspension_end_date" in updated
        mock_susp.assert_called_once()
        mock_warn.assert_not_called()
        mock_geo.assert_called_once_with("store_001", 18.5204, 73.8567)

    @patch("services.penalties.send_store_suspended")
    @patch("services.penalties.send_strike_warning")
    @patch("services.penalties.remove_store_from_geofence_index")
    @patch("services.penalties.db")
    def test_fifth_total_strike_triggers_permanent_ban(self, mock_db, mock_geo, mock_warn, mock_susp):
        # total_strikes=4 → next hit → total_strikes=5 → permanent ban
        store = _make_store(strike_count=0, total_strikes=4)
        store_ref = MagicMock()
        strike_ref = MagicMock()

        def ref_side_effect(path):
            if path.startswith("stores/store_001"):
                return store_ref
            return strike_ref
        mock_db.reference.side_effect = ref_side_effect
        store_ref.get.return_value = store

        from services.penalties import process_store_failure
        process_store_failure("store_001", "order_003", "fraud")

        updated = store_ref.update.call_args[0][0]
        assert updated["is_active"] is False
        assert updated["is_suspended"] is True
        assert updated.get("suspension_end_date") is None  # permanent ban has None
        mock_susp.assert_called_once_with("tok_abc", 0)  # 0 days = permanent
        mock_warn.assert_not_called()
        mock_geo.assert_called_once()

    @patch("services.penalties.send_store_suspended")
    @patch("services.penalties.send_strike_warning")
    @patch("services.penalties.remove_store_from_geofence_index")
    @patch("services.penalties.db")
    def test_does_nothing_for_nonexistent_store(self, mock_db, mock_geo, mock_warn, mock_susp):
        store_ref = MagicMock()
        mock_db.reference.return_value = store_ref
        store_ref.get.return_value = None

        from services.penalties import process_store_failure
        process_store_failure("nonexistent", "order_x", "reason")

        store_ref.update.assert_not_called()
        mock_warn.assert_not_called()
        mock_susp.assert_not_called()

    @patch("services.penalties.send_store_suspended")
    @patch("services.penalties.send_strike_warning")
    @patch("services.penalties.remove_store_from_geofence_index")
    @patch("services.penalties.db")
    def test_strike_log_always_written(self, mock_db, mock_geo, mock_warn, mock_susp):
        store = _make_store(strike_count=0, total_strikes=0)
        store_ref = MagicMock()
        log_ref = MagicMock()

        paths_seen = []

        def ref_side_effect(path):
            paths_seen.append(path)
            if path.startswith("stores/store_001"):
                return store_ref
            return log_ref
        mock_db.reference.side_effect = ref_side_effect
        store_ref.get.return_value = store

        from services.penalties import process_store_failure
        process_store_failure("store_001", "order_999", "test")

        strike_paths = [p for p in paths_seen if p.startswith("strike_logs/")]
        assert len(strike_paths) == 1
        log_ref.set.assert_called_once()
        log_data = log_ref.set.call_args[0][0]
        assert log_data["store_id"] == "store_001"
        assert log_data["order_id"] == "order_999"
        assert log_data["reason"] == "test"


# ---------------------------------------------------------------------------
# lift_expired_suspensions
# ---------------------------------------------------------------------------

class TestLiftExpiredSuspensions:
    @patch("services.penalties.db")
    def test_lifts_expired_suspension(self, mock_db):
        past_time = now_ms() - 1_000  # 1 second ago
        stores = {
            "store_001": {
                "is_suspended": True,
                "suspension_end_date": past_time,
            }
        }
        root_ref = MagicMock()
        store_ref = MagicMock()
        root_ref.get.return_value = stores

        def ref_side_effect(path):
            if path == "stores":
                return root_ref
            return store_ref
        mock_db.reference.side_effect = ref_side_effect

        from services.penalties import lift_expired_suspensions
        count = lift_expired_suspensions()

        assert count == 1
        store_ref.update.assert_called_once()
        update_data = store_ref.update.call_args[0][0]
        assert update_data["is_suspended"] is False
        assert update_data["suspension_end_date"] is None

    @patch("services.penalties.db")
    def test_does_not_lift_active_suspension(self, mock_db):
        future_time = now_ms() + 86_400_000  # tomorrow
        stores = {
            "store_001": {
                "is_suspended": True,
                "suspension_end_date": future_time,
            }
        }
        root_ref = MagicMock()
        root_ref.get.return_value = stores
        mock_db.reference.return_value = root_ref

        from services.penalties import lift_expired_suspensions
        count = lift_expired_suspensions()

        assert count == 0

    @patch("services.penalties.db")
    def test_skips_non_suspended_stores(self, mock_db):
        stores = {
            "store_001": {"is_suspended": False, "suspension_end_date": None},
            "store_002": {"is_suspended": False},
        }
        root_ref = MagicMock()
        root_ref.get.return_value = stores
        mock_db.reference.return_value = root_ref

        from services.penalties import lift_expired_suspensions
        count = lift_expired_suspensions()
        assert count == 0

    @patch("services.penalties.db")
    def test_returns_zero_on_empty_store_list(self, mock_db):
        root_ref = MagicMock()
        root_ref.get.return_value = {}
        mock_db.reference.return_value = root_ref

        from services.penalties import lift_expired_suspensions
        count = lift_expired_suspensions()
        assert count == 0


# ---------------------------------------------------------------------------
# auto_fail_stuck_orders
# ---------------------------------------------------------------------------

class TestAutoFailStuckOrders:
    @patch("services.penalties.process_store_failure")
    @patch("services.penalties.db")
    def test_fails_old_pending_order(self, mock_db, mock_psf):
        old_time = now_ms() - (4 * 3_600_000)  # 4 hours ago (> 3h threshold)
        orders = {
            "order_001": {
                "status": "pending",
                "created_at": old_time,
                "accepted_by_store_id": None,
            }
        }
        orders_root = MagicMock()
        order_ref = MagicMock()
        orders_root.get.return_value = orders

        def ref_side_effect(path):
            if path == "orders":
                return orders_root
            return order_ref
        mock_db.reference.side_effect = ref_side_effect

        from services.penalties import auto_fail_stuck_orders
        count = auto_fail_stuck_orders(max_hours=3)

        assert count == 1
        order_ref.update.assert_called_once()
        update_data = order_ref.update.call_args[0][0]
        assert update_data["status"] == "failed"
        assert update_data["failure_reason"] == "auto_failed_timeout"

    @patch("services.penalties.process_store_failure")
    @patch("services.penalties.db")
    def test_does_not_fail_recent_order(self, mock_db, mock_psf):
        recent_time = now_ms() - (1 * 3_600_000)  # 1 hour ago (< 3h threshold)
        orders = {
            "order_001": {
                "status": "pending",
                "created_at": recent_time,
            }
        }
        orders_root = MagicMock()
        orders_root.get.return_value = orders
        mock_db.reference.return_value = orders_root

        from services.penalties import auto_fail_stuck_orders
        count = auto_fail_stuck_orders(max_hours=3)

        assert count == 0

    @patch("services.penalties.process_store_failure")
    @patch("services.penalties.db")
    def test_ignores_delivered_orders(self, mock_db, mock_psf):
        old_time = now_ms() - (10 * 3_600_000)
        orders = {
            "order_001": {
                "status": "delivered",
                "created_at": old_time,
            }
        }
        orders_root = MagicMock()
        orders_root.get.return_value = orders
        mock_db.reference.return_value = orders_root

        from services.penalties import auto_fail_stuck_orders
        count = auto_fail_stuck_orders(max_hours=3)

        assert count == 0

    @patch("services.penalties.process_store_failure")
    @patch("services.penalties.db")
    def test_calls_process_failure_when_store_assigned(self, mock_db, mock_psf):
        old_time = now_ms() - (4 * 3_600_000)
        orders = {
            "order_001": {
                "status": "packed",
                "created_at": old_time,
                "accepted_by_store_id": "store_xyz",
            }
        }
        orders_root = MagicMock()
        order_ref = MagicMock()
        orders_root.get.return_value = orders

        def ref_side_effect(path):
            if path == "orders":
                return orders_root
            return order_ref
        mock_db.reference.side_effect = ref_side_effect

        from services.penalties import auto_fail_stuck_orders
        auto_fail_stuck_orders(max_hours=3)

        mock_psf.assert_called_once_with("store_xyz", "order_001",
                                          reason="auto_failed_timeout")
