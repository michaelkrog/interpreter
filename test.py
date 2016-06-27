import os
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GObject, GLib

class Main(object):
    def __init__(self, path):
        print "Init"
        self.path = path
        self.player = Gst.ElementFactory.make("playbin", "player")
        sink = Gst.ElementFactory.make("autovideosink", "videosink")
        self.player.set_property("video-sink", sink)
        bus = self.player.get_bus()
        bus.add_signal_watch()
        bus.connect("message", self.on_message)

    def start(self):
        print "start"

        filepath = self.path
        filepath = os.path.realpath(filepath)
        fiepath = "file://" + filepath
        filepath = "http://wtbtshdflash-f.akamaihd.net/i/AAzoD5JE3RyaT9cWPAoU6N8qSA2JNxKyM7QcC6fXA5iCp7izzqFoCAq7vylVOAg9HxF3DUt7_mUuQdUH4V@83006/index_1500_av-p.m3u8"
        self.player.set_property("uri", filepath)
        self.player.set_state(Gst.State.PLAYING)

    def on_message(self, bus, message):
        t = message.type
        print t
        if t == Gst.MessageType.EOS:
            print "The end!"
            self.player.set_state(Gst.State.NULL)
        elif t == Gst.MessageType.ERROR:
            self.player.set_state(Gst.State.NULL)
            err, debug = message.parse_error()
            print "Error: %s" % err, debug
        elif t == Gst.MessageType.TAG:

            def handle_tag(taglist, tag, userdata):
                print tag

            tags = message.parse_tag()
            tags.foreach(handle_tag, None)




Gst.init(None)
player = Main("/Users/michael/Desktop/herlufmagle-dansk.mp4")
GObject.threads_init()

player.start()
loop = GLib.MainLoop()
loop.run()