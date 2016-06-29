all: clean build

build:
	mkdir target
	valac --pkg gstreamer-1.0 src/vala/app.vala -o target/app

clean:
	rm -rf target
