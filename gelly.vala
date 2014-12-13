using Gtk;

using Xml;
using Xml.XPath;

// To compile you need vala, then use this command line:
// valac --pkg gtk+-3.0 --pkg libsoup-2.4 --pkg libxml-2.0 gelly.vala

public errordomain XPathFailed {
    CODE_1A
}

struct Post {
    public string preview_url;
	public Gtk.Image preview_image;
	public string file_url;
	public string tags;
}

public class Uru : Window {
	ListStore catalog;

	ImageStorer thumbnails;
	ImageStorer originals;
	
	public Uru() {
		thumbnails = new ImageStorer ("thumbnails");
		originals = new ImageStorer ("originals");
		
		this.title = "Gelly";
		this.border_width = 10;
		this.window_position = Gtk.WindowPosition.CENTER;
		this.set_default_size (500, 800);
		this.destroy.connect (Gtk.main_quit);

		var box_a = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
		var box_b = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
		var scroll = new ScrolledWindow (null, null);
		var box_c = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 1);
	
		{
			var label = new Gtk.Label ("Search: ");
			var entry = new Gtk.Entry ();
			var button = new Gtk.Button.with_label ("Gelly!");
	
			box_b.pack_start (label, false);
			box_b.pack_start (entry);
			box_b.pack_start (button, false);

			entry.activate.connect (() => {
					unowned string str = entry.get_text ();
					string tags = process_search (str);
					perform_search.begin(tags);
				});
			button.clicked.connect (() => {
					unowned string str = entry.get_text ();
					string tags = process_search (str);
					perform_search.begin(tags);
				});
		}
		
		{
			var view = new TreeView ();
			var listmodel = new ListStore (3, typeof (Gdk.Pixbuf), typeof (string), typeof (string));
			
			view.set_model (listmodel);
			view.insert_column_with_attributes (-1, "thumbnail", new CellRendererPixbuf (), "pixbuf", 0);
			view.insert_column_with_attributes (-1, "filename", new CellRendererText (), "text", 1);
			view.insert_column_with_attributes (-1, "tags", new CellRendererText (), "text", 2);

			view.row_activated.connect((path,  col) => {
					//var index = int.parse(path.to_string());
					//var item = list.nth_data(index);
					TreeIter iter;
					catalog.get_iter(out iter, path);
					
					Value val1;
					catalog.get_value (iter, 1, out val1);

					string file_url = (string)val1;

					originals.storeLocal(file_url);
				});
			
			scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
			scroll.add (view);
			
			catalog = listmodel;
		}
	
		{
			var button = new Gtk.Button.with_label ("Download");
		
			box_c.pack_end (button, false);
		}

		box_a.pack_start (box_b, false);
		box_a.pack_start (scroll);
		box_a.pack_end (box_c, false);
	
		add (box_a);
	}

	string process_search(string s) {
		try {
			var r = / /;
			var o = r.replace (s, -1, 0, "+");
			return o;
		} catch(RegexError r) {
			print("WARNING: Regex Error!");
			return "";
		}
	}

	async void perform_search(string tags) {
		string url = "http://safebooru.org/index.php?page=dapi&s=post&q=index&limit=20&tags=" + tags;

		//print(url);
		//print("!!!");
		
		Soup.Session session = new Soup.Session(); // TODO should we create a soup session every time or just once?
		Soup.Message message = new Soup.Message ("GET", url);
		session.send_message(message);

		try {
			Xml.Doc* doc = Parser.parse_memory ((string) message.response_body.data, (int) message.response_body.length);
			if(doc==null) { print("failed to read the .xml file\n"); throw new XPathFailed.CODE_1A(""); }
			
			try {
				Context ctx = new Context(doc);
				if(ctx==null) { print("failed to create the xpath context\n"); throw new XPathFailed.CODE_1A(""); }

				try {
					Xml.XPath.Object* obj = ctx.eval_expression("/posts/post");
					if(obj==null) { print("failed to evaluate xpath\n"); throw new XPathFailed.CODE_1A(""); }

					if(obj->nodesetval != null) {
						yield process_search_results(obj->nodesetval);
					}
					
					delete obj;
				}
				catch(XPathFailed e) {}
			}
			catch(XPathFailed e) {}
			
			delete doc;
		}
		catch(XPathFailed e) {}
	}
	
	async void process_search_results(NodeSet* nodes) {
		int i;

		catalog.clear();
		
		for (i = 0; nodes != null && i < nodes->length(); i++) {
			Xml.Node* node = null;
			if ( nodes->item(0) != null ) {
				node = nodes->item(i);
				print("Found the node we want");
			} else {
				print("failed to find the expected node");
			}
			Xml.Attr* attr = null;
			attr = node->properties;

			Post p = Post();
			
			print("Node attributes:\n");
			while ( attr != null )
			{
				print("Attribute: \tname: %s\tvalue: %s\n", attr->name, attr->children->content);
				
				if(attr->name == "preview_url") {
					p.preview_url = attr->children->content;
				} else if(attr->name == "file_url") {
					p.file_url = attr->children->content;
				} else if(attr->name == "tags") {
					p.tags = attr->children->content;
				}
				
				attr = attr->next;
			}
			print("\n\n");
			
			// hopefully post is fully populated
			// TODO Handle the case where its not
			
			p.preview_image = yield thumbnails.store_local_async(p.preview_url);
			
			// Add it to the list view
			TreeIter iter;
			catalog.append (out iter);
			catalog.set (iter, 0, p.preview_image.pixbuf, 1, p.file_url, 2, p.tags);
		}
	}
}

public class ImageStorer : GLib.Object {
	string store;
	
	public ImageStorer (string store) {
		this.store = store;
		if(GLib.DirUtils.create_with_parents (store, 0777) == -1) {
			print ("ImageStorer could not set up a directory");
		}
	}

		private string split_filename_off_url(string url) {
		try {
			var r = new Regex("/");
			var o = r.split (url);
			return o[o.length-1];
		} catch(RegexError r) {
			print("WARNING: Regex Error!");
			return "tmp.jpg";
		}
	}

	public Gtk.Image storeLocal(string url) {
		Soup.Session session = new Soup.Session();
		Soup.Message message = new Soup.Message ("GET", url);
		session.send_message(message);

		var name = split_filename_off_url(url);
		var dest_name = store + "/" + name;

		if(!FileUtils.test (dest_name, FileTest.EXISTS)) {
			
			var file = File.new_for_path (dest_name);
			
			{
				// Create a new file with this name
				var file_stream = file.create (FileCreateFlags.NONE);
				
				// Test for the existence of file
				if (file.query_exists ()) {
					stdout.printf ("File successfully created.\n");
				}
				
				// Write text data to file
				var data_stream = new DataOutputStream (file_stream);
				data_stream.write (message.response_body.data);
			} // Streams closed at this point
			
		}

		
		var i = new Gtk.Image ();
		i.set_from_file(dest_name);
		return i;
	}
	
	public async Gtk.Image store_local_async(string url) {
		SourceFunc callback = store_local_async.callback;
		
		Soup.Session session = new Soup.Session();
		Soup.Message message = new Soup.Message ("GET", url);
		//session.send_message(message);
		
		var name = split_filename_off_url(url);
		var dest_name = store + "/" + name;

		if(!FileUtils.test (dest_name, FileTest.EXISTS)) {
			
			//print("QUEING MESSAGE");
			session.queue_message (message, (sess, mess) => {
					// Process the result:
					stdout.printf ("Status Code: %u\n", mess.status_code);
					stdout.printf ("Message length: %lld\n", mess.response_body.length);
					stdout.printf ("Data: \n%s\n", (string) mess.response_body.data);
					
					message = mess;
					Idle.add((owned) callback);
				});
			
			//print("ok but waiting");
			
			// https://wiki.gnome.org/Projects/Vala/AsyncSamples
			// Wait for background thread to schedule our callback
			yield;
			//print("cool got it");
			
			var file = File.new_for_path (dest_name);
			
			{
				// Create a new file with this name
				var file_stream = file.create (FileCreateFlags.NONE);
				
				// Test for the existence of file
				if (file.query_exists ()) {
					stdout.printf ("File successfully created.\n");
				}
				
				// Write text data to file
				// TODO
				var data_stream = new DataOutputStream (file_stream);
				yield data_stream.write_async (message.response_body.data);
			} // Streams closed at this point
			
		}
		

		
		// var web_image = File.new_for_uri (url) ;
		// string dest_name = store + "/" + web_image.get_basename ();
		// if(!FileUtils.test (dest_name, FileTest.EXISTS)) {
		// 	var destination = File.new_for_path (dest_name);
		// 	try {
		// 		web_image.copy (destination, FileCopyFlags.NONE);
		// 	} catch(Error e) {
		// 		error("I couldn't store the image! [" + store + " - " + url + "]");
		// 	}
		// }
		
		// return dest_name;
		
		var i = new Gtk.Image ();
		i.set_from_file(dest_name);
		return i;
	}
}

void main (string[] args) {
	Gtk.init (ref args);
	new Uru().show_all ();
	Gtk.main ();
}
