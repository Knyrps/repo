function repo --description 'bookmark and jump between repositories'
    set -l cmd $argv[1]
    set -e argv[1]

    switch "$cmd"
        case ''
            __repo_list
        case register rg
            __repo_register $argv
        case list ls
            __repo_list $argv
        case go cd
            __repo_go $argv
        case get
            __repo_get $argv
        case make mk
            __repo_make $argv
        case remove rm delete
            __repo_remove $argv
        case rename mv
            __repo_rename $argv
        case prune
            __repo_prune
        case help -h --help
            __repo_help
        case __names
            __repo_entries
        case __path
            __repo_path $argv
        case '*'
            __repo_go $cmd $argv
    end
end

set -g __repo_reserved register rg list ls go cd get make mk remove rm delete rename mv prune help

function __repo_help
    echo 'usage: repo [<name>[/sub/path]] | <command> [args]

  repo                       list repos
  repo <name>[/sub]          cd into a repo (or a folder inside it)
  repo rg [name] [path]      register path (default: cwd, name: folder name)
  repo ls [-r]               list repos (-r: only under cwd)
  repo get <name>[/sub]      print the path
  repo mk <folder>           create folder, register it, git init
  repo rm <name>             remove a repo
  repo mv <old> <new>        rename a repo
  repo prune                 remove repos whose path no longer exists

data: '(__repo_file)
end

function __repo_err
    echo "repo: $argv" >&2
    return 1
end

function __repo_file
    if set -q REPO_FILE
        echo $REPO_FILE
    else if set -q XDG_CONFIG_HOME
        echo $XDG_CONFIG_HOME/repo/repos
    else
        echo ~/.config/repo/repos
    end
end

# one "name<TAB>path" line per repo
function __repo_entries
    set -l file (__repo_file)
    test -f $file; or return 0
    string match -e \t <$file
end

function __repo_path -a name
    set name (string lower -- $name)
    for line in (__repo_entries)
        set -l f (string split -m1 \t -- $line)
        if test "$f[1]" = "$name"
            echo $f[2]
            return 0
        end
    end
    return 1
end

# print all entries except the given name
function __repo_without -a name
    for line in (__repo_entries)
        set -l f (string split -m1 \t -- $line)
        test "$f[1]" = "$name"; or echo $line
    end
end

# write lines from stdin as the new repo list
function __repo_write
    set -l file (__repo_file)
    mkdir -p (path dirname -- $file)
    sort >$file.tmp; and mv $file.tmp $file
end

function __repo_check_name -a name
    if test -z "$name"
        __repo_err 'name must not be empty'
    else if string match -qr '[/\t]|^-' -- $name
        __repo_err "invalid name '$name' (no '/', tabs or leading '-')"
    else if contains -- $name $__repo_reserved
        __repo_err "'$name' is reserved: $__repo_reserved"
    end
end

# split "name/sub/path" into name and sub path
function __repo_split -a value
    set -l parts (string split -m1 / -- $value)
    echo $parts[1]
    string trim -r -c / -- "$parts[2]"
end

function __repo_suggest -a name
    for line in (__repo_entries)
        set -l f (string split -m1 \t -- $line)
        if string match -qi -- "*$name*" $f[1] (path basename -- $f[2])
            echo $f[1]
        end
    end
end

# resolve "name/sub" to a directory; offers fzf when the name is unknown
function __repo_resolve -a target
    set -l split (__repo_split $target)
    set -l name $split[1]
    set -l sub $split[2]

    set -l root (__repo_path $name)
    if test -z "$root"
        if isatty stdin; and command -q fzf
            set name (__repo_entries | fzf --delimiter \t --with-nth 1 --nth 1 \
                --query $name --select-1 --exit-0 --height 40% --reverse \
                --preview 'echo {2}' --preview-window down,1 | string split -f1 \t)
            or return 1
            set root (__repo_path $name)
        else
            set -l similar (__repo_suggest $name)
            if set -q similar[1]
                __repo_err "'$name' is not registered. did you mean: "(string join ', ' $similar)'?'
            else
                __repo_err "'$name' is not registered. use 'repo rg $name <path>'"
            end
            return 1
        end
    end

    if not test -d $root
        __repo_err "'$name' points to a missing directory: $root"
        return 1
    end

    if test -n "$sub"
        if test -d $root/$sub
            echo $root/$sub
            return 0
        end
        echo "repo: '$sub' does not exist in '$name', using repo root" >&2
    end
    echo $root
end

function __repo_go
    set -q argv[1]; or return (__repo_err 'usage: repo <name>[/sub]')
    set -l dir (__repo_resolve $argv[1]); or return 1
    cd $dir
end

function __repo_get
    set -q argv[1]; or return (__repo_err 'usage: repo get <name>[/sub]')
    __repo_resolve $argv[1]
end

function __repo_list
    set -l entries (__repo_entries)
    if contains -- $argv[1] -r --relative
        set -l under
        for line in $entries
            set -l f (string split -m1 \t -- $line)
            if test "$f[2]" = $PWD; or string match -q -- "$PWD/*" $f[2]
                set -a under $line
            end
        end
        set entries $under
        set -q entries[1]; or echo 'no repos under the current directory' >&2
    else if not set -q entries[1]
        echo 'no repos registered' >&2
    end
    set -q entries[1]; or return 0

    set -l width 0
    for line in $entries
        set width (math max $width, (string length -- (string split -f1 \t -- $line)))
    end

    set -l tty (isatty stdout; and echo 1)
    for line in $entries
        set -l f (string split -m1 \t -- $line)
        set -l name (string pad -r -w $width -- $f[1])
        if test -z "$tty"
            echo "$name  $f[2]"
        else if test -d $f[2]
            echo (set_color --bold)$name(set_color normal)"  $f[2]"
        else
            echo (set_color red)"$name  $f[2]  (missing)"(set_color normal)
        end
    end
end

function __repo_register
    set -l name $argv[1]
    set -l dir $argv[2]
    test -n "$dir"; or set dir $PWD
    set dir (path resolve -- $dir)
    test -n "$name"; or set name (path basename -- $dir)
    set name (string lower -- $name)

    test -d $dir; or return (__repo_err "not a directory: $dir")
    __repo_check_name $name; or return 1

    set -l old (__repo_path $name)
    begin
        __repo_without $name
        printf '%s\t%s\n' $name $dir
    end | __repo_write; or return 1

    if test -n "$old"
        echo "repo: '$name' updated: $old -> $dir" >&2
    else
        echo "registered '$name' -> $dir"
    end
end

function __repo_make
    set -q argv[1]; or return (__repo_err 'usage: repo mk <folder>')
    set -l dir (path resolve -- $argv[1])
    test -e $dir; and return (__repo_err "already exists: $dir")
    set -l name (string lower -- (path basename -- $dir))
    __repo_check_name $name; or return 1

    mkdir -p $dir; or return 1
    __repo_register $name $dir; or return 1
    cd $dir
    git init -q
end

function __repo_remove
    set -q argv[1]; or return (__repo_err 'usage: repo rm <name>')
    set -l name (string lower -- $argv[1])
    set -l dir (__repo_path $name); or return (__repo_err "'$name' is not registered")

    read -l -P "remove '$name' ($dir)? [y/N] " answer; or return 1
    string match -qi y -- $answer; or return 1

    __repo_without $name | __repo_write; and echo "removed '$name'"
end

function __repo_rename
    set -q argv[2]; or return (__repo_err 'usage: repo mv <old> <new>')
    set -l old (string lower -- $argv[1])
    set -l new (string lower -- $argv[2])
    set -l dir (__repo_path $old); or return (__repo_err "'$old' is not registered")
    __repo_check_name $new; or return 1
    __repo_path $new >/dev/null; and return (__repo_err "'$new' already exists")

    begin
        __repo_without $old
        printf '%s\t%s\n' $new $dir
    end | __repo_write; and echo "renamed '$old' -> '$new'"
end

function __repo_prune
    set -l keep
    set -l pruned 0
    for line in (__repo_entries)
        set -l f (string split -m1 \t -- $line)
        if test -d $f[2]
            set -a keep $line
        else
            echo "removing '$f[1]' -> $f[2]"
            set pruned (math $pruned + 1)
        end
    end

    if test $pruned -eq 0
        echo 'all repos are valid'
        return 0
    end
    printf '%s\n' $keep | string match -e \t | __repo_write
    echo "pruned $pruned repo(s)"
end
