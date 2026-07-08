namespace RDPConnect {

const string APP_ID = "com.example.RDPConnect";

const string[] RESOLUTION_PRESETS = {
    "2560x1600", "2560x1440", "1920x1200", "1920x1080",
    "1600x900", "1440x900", "1366x768", "1280x800", "1024x768",
};

const string[] MODE_IDS = { "fixed", "dynamic", "scale" };
const string[] MODE_LABELS = { "Fixed size", "Dynamic resolution", "Scale to fit" };

const string[] SCALE_PRESETS        = { "100", "125", "150", "175", "200", "Custom" };
const string[] SCALE_LABELS         = { "100 %", "125 %", "150 %", "175 %", "200 %", "Custom..." };
const string[] SERVER_SCALE_PRESETS = { "100", "125", "150", "175", "200", "225", "250", "Custom" };
const string[] SERVER_SCALE_LABELS  = {
    "Off (100 %)", "125 %", "150 %", "175 %", "200 %", "225 %", "250 %", "Custom...",
};

class Connection : Object {
    public string host = "";
    public string username = "";
    public string password = "";
    public string domain = "";

    public string resolution = "Fullscreen";
    public string custom_resolution = "1920x1200";
    public string display_mode = "dynamic";
    public string client_scale = "100";
    public string custom_scale = "150";
    public string server_scale = "100";
    public string custom_server_scale = "150";
    public bool multi_monitor = false;

    public bool ignore_cert = true;
    public bool clipboard = true;
    public bool audio = true;
    public bool microphone = false;
    public bool drive_redirect = false;

    public string extra_args = "";

    private static string js (Json.Object o, string key, string dflt) {
        if (o.has_member (key)) {
            var n = o.get_member (key);
            if (n.get_node_type () == Json.NodeType.VALUE
                && n.get_value_type () == typeof (string))
                return n.get_string ();
        }
        return dflt;
    }

    private static bool jb (Json.Object o, string key, bool dflt) {
        if (o.has_member (key)) {
            var n = o.get_member (key);
            if (n.get_node_type () == Json.NodeType.VALUE
                && n.get_value_type () == typeof (bool))
                return n.get_boolean ();
        }
        return dflt;
    }

    private static string j_scale (Json.Object o, string key, string dflt) {
        if (o.has_member (key)) {
            var n = o.get_member (key);
            if (n.get_node_type () == Json.NodeType.VALUE) {
                var t = n.get_value_type ();
                if (t == typeof (string)) return n.get_string ();
                if (t == typeof (int64))  return n.get_int ().to_string ();
            }
        }
        return dflt;
    }

    private static bool in_list (string[] arr, string v) {
        foreach (var s in arr) if (s == v) return true;
        return false;
    }

    public static int percent (string value, string custom) {
        var raw = (value == "Custom" ? custom : value).replace ("%", "").strip ();
        var v = int.parse (raw);
        if (v <= 0) v = 100;
        return int.min (int.max (v, 50), 500);
    }

    public int scale_percent () { return percent (client_scale, custom_scale); }
    public double scale_factor () { return scale_percent () / 100.0; }
    public int server_scale_percent () { return percent (server_scale, custom_server_scale); }

    public static bool parse_size (string s, out int w, out int h) {
        w = 0; h = 0;
        string[] parts = {};
        foreach (var p in s.down ().replace ("×", "x").split_set ("x ")) {
            var t = p.strip ();
            if (t != "") parts += t;
        }
        if (parts.length != 2) return false;
        w = int.parse (parts[0]);
        h = int.parse (parts[1]);
        return w > 0 && h > 0;
    }

    private static int gcd (int a, int b) { return b == 0 ? a : gcd (b, a % b); }

    public static string aspect_ratio (int w, int h) {
        var g = int.max (gcd (w, h), 1);
        int rw = w / g, rh = h / g;
        switch (@"$(rw):$(rh)") {
            case "16:9":                       return "16:9";
            case "8:5":   case "16:10":        return "16:10";
            case "4:3":                        return "4:3";
            case "5:4":                        return "5:4";
            case "3:2":                        return "3:2";
            case "1:1":                        return "1:1";
            case "43:18": case "64:27":
            case "12:5":  case "21:9":         return "21:9";
        }
        if (rw <= 24 && rh <= 24) return @"$(rw):$(rh)";
        double r = (double) w / (double) h;
        return r >= 1 ? "%.2f:1".printf (r) : "1:%.2f".printf (1 / r);
    }

    private static int even (int n) { return int.max (n - (n % 2), 2); }

    public static Connection from_json (Json.Object o) {
        var c = new Connection ();
        c.host = js (o, "host", c.host);
        var old_port = js (o, "port", "");
        if (old_port != "" && old_port != "3389" && !c.host.contains (":"))
            c.host = @"$(c.host):$old_port";
        c.username = js (o, "username", c.username);
        c.domain = js (o, "domain", c.domain);

        var saved_res = js (o, "resolution", c.resolution);
        if (saved_res == "Fullscreen" || saved_res == "Custom"
            || in_list (RESOLUTION_PRESETS, saved_res)) {
            c.resolution = saved_res;
            c.custom_resolution = js (o, "custom_resolution", c.custom_resolution);
        } else {
            c.resolution = "Custom";
            c.custom_resolution = saved_res;
        }

        c.display_mode = js (o, "display_mode", c.display_mode);

        c.client_scale = j_scale (o, "client_scale", j_scale (o, "scale", c.client_scale));
        c.custom_scale = js (o, "custom_scale", c.custom_scale);
        c.server_scale = j_scale (o, "server_scale", c.server_scale);
        c.custom_server_scale = js (o, "custom_server_scale", c.custom_server_scale);

        c.extra_args = js (o, "extra_args", c.extra_args);
        c.multi_monitor = jb (o, "multi_monitor", c.multi_monitor);
        c.ignore_cert = jb (o, "ignore_cert", c.ignore_cert);
        c.clipboard = jb (o, "clipboard", c.clipboard);
        c.audio = jb (o, "audio", c.audio);
        c.microphone = jb (o, "microphone", c.microphone);
        c.drive_redirect = jb (o, "drive_redirect", c.drive_redirect);

        if (c.display_mode == "scale-server") {
            c.display_mode = "fixed";
            if (c.server_scale == "100" && c.client_scale != "100")
                c.server_scale = c.client_scale;
            c.client_scale = "100";
        }

        if (!in_list (SCALE_PRESETS, c.client_scale)) {
            c.custom_scale = c.client_scale;
            c.client_scale = "Custom";
        }
        if (!in_list (SERVER_SCALE_PRESETS, c.server_scale)) {
            c.custom_server_scale = c.server_scale;
            c.server_scale = "Custom";
        }

        var valid = false;
        foreach (var m in MODE_IDS)
            if (m == c.display_mode) valid = true;
        if (!valid) c.display_mode = "dynamic";
        return c;
    }

    public void to_json (Json.Builder b) {
        b.begin_object ();
        b.set_member_name ("host");                b.add_string_value (host);
        b.set_member_name ("username");            b.add_string_value (username);
        b.set_member_name ("domain");              b.add_string_value (domain);
        b.set_member_name ("resolution");          b.add_string_value (resolution);
        b.set_member_name ("custom_resolution");   b.add_string_value (custom_resolution);
        b.set_member_name ("display_mode");        b.add_string_value (display_mode);
        b.set_member_name ("client_scale");        b.add_string_value (client_scale);
        b.set_member_name ("custom_scale");        b.add_string_value (custom_scale);
        b.set_member_name ("server_scale");        b.add_string_value (server_scale);
        b.set_member_name ("custom_server_scale"); b.add_string_value (custom_server_scale);
        b.set_member_name ("extra_args");          b.add_string_value (extra_args);
        b.set_member_name ("multi_monitor");       b.add_boolean_value (multi_monitor);
        b.set_member_name ("ignore_cert");         b.add_boolean_value (ignore_cert);
        b.set_member_name ("clipboard");           b.add_boolean_value (clipboard);
        b.set_member_name ("audio");               b.add_boolean_value (audio);
        b.set_member_name ("microphone");          b.add_boolean_value (microphone);
        b.set_member_name ("drive_redirect");      b.add_boolean_value (drive_redirect);
        b.end_object ();
    }

    public string[]? build_arguments (out string? error,
                                      int screen_w = 0, int screen_h = 0) {
        error = null;
        var h = host.strip ();
        if (h == "") {
            error = "Server address is required.";
            return null;
        }

        string[] args = {};
        args += @"/v:$h";

        var user = username.strip ();
        if (user != "") args += @"/u:$user";
        var dom = domain.strip ();
        if (dom != "") args += @"/d:$dom";
        if (password != "") args += @"/p:$password";

        var fullscreen = (resolution == "Fullscreen");
        int bw = 0, bh = 0;
        var have_base = false;
        if (fullscreen) {
            if (screen_w > 0 && screen_h > 0) { bw = screen_w; bh = screen_h; have_base = true; }
        } else {
            var size_str = (resolution == "Custom") ? custom_resolution : resolution;
            if (!parse_size (size_str, out bw, out bh)) {
                error = @"Invalid resolution '$size_str'. Use WIDTHxHEIGHT, e.g. 1920x1200.";
                return null;
            }
            have_base = true;
        }

        switch (display_mode) {
        case "scale":
            if (fullscreen) args += "/f";
            else if (have_base) { args += @"/w:$(even (bw))"; args += @"/h:$(even (bh))"; }
            if (have_base) {
                var factor = scale_factor ();
                var sw = even (int.max ((int) (bw / factor + 0.5), 320));
                var sh = even (int.max ((int) (bh / factor + 0.5), 240));
                args += @"/smart-sizing:$(sw)x$(sh)";
            } else {
                args += "/smart-sizing";
            }
            break;
        case "dynamic":
            if (fullscreen) args += "/f";
            else if (have_base) { args += @"/w:$(even (bw))"; args += @"/h:$(even (bh))"; }
            args += "/dynamic-resolution";
            break;
        default:
            if (fullscreen) args += "/f";
            else if (have_base) { args += @"/w:$(even (bw))"; args += @"/h:$(even (bh))"; }
            break;
        }

        var spct = server_scale_percent ();
        if (spct != 100) args += @"/scale-desktop:$(int.min (int.max (spct, 100), 500))";
        if (multi_monitor) args += "/multimon";

        if (ignore_cert) args += "/cert:ignore";
        if (clipboard) args += "+clipboard";
        if (audio) args += "/sound";
        if (microphone) args += "/microphone";
        if (drive_redirect) args += @"/drive:home,$(Environment.get_home_dir ())";

        foreach (var tok in extra_args.split_set (" \t\n"))
            if (tok != "") args += tok;

        return args;
    }
}

class Favorite : Object {
    public string id = Uuid.string_random ();
    public string name = "";
    public Connection conn = new Connection ();
}

namespace Keyring {
    private Secret.Schema? _schema = null;

    private unowned Secret.Schema schema () {
        if (_schema == null)
            _schema = new Secret.Schema (APP_ID, Secret.SchemaFlags.NONE,
                                         "uuid", Secret.SchemaAttributeType.STRING);
        return _schema;
    }

    public void store (string id, string password) {
        try {
            Secret.password_clear_sync (schema (), null, "uuid", id);
            if (password != "")
                Secret.password_store_sync (schema (), Secret.COLLECTION_DEFAULT,
                                            @"RDPConnect: $id", password, null,
                                            "uuid", id);
        } catch (Error e) {
            warning ("keyring: %s", e.message);
        }
    }

    public string lookup (string id) {
        try {
            return Secret.password_lookup_sync (schema (), null, "uuid", id) ?? "";
        } catch (Error e) {
            return "";
        }
    }

    public void remove (string id) {
        try {
            Secret.password_clear_sync (schema (), null, "uuid", id);
        } catch (Error e) {
        }
    }
}

string? find_binary () {
    foreach (var name in new string[] { "sdl-freerdp", "sdl-freerdp3" }) {
        var path = Environment.find_program_in_path (name);
        if (path != null) return path;
    }
    foreach (var path in new string[] {
        "/opt/homebrew/bin/sdl-freerdp", "/usr/local/bin/sdl-freerdp",
        "/opt/homebrew/bin/sdl-freerdp3", "/usr/bin/sdl-freerdp" })
        if (FileUtils.test (path, FileTest.IS_EXECUTABLE)) return path;
    return null;
}

string store_path () {
    var dir = Path.build_filename (Environment.get_user_data_dir (), "RDPConnect");
    DirUtils.create_with_parents (dir, 0755);
    return Path.build_filename (dir, "favorites.json");
}

string last_path () {
    var dir = Path.build_filename (Environment.get_user_data_dir (), "RDPConnect");
    DirUtils.create_with_parents (dir, 0755);
    return Path.build_filename (dir, "last.json");
}

const string LAST_KEYRING_ID = "last-connection";

uint index_of (string[] arr, string value, uint dflt) {
    for (int i = 0; i < arr.length; i++)
        if (arr[i] == value) return (uint) i;
    return dflt;
}

Gtk.StringList string_list (string[] items) {
    var list = new Gtk.StringList (null);
    foreach (var s in items) list.append (s);
    return list;
}

class LogWindow : Adw.Window {
    private Gtk.TextView view;

    public LogWindow (Gtk.TextBuffer buffer) {
        Object (title: "Log", default_width: 560, default_height: 360,
                hide_on_close: true);

        view = new Gtk.TextView.with_buffer (buffer);
        view.editable = false;
        view.monospace = true;
        view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
        view.left_margin = 8;
        view.right_margin = 8;
        view.top_margin = 8;
        view.bottom_margin = 8;

        var scroll = new Gtk.ScrolledWindow ();
        scroll.child = view;
        scroll.vexpand = true;

        var clear = new Gtk.Button.with_label ("Clear");
        clear.halign = Gtk.Align.END;
        clear.margin_top = 8;
        clear.margin_bottom = 8;
        clear.margin_end = 8;
        clear.clicked.connect (() => { buffer.text = ""; });

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (scroll);
        box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        box.append (clear);

        var toolbar = new Adw.ToolbarView ();
        toolbar.content = box;
        toolbar.add_top_bar (new Adw.HeaderBar ());
        content = toolbar;
    }

    public void scroll_to_end () {
        var buf = view.buffer;
        Gtk.TextIter end;
        buf.get_end_iter (out end);
        var mark = buf.create_mark (null, end, false);
        view.scroll_to_mark (mark, 0.0, false, 0.0, 1.0);
        buf.delete_mark (mark);
    }
}

class MainWindow : Adw.ApplicationWindow {
    private string? binary;
    private Favorite[] favorites = {};
    private string? selected_id = null;
    private Subprocess? process = null;

    private Gtk.TextBuffer log_buffer = new Gtk.TextBuffer (null);
    private LogWindow? log_window = null;

    private Adw.EntryRow row_host;
    private Adw.EntryRow row_user;
    private Adw.PasswordEntryRow row_pass;
    private Adw.ComboRow row_resolution;
    private string[] resolution_values;
    private Adw.EntryRow row_custom_res;
    private Gtk.Label aspect_label;
    private Adw.ComboRow row_mode;
    private Adw.ComboRow row_scale;
    private Adw.EntryRow row_custom_scale;
    private Adw.ComboRow row_server_scale;
    private Adw.EntryRow row_custom_server_scale;
    private Adw.EntryRow row_domain;
    private Adw.SwitchRow sw_multimon;
    private Adw.SwitchRow sw_cert;
    private Adw.SwitchRow sw_clipboard;
    private Adw.SwitchRow sw_audio;
    private Adw.SwitchRow sw_mic;
    private Adw.SwitchRow sw_drive;
    private Adw.EntryRow row_extra;

    private Adw.WindowTitle window_title;
    private Gtk.MenuButton fav_button;
    private Gtk.Label status_label;
    private Gtk.Button btn_connect;
    private SimpleAction delete_action;

    public MainWindow (Adw.Application app) {
        Object (application: app, title: "RDPConnect",
                default_width: 440, default_height: 640);

        binary = find_binary ();
        build_ui ();
        install_actions ();
        load_favorites ();
        load_last ();
        rebuild_favorites_menu ();
        set_status (binary != null ? "Ready." : "sdl-freerdp not found.");
    }

    private static Adw.SwitchRow make_switch (string title, bool active) {
        var row = new Adw.SwitchRow ();
        row.title = title;
        row.active = active;
        return row;
    }

    private void build_ui () {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        page.margin_top = 24;
        page.margin_bottom = 24;
        page.margin_start = 16;
        page.margin_end = 16;

        var conn_group = new Adw.PreferencesGroup ();
        conn_group.title = "Connection";
        row_host = new Adw.EntryRow ();
        row_host.title = "Server (host:port)";
        row_user = new Adw.EntryRow ();
        row_user.title = "Username";
        row_pass = new Adw.PasswordEntryRow ();
        row_pass.title = "Password";
        row_host.activates_default = true;
        row_user.activates_default = true;
        row_pass.activates_default = true;
        conn_group.add (row_host);
        conn_group.add (row_user);
        conn_group.add (row_pass);
        page.append (conn_group);

        var disp_group = new Adw.PreferencesGroup ();
        disp_group.title = "Display";

        row_resolution = new Adw.ComboRow ();
        row_resolution.title = "Resolution";
        string[] res_values = { "Fullscreen" };
        string[] res_labels = { "Fullscreen" };
        foreach (var p in RESOLUTION_PRESETS) { res_values += p; res_labels += p; }
        res_values += "Custom";
        res_labels += "Custom...";
        resolution_values = res_values;
        row_resolution.model = string_list (res_labels);
        row_resolution.selected = 0;

        row_custom_res = new Adw.EntryRow ();
        row_custom_res.title = "Custom size (WxH)";
        row_custom_res.text = "1920x1200";
        aspect_label = new Gtk.Label ("");
        aspect_label.add_css_class ("dim-label");
        aspect_label.add_css_class ("caption");
        row_custom_res.add_suffix (aspect_label);

        row_mode = new Adw.ComboRow ();
        row_mode.title = "Mode";
        row_mode.model = string_list (MODE_LABELS);
        row_mode.selected = 1;

        row_scale = new Adw.ComboRow ();
        row_scale.title = "Client-side scale";
        row_scale.model = string_list (SCALE_LABELS);
        row_scale.selected = 0;

        row_custom_scale = new Adw.EntryRow ();
        row_custom_scale.title = "Client scale %";
        row_custom_scale.text = "150";

        row_server_scale = new Adw.ComboRow ();
        row_server_scale.title = "Server-side scale";
        row_server_scale.model = string_list (SERVER_SCALE_LABELS);
        row_server_scale.selected = 0;

        row_custom_server_scale = new Adw.EntryRow ();
        row_custom_server_scale.title = "Server scale %";
        row_custom_server_scale.text = "150";

        row_resolution.notify["selected"].connect (update_display_rows);
        row_mode.notify["selected"].connect (update_display_rows);
        row_scale.notify["selected"].connect (update_display_rows);
        row_server_scale.notify["selected"].connect (update_display_rows);
        row_custom_res.changed.connect (update_aspect);

        disp_group.add (row_resolution);
        disp_group.add (row_custom_res);
        disp_group.add (row_mode);
        disp_group.add (row_scale);
        disp_group.add (row_custom_scale);
        disp_group.add (row_server_scale);
        disp_group.add (row_custom_server_scale);
        page.append (disp_group);
        update_display_rows ();

        var opt_group = new Adw.PreferencesGroup ();
        opt_group.title = "Options";
        row_domain = new Adw.EntryRow ();
        row_domain.title = "Domain";
        sw_multimon = make_switch ("Use all monitors", false);
        sw_cert = make_switch ("Ignore certificate", true);
        sw_clipboard = make_switch ("Share clipboard", true);
        sw_audio = make_switch ("Forward audio", true);
        sw_mic = make_switch ("Forward microphone", false);
        sw_drive = make_switch ("Share home folder", false);
        row_extra = new Adw.EntryRow ();
        row_extra.title = "Extra arguments (e.g. /gfx /rfx)";
        opt_group.add (row_domain);
        opt_group.add (sw_multimon);
        opt_group.add (sw_cert);
        opt_group.add (sw_clipboard);
        opt_group.add (sw_audio);
        opt_group.add (sw_mic);
        opt_group.add (sw_drive);
        opt_group.add (row_extra);
        page.append (opt_group);

        var clamp = new Adw.Clamp ();
        clamp.child = page;
        clamp.maximum_size = 520;
        var scroll = new Gtk.ScrolledWindow ();
        scroll.child = clamp;
        scroll.vexpand = true;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        status_label = new Gtk.Label ("");
        status_label.xalign = 0;
        status_label.hexpand = true;
        status_label.ellipsize = Pango.EllipsizeMode.END;
        status_label.add_css_class ("dim-label");
        status_label.add_css_class ("caption");

        var btn_log = new Gtk.Button.from_icon_name ("utilities-terminal-symbolic");
        btn_log.tooltip_text = "Show log";
        btn_log.add_css_class ("flat");
        btn_log.clicked.connect (() => { show_log (); });

        btn_connect = new Gtk.Button.with_label ("Connect");
        btn_connect.add_css_class ("suggested-action");
        btn_connect.clicked.connect (() => { connect_clicked (); });

        var bottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        bottom.margin_top = 10;
        bottom.margin_bottom = 10;
        bottom.margin_start = 16;
        bottom.margin_end = 16;
        bottom.append (status_label);
        bottom.append (btn_log);
        bottom.append (btn_connect);

        window_title = new Adw.WindowTitle ("RDPConnect", "");
        var header = new Adw.HeaderBar ();
        header.title_widget = window_title;
        fav_button = new Gtk.MenuButton ();
        fav_button.icon_name = "user-bookmarks-symbolic";
        fav_button.tooltip_text = "Favorites";
        header.pack_start (fav_button);

        var view = new Adw.ToolbarView ();
        view.content = scroll;
        view.add_top_bar (header);
        view.add_bottom_bar (bottom);
        content = view;
        default_widget = btn_connect;
    }

    private void update_display_rows () {
        row_custom_res.visible = (resolution_values[row_resolution.selected] == "Custom");

        var mode = MODE_IDS[row_mode.selected];
        row_scale.visible = (mode == "scale");
        row_custom_scale.visible = row_scale.visible
            && SCALE_PRESETS[row_scale.selected] == "Custom";
        row_custom_server_scale.visible =
            SERVER_SCALE_PRESETS[row_server_scale.selected] == "Custom";

        update_aspect ();
    }

    private void update_aspect () {
        int w = 0, h = 0;
        if (row_custom_res.visible && Connection.parse_size (row_custom_res.text, out w, out h))
            aspect_label.label = Connection.aspect_ratio (w, h);
        else
            aspect_label.label = "";
    }

    private void install_actions () {
        var load = new SimpleAction ("load-favorite", VariantType.STRING);
        load.activate.connect ((a, param) => { load_favorite (param.get_string ()); });
        add_action (load);

        var nc = new SimpleAction ("new-connection", null);
        nc.activate.connect ((a, param) => { new_connection (); });
        add_action (nc);

        var save = new SimpleAction ("save-favorite", null);
        save.activate.connect ((a, param) => { save_clicked (); });
        add_action (save);

        delete_action = new SimpleAction ("delete-favorite", null);
        delete_action.activate.connect ((a, param) => { delete_clicked (); });
        delete_action.set_enabled (false);
        add_action (delete_action);
    }

    private Connection form_to_conn () {
        var c = new Connection ();
        c.host = row_host.text;
        c.username = row_user.text;
        c.password = row_pass.text;
        c.domain = row_domain.text;
        c.resolution = resolution_values[row_resolution.selected];
        c.custom_resolution = row_custom_res.text;
        c.display_mode = MODE_IDS[row_mode.selected];
        c.client_scale = SCALE_PRESETS[row_scale.selected];
        c.custom_scale = row_custom_scale.text;
        c.server_scale = SERVER_SCALE_PRESETS[row_server_scale.selected];
        c.custom_server_scale = row_custom_server_scale.text;
        c.multi_monitor = sw_multimon.active;
        c.ignore_cert = sw_cert.active;
        c.clipboard = sw_clipboard.active;
        c.audio = sw_audio.active;
        c.microphone = sw_mic.active;
        c.drive_redirect = sw_drive.active;
        c.extra_args = row_extra.text;
        return c;
    }

    private void conn_to_form (Connection c) {
        row_host.text = c.host;
        row_user.text = c.username;
        row_pass.text = c.password;
        row_domain.text = c.domain;
        row_resolution.selected = index_of (resolution_values, c.resolution, 0);
        row_custom_res.text = c.custom_resolution;
        row_mode.selected = index_of (MODE_IDS, c.display_mode, 1);
        row_scale.selected = index_of (SCALE_PRESETS, c.client_scale, 0);
        row_custom_scale.text = c.custom_scale;
        row_server_scale.selected = index_of (SERVER_SCALE_PRESETS, c.server_scale, 0);
        row_custom_server_scale.text = c.custom_server_scale;
        sw_multimon.active = c.multi_monitor;
        sw_cert.active = c.ignore_cert;
        sw_clipboard.active = c.clipboard;
        sw_audio.active = c.audio;
        sw_mic.active = c.microphone;
        sw_drive.active = c.drive_redirect;
        row_extra.text = c.extra_args;
        update_display_rows ();
    }

    private Favorite? find_favorite (string? id) {
        if (id == null) return null;
        foreach (var f in favorites)
            if (f.id == id) return f;
        return null;
    }

    private void load_favorites () {
        var parser = new Json.Parser ();
        try {
            parser.load_from_file (store_path ());
        } catch (Error e) {
            return;
        }
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.ARRAY) return;
        root.get_array ().foreach_element ((arr, i, node) => {
            if (node.get_node_type () != Json.NodeType.OBJECT) return;
            var o = node.get_object ();
            if (!o.has_member ("name")) return;
            var fav = new Favorite ();
            fav.name = o.get_string_member_with_default ("name", "");
            if (fav.name == "") return;
            var id = o.get_string_member_with_default ("id", "");
            if (id != "") fav.id = id;
            if (o.has_member ("conn")
                && o.get_member ("conn").get_node_type () == Json.NodeType.OBJECT)
                fav.conn = Connection.from_json (o.get_object_member ("conn"));
            favorites += fav;
        });
    }

    private void persist_favorites () {
        var b = new Json.Builder ();
        b.begin_array ();
        foreach (var f in favorites) {
            b.begin_object ();
            b.set_member_name ("id");
            b.add_string_value (f.id);
            b.set_member_name ("name");
            b.add_string_value (f.name);
            b.set_member_name ("conn");
            f.conn.to_json (b);
            b.end_object ();
        }
        b.end_array ();

        var gen = new Json.Generator ();
        gen.root = b.get_root ();
        gen.pretty = true;
        try {
            gen.to_file (store_path ());
        } catch (Error e) {
            set_status (@"Could not save favorites: $(e.message)");
        }
    }

    private void sort_favorites () {
        for (int i = 1; i < favorites.length; i++) {
            var f = favorites[i];
            int j = i - 1;
            while (j >= 0
                   && favorites[j].name.casefold ().collate (f.name.casefold ()) > 0) {
                favorites[j + 1] = favorites[j];
                j--;
            }
            favorites[j + 1] = f;
        }
    }

    private void rebuild_favorites_menu () {
        var selected = find_favorite (selected_id);

        var menu = new GLib.Menu ();
        if (favorites.length > 0) {
            var section = new GLib.Menu ();
            foreach (var fav in favorites) {
                var item = new GLib.MenuItem (fav.name, null);
                item.set_action_and_target_value ("win.load-favorite",
                                                  new Variant.string (fav.id));
                section.append_item (item);
            }
            menu.append_section (null, section);
        }
        var actions = new GLib.Menu ();
        actions.append ("New Connection", "win.new-connection");
        actions.append ("Save as Favorite...", "win.save-favorite");
        if (selected != null)
            actions.append (@"Delete '$(selected.name)'", "win.delete-favorite");
        menu.append_section (null, actions);

        delete_action.set_enabled (selected != null);
        fav_button.menu_model = menu;
        window_title.subtitle = selected != null ? selected.name : "";
    }

    private void load_favorite (string id) {
        var fav = find_favorite (id);
        if (fav == null) return;
        var c = fav.conn;
        c.password = Keyring.lookup (fav.id);
        selected_id = fav.id;
        conn_to_form (c);
        rebuild_favorites_menu ();
        set_status (@"Loaded '$(fav.name)'.");
    }

    private void new_connection () {
        selected_id = null;
        conn_to_form (new Connection ());
        rebuild_favorites_menu ();
        set_status ("New connection.");
    }

    private void save_clicked () {
        var selected = find_favorite (selected_id);
        var dflt = selected != null ? selected.name : row_host.text.strip ();

        var dialog = new Adw.AlertDialog ("Save Favorite", null);
        var entry = new Gtk.Entry ();
        entry.text = dflt;
        entry.activates_default = true;
        entry.placeholder_text = "Name";
        dialog.extra_child = entry;
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("save", "Save");
        dialog.set_response_appearance ("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.default_response = "save";
        dialog.close_response = "cancel";
        dialog.choose.begin (this, null, (obj, res) => {
            if (dialog.choose.end (res) != "save") return;
            save_favorite (entry.text.strip ());
        });
    }

    private void save_favorite (string name) {
        if (name == "") return;
        var conn = form_to_conn ();
        var password = conn.password;
        conn.password = "";

        var fav = null as Favorite;
        foreach (var f in favorites)
            if (f.name == name) { fav = f; break; }
        if (fav != null) {
            fav.conn = conn;
        } else {
            fav = new Favorite ();
            fav.name = name;
            fav.conn = conn;
            favorites += fav;
        }
        Keyring.store (fav.id, password);
        selected_id = fav.id;
        sort_favorites ();
        persist_favorites ();
        rebuild_favorites_menu ();
        set_status (@"Saved '$name'.");
    }

    private void delete_clicked () {
        var fav = find_favorite (selected_id);
        if (fav == null) return;
        Keyring.remove (fav.id);
        Favorite[] kept = {};
        foreach (var f in favorites)
            if (f.id != fav.id) kept += f;
        favorites = kept;
        selected_id = null;
        persist_favorites ();
        rebuild_favorites_menu ();
        set_status (@"Deleted '$(fav.name)'.");
    }

    private void save_last (Connection conn) {
        var b = new Json.Builder ();
        b.begin_object ();
        b.set_member_name ("selected_id");
        b.add_string_value (selected_id ?? "");
        b.set_member_name ("conn");
        conn.to_json (b);
        b.end_object ();

        var gen = new Json.Generator ();
        gen.root = b.get_root ();
        gen.pretty = true;
        try {
            gen.to_file (last_path ());
        } catch (Error e) {
            warning ("last connection: %s", e.message);
        }
        Keyring.store (LAST_KEYRING_ID, conn.password);
    }

    private void load_last () {
        var parser = new Json.Parser ();
        try {
            parser.load_from_file (last_path ());
        } catch (Error e) {
            return;
        }
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return;
        var o = root.get_object ();
        if (!o.has_member ("conn")
            || o.get_member ("conn").get_node_type () != Json.NodeType.OBJECT)
            return;
        var c = Connection.from_json (o.get_object_member ("conn"));
        c.password = Keyring.lookup (LAST_KEYRING_ID);
        var id = o.get_string_member_with_default ("selected_id", "");
        selected_id = find_favorite (id) != null ? id : null;
        conn_to_form (c);
    }

    private void set_status (string text) {
        status_label.label = text;
    }

    private void append_log (string line) {
        Gtk.TextIter end;
        log_buffer.get_end_iter (out end);
        log_buffer.insert (ref end, line + "\n", -1);
        if (log_window != null && log_window.visible)
            log_window.scroll_to_end ();
    }

    private void show_log () {
        if (log_window == null)
            log_window = new LogWindow (log_buffer);
        log_window.present ();
    }

    private void connect_clicked () {
        if (process != null) {
            process.send_signal (Posix.Signal.TERM);
            return;
        }
        if (binary == null) {
            set_status ("sdl-freerdp not found.");
            append_log ("sdl-freerdp not found. Install it with your "
                        + "package manager (e.g. dnf install freerdp).");
            return;
        }
        var conn = form_to_conn ();
        int mon_w, mon_h;
        monitor_pixels (out mon_w, out mon_h);
        string? err;
        var args = conn.build_arguments (out err, mon_w, mon_h);
        if (args == null) {
            set_status (err ?? "Invalid settings.");
            return;
        }
        launch (conn, args);
    }

    private void monitor_pixels (out int w, out int h) {
        w = 0;
        h = 0;
        var surface = get_surface ();
        if (surface == null) return;
        var display = Gdk.Display.get_default ();
        if (display == null) return;
        var mon = display.get_monitor_at_surface (surface);
        if (mon == null) return;
        var geo = mon.get_geometry ();
        w = geo.width * mon.scale_factor;
        h = geo.height * mon.scale_factor;
    }

    private void launch (Connection conn, string[] args) {
        var shown = new StringBuilder ();
        shown.append ((!) binary);
        foreach (var a in args) {
            shown.append_c (' ');
            shown.append (a.has_prefix ("/p:") ? "/p:******" : a);
        }
        append_log (@"run: $(shown.str)");

        string[] argv = { (!) binary };
        foreach (var a in args) argv += a;

        Subprocess proc;
        try {
            var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE
                                                   | SubprocessFlags.STDERR_MERGE);
            proc = launcher.spawnv (argv);
        } catch (Error e) {
            set_status ("Failed to launch.");
            append_log (@"Failed to launch: $(e.message)");
            return;
        }

        process = proc;
        save_last (conn);
        set_connect_state (true);
        set_status (@"Connected to $(conn.host).");

        var stream = new DataInputStream (proc.get_stdout_pipe ());
        read_lines (stream);
        proc.wait_async.begin (null, (obj, res) => {
            try {
                proc.wait_async.end (res);
            } catch (Error e) {
            }
            int code;
            if (proc.get_if_exited ()) code = proc.get_exit_status ();
            else if (proc.get_if_signaled ()) code = -proc.get_term_sig ();
            else code = -1;
            process = null;
            set_connect_state (false);
            set_status (@"Session ended (exit $code).");
            append_log (@"Session ended (exit code $code)");
        });
    }

    private void read_lines (DataInputStream stream) {
        stream.read_line_async.begin (Priority.DEFAULT, null, (obj, res) => {
            string? line;
            try {
                line = stream.read_line_async.end (res);
            } catch (Error e) {
                return;
            }
            if (line == null) return;
            append_log (line.strip ());
            read_lines (stream);
        });
    }

    private void set_connect_state (bool running) {
        if (running) {
            btn_connect.label = "Disconnect";
            btn_connect.remove_css_class ("suggested-action");
            btn_connect.add_css_class ("destructive-action");
        } else {
            btn_connect.label = "Connect";
            btn_connect.remove_css_class ("destructive-action");
            btn_connect.add_css_class ("suggested-action");
        }
    }
}

int main (string[] args) {
    var app = new Adw.Application (APP_ID, ApplicationFlags.DEFAULT_FLAGS);
    app.activate.connect (() => {
        var win = app.active_window;
        if (win == null) win = new MainWindow (app);
        win.present ();
    });
    return app.run (args);
}

}
