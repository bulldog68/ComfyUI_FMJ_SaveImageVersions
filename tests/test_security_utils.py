import os
import sys
import pytest

# Ensure the package directory is importable when running pytest from repo root
# tests_dir: .../ComfyUI_FMJ_SaveImageVersions/tests
tests_dir = os.path.dirname(__file__)
pkg_dir = os.path.abspath(os.path.join(tests_dir, ".."))  # .../ComfyUI_FMJ_SaveImageVersions
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

from security_utils import is_within_directory, sha256_of_file, safe_run_git


def test_is_within_directory_normal(tmp_path):
    base = tmp_path / "base"
    base.mkdir()
    target = base / "file.txt"
    target.write_text("hello")
    assert is_within_directory(str(base), str(target))


def test_is_within_directory_traversal(tmp_path):
    base = tmp_path / "base"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    target = outside / "file.txt"
    target.write_text("nope")
    # relative traversal attempt
    attempted = os.path.join(str(base), "..", "outside", "file.txt")
    assert not is_within_directory(str(base), attempted)


@pytest.mark.skipif(sys.platform.startswith("win"), reason="Symlink requires admin on Windows")
def test_is_within_directory_symlink(tmp_path):
    base = tmp_path / "base"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    secret = outside / "secret.txt"
    secret.write_text("secret")
    # create symlink inside base pointing to outside
    link = base / "link"
    os.symlink(str(outside), str(link))
    target_via_link = os.path.join(str(link), "secret.txt")
    assert not is_within_directory(str(base), target_via_link)


def test_sha256_of_file(tmp_path):
    f = tmp_path / "a.txt"
    f.write_bytes(b"abc")
    assert sha256_of_file(str(f)).startswith("ba781")


def test_safe_run_git_no_repo(tmp_path):
    # Running git in a folder without a repo should return None
    res = safe_run_git(["rev-parse", "HEAD"], str(tmp_path))
    assert res is None