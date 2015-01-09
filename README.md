This started as a Mojolicious boilerplate, then turned into a Mojolicious demo app then as a utility to visualize some KPI of an Exalogic infrastructure using D3.

**This is currently work in progress.**

## Prerequisites

- [Mojolicious](http://mojolicio.us/) latest, tested with 5.71
    - Mojolicious::Plugin::Config
- [Bootstrap](http://getbootstrap.com/) (3.3.1)
- [Font Awesome](http://fortawesome.github.io/Font-Awesome/) (4.2.0)

- Librerie javascript:
    - [jquery (>=2.0.3)](http://jquery.com) (2.1.1)
    - [D3](http://d3js.org/) (3.4.13)
    - [DateTime Picker](http://www.malot.fr/bootstrap-datetimepicker/) (2.3.1)
    - [intro.js](http://usablica.github.io/intro.js/) v0.9.0

- Additional Perl modules
    - IO:Socket (1.36)
    - MIME::Lite (3.030)
    - EV (4.18)

- Other software needed
    - pod2html to generate API docs from source (see script/generate_api_docs.sh)
    - git-cache-meta to handle permission in a git repo

## Versioning

Releases will be numbered with the follow format:

`<major>.<minor>.<patch>`

And constructed with the following guidelines:

* Breaking backwards compatibility bumps the major
* New additions without breaking backwards compatibility bumps the minor
* Bug fixes and misc changes bump the patch

For more information on semantic versioning, please visit http://semver.org/.
