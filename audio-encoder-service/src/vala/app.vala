using Gst;

public class Application: GLib.Object {
  private string pipeline_template = "uridecodebin uri=file:///Users/michael/Development/Vala/interpreter/src/resources/talk.mp3 !
  audioconvert ! faac quality=1000 ! mpegtsmux name=muxer ! tsparse ! rtpmp2tpay ! tcpserversink port=3333";

  private Pipeline pipeline;
  private Gst.Bus bus;
  private MainLoop loop;

  public Application() {
    // Creating pipeline and elements
    pipeline = (Pipeline)parse_launch(pipeline_template);

    bus = pipeline.get_bus();
    bus.add_watch (0, bus_callback);
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
    loop.run ();
  }

  public static int main (string[] args) {

      Gst.init (ref args);

      var app = new Application ();
      app.start();

      return 0;


  }
}
