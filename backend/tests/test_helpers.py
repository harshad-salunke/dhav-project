"""
Unit tests for utils/helpers.py — no Firebase needed.
"""
import time
import uuid
import pytest
from utils.helpers import new_id, now_ms


class TestNewId:
    def test_returns_string(self):
        assert isinstance(new_id(), str)

    def test_is_valid_uuid(self):
        result = new_id()
        # Should not raise
        parsed = uuid.UUID(result)
        assert str(parsed) == result

    def test_each_call_unique(self):
        ids = {new_id() for _ in range(1000)}
        assert len(ids) == 1000  # All unique


class TestNowMs:
    def test_returns_int(self):
        assert isinstance(now_ms(), int)

    def test_reasonable_value(self):
        # Must be after 2024-01-01 and before year 2100
        t = now_ms()
        assert t > 1_704_067_200_000, "Timestamp before 2024"
        assert t < 4_102_444_800_000, "Timestamp past year 2100"

    def test_monotonically_increasing(self):
        t1 = now_ms()
        time.sleep(0.01)
        t2 = now_ms()
        assert t2 >= t1, "now_ms() went backwards"

    def test_matches_current_time(self):
        before = int(time.time() * 1000)
        result = now_ms()
        after = int(time.time() * 1000)
        assert before <= result <= after + 5
