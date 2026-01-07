import subprocess
import hashlib
import os

def safe_run_git(cmd_args, cwd):
    """
    Run git safely without shell=True. cmd_args is a list of git arguments,
    e.g. ["rev-parse", "HEAD"].
    Returns stdout stripped, or None on error.
    """
    try:
        proc = subprocess.run(["git"] + list(cmd_args), cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=True)
        return proc.stdout.strip()
    except subprocess.CalledProcessError:
        return None
    except (OSError, ValueError):
        return None

def is_within_directory(base_dir, target_path):
    """
    Return True if realpath(target_path) is within realpath(base_dir).
    Protects against symlinks and path traversal.
    """
    base_real = os.path.realpath(base_dir)
    target_real = os.path.realpath(target_path)
    try:
        common = os.path.commonpath([base_real, target_real])
    except ValueError:
        # On Windows, commonpath raises ValueError if paths are on different drives
        return False
    return common == base_real

def sha256_of_file(path, chunk_size=8192):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()