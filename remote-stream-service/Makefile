all: clean build

build:
	mkdir target
	valac --pkg gstreamer-1.0 --pkg libsoup-2.4 --pkg gee-0.8 src/vala/controller.vala src/vala/app.vala -o target/app

clean:
	rm -rf target
