ifndef WEBKIT_FRAMEWORK_PATH
$(error WEBKIT_FRAMEWORK_PATH must be set to a path that contains WebKit.framework)
endif

SRCS := $(shell find src -name '*.m')
OBJS := $(SRCS:%=./build/%.o)

XIBS := $(shell find src -name '*.xib')
NIBS_1 := $(XIBS:%=./build/%)
NIBS := $(NIBS_1:.xib=.nib)

CFLAGS := \
	-std=c99 \
        -F $(WEBKIT_FRAMEWORK_PATH) \
	-framework WebKit \
	-framework WebKitLegacy \
	-framework Cocoa \
	-framework UniformTypeIdentifiers \
	-framework SecurityInterface \
	-framework QuartzCore \
	-Wno-deprecated-declarations \
	-Wno-unused-command-line-argument

./build/%.m.o: %.m
	@echo CC $@
	@mkdir -p $(@D)
	cc $(CFLAGS) -c -o $@ $<

./build/%.nib: %.xib
	@echo ibtool $@
	@mkdir -p $(@D)
	ibtool --compile $@ $<

MiniBrowser: $(OBJS)
	@echo LD $@
	@mkdir -p $(@D)
	cc $(CFLAGS) -o build/$@ $(OBJS)

MiniBrowser.app: MiniBrowser $(NIBS)
	@mkdir -p MiniBrowser.app/Contents/MacOS
	@mkdir -p MiniBrowser.app/Contents/Resources
	cp build/MiniBrowser MiniBrowser.app/Contents/MacOS
	cp Info.plist MiniBrowser.app/Contents/
	cp $(NIBS) MiniBrowser.app/Contents/Resources
	printf 'APPL????' > MiniBrowser.app/Contents/PkgInfo
