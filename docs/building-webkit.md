# Building WebKit

This guide assumes that you clone WebKit under the LargeBrowser directory.

```
# clone the repository
git clone https://github.com/WebKit/WebKit.git
cd WebKit

# optionally patch the source to add support for an 'execute-script' action for Content Blockers
patch -p1 < ../patches/WebKit-0001-ContentBlockers-add-execute-script-action.patch

# run the build script, optionally with MACOSX_DEPLOYMENT_TARGET set if you
# aren't running the latest version of macOS.
./Tools/Scripts/build-webkit --release MACOSX_DEPLOYMENT_TARGET=13.0
cd ..
```

You may now run `make WEBKIT_FRAMEWORK_PATH=$PWD/WebKit/WebKitBuild/Release` to build the browser.
