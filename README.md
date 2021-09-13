# StreamTaffy - An open source overlay engine for Twitch streams

StreamTaffy is an overlay engine designed for use on Twitch streams.
Unlike most Twitch Applications, which are run by a single organization
and are used to service countless users,
StreamTaffy is designed to be run as your very own Twitch Application.
It is intended for use by individuals or groups
with at least some programming experience,
who are looking for a more thoroughly customizeable experience
than is given by other existing overlay services.

### Features:

* Provides a web page that shows notifications when certain Twitch events occur.

* Allows multiple templates for each event type, selecting one randomly each
  time an event occurs.

* Currently only supports follows.



### Requirements:

* A Twitch dev account, with an application ID and secret.
  StreamTaffy does not yet support the initial authentication process.
  https://dev.twitch.tv/

* A web host capable of running CGI scripts to serve the listener and overlay
  from.  Twitch requires https to be correctly configured for EventSub
  endpoints.  The host must have:

* * Perl, minimum v5.20.  This could be lowered with little effort if needed,
    but for simplicity a non-ancient version is assumed.

* * Perl modules Digest::SHA and JSON.

* * A POSIX environment to run in - StreamTaffy has only been tested on Linux,
    though it should presumably run well in other similar environments.



### How to:

1. On the web host, preferably in a location that is not accessible from the
   web, clone the repository with `git clone https://github.com/edwinsage/StreamTaffy`,
   or download and extract one of the releases.

1. Configure your web server software to pass the environment variable DATA_DIR
   to CGI scripts that run.  It should be set to the directory where the
   repository was cloned, not including the final `StreamTaffy/`.  In the case
   of nginx using fcgiwrap, this can be done by adding
   `fastcgi_param DATA_DIR <location>;` to the section of the config that
   handles CGI files.

1. If needed, modify the permissions of the `StreamTaffy/live` directory to
   allow writing by the user that CGI scripts are run as.

1. Copy the example config file to StreamTaffy.conf, and at minimum fill in
   the essential config with the credentials of your registered Twitch
   application, as well as a secret for verifying received subscription events.

1. In the config file, set overlay_visible to a hosted location.  This will be
   the page that will be used to display the overlay events.  Your broadcasting
   software should be configured to display this page as an overlay.

1. Link or copy the file listener.cgi to a hosted location.  This will be the
   page that will receive subscription events from Twitch.  Using a symlink
   will allow you to update StreamTaffy in place without having to make
   additional changes.

1. ...



### Hacking:

To get useful feedback from the non-interactive scripts, you can set debug_level
to a number higher than 0 in the config.  Higher numbers output more
information, with the highest level currently being 3.

The displayed file live/overlay.html is set to refresh automatically every two
seconds, so that streaming software will notice when the file changes.  Any
templates created should similarly have a timed refresh after the desired
display time.  StreamTaffy looks for a line in the template file that matches
`meta http-equiv="refresh" content="(\d+)"`, capturing the time so that the
overlay lock can be held for the full duration.  Make sure any templates added
have a matching line, otherwise the overlay will stop updating.

Any software that intends to modify the overlay should first wait on obtaining
an exclusive lock on live/overlay.lock, or more specifically
`$cfg{cgi_live_dir}/overlay.lock`.  On *NIX systems this can be done with
flock(2), or from within Perl with the flock command.  This lock should be held
for the duration of the change.

Note that StreamTaffy is released under the AGPL, meaning that if you
host the software for other people to use, you must make sure  to include
a notice of the license as well as a link to the source code.  In
particular, this means IF YOU HOST THIS SOFTWARE FOR OTHER USERS, YOU
WILL NEED TO ALSO WRITE AN INTERFACE THAT PROVIDES THE NECESSARY LEGAL
INFORMATION.  This will be built into the project at some point in the
future, once it has a user interface.


