#!/usr/bin/env bash

set -e

# USAGE:
# - Set PLUGINS_DIR to wherever OpenplanetNext/Plugins lives
# ./build.sh [dev|release]
# Defaults to `dev` build mode.

# https://greengumdrops.net/index.php/colorize-your-bash-scripts-bash-color-library/
source ./vendor/_colors.bash

_build_mode=${1:-dev}

case $_build_mode in
  dev|release|prerelease|unittest)
    ;;
  *)
    _colortext16 red "⚠ Error: build mode of '$_build_mode' is not a valid option.\n\tOptions: dev, release.";
    exit -1;
    ;;
esac

_colortext16 yellow "🚩 Build mode: $_build_mode"

pluginSources=( 'src' )

for pluginSrc in ${pluginSources[@]}; do
  # if we don't have `dos2unix` below then we need to add `\r` to the `tr -d`
  PLUGIN_PRETTY_NAME="$(cat ./info.toml | dos2unix | grep '^name' | cut -f 2 -d '=' | tr -d '\"\r' | sed 's/^[ ]*//')"
  PLUGIN_VERSION="$(cat ./info.toml | dos2unix | grep '^version' | cut -f 2 -d '=' | tr -d '\"\r' | sed 's/^[ ]*//')"

  # prelim stuff
  case $_build_mode in
    dev)
      # we will replicate this in the info.toml file later
      export PLUGIN_PRETTY_NAME="${PLUGIN_PRETTY_NAME:-} (Dev)"
      ;;
    prerelease)
      export PLUGIN_PRETTY_NAME="${PLUGIN_PRETTY_NAME:-} (Prerelease)"
      ;;
    unittest)
      export PLUGIN_PRETTY_NAME="${PLUGIN_PRETTY_NAME:-} (UnitTest)"
      ;;
    *)
      ;;
  esac

  echo
  _colortext16 green "✅ Building: ${PLUGIN_PRETTY_NAME} (./$pluginSrc)"

  # remove parens, replace spaces with dashes, and uppercase characters with lowercase ones
  # => `Never Give Up (Dev)` becomes `never-give-up-dev`
  PLUGIN_NAME=$(echo "$PLUGIN_PRETTY_NAME" | tr -d '(),:;'\''"' | tr 'A-Z ' 'a-z-')
  # echo $PLUGIN_NAME
  _colortext16 green "✅ Output file/folder name: ${PLUGIN_NAME}"

  BUILD_NAME=$PLUGIN_NAME-$(date +%s).zip
  RELEASE_NAME=$PLUGIN_NAME-$PLUGIN_VERSION.op
  PLUGINS_DIR=${PLUGINS_DIR:-$HOME/win/OpenplanetNext/Plugins}
  PLUGIN_DEV_LOC=$PLUGINS_DIR/$PLUGIN_NAME
  PLUGIN_RELEASE_LOC=$PLUGINS_DIR/$RELEASE_NAME

  function buildPlugin {
    # 7z a ./$BUILD_NAME ./fonts ./$pluginSrc/* ./LICENSE ./README.md
    7z a ./$BUILD_NAME ./$pluginSrc/* ./LICENSE ./README.md

    cp -v $BUILD_NAME $RELEASE_NAME

    _colortext16 green "\n✅ Built plugin as ${BUILD_NAME} and copied to ./${RELEASE_NAME}.\n"
  }

  # this case should set both _copy_exit_code and _build_dest

  # common for non-release builds
  case $_build_mode in
    dev|prerelease|unittest)
      # in case it doesn't exist
      _build_dest=$PLUGIN_DEV_LOC
      mkdir -p $_build_dest/
      rm -vr $_build_dest/* || true
      cp -LR -v ./$pluginSrc/* $_build_dest/
      # cp -LR -v ./fonts $_build_dest/fonts
      # cp -LR -v ./fonts/* $_build_dest/fonts/
      # cp -LR -v ./external/* $_build_dest/
      cp -LR -v ./info.toml $_build_dest/
      _copy_exit_code="$?"
      ;;
  esac

  case $_build_mode in
    dev)
      sed -i 's/^\(name[ \t="]*\)\(.*\)"/\1\2 (Dev)"/' $_build_dest/info.toml
      sed -i 's/^#__DEFINES__/defines = ["DEV"]/' $_build_dest/info.toml
      ;;
    prerelease)
      sed -i 's/^\(name[ \t="]*\)\(.*\)"/\1\2 (Prerelease)"/' $_build_dest/info.toml
      sed -i 's/^#__DEFINES__/defines = ["RELEASE"]/' $_build_dest/info.toml
      ;;
    unittest)
      sed -i 's/^\(name[ \t="]*\)\(.*\)"/\1\2 (UnitTest)"/' $_build_dest/info.toml
      sed -i 's/^#__DEFINES__/defines = ["UNIT_TEST"]/' $_build_dest/info.toml
      ;;
    release)
      cp ./info.toml ./$pluginSrc/info.toml
      sed -i 's/^#__DEFINES__/defines = ["RELEASE"]/' ./$pluginSrc/info.toml
      buildPlugin
      rm ./$pluginSrc/info.toml
      _build_dest=$PLUGIN_RELEASE_LOC
      # cp -v $RELEASE_NAME $_build_dest
      _copy_exit_code="$?"
      ;;
    *)
      _colortext16 red "\n⚠ Error: unknown build mode: $_build_mode"
  esac


  echo ""
  if [[ "$_copy_exit_code" != "0" ]]; then
    echo $PLUGIN_PRETTY_NAME
    _colortext16 red "⚠ Error: could not copy plugin to Trackmania directory. You might need to click\n\t\`F3 > Scripts > TogglePlugin > PLUGIN\`\nto unlock the file for writing."
    _colortext16 red "⚠   Also, \"Stop Recent\" and \"Reload Recent\" should work, too, if the plugin is the \"recent\" plugin."
  else
    _colortext16 green "✅ Release file: ${RELEASE_NAME}"
  fi


  # # cleanup
  # case $_build_mode in
  #   dev)
  #     # remove the build artifact b/c they'll just take up space
  #     (rm $BUILD_NAME && _colortext16 green "✅ Removed ${BUILD_NAME}") || _colortext16 red "Failed to remove ${BUILD_NAME}."
  #     ;;
  #   *)
  #     ;;
  # esac

done

_colortext16 green "✅ Done."
