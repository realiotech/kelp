#!/bin/bash

function install_web_dependencies() {
    echo "installing web dependencies ..."
    CURRENT_DIR=`pwd`
    cd $CURRENT_DIR/gui/web

    yarn install
    check_build_result $?

    cd $CURRENT_DIR
    echo "... finished installing web dependencies"
    echo ""
}

function generate_static_web_files() {
    echo "generating contents of gui/web/build ..."
    CURRENT_DIR=`pwd`
    cd $CURRENT_DIR/gui/web

    yarn build
    check_build_result $?

    cd $CURRENT_DIR
    echo "... finished generating contents of gui/web/build"
    echo ""
}

# takes in the exit code ($?) of the previous command as the input
function check_build_result() {
    if [[ $1 -ne 0 ]]
    then
        echo ""
        echo "build failed with error code $1"
        exit $1
    fi
}

# takes in the ARGS for which to build
function gen_bundler_json() {
    echo -n "generating the bundler.json file in / to create missing files for '$@' platforms ... "
    go run ./scripts/gen_bundler_json/gen_bundler_json.go $@ > $KELP/bundler.json
    check_build_result $?
    echo "done"
}

# takes in no args
function gen_bind_files() {
    echo -n "generating the bind file in /cmd to create missing files for platforms specified in the bundler.json ... "
    astilectron-bundler bd -c $KELP/bundler.json
    check_build_result $?
    echo "done"
}


if [[ $(basename $("pwd")) != "kelp" ]]
then
    echo "need to invoke from the root 'kelp' directory"
    exit 1
fi

KELP=`pwd`
ENV="dev"

# version is git tag if it's available, otherwise git hash
GUI_VERSION=v1.0.0-rc2
VERSION=$(git describe --always --abbrev=8 --dirty --tags)
GIT_BRANCH=$(git branch | grep \* | cut -d' ' -f2)
VERSION_STRING="$GIT_BRANCH:$VERSION"
GIT_HASH=$(git describe --always --abbrev=50 --dirty --long)
DATE=$(date -u +%"Y%m%dT%H%M%SZ")
LDFLAGS_ARRAY=("github.com/stellar/kelp/cmd.version=$VERSION_STRING" "github.com/stellar/kelp/cmd.guiVersion=$GUI_VERSION" "github.com/stellar/kelp/cmd.gitBranch=$GIT_BRANCH" "github.com/stellar/kelp/cmd.gitHash=$GIT_HASH" "github.com/stellar/kelp/cmd.buildDate=$DATE" "github.com/stellar/kelp/cmd.env=$ENV" "github.com/stellar/kelp/cmd.amplitudeAPIKey=$AMPLITUDE_API_KEY")

LDFLAGS=""
LDFLAGS_UI=""
for FLAG in "${LDFLAGS_ARRAY[@]}"
do
    LDFLAGS="$LDFLAGS -X $FLAG"
    LDFLAGS_UI="$LDFLAGS_UI -ldflags X:$FLAG"
done

echo "version: $VERSION_STRING"
echo "git branch: $GIT_BRANCH"
echo "git hash: $GIT_HASH"
echo "build date: $DATE"
echo "env: $ENV"
echo "LDFLAGS: $LDFLAGS"

echo ""
echo ""
install_web_dependencies

echo ""
echo "embedding contents of gui/web/build into a .go file (env=$ENV) ..."
go run ./scripts/fs_bin_gen/fs_bin_gen.go -env $ENV
check_build_result $?
echo "... finished embedding contents of gui/web/build into a .go file (env=$ENV)"
echo ""


GOOS="$(go env GOOS)"
GOARCH="$(go env GOARCH)"
echo "GOOS: $GOOS"
echo "GOARCH: $GOARCH"
echo ""

# generate outfile
OUTFILE=bin/kelp
mkdir -p bin

gen_bundler_json
gen_bind_files
echo ""

# manually set buildType for GUI
DYNAMIC_LDFLAGS="$LDFLAGS -X github.com/stellar/kelp/cmd.buildType=gui"

# cannot set goarm because not accessible (need to figure out a way)
echo -n "compiling ... "
go build -ldflags "$DYNAMIC_LDFLAGS" -o $OUTFILE
check_build_result $?
echo "successful: $OUTFILE"
echo ""
generate_static_web_files
echo "BUILD SUCCESSFUL"
exit 0

