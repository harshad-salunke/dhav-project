"""
Unit tests for services/geo.py — pure math, no Firebase needed.
"""
import math
import pytest
from services.geo import haversine_km


class TestHaversineKm:
    def test_same_point_returns_zero(self):
        assert haversine_km(18.5204, 73.8567, 18.5204, 73.8567) == pytest.approx(0.0, abs=1e-6)

    def test_known_distance_pune_kothrud_to_aundh(self):
        # Kothrud approx (18.5074, 73.8077) → Aundh approx (18.5590, 73.8075)
        # Straight-line distance ≈ 5.7 km (north-south)
        dist = haversine_km(18.5074, 73.8077, 18.5590, 73.8075)
        assert 5.5 < dist < 6.0, f"Expected ~5.7 km, got {dist:.3f}"

    def test_symmetry(self):
        a, b = haversine_km(18.5204, 73.8567, 18.5590, 73.8075), \
               haversine_km(18.5590, 73.8075, 18.5204, 73.8567)
        assert a == pytest.approx(b, rel=1e-9)

    def test_equator_one_degree_longitude(self):
        # 1 degree longitude at equator ≈ 111.32 km
        dist = haversine_km(0.0, 0.0, 0.0, 1.0)
        assert 111.0 < dist < 111.6, f"Got {dist:.3f}"

    def test_short_distance_within_1km(self):
        # ~100 m north
        dist = haversine_km(18.5204, 73.8567, 18.5213, 73.8567)
        assert 0.05 < dist < 0.15, f"Expected ~0.1 km, got {dist:.4f}"

    def test_returns_float(self):
        result = haversine_km(18.5204, 73.8567, 18.5300, 73.8600)
        assert isinstance(result, float)

    def test_negative_coordinates(self):
        # Sydney → Melbourne approx 714 km
        dist = haversine_km(-33.8688, 151.2093, -37.8136, 144.9631)
        assert 700 < dist < 730, f"Got {dist:.1f}"
