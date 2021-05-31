# StreamTaffy - An open source overlay engine for Twitch streams



### Features:

* Provides a web page that shows notifications when certain Twitch events occur.

* Currently only supports follows.

### Requirements:

* A Twitch dev account, with an application ID and secret.
  StreamTaffy does not yet support the initial authentication process.
  https://dev.twitch.tv/

* A web host capable of running CGI scripts to serve the listener and overlay
  from.  Twitch requires https to be correctly configured for EventSub
  endpoints.  The host must have:

** Perl, minimum v5.20.  This could be lowered with little effort if needed,
   but for simplicity a non-ancient version is assumed.

** Perl modules Digest::SHA and JSON.

** A POSIX environment to run in - StreamTaffy has only been tested on Linux,
   though it should presumably run well in other similar environments.


### How to:

1. Clone the repository with `git clone https://github.com/edwinsage/StreamTaffy`,
   or download and extract one of the releases.

1. Um.  Magic?


### Hacking:

Not gonna lie, it's a mess in here right now.

Note that StreamTaffy is released under the AGPL, meaning that if you
host the software for other people to use, you must make sure  to include
a notice of the license as well as a link to the source code.  In
particular, this means IF YOU HOST THIS SOFTWARE FOR OTHER USERS, YOU
WILL NEED TO ALSO WRITE AN INTERFACE THAT PROVIDES THE NECESSARY LEGAL
INFORMATION.  This will be built into the project at some point in the
future, once it has a user interface.


