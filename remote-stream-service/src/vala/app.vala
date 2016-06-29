using Gst;

public class Application: GLib.Object {
  private static string pads = "audio/x-raw,channels=2,rate=48000,format=F32LE";
  private string @pipeline_template = "tcpclientsrc port=3333 name=src1 !
    queue ! decodebin ! queue !
    audioconvert ! audioresample ! " + pads + " ! tee name=src1_split !
    " + pads + " ! queue ! volume name=volume ! audiomixer name=mixer ! queue !
    audioconvert ! faac ! mux.audio_0
    src1_split. ! queue ! audioconvert ! " + pads + " ! autoaudiosink
    autoaudiosrc ! level name=level ! queue ! audioconvert ! audioresample !
    " + pads + " ! mixer.
    tcpclientsrc port=2220 ! queue ! tsdemux ! h264parse ! mux.video_0
    mp4mux name=mux ! filesink name=filesink";

  /*private string @pipeline_template = """filesrc name=src1 !
    mad ! queue ! audioconvert ! audioresample ! """+pads+""" ! tee name=src1_split !
    """ + pads + """ ! queue ! volume name=volume ! audiomixer name=mixer ! queue !
    audioconvert ! lamemp3enc ! filesink name=filesink
    src1_split. ! queue ! audioconvert ! """+pads+""" ! autoaudiosink
    autoaudiosrc ! level name=level ! queue ! audioconvert ! audioresample !
    """+pads+""" ! mixer.
  """;*/
  private Pipeline pipeline;
  private Bus bus;
  private MainLoop loop;
  private Element src1;
  private Element filesink;
  private Element level;
  private Element volume;
  private Element encode;
  private double current_volume = 1.0;

  public Application(string output_path) {
    // Creating pipeline and elements
    pipeline = (Pipeline)parse_launch(pipeline_template);

    src1 = pipeline.get_by_name("src1");
    filesink = pipeline.get_by_name("filesink");
    level = pipeline.get_by_name("level");
    volume = pipeline.get_by_name("volume");
    encode = pipeline.get_by_name("encode");

    //src1.set_property("uri", input_uri);
    filesink.set_property("location", output_path);
    level.set_property("peak-falloff", 40);
    encode.set_property("quality", 3);
    encode.set_property("encoding-engine-quality", "high");

    bus = pipeline.get_bus();
    bus.add_watch (0, bus_callback);
  }

  private void handleDecay(double decay) {
    double fade_to = 0.1f;
    double max_vol = 1.0;
    double target_volume;
    double new_volume = 1.0;
    stdout.printf ("DECAY: %s\n", decay.to_string());
    if(decay > -20) {
      target_volume = fade_to;
    } else {
        target_volume = max_vol;
        if(decay > -35) {
          target_volume = fade_to + ((max_vol - fade_to) * ((decay+15)*-1/15));
        }
    }

    double diff = target_volume - current_volume;
    if(diff > 0.2 || diff < -0.2) {
        if(target_volume > current_volume) {
            new_volume = current_volume + 0.1;
        } else {
            new_volume = current_volume - 0.1;
        }
    } else {
        new_volume = target_volume;
    }

    volume.set_property("volume", new_volume);
    current_volume = new_volume;
  }

  private bool bus_callback (Gst.Bus bus, Gst.Message message) {
    switch (message.type) {
        case MessageType.ERROR:
            GLib.Error err;
            string debug;
            message.parse_error (out err, out debug);
            stdout.printf ("Error: %s\n", err.message);
            loop.quit ();
            break;
        case MessageType.EOS:
            stdout.printf ("end of stream\n");
            break;
        case MessageType.STATE_CHANGED:
            Gst.State oldstate;
            Gst.State newstate;
            Gst.State pending;
            message.parse_state_changed (out oldstate, out newstate,
                                         out pending);
            stdout.printf ("state changed: %s->%s:%s\n",
                           oldstate.to_string (), newstate.to_string (),
                           pending.to_string ());
            break;
        case MessageType.TAG:
            //Gst.TagList tag_list;
            stdout.printf ("taglist found\n");
            //message.parse_tag (out tag_list);
            //tag_list.foreach ((TagForeachFunc) foreach_tag);
            break;
        case MessageType.ELEMENT:
          if(message.has_name("level")) {
            unowned Structure s = message.get_structure();
            unowned GLib.ValueArray decay = (GLib.ValueArray) s.get_value("decay");
            Type type = decay.values[0].type();
            this.handleDecay(decay.values[0].get_double());

          }
          break;
        default:
            break;
        }

        return true;
  }

  public void start() {
    // Set pipeline state to PLAYING
    pipeline.set_state (State.PLAYING);

    // Creating and starting a GLib main loop
    loop = new MainLoop();
    GLib.Timeout.add (20000, () => {
      StateChangeReturn ret = pipeline.set_state(State.PAUSED);
      while(ret == StateChangeReturn.ASYNC) {
        yield;
      }
      loop.quit();
      return false;
    });
    loop.run ();
  }

  public static int main (string[] args) {

      Gst.init (ref args);

      var app = new Application ("out.mp4");
      app.start();

      return 0;


  }
}
