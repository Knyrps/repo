# repo

Bookmark and jump between repositories in [fish](https://fishshell.com). A Linux port of the `Repo` module from [pstools](https://github.com/Knyrps/pstools).

```fish
repo                    # list repos
repo nix                # cd into a repo
repo nix/src/tools      # cd into a folder inside it
repo rg                 # register cwd under its folder name
repo rg work ~/code/w   # register a path under a name
repo ls -r              # only repos under cwd
repo get nix            # print the path, e.g. zed (repo get nix)
repo mk thing           # mkdir, register, git init
repo rm nix             # remove (asks first)
repo mv old new         # rename
repo prune              # remove repos whose folder is gone
```

Tab completes repo names (with their paths as descriptions), subcommands, and folders inside a repo once you type `name/`.

Unknown names open [fzf](https://github.com/junegunn/fzf) pre-filled with what you typed, if it is installed. Otherwise you get "did you mean" suggestions.

## Install

[fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install knyrps/repo
```

home-manager:

```nix
programs.fish.plugins = [{
  name = "repo";
  src = pkgs.fetchFromGitHub {
    owner = "knyrps";
    repo = "repo";
    rev = "<commit>";
    hash = "<hash>";
  };
}];
```

## Data

One `name<TAB>path` line per repo in `$XDG_CONFIG_HOME/repo/repos` (`~/.config/repo/repos`). Override with `REPO_FILE`.
