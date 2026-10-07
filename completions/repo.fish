function __repo_complete_args -a n
    test (count (commandline -opc)) -eq $n
end

function __repo_complete_after -a n
    set -l tokens (commandline -opc)
    test (count $tokens) -eq $n; and contains -- $tokens[2] $argv[2..]
end

# repo names, or folders inside a repo once the token contains a '/'
function __repo_complete_target
    set -l token (commandline -ct)
    if not string match -q '*/*' -- $token
        repo __names
        return
    end

    set -l parts (string split -m1 / -- $token)
    set -l root (repo __path $parts[1]); or return
    set -l parent (string replace -r '[^/]*$' '' -- $parts[2])
    set -l leaf (string replace -r '.*/' '' -- $parts[2])

    set -l dirs $root/$parent*/
    string match -q '.*' -- $leaf; and set dirs $root/$parent.*/
    for dir in $dirs
        echo $parts[1]/(string replace -- $root/ '' $dir)
    end
end

complete -c repo -f

complete -c repo -n '__repo_complete_args 1' -a '(__repo_complete_target)'
complete -c repo -n '__repo_complete_args 1' -a rg -d 'register a repo'
complete -c repo -n '__repo_complete_args 1' -a ls -d 'list repos'
complete -c repo -n '__repo_complete_args 1' -a get -d 'print repo path'
complete -c repo -n '__repo_complete_args 1' -a mk -d 'create, register, git init'
complete -c repo -n '__repo_complete_args 1' -a rm -d 'remove a repo'
complete -c repo -n '__repo_complete_args 1' -a mv -d 'rename a repo'
complete -c repo -n '__repo_complete_args 1' -a prune -d 'remove missing repos'
complete -c repo -n '__repo_complete_args 1' -a help -d 'show help'

complete -c repo -n '__repo_complete_after 2 go cd get' -a '(__repo_complete_target)'
complete -c repo -n '__repo_complete_after 2 remove rm delete rename mv' -a '(repo __names)'
complete -c repo -n '__repo_complete_after 2 list ls' -a -r -d 'only repos under cwd'
complete -c repo -n '__repo_complete_after 2 make mk' -a '(__fish_complete_directories)'
complete -c repo -n '__repo_complete_after 3 register rg' -a '(__fish_complete_directories)'
