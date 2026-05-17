#! /bin/bash
#
#   Declare and store variables

declare -Agx STORED_VARS  # Array of variables 

# Function sets and exports variables 
# example: storer foo bar <- sets variable foo to bar iff foo not set
setAndStore() {
    export ${1}="${!1:-${2}}"
    ${DEBUG:-false} && echo "${1} = ${!1}" >&2
    STORED_VARS[$1]="${!1}"
}

printSTORED(){
    for i in "${!STORED_VARS[@]}" ; do
        echo "${i}=\"${STORED_VARS[$i]}"\"
    done
}

main() {
    echo -ne "\nTesting variable setting and printing\n\n"
    a=1
    setAndStore a c 
    setAndStore b d
    setAndStore c "b duh"
    printSTORED
}

return &> /dev/null || main  # Run main() if called as a script
