package Exasteel;

use 5.018;
use Mojo::Base 'Mojolicious';
use Mojo::Log;
use POSIX qw(strftime);
use MongoDB;
use MongoDB::OID;
use Exasteel::Model;

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/exasteel.log', level => 'debug');
my $debug=0; # global log level, override in each sub if needed

# utils
  sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# This method will run once at server start
sub startup {
  my $self = shift;
  my $version;

  if ($debug>0) { $log->debug("Exasteel starting..."); }

  $self->secrets(['2a595521e0a038f473c85d7360a10ec8','This secret is used _only_ for validation']);
  $self->sessions->default_expiration(60*60*72); #3gg
  $version = $self->defaults({version => '0.1&alpha;'});

  #################################################################################
  # Plugins
    if ($debug>0) { $log->debug("Exasteel reading config"); }
    my $config=$self->plugin('Config');
    $self->plugin(charset => {charset => 'utf8'});
    # $self->plugin('TagHelpers');
  #################################################################################

  #################################################################################
  # Helpers
    $self->helper(
      db => sub {
        Exasteel::Model->init( $config->{db} );
      }
    );
    $self->helper(
      value2oid => sub {
        my ($self, $value) = @_;
        MongoDB::OID->new($value);
      }
    );
  #################################################################################

  # Default layout
  $self->defaults(layout => 'default');

  my $sessions = $self->sessions;
  $self        = $self->sessions(Mojolicious::Sessions->new);
  # Change name of cookie used for all sessions
  $self->sessions->cookie_name('exasteel');

  # Router
  my $r = $self->routes;

  # Default namespace
  $r->namespaces(['Exasteel::Controller']);

  ###################################################################################################
  # UI (no login required)
    $r->get('/')                     ->to('pages#home')       ->name('home');
    $r->get('/credits')              ->to('pages#credits')    ->name('credits');
    # login
      $r->route('/login')            ->to('auth#login')       ->name('auth_login');
      $r->route('/auth')             ->to('auth#create')      ->name('auth_create');
      $r->route('/logout')           ->to('auth#logout')      ->name('auth_logout');
  ###################################################################################################

  ###################################################################################################
  # Public API
    $r->get('/api/v1/docs')                                     ->to('Public_API#docs');
    $r->route('/api/v1/vdcaccounts/:vdc', format => [qw(json)]) ->to('Public_API#VDCAccounts');
    $r->get('/api/v1/vdckpi/:vdc_name')                         ->to('Public_API#VDCKPI');
  ###################################################################################################

  ###################################################################################################
  # Private API
    $r->route('/api/getsession', format => [qw(json)])     ->via('get')    ->to('Private_API#getSession');
    $r->route('/api/setsession')                           ->via('post')   ->to('Private_API#setSession');
    $r->route('/api/v1/vdc/:vdcid', format => [qw(json)])  ->via('delete') ->to('Private_API#removeVDC');
    $r->route('/api/v1/getvdcs', format => [qw(json)])     ->via('get')    ->to('Private_API#getVDCs');
  ###################################################################################################

  ###################################################################################################
  # protected pages (login required)
    my $auth = $r->under->to('auth#check');
    $auth->get('/settings')          ->to('pages#settings')    ->name('settings');
    $auth->get('/kpi')               ->to('pages#kpi')         ->name('kpi');
    $auth->get('/map')               ->to('pages#map')         ->name('map');
    $auth->get('/vdc/:vdc_name')     ->to('pages#vdcdetails')  ->name('vdcdetails');
    $auth->get('/api/docs')          ->to('Private_API#docs');
  ###################################################################################################

  ###################################################################################################
  # Black hole... you'll reach the Holy Cow!
  ###################################################################################################
    $r->any('/*whatever' => {whatever => ''} => sub {
      my $c        = shift;
      my $whatever = $c->param('whatever');
      $c->render(template => 'pages/404', status => 404);
    });
}

"Raging bull (1979)";

# http://stackoverflow.com/questions/1860869/what-are-valid-perl-module-return-values
