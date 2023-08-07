ifndef WEBKIT_FRAMEWORK_PATH
$(error WEBKIT_FRAMEWORK_PATH must be set to a path that contains WebKit.framework)
endif

.DEFAULT_GOAL := LargeBrowser.app

SRCS := $(shell find src -name '*.m')
OBJS := $(SRCS:%=./build/%.o)

XIBS := $(shell find src -name '*.xib')
NIBS_1 := $(XIBS:%=./build/%)
NIBS := $(NIBS_1:.xib=.nib)

CFLAGS := \
	-std=c99 \
	-fobjc-arc \
        -F $(WEBKIT_FRAMEWORK_PATH) \
	-framework WebKit \
	-framework Cocoa \
	-framework UniformTypeIdentifiers \
	-framework SecurityInterface \
	-framework QuartzCore \
	-Wall \
	-Wextra \
	-Wno-deprecated-declarations \
	-Wno-unused-command-line-argument \
	-Wno-unused-parameter

./build/%.m.o: %.m
	@echo CC $@
	@mkdir -p $(@D)
	cc $(CFLAGS) -c -o $@ $<

./build/%.nib: %.xib
	@echo ibtool $@
	@mkdir -p $(@D)
	ibtool --compile $@ $<

# Mimic what Safari Technology Preview does, i.e. just embed DYLD_FRAMEWORK_PATH and DYLD_LIBRARY_PATH into the main binary.
LargeBrowser: $(OBJS)
	@echo LD $@
	@mkdir -p $(@D)
	cc $(CFLAGS) -Wl,-dyld_env,DYLD_FRAMEWORK_PATH=@loader_path/../Frameworks -Wl,-dyld_env,DYLD_LIBRARY_PATH=@loader_path/../Frameworks -o build/$@ $(OBJS)

LargeBrowser.app: LargeBrowser $(NIBS)
	@mkdir -p LargeBrowser.app/Contents/MacOS
	@mkdir -p LargeBrowser.app/Contents/Frameworks
	@mkdir -p LargeBrowser.app/Contents/Resources
	cp build/LargeBrowser LargeBrowser.app/Contents/MacOS
	cp -a "$(WEBKIT_FRAMEWORK_PATH)"/* LargeBrowser.app/Contents/Frameworks
	cp $(NIBS) LargeBrowser.app/Contents/Resources
	cp Info.plist LargeBrowser.app/Contents
	iconutil --convert icns icons/LargeBrowser.iconset
	mv icons/LargeBrowser.icns LargeBrowser.app/Contents/Resources
	printf 'APPL????' > LargeBrowser.app/Contents/PkgInfo

clean:
	rm -rf LargeBrowser.app build
