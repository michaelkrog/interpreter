using Soup;
using Gee;

public interface MetricsHandler: GLib.Object {

}

public interface InfoHandler: GLib.Object {
  public abstract HashMap<string, string> getInfoMap ();
}

public class Controller : Soup.Server {
	private int access_counter = 0;
  private InfoHandler infoHandler;
  private MetricsHandler metricsHandler;

	public Controller (InfoHandler infoHandler, MetricsHandler metricsHandler) {
		assert (this != null);
    assert (infoHandler != null);
    assert (metricsHandler != null);

    this.infoHandler = infoHandler;
    this.metricsHandler = metricsHandler;

    this.add_handler ("/event-stream", this.event_handler);
    this.add_handler ("/shutdown", this.shutdown_handler);
    this.add_handler ("/start", this.start_handler);
    this.add_handler ("/stop", this.stop_handler);
    this.add_handler ("/info", this.info_handler);
    this.add_handler ("/env", this.env_handler);
    this.add_handler ("/metrics", this.metrics_handler);
		//this.add_handler (null, this.default_handler);
	}

  public signal void got_shutdown ();
  public signal void got_start ();
  public signal void got_stop ();


  private void metrics_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {

  }

  private void env_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
    if(msg.method == "GET") {
      stdout.printf ("Environment request recieved.\n");
      msg.set_status(Soup.Status.OK);
      string[] args = Environment.list_variables ();
      string message = "{";
      int count = 0;
    	foreach (string arg in args) {
  		    stdout.printf ("%s\n", arg);

          if(count > 0) {
            message += ",";
          }
          message += "\n\t";
          message += "\"" + arg + "\": ";
          message += "\""+ this.escape_json_value(Environment.get_variable(arg)) + "\"";
          count++;
    	}
      message+="\n}";
      stdout.printf ("Sending Environment request.\n");
      msg.set_response("application/json", Soup.MemoryUse.COPY, message.data);
    }
  }



  private void info_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
    if(msg.method == "GET") {
      stdout.printf ("Info request recieved.\n");
      msg.set_status(Soup.Status.OK);
      HashMap<string, string> map = this.infoHandler.getInfoMap();

      stdout.printf ("Building info request.\n");

      string message = "{";
      int count = 0;
      foreach (var entry in map.entries) {
        if(count > 0) {
          message += ",";
        }
        message += "\n\t";
        message += "\"" + entry.key + "\": ";
        message += "\""+ entry.value + "\"";
        count++;
      }
      message+="\n}";

      stdout.printf ("Sending info request.\n");
      msg.set_response("application/json", Soup.MemoryUse.COPY, message.data);
    }
  }

  private void shutdown_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
    if(msg.method == "POST") {
      msg.set_status(Soup.Status.OK);
      stdout.printf ("Shutdown request recieved.\n");
      this.got_shutdown();
    }
  }

  private void start_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
    if(msg.method == "POST") {
      msg.set_status(Soup.Status.OK);
      stdout.printf ("Start request recieved.\n");
      this.got_start();
    }
  }

  private void stop_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
    if(msg.method == "POST") {
      msg.set_status(Soup.Status.OK);
      stdout.printf ("Stop request recieved.\n");
      this.got_stop();
    }
  }

	private void event_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
		unowned Controller self = server as Controller;

		uint id = self.access_counter++;
		stdout.printf ("Event handler start (%u)\n", id);
    msg.request_headers.append("Content-Type", "text/event-stream");
    msg.set_status(Soup.Status.OK);

		// Simulate asynchronous input / time consuming operations:
		// See GLib.IOSchedulerJob for time consuming operations
		Timeout.add_seconds (5, () => {
			msg.request_body.append_take ("""{"data":"test"}""".data);

			// Resumes HTTP I/O on msg:
			self.unpause_message (msg);
			stdout.printf ("event sent (%u)\n", id);
			return false;
		}, Priority.DEFAULT);

		// Pauses HTTP I/O on msg:
		self.pause_message (msg);
	}

  private string escape_json_value(string value) {
    return value.replace("\"", "\\\"");
  }


}
