# Content Blockers

For an introduction to Content Blockers, see: https://webkit.org/blog/3476/content-blockers-first-look

---

LargeBrowser has been built with Content Blockers in mind. This document details how they can be utilized optimally.

## Loading Rules

1. Open 'Debug->Show Extensions Manager'
2. Click the '+' button.

## Using the `execute-script` Action

With the help of [a downstream WebKit patch](../patches/WebKit-0001-ContentBlockers-add-execute-script-action.patch), Content Blockers can modify the JavaScript environment before any third-party JavaScript gets a chance to run. Most mainstream adblock extensions use "scriptlets" for this purpose.
See [YT-Adblock.json](YT-Adblock.json) for an in-depth example.

## Using the EasyList Filter

There are a couple of limitations to this, but the EasyList filter works fairly well for blocking basic ads / trackers.
The following tutorial is expected to be followed from the LargeBrowser directory.

```
# clone SafariConverterLib
git clone https://github.com/AdguardTeam/SafariConverterLib.git
cd SafariConverterLib

# patch the source to easily obtain the generated JSON file.
patch -p1 < ../patches/SafariConverterLib-0001-output-json.patch

# build SafariConverterLib
swift build

# download the EasyList filter
curl -OL https://github.com/AdguardTeam/FiltersRegistry/raw/master/filters/ThirdParty/filter_101_EasyList/filter.txt

# convert it
cat filter.txt | $(find . -name ConverterTool) --safari-version 16 --optimize true 2> EasyList.json
```

The resulting EasyList.json may be loaded into LargeBrowser. (It will take a few seconds to import.) Do note that the filter is updated quite often, so you may want to occasionally repeat the last two steps.
