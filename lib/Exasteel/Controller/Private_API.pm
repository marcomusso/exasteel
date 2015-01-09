package Exasteel::Controller::Private_API;

use 5.018;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use Mojo::Log;
use DateTime;
use POSIX qw(strftime locale_h);
use locale;
use Mojo::UserAgent;
use Mojo::IOLoop;

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/private_API.log', level => 'debug');
my $debug=2; # global log level, override in each sub if needed

# render static docs
sub docs {
  my $self = shift;
  $self->render('api/docs');
}

=head1 Exasteel PRIVATE API

This are the public API for Exasteel. You can call every method via an HTTP GET:

  http://<EXASTEEL_URL>/api/v1/<method>/<parameters...>

Example:

  http://<EXASTEEL_URL>/api/v1/getVCDKPI/<KPI>.csv

The HTTP response will be according to the extension requested (mostly supported: CSV and JSON).

Method list:
=cut

#########################################################################
# Private API
#########################################################################

sub getSession {
  my $self = shift;

  my ($sec,$min,$hour,$day,$month,$year) = (localtime(time-60*60*24))[0,1,2,3,4,5];
  my $startlocale="$day/".($month+1)."/".($year+1900)." ".sprintf("%2d",$hour).":".sprintf("%2d",$min);
  ($sec,$min,$hour,$day,$month,$year) = (localtime(time))[0,1,2,3,4,5];
  my $endlocale="$day/".($month+1)."/".($year+1900)." ".sprintf("%2d",$hour).":".sprintf("%2d",$min);

  my %defaults=('theme'       => 'default',
                'username'    => '',
                'startepoch'  => time-60*60*24,
                'endepoch'    => time,
                'startlocale' => $startlocale,
                'endlocale'   => $endlocale,
               );

  my $rua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($debug>0) {
    $log->debug("Exasteel::Controller::Private_API::getSession | Request by $rua @ $ip");
  }

  # initialize from %defaults
    foreach my $key ( keys %defaults ) {
      if (!defined $self->session->{$key} or $self->session->{$key} eq '') {
        $self->session->{$key}=$defaults{$key};
      }
    }

  if ($debug>1) { $log->debug("Exasteel::Controller::Private_API::getSession | Session: ". Dumper($self->session)); }

  $self->respond_to(
    json => { json => $self->session },
  );
}

sub setSession {
  my $self  = shift;

  my $rua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($debug>0) {
    $log->debug("Exasteel::Controller::Private_API::setSession | Request by $rua @ $ip");
  }

  my $params = $self->req->json;

  # store known parameters in session!
  $self->session->{env_display}= $params->{'env_display'};
  $self->session->{env_code}   = $params->{'env_code'};
  $self->session->{startepoch} = $params->{'startepoch'};
  $self->session->{endepoch}   = $params->{'endepoch'};
  $self->session->{username}   = $params->{'username'};;
  $self->session->{theme}      = $params->{'theme'};
  $self->session->{units}      = $params->{'units'};

  my ($sec,$min,$hour,$day,$month,$year) = (localtime($params->{'startepoch'}))[0,1,2,3,4,5];
  my $startlocale="$day/".($month+1)."/".($year+1900)." ".sprintf("%d",$hour).":".sprintf("%02d",$min);
  ($sec,$min,$hour,$day,$month,$year) = (localtime($params->{'endepoch'}))[0,1,2,3,4,5];
  my $endlocale="$day/".($month+1)."/".($year+1900)." ".sprintf("%d",$hour).":".sprintf("%02d",$min);

  $self->session->{startlocale} = $startlocale;
  $self->session->{endlocale}   = $endlocale;

  if ($debug>1) { $log->debug("Exasteel::Controller::Private_API::setSession | Session: ". Dumper($self->session)); }

  $self->respond_to(
    json => { json => { status => 'OK'} },
    txt  => { text => 'OK' }
  );
}

sub getvDCs {
  my $self     = shift;
  my $db       = $self->db;

  if ($debug>0) { $log->debug("Exasteel::Controller::Private_API::getvDCs"); }

  my $vdcs_collection=$self->db->get_collection('vdcs');
  my $find_result=$vdcs->find({});
  my @vcds=$find_result->all;

  if ( @vdcs and (0+@vdcs)>0) {
      if ($debug>0) { $log->debug("Exasteel::Controller::Private_API::getvDCs found "+(0+@vdcs)+" vDCs"); }
  } else {
    # no vDCs found
  }

  if ($debug>1) { $log->debug("Exasteel::Controller::Private_API::getvDCs | vDCs: ". Dumper(@vdcs)); }

  $self->respond_to(
    json => { json => \@vdcs }
  );
}

"Do you suppose the Ivory Tower is still standing? (Neverending Story, 1984)";
