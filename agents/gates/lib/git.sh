# shellcheck shell=bash

# git_resolve <repo> <rev>: prints the full commit sha for rev, or fails.
git_resolve() {
    git -C "$1" rev-parse --verify --quiet "$2^{commit}"
}

git_head() {
    git -C "$1" rev-parse --verify --quiet HEAD
}

# git_dirty <repo> [excluded path...]: succeeds when the tree has uncommitted changes outside the excluded paths.
git_dirty() {
    local repo="$1" path
    shift
    local specs=(.)
    for path in "$@"; do
        specs+=(":(exclude)$path")
    done
    [[ -n "$(git -C "$repo" status --porcelain --untracked-files=normal -- "${specs[@]}")" ]]
}

# git_show <repo> <sha> <path>: prints a file as committed at sha, or fails if it is not there.
git_show() {
    git -C "$1" cat-file -e "$2:$3" 2>/dev/null && git -C "$1" show "$2:$3"
}
