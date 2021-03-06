using Gst;
using Gee;

public class ApplicationInfoHandler : GLib.Object, InfoHandler {
    private HashMap<string, string> _map = new HashMap<string, string>();

    public HashMap<string, string> map {
        get { return _map; }
    }

    public HashMap<string, string> getInfoMap () {
      return this._map;
    }
}

public class ApplicationMetricsHandler: GLib.Object, MetricsHandler {

}

public class Application: GLib.Object {
  private static string pads = "audio/x-raw,channels=2,rate=48000,format=F32LE";
  private string pipeline_template = "tcpclientsrc port=3333 name=src1 !
    queue ! decodebin ! queue !
    audioconvert ! audioresample ! " + pads + " ! tee name=src1_split !
    " + pads + " ! queue ! volume name=volume ! audiomixer name=mixer ! queue !
    audioconvert ! faac ! aacparse ! mux.
    src1_split. ! queue ! audioconvert ! " + pads + " ! autoaudiosink
    autoaudiosrc ! level name=level ! queue ! audioconvert ! audioresample !
    " + pads + " ! mixer.
    tcpclientsrc port=2220 ! queue ! tsdemux ! h264parse ! mux.
    mpegtsmux name=mux ! filesink name=filesink";
    //tcpclientsrc port=2220 ! queue ! tsdemux ! h264parse ! mux.video_0

    private ApplicationMetricsHandler metricsHandler = new ApplicationMetricsHandler();
    private ApplicationInfoHandler infoHandler = new ApplicationInfoHandler();

  /*private string @pipeline_template = """filesrc name=src1 !
    mad ! queue ! audioconvert ! audioresample ! """+pads+""" ! tee name=src1_split !
    """ + pads + """ ! queue ! volume name=volume ! audiomixer name=mixer ! queue !
    audioconvert ! lamemp3enc ! filesink name=filesink
    src1_split. ! queue ! audioconvert ! """+pads+""" ! autoaudiosink
    autoaudiosrc ! level name=level ! queue ! audioconvert ! audioresample !
    """+pads+""" ! mixer.
  """;*/
  private Pipeline pipeline;
  private Gst.Bus bus;
  private MainLoop loop;
  private Element src1;
  private Element filesink;
  private Element level;
  private Element volume;
  private Element encode;
  private double current_volume = 1.0;
  private string output_path;
  private bool shuttingDown = false;

  public Application(string output_path) {
    this.output_path = output_path;
  }

  private void handleDecay(double decay) {
    double fade_to = 0.1f;
    double max_vol = 1.0;
    double target_volume;
    double new_volume = 1.0;
    //stdout.printf ("DECAY: %s\n", decay.to_string());
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
            this.destroyPipeline();
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
            this.infoHandler.map["state"] = this.state_from_gst_state(newstate);
            break;
        case MessageType.TAG:
            //Gst.TagList tag_list;
            //stdout.printf ("taglist found\n");
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
        case MessageType.INFO:
          stdout.printf ("info message\n");
          break;
        case MessageType.BUFFERING:
          stdout.printf ("buffering message\n");
          break;
        case MessageType.STREAM_STATUS:
          Gst.StreamStatusType type;
          Gst.Element owner;
          message.parse_stream_status (out type, out owner);

          stdout.printf ("stream changed: %s\n", type.to_string());

          break;
        case MessageType.QOS:
          stdout.printf ("QOS message\n");
          break;
        case MessageType.UNKNOWN:
          stdout.printf ("unknown message\n");
          break;
        case MessageType.WARNING:
          stdout.printf ("warning message\n");
          break;
        default:
          break;
        }

        return true;
  }

  private void stopPipeline() {
    if(this.pipeline != null) {
      stdout.printf ("Stopping pipeline.\n");
      pipeline.send_event(new Event.eos());
    }
  }

  private void destroyPipeline() {
    stdout.printf ("Destroying pipeline.\n");
    pipeline.set_state(State.NULL);
    pipeline = null;
    this.infoHandler.map["state"] = this.state_from_gst_state(State.NULL);

    if(this.shuttingDown) {
      stdout.printf ("Quiting.\n");
      loop.quit();
    }
  }

  private void startPipeline() {
    if(this.pipeline == null) {
      stdout.printf ("Starting pipeline.\n");
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

      pipeline.set_state (State.PLAYING);
    }
  }

  public void shutdown() {
    stdout.printf ("Shutting down.\n");
    if(this.pipeline != null) {
      this.shuttingDown = true;
      this.stopPipeline();
    } else {
      loop.quit();
    }
  }

  public void start() {

    int port = 8088;

    // Creating and starting a GLib main loop
    loop = new MainLoop();

    Controller controller = new Controller (this.infoHandler, this.metricsHandler);
    controller.listen_all (port, 0);
    controller.got_shutdown.connect (this.shutdown);
    controller.got_start.connect (this.startPipeline);
    controller.got_stop.connect (this.stopPipeline);

    this.infoHandler.map["pipeline"] = this.pipeline_template;
    this.infoHandler.map["state"] = this.state_from_gst_state(Gst.State.NULL);

    stdout.printf ("Started.\n");
    loop.run ();



  }

  private string state_from_gst_state(Gst.State state) {
    switch(state) {
      case Gst.State.NULL:
        return "Idle";
      case Gst.State.PLAYING:
        return "Playing";
      case Gst.State.PAUSED:
        return "Paused";
      case Gst.State.READY:
        return "Ready";
      default:
        return "None";
    }
  }

  public static int main (string[] args) {

      Gst.init (ref args);

      var app = new Application ("out.mp4");
      app.start();

      return 0;


  }
}
