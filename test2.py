import os
from gettext import c2py

import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GObject, GLib

class Main(object):
    def __init__(self, path):
        print "Init"
        self.path = path
        self.caps = Gst.caps_from_string('audio/x-raw,channels=2,rate=48000,format=F32LE')

        self.src1 = Gst.ElementFactory.make('filesrc', None)
        self.src1_decode = Gst.ElementFactory.make('mad', None)
        self.src1_queue = Gst.ElementFactory.make('queue', None)
        self.src1_audioconvert = Gst.ElementFactory.make('audioconvert', None)
        self.src1_audioresample = Gst.ElementFactory.make('audioresample', None)
        self.src1_volume = Gst.ElementFactory.make('volume', None)

        self.src1_volume_queue = Gst.ElementFactory.make('volume', None)

        self.filesink_queue = Gst.ElementFactory.make('queue', None)
        self.filesink_audioconvert = Gst.ElementFactory.make('audioconvert', None)

        self.tee1= Gst.ElementFactory.make('tee', None)
        self.audiomixer = Gst.ElementFactory.make('audiomixer', None)

        self.audiosink_queue = Gst.ElementFactory.make('queue', None)
        self.audiosink_audioconvert = Gst.ElementFactory.make('audioconvert', None)
        self.audiosink = Gst.ElementFactory.make('autoaudiosink', None)
        self.filesink_encode = Gst.ElementFactory.make('lamemp3enc', None)
        self.filesink = Gst.ElementFactory.make('filesink', None)

        self.src2 = Gst.ElementFactory.make('autoaudiosrc', None)
        self.src2_level = Gst.ElementFactory.make('level', None)
        self.src2_volume = Gst.ElementFactory.make('volume', None)

        self.src2_queue= Gst.ElementFactory.make('queue', None)
        self.src2_audioconvert = Gst.ElementFactory.make('audioconvert', None)
        self.src2_audioresample = Gst.ElementFactory.make('audioresample', None)

        self.pipeline = Gst.Pipeline()
        self.pipeline.add(self.src1)
        self.pipeline.add(self.src1_decode)
        self.pipeline.add(self.src1_volume)
        self.pipeline.add(self.tee1)
        self.pipeline.add(self.src1_volume_queue)
        self.pipeline.add(self.src1_queue)
        self.pipeline.add(self.src1_audioconvert)
        self.pipeline.add(self.src1_audioresample)
        self.pipeline.add(self.filesink_queue)
        self.pipeline.add(self.filesink_audioconvert)
        self.pipeline.add(self.filesink_encode)
        self.pipeline.add(self.audiomixer)
        self.pipeline.add(self.filesink)

        self.pipeline.add(self.audiosink_queue)
        self.pipeline.add(self.audiosink_audioconvert)
        self.pipeline.add(self.audiosink)
        self.pipeline.add(self.src2)
        self.pipeline.add(self.src2_level)
        self.pipeline.add(self.src2_volume)
        self.pipeline.add(self.src2_queue)
        self.pipeline.add(self.src2_audioconvert)
        self.pipeline.add(self.src2_audioresample)

        self.src1.link(self.src1_decode)
        self.src1_decode.link(self.src1_queue)
        self.src1_queue.link(self.src1_audioconvert)
        self.src1_audioconvert.link(self.src1_audioresample)
        self.src1_audioresample.link_filtered(self.tee1, self.caps)
        self.tee1.link_filtered(self.src1_volume_queue, self.caps)
        self.src1_volume_queue.link(self.src1_volume)
        self.src1_volume.link(self.audiomixer)
        self.audiomixer.link(self.filesink_queue)
        self.filesink_queue.link(self.filesink_audioconvert)
        self.filesink_audioconvert.link(self.filesink_encode)
        self.filesink_encode.link(self.filesink)

        self.tee1.link(self.audiosink_queue)
        self.audiosink_queue.link(self.audiosink_audioconvert)
        self.audiosink_audioconvert.link_filtered(self.audiosink, self.caps)

        self.src2.link(self.src2_level)
        self.src2_level.link(self.src2_volume)
        self.src2_volume.link(self.src2_queue)
        self.src2_queue.link(self.src2_audioconvert)
        self.src2_audioconvert.link(self.src2_audioresample)
        self.src2_audioresample.link_filtered(self.audiomixer, self.caps)

        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect("message", self.on_message)

    def start(self):
        print "start"

        #filepath = self.path
        #filepath = os.path.realpath(filepath)
        #fiepath = "file://" + filepath
        #filepath = "http://wtbtshdflash-f.akamaihd.net/i/AAzoD5JE3RyaT9cWPAoU6N8qSA2JNxKyM7QcC6fXA5iCp7izzqFoCAq7vylVOAg9HxF3DUt7_mUuQdUH4V@83006/index_1500_av-p.m3u8"
        self.src1.set_property("location", "talk.mp3")
        self.filesink.set_property("location", "out.mp3")
        self.src2_level.set_property("peak-falloff", 40)
        self.filesink_encode.set_property("quality", 3)
        self.filesink_encode.set_property("encoding-engine-quality", "high")

        self.pipeline.set_state(Gst.State.PLAYING)

    def process_levels(self, levels):
        current_volume = self.src1_volume.get_property("volume")
        fade_to = 0.1
        max_vol = 1

        if levels['decay'][0] > -20:
            target_volume = fade_to
            #self.src1_volume.set_property("volume", fade_to)
            #self.src2_volume.set_property("volume", max_vol)
        else:
            target_volume = max_vol
            if levels['decay'][0] > -35:
                target_volume = fade_to + ((max_vol - fade_to) * ((levels['decay'][0]+15)*-1/15))
            #self.src1_volume.set_property("volume", volume)
            #self.src2_volume.set_property("volume", max_vol - volume)

        if abs(target_volume - current_volume) > 0.2:
            if target_volume > current_volume:
                volume = current_volume + 0.1
            else:
                volume = current_volume - 0.1
        else:
            volume = target_volume

        self.src1_volume.set_property("volume", volume)


    def on_message(self, bus, message):
        t = message.type
        print t
        if t == Gst.MessageType.EOS:
            print "The end!"
            self.pipeline.set_state(Gst.State.NULL)
        elif t == Gst.MessageType.ELEMENT and message.has_name("level"):
            s = message.get_structure()
            try:
                levs = {}
                for type in ("rms", "peak", "decay"):
                    levs[type] = s.get_value(type)

                print "PEAK: ", levs['peak'][0]
                print "DECAY: ", levs['decay'][0]

                self.process_levels(levs)

            except ValueError as e:
                print e
        elif t == Gst.MessageType.ERROR:
            self.pipeline.set_state(Gst.State.NULL)
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