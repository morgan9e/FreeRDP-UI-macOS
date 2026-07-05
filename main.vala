namespace RDPConnect {

const string APP_ID = "com.example.RDPConnect";

const string[] RESOLUTION_PRESETS = {
    "Fullscreen", "2560x1440", "1920x1080", "1600x900",
    "1440x900", "1280x800", "1280x720", "1024x768",
};

const string[] MODE_IDS = { "fixed", "dynamic", "scale" };
const string[] MODE_LABELS = { "Fixed size", "Dynamic resolution", "Scale to fit" };

const int[] SCALE_VALUES = { 100, 125, 133, 150, 166, 175, 200 };
const string[] SCALE_LABELS = {
    "100 %", "125 %", "133 %", "150 %", "166 %", "175 %", "200 %",
};

class Connection : Object {
    public string host = "";
    public string username = "";
    public string password = "";
    public string domain = "";

    public string resolution = "1920x1080";
    public string display_mode = "dynamic";
    public int scale = 100;
    public int server_scale = 100;
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

    private static int ji (Json.Object o, string key, int dflt) {
        if (o.has_member (key)) {
            var n = o.get_member (key);
            if (n.get_node_type () == Json.NodeType.VALUE
                && n.get_value_type () == typeof (int64))
                return (int) n.get_int ();
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

    public static Connection from_json (Json.Object o) {
        var c = new Connection ();
        c.host = js (o, "host", c.host);
        var old_port = js (o, "port", "");
        if (old_port != "" && old_port != "3389" && !c.host.contains (":"))
            c.host = @"$(c.host):$old_port";
        c.username = js (o, "username", c.username);
        c.domain = js (o, "domain", c.domain);
        c.resolution = js (o, "resolution", c.resolution);
        c.display_mode = js (o, "display_mode", c.display_mode);
        c.scale = ji (o, "scale", c.scale);
        c.server_scale = ji (o, "server_scale", c.server_scale);
        c.extra_args = js (o, "extra_args", c.extra_args);
        c.multi_monitor = jb (o, "multi_monitor", c.multi_monitor);
        c.ignore_cert = jb (o, "ignore_cert", c.ignore_cert);
        c.clipboard = jb (o, "clipboard", c.clipboard);
        c.audio = jb (o, "audio", c.audio);
        c.microphone = jb (o, "microphone", c.microphone);
        c.drive_redirect = jb (o, "drive_redirect", c.drive_redirect);

        if (c.display_mode == "scale-server") {
            c.display_mode = "fixed";
            if (c.server_scale <= 100) c.server_scale = c.scale;
            c.scale = 100;
        }

        var valid = false;
        foreach (var m in MODE_IDS)
            if (m == c.display_mode) valid = true;
        if (!valid) c.display_mode = "dynamic";
        return c;
    }

    public void to_json (Json.Builder b) {
        b.begin_object ();
        b.set_member_name ("host");          b.add_string_value (host);
        b.set_member_name ("username");      b.add_string_value (username);
        b.set_member_name ("domain");        b.add_string_value (domain);
        b.set_member_name ("resolution");    b.add_string_value (resolution);
        b.set_member_name ("display_mode");  b.add_string_value (display_mode);
        b.set_member_name ("scale");         b.add_int_value (scale);
        b.set_member_name ("server_scale");  b.add_int_value (server_scale);
        b.set_member_name ("extra_args");    b.add_string_value (extra_args);
        b.set_member_name ("multi_monitor"); b.add_boolean_value (multi_monitor);
        b.set_member_name ("ignore_cert");   b.add_boolean_value (ignore_cert);
        b.set_member_name ("clipboard");     b.add_boolean_value (clipboard);
        b.set_member_name ("audio");         b.add_boolean_value (audio);
        b.set_member_name ("microphone");    b.add_boolean_value (microphone);
        b.set_member_name ("drive_redirect"); b.add_boolean_value (drive_redirect);
        b.end_object ();
    }

    private static int session_px (int window_px, int pct) {
        return (window_px * 100 / pct) & ~1;
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

        var cpct = int.max (scale, 100);
        var client_scale = (display_mode == "scale" || resolution == "Fullscreen")
                           && display_mode != "dynamic";
        if (resolution == "Fullscreen") {
            args += "/f";
            if (client_scale) {
                if (cpct > 100 && screen_w > 0 && screen_h > 0)
                    args += @"/smart-sizing:$(session_px (screen_w, cpct))x$(session_px (screen_h, cpct))";
                else if (display_mode == "scale")
                    args += "/smart-sizing";
            }
        } else {
            var parts = resolution.split ("x");
            if (parts.length == 2) {
                var w = int.parse (parts[0]);
                var hh = int.parse (parts[1]);
                args += @"/size:$(w)x$(hh)";
                if (client_scale) {
                    if (cpct > 100)
                        args += @"/smart-sizing:$(session_px (w, cpct))x$(session_px (hh, cpct))";
                    else
                        args += "/smart-sizing";
                }
            }
        }
        if (display_mode == "dynamic") args += "/dynamic-resolution";
        var spct = int.max (server_scale, 100);
        if (spct > 100) args += @"/scale-desktop:$spct";
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

uint index_of_int (int[] arr, int value, uint dflt) {
    for (int i = 0; i < arr.length; i++)
        if (arr[i] == value) return (uint) i;
    return dflt;
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
    private Adw.ComboRow row_mode;
    private Adw.ComboRow row_scale;
    private Adw.ComboRow row_server_scale;
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
        row_resolution.model = new Gtk.StringList (RESOLUTION_PRESETS);
        row_resolution.selected = index_of (RESOLUTION_PRESETS, "1280x800", 0);
        row_mode = new Adw.ComboRow ();
        row_mode.title = "Mode";
        row_mode.model = new Gtk.StringList (MODE_LABELS);
        row_mode.selected = 1;
        row_scale = new Adw.ComboRow ();
        row_scale.title = "Client-side scale";
        row_scale.model = new Gtk.StringList (SCALE_LABELS);
        row_scale.selected = 0;
        row_server_scale = new Adw.ComboRow ();
        row_server_scale.title = "Server-side scale";
        row_server_scale.model = new Gtk.StringList (SCALE_LABELS);
        row_server_scale.selected = 0;
        row_mode.notify["selected"].connect (update_scale_row);
        row_resolution.notify["selected"].connect (update_scale_row);
        disp_group.add (row_resolution);
        disp_group.add (row_mode);
        disp_group.add (row_scale);
        disp_group.add (row_server_scale);
        page.append (disp_group);
        update_scale_row ();

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

    private void update_scale_row () {
        var mode = MODE_IDS[row_mode.selected];
        var fullscreen = RESOLUTION_PRESETS[row_resolution.selected] == "Fullscreen";
        row_scale.visible = (mode == "scale" || fullscreen) && mode != "dynamic";
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
        c.resolution = RESOLUTION_PRESETS[row_resolution.selected];
        c.display_mode = MODE_IDS[row_mode.selected];
        c.scale = SCALE_VALUES[row_scale.selected];
        c.server_scale = SCALE_VALUES[row_server_scale.selected];
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
        row_resolution.selected = index_of (RESOLUTION_PRESETS, c.resolution,
                                            index_of (RESOLUTION_PRESETS, "1280x800", 0));
        row_mode.selected = index_of (MODE_IDS, c.display_mode, 1);
        row_scale.selected = index_of_int (SCALE_VALUES, c.scale, 0);
        row_server_scale.selected = index_of_int (SCALE_VALUES, c.server_scale, 0);
        sw_multimon.active = c.multi_monitor;
        sw_cert.active = c.ignore_cert;
        sw_clipboard.active = c.clipboard;
        sw_audio.active = c.audio;
        sw_mic.active = c.microphone;
        sw_drive.active = c.drive_redirect;
        row_extra.text = c.extra_args;
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
        actions.append ("Save as Favorite…", "win.save-favorite");
        if (selected != null)
            actions.append (@"Delete “$(selected.name)”", "win.delete-favorite");
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
        set_status (@"Loaded “$(fav.name)”.");
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
        set_status (@"Saved “$name”.");
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
        set_status (@"Deleted “$(fav.name)”.");
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
            append_log ("❌ sdl-freerdp not found. Install it with your "
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
            shown.append (a.has_prefix ("/p:") ? "/p:••••••" : a);
        }
        append_log (@"▶ $(shown.str)");

        string[] argv = { (!) binary };
        foreach (var a in args) argv += a;

        Subprocess proc;
        try {
            var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE
                                                   | SubprocessFlags.STDERR_MERGE);
            proc = launcher.spawnv (argv);
        } catch (Error e) {
            set_status ("Failed to launch.");
            append_log (@"❌ failed to launch: $(e.message)");
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
            append_log (@"■ session ended (exit code $code)");
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
