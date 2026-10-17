/*
 * quiet-filemanager1: hand org.freedesktop.FileManager1 to this desktop's own Files.
 *
 * "Show in folder" in Firefox and Zen does not use the inode/directory handler at all. It calls
 * org.freedesktop.FileManager1.ShowItems over D-Bus, and on this machine that name was owned by
 * Nautilus through /usr/share/dbus-1/services, so the file opened in a file manager the desktop
 * does not otherwise use. This owns the name instead and forwards to the shell.
 *
 *   ShowItems(uris, startup_id)   -> files reveal <path>   (selects the file)
 *   ShowFolders(uris, startup_id) -> files at <path>       (opens the folder, one per URI)
 *
 * ShowItems acts on uris[0] only: the shell's reveal takes one path and selects one file, so a
 * caller handing over a multi-selection gets its first file. ShowFolders is one window per folder,
 * as the name asks. ShowItemProperties is deliberately not declared -- there is no properties
 * surface here, and an undeclared method lets the caller open its own dialog instead of being
 * handed a folder listing it did not ask for.
 *
 * The name is held for the rest of the session once taken. It used to be released after 30 idle
 * seconds, but any GTK app that activates org.gnome.Nautilus in that gap gives Nautilus the name
 * for the rest of the session -- the exact thing this program exists to prevent.
 *
 *   ./build.sh          (then ./install.sh; it generates the D-Bus activation file)
 */
#include <gio/gio.h>
#include <signal.h>
#include <string.h>

/* Which quickshell configuration to talk to. QS_CONFIG_NAME is quickshell's own name for it. */
#define CONFIG_DEFAULT "tacit"

/* A call takes about 30 ms. A wedged shell would otherwise hold the caller until its own D-Bus
 * timeout runs out, with no window and no message. */
#define CHILD_SECONDS 5

static GMainLoop *loop;

static const gchar introspection[] =
    "<node>"
    "  <interface name='org.freedesktop.FileManager1'>"
    "    <method name='ShowItems'>"
    "      <arg type='as' name='URIs' direction='in'/>"
    "      <arg type='s' name='StartupId' direction='in'/>"
    "    </method>"
    "    <method name='ShowFolders'>"
    "      <arg type='as' name='URIs' direction='in'/>"
    "      <arg type='s' name='StartupId' direction='in'/>"
    "    </method>"
    "  </interface>"
    "</node>";

/* One D-Bus call, answered once however many children it took: ShowFolders opens a window per
 * folder, and the caller hears about the first one that failed. */
typedef struct {
    GDBusMethodInvocation *invocation;   /* the reply owes this; returning a value consumes it */
    gint pending;                        /* children not yet accounted for */
    gchar *why;                          /* the first failure, if any */
} Batch;

/* One `qs ipc call` child within a Batch. */
typedef struct {
    Batch *batch;
    gchar *what;
    gint err_fd;
    GPid pid;
    guint timeout_id;
    gboolean timed_out;
} Call;

/* One child is done. The reply waits for the last of them, so a caller is never told the request
 * succeeded while a second window is still being asked for. */
static void batch_done(Batch *batch, const gchar *why) {
    if (why && !batch->why)
        batch->why = g_strdup(why);
    if (--batch->pending > 0)
        return;
    if (batch->why)
        g_dbus_method_invocation_return_error(batch->invocation, G_DBUS_ERROR, G_DBUS_ERROR_FAILED,
                                             "the shell did not take the request: %s", batch->why);
    else
        g_dbus_method_invocation_return_value(batch->invocation, NULL);
    g_free(batch->why);
    g_free(batch);
}

static gboolean child_too_slow(gpointer data) {
    Call *call = data;
    call->timeout_id = 0;
    call->timed_out = TRUE;
    kill(call->pid, SIGTERM);            /* the child watch then sends the failure reply */
    return G_SOURCE_REMOVE;
}

/* qs exits 0 even when it prints "Target not found.", "Function not found." or an arity error, so
 * anything the child wrote to stderr counts as a failure as much as a non-zero exit does. */
static void on_child_exit(GPid pid, gint wait_status, gpointer data) {
    Call *call = data;
    GIOChannel *err = g_io_channel_unix_new(call->err_fd);
    gchar *text = NULL;
    gsize len = 0;

    if (call->timeout_id)
        g_source_remove(call->timeout_id);
    g_io_channel_set_close_on_unref(err, TRUE);
    g_io_channel_read_to_end(err, &text, &len, NULL);   /* the child is gone, so this cannot block */
    g_io_channel_unref(err);
    g_spawn_close_pid(pid);

    if (text) {
        /* qs says it in one line; keep the reply bounded and valid UTF-8 whatever the child wrote. */
        gchar *nl = strchr(text, '\n');
        if (nl)
            *nl = '\0';
        gchar *bounded = g_utf8_make_valid(text, MIN(strlen(text), 200));
        g_free(text);
        text = g_strstrip(bounded);
    }

    if (!g_spawn_check_wait_status(wait_status, NULL) || (text && *text)) {
        const gchar *why = (text && *text) ? text
                         : call->timed_out ? "the shell did not answer"
                         : "qs exited with a failure";
        g_warning("the shell did not take `%s`: %s", call->what, why);
        batch_done(call->batch, why);
    } else {
        batch_done(call->batch, NULL);
    }

    g_free(text);
    g_free(call->what);
    g_free(call);
}

/* The shell is asked through its own IPC; a path is passed as one argument, never a shell line.
 * The reply waits for the child, so a shell that is down or a renamed config reaches the caller
 * as an error instead of looking like a silent success. */
static void tell_shell(const gchar *verb, gchar **paths, guint n, GDBusMethodInvocation *invocation) {
    const gchar *config = g_getenv("QS_CONFIG_NAME");
    Batch *batch = g_new0(Batch, 1);
    batch->invocation = invocation;
    batch->pending = (gint) n;   /* counted up front: a spawn that fails must not answer for the rest */

    for (guint i = 0; i < n; i++) {
        const gchar *argv[] = { "qs", "-c", (config && *config) ? config : CONFIG_DEFAULT,
                                "ipc", "call", "files", verb, paths[i], NULL };
        GError *error = NULL;
        GPid pid = 0;
        gint err_fd = -1;

        if (!g_spawn_async_with_pipes(NULL, (gchar **) argv, NULL,
                                      G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL |
                                      G_SPAWN_DO_NOT_REAP_CHILD,
                                      NULL, NULL, &pid, NULL, NULL, &err_fd, &error)) {
            g_warning("could not reach the shell: %s", error->message);
            batch_done(batch, error->message);
            g_clear_error(&error);
            continue;
        }

        Call *call = g_new0(Call, 1);
        call->batch = batch;
        call->what = g_strdup_printf("files %s %s", verb, paths[i]);
        call->err_fd = err_fd;
        call->pid = pid;
        call->timeout_id = g_timeout_add_seconds(CHILD_SECONDS, child_too_slow, call);
        g_child_watch_add(pid, on_child_exit, call);
    }
}

/* One URI as a local path, or NULL with the error already replied to the caller. */
static gchar *local_path(const gchar *uri, GDBusMethodInvocation *invocation) {
    /* Several callers hand over a bare path rather than a URI. Anything else has to convert to a
     * local file: Files cannot show a trash://, sftp:// or file://host/ location. */
    GError *error = NULL;
    gchar *host = NULL;
    gchar *path = g_path_is_absolute(uri) ? g_strdup(uri) : g_filename_from_uri(uri, &host, &error);
    /* glib hands a foreign hostname back instead of refusing it, so file://elsewhere/etc/passwd
     * would otherwise quietly reveal the local copy. */
    if (path && host && !g_str_equal(host, "localhost") &&
        g_ascii_strcasecmp(host, g_get_host_name()) != 0)
        g_clear_pointer(&path, g_free);
    g_free(host);
    if (!path) {
        g_dbus_method_invocation_return_error(invocation, G_DBUS_ERROR, G_DBUS_ERROR_INVALID_ARGS,
                                             "not a local file: %s (%s)", uri,
                                             error ? error->message : "unsupported location");
        g_clear_error(&error);
        return NULL;
    }
    /* Otherwise a deleted download opens its parent folder with nothing selected, which the user
     * cannot tell apart from a broken reveal. */
    if (!g_file_test(path, G_FILE_TEST_EXISTS)) {
        g_dbus_method_invocation_return_error(invocation, G_DBUS_ERROR, G_DBUS_ERROR_FILE_NOT_FOUND,
                                             "%s is not there any more", path);
        g_free(path);
        return NULL;
    }
    return path;
}

static void handle_call(GDBusConnection *connection, const gchar *sender, const gchar *object,
                        const gchar *interface, const gchar *method, GVariant *parameters,
                        GDBusMethodInvocation *invocation, gpointer user_data) {
    (void) connection; (void) sender; (void) object; (void) interface; (void) user_data;

    const gchar **uris = NULL;
    const gchar *startup_id = NULL;   /* unpacked for the signature; no activation token is used */
    g_variant_get(parameters, "(^a&s&s)", &uris, &startup_id);

    /* An empty array unpacks to a one-element {NULL}, which used to fall straight through to a
     * successful reply with nothing done. */
    if (!uris || !uris[0]) {
        g_dbus_method_invocation_return_error(invocation, G_DBUS_ERROR, G_DBUS_ERROR_INVALID_ARGS,
                                             "no URIs given");
        g_free(uris);
        return;
    }

    /* ShowFolders is given folders to open, one window each; ShowItems is given a file to select,
     * and the shell's reveal takes one path, so the rest of a multi-selection is not acted on. */
    gboolean folders = g_str_equal(method, "ShowFolders");
    guint n = 0;
    while (uris[n])
        n++;
    if (!folders)
        n = 1;

    /* Every path is checked before any window is asked for: a request that is partly impossible
     * comes back as one error rather than some folders open and an error for the rest. */
    gchar **paths = g_new0(gchar *, n + 1);
    for (guint i = 0; i < n; i++) {
        paths[i] = local_path(uris[i], invocation);
        if (!paths[i]) {
            g_strfreev(paths);
            g_free(uris);
            return;
        }
    }

    tell_shell(folders ? "at" : "reveal", paths, n, invocation);
    g_strfreev(paths);
    g_free(uris);
}

static const GDBusInterfaceVTable vtable = { handle_call, NULL, NULL, { 0 } };

static void on_bus_acquired(GDBusConnection *connection, const gchar *name, gpointer user_data) {
    (void) name;
    GDBusNodeInfo *info = (GDBusNodeInfo *) user_data;
    GError *error = NULL;
    g_dbus_connection_register_object(connection, "/org/freedesktop/FileManager1",
                                      info->interfaces[0], &vtable, NULL, NULL, &error);
    if (error) {
        g_printerr("could not register the object: %s\n", error->message);
        g_clear_error(&error);
        g_main_loop_quit(loop);
    }
}

static void on_name_lost(GDBusConnection *connection, const gchar *name, gpointer user_data) {
    (void) connection; (void) user_data;
    /* Either something else refused to give the name up, or a newer instance of this replaced us. */
    g_printerr("%s went to another owner\n", name);
    g_main_loop_quit(loop);
}

int main(void) {
    GError *error = NULL;
    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(introspection, &error);
    if (error) {
        g_printerr("bad introspection xml: %s\n", error->message);
        return 1;
    }
    loop = g_main_loop_new(NULL, FALSE);
    /* Take the name even if Nautilus got there first, and hand it to a newer instance of this
     * program rather than making that one fail. */
    guint owner = g_bus_own_name(G_BUS_TYPE_SESSION, "org.freedesktop.FileManager1",
                                 G_BUS_NAME_OWNER_FLAGS_REPLACE |
                                 G_BUS_NAME_OWNER_FLAGS_ALLOW_REPLACEMENT,
                                 on_bus_acquired, NULL, on_name_lost, info, NULL);
    g_main_loop_run(loop);
    g_bus_unown_name(owner);
    g_dbus_node_info_unref(info);
    g_main_loop_unref(loop);
    return 0;
}
