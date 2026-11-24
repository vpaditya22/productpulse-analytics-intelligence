import math

import pytest

from productpulse.analytics import two_proportion_test


def test_two_proportion_test_detects_strong_lift():
    result = two_proportion_test(120, 1000, 180, 1000)
    assert result["treatment_rate"] > result["control_rate"]
    assert result["significant_95"] is True
    assert result["p_value"] < 0.01


def test_zero_baseline_lift_is_defined_without_division_error():
    result = two_proportion_test(0, 100, 10, 100)
    assert result["absolute_lift"] == 0.1
    assert math.isnan(result["relative_lift"])


@pytest.mark.parametrize("counts", [(-1, 10, 1, 10), (11, 10, 1, 10), (1, 0, 1, 10)])
def test_two_proportion_test_rejects_invalid_counts(counts):
    with pytest.raises(ValueError):
        two_proportion_test(*counts)
