package Exasteel;

use Mojo::Base 'Mojolicious';
use Mojo::Log;
use MongoDB;
use MongoDB::OID;
use Exasteel::Model;
use POSIX qw(strftime);

# utils
  sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# This method will run once at server start
sub startup {
  my $self=shift;
  my $version;

  my $log_level=2; # mail log level, not the helper!
  my $main_log=Mojo::Log->new(path => 'log/exasteel.log', level => 'debug');

  $self->secrets(['2a595521e0a038f473c85d7360a10ec8','This secret is used _only_ for validation']);
  $self->sessions->default_expiration(60*60*24*7); #7gg
  $version = $self->defaults({version => '0.5&alpha;'});

  #################################################################################
  # Plugins
    $main_log->debug("Exasteel reading config") if ($log_level>0);
    my $config=$self->plugin('Config');
    $self->plugin(charset => {charset => 'utf8'});
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
    # Log handling
    my $private_api_log = Mojo::Log->new(path => 'log/private_API.log', level => 'debug');
    my $public_api_log  = Mojo::Log->new(path => 'log/public_API.log',  level => 'debug');
    $self->helper(
      main_log => sub { return $main_log }
    );
    $self->helper(
      private_api_log => sub { return $private_api_log }
    );
    $self->helper(
      public_api_log  => sub { return $public_api_log }
    );
    $self->helper(
      log_level  => sub { return 2 }
    );
  #################################################################################

  # Default layout
  $self->defaults(layout => 'default');

  my $sessions = $self->sessions;
  # $self        = $self->sessions(Mojolicious::Sessions->new);
  # Change name of cookie used for all sessions
  $self->sessions->cookie_name('exasteel');

  # Router
  my $r = $self->routes;

  # Default namespace
  $r->namespaces(['Exasteel::Controller']);

  ###################################################################################################
  # UI (no login required)
    $r->get('/')                     ->to('Pages#home')       ->name('home');
    $r->get('/credits')              ->to('Pages#credits')    ->name('credits');
    # login
      $r->route('/login')            ->to('auth#login')       ->name('auth_login');
      $r->route('/auth')             ->to('auth#create')      ->name('auth_create');
      $r->route('/logout')           ->to('auth#logout')      ->name('auth_logout');
      $r->route('/no-local-storage') ->to('Pages#nolocalstorage')      ->name('nolocalstorage');
  ###################################################################################################

  ###################################################################################################
  # Public API
    $r->route('/api/v1/docs')                                   ->via('get') ->to('Public_API#docs');
    $r->route('/api/v1/vdcaccounts/:vdc', format => [qw(json)]) ->via('get') ->to('Public_API#VDCAccounts');
    $r->route('/api/v1/vdckpi/:vdc_name')                       ->via('get') ->to('Public_API#VDCKPI');
    $r->route('/api/v1/getvdcguestsbycn/:vdc_name')                ->via('get') ->to('Public_API#getVDCGuestsByCN');
  ###################################################################################################

  ###################################################################################################
  # Private API
    $r->route('/api/getsession', format => [qw(json)])       ->via('get')    ->to('Private_API#getSession');
    $r->route('/api/setsession')                             ->via('post')   ->to('Private_API#setSession');
    $r->route('/api/v1/vdc/:vdcid', format => [qw(json)])    ->via('delete') ->to('Private_API#removeVDC');
    $r->route('/api/v1/vdc/:vdc_name', format => [qw(json)]) ->via('post')   ->to('Private_API#addVDC'); # TODO use _id and not name
    $r->route('/api/v1/getvdcs', format => [qw(json)])       ->via('get')    ->to('Private_API#getVDCs');
  ###################################################################################################

  ###################################################################################################
  # protected pages (login required)
    my $auth = $r->under->to('auth#check');
    $auth->get('/settings/vdc')      ->to('Pages#settings_vdc')      ->name('settings_vdc');
    $auth->get('/settings/services') ->to('Pages#settings_services') ->name('settings_services');
    $auth->get('/kpi')               ->to('Pages#kpi')         ->name('kpi');
    $auth->get('/map')               ->to('Pages#map')         ->name('map');
    $auth->get('/vdc/:vdcname')      ->to('Pages#vdcdetails')  ->name('vdcdetails');
    $auth->get('/api/docs')          ->to('Private_API#docs')  ->name('private_docs');
    $auth->get('/temp')               ->to('Pages#temp');
  ###################################################################################################

  ###################################################################################################
  # Black hole... you'll reach the Holy Cow!
  ###################################################################################################
    $r->any('/*whatever' => {whatever => ''} => sub {
      my $c        = shift;
      my $whatever = $c->param('whatever');
      $c->render(template => 'errors/404', status => 404);
    });
}

# http://stackoverflow.com/questions/1860869/what-are-valid-perl-module-return-values
"Raging bull (1979)";
