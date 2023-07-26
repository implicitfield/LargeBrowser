ifndef WEBKIT_FRAMEWORK_PATH
$(error WEBKIT_FRAMEWORK_PATH must be set to a path that contains WebKit.framework)
endif

.DEFAULT_GOAL := MiniBrowser.app

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
MiniBrowser: $(OBJS)
	@echo LD $@
	@mkdir -p $(@D)
	cc $(CFLAGS) -Wl,-dyld_env,DYLD_FRAMEWORK_PATH=@loader_path/../Frameworks -Wl,-dyld_env,DYLD_LIBRARY_PATH=@loader_path/../Frameworks -o build/$@ $(OBJS)

MiniBrowser.app: MiniBrowser $(NIBS)
	@mkdir -p MiniBrowser.app/Contents/MacOS
	@mkdir -p MiniBrowser.app/Contents/Frameworks
	@mkdir -p MiniBrowser.app/Contents/Resources
	cp build/MiniBrowser MiniBrowser.app/Contents/MacOS
	cp -a "$(WEBKIT_FRAMEWORK_PATH)"/* MiniBrowser.app/Contents/Frameworks
	cp $(NIBS) MiniBrowser.app/Contents/Resources
	cp Info.plist MiniBrowser.app/Contents/
	printf 'APPL????' > MiniBrowser.app/Contents/PkgInfo

clean:
	rm -rf MiniBrowser.app build
