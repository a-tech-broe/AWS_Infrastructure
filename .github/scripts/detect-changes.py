#!/usr/bin/env python3
"""Select the environment stacks affected by a set of changed files.

An environment is selected when its own files changed, or when any local
terraform module it depends on (transitively) changed. A change to the CI
workflow or .tflint.hcl selects every environment.

Reads BASE and HEAD git refs from the environment and prints a JSON array of
environment names (e.g. ["dev","prod"]) to stdout.
"""
import json
import os
import re
import subprocess

ENV_ROOT = "environments"
GLOBAL_PATHS = (".github/workflows/terraform.yml", ".github/scripts/detect-changes.py", ".tflint.hcl")
SOURCE_RE = re.compile(r'^\s*source\s*=\s*"([^"]+)"', re.MULTILINE)


def sh(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def changed_files(base, head):
    return [line for line in sh("git", "diff", "--name-only", base, head).splitlines() if line.strip()]


def tf_files(directory):
    if not os.path.isdir(directory):
        return []
    return [os.path.join(directory, f) for f in os.listdir(directory) if f.endswith(".tf")]


def local_module_dirs(directory):
    """Directories of local (path-based) modules referenced directly in `directory`."""
    dirs = set()
    for path in tf_files(directory):
        with open(path) as fh:
            for src in SOURCE_RE.findall(fh.read()):
                if src.startswith("."):  # local path module, not a registry module
                    dirs.add(os.path.normpath(os.path.join(directory, src)).replace(os.sep, "/"))
    return dirs


def transitive_module_dirs(directory):
    """All local module dirs reachable from `directory`, following nested modules."""
    resolved, queue = set(), list(local_module_dirs(directory))
    while queue:
        mod = queue.pop()
        if mod in resolved:
            continue
        resolved.add(mod)
        queue.extend(local_module_dirs(mod))
    return resolved


def environments():
    if not os.path.isdir(ENV_ROOT):
        return []
    return sorted(
        name for name in os.listdir(ENV_ROOT)
        if tf_files(os.path.join(ENV_ROOT, name))  # only envs that contain terraform
    )


def main():
    base, head = os.environ["BASE"], os.environ["HEAD"]
    changed = changed_files(base, head)
    envs = environments()

    if any(c in GLOBAL_PATHS for c in changed):
        print(json.dumps(envs))
        return

    selected = []
    for env in envs:
        watched = {f"{ENV_ROOT}/{env}"} | transitive_module_dirs(os.path.join(ENV_ROOT, env))
        if any(c.startswith(prefix + "/") for c in changed for prefix in watched):
            selected.append(env)

    print(json.dumps(selected))


if __name__ == "__main__":
    main()
