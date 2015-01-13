package Exasteel::Controller::Private_API;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use Mojo::Log;
use Mojo::UserAgent;
use Mojo::IOLoop;
use DateTime;
use POSIX qw(strftime locale_h);
use locale;

# render static docs
sub docs {
  my $self = shift;
  $self->render('api/docs');
}

=head1 Exasteel PRIVATE API

This are the private API for Exasteel. You can call every method via an HTTP GET:

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
  my $log_level=$self->log_level;

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
  if ($log_level>0) {
    $self->private_api_log->debug("Exasteel::Controller::Private_API::getSession | Request by $rua @ $ip");
  }

  # initialize from %defaults
    foreach my $key ( keys %defaults ) {
      if (!defined $self->session->{$key} or $self->session->{$key} eq '') {
        $self->session->{$key}=$defaults{$key};
      }
    }

  if ($log_level>1) { $self->private_api_log->debug("Exasteel::Controller::Private_API::getSession | Session: ". Dumper($self->session)); }

  $self->respond_to(
    json => { json => $self->session },
  );
}

sub setSession {
  my $self  = shift;
  my $log_level=$self->log_level;

  my $rua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($log_level>0) {
    $self->private_api_log->debug("Exasteel::Controller::Private_API::setSession | Request by $rua @ $ip");
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

  if ($log_level>1) { $self->private_api_log->debug("Exasteel::Controller::Private_API::setSession | Session: ".Dumper($self->session)); }

  $self->respond_to(
    json => { json => { status => 'OK'} },
    txt  => { text => 'OK' }
  );
}

sub getVDCs {
  my $self     = shift;
  my $log_level=$self->log_level;
  my $db       = $self->db;

  if ($log_level>0) { $self->private_api_log->debug("Exasteel::Controller::Private_API::getVDCs"); }

  my $vdcs_collection=$self->db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({});
  my @vdcs=$find_result->all;

  if ( @vdcs and (0+@vdcs)>0) {
      if ($log_level>0) { $self->private_api_log->debug("Exasteel::Controller::Private_API::getVDCs found $#vdcs VDCs"); }
  } else {
    # no VDCs found
  }

  if ($log_level>1) { $self->private_api_log->debug("Exasteel::Controller::Private_API::getVDCs | vDCs: ".Dumper(@vdcs)); }

  $self->respond_to(
    json => { json => \@vdcs }
  );
}

sub removeVDC {
  my $self  = shift;
  my $log_level=$self->log_level;
  my $db    = $self->db;
  my $vdcid = $self->param('vdcid');

  my $status='OK';

  if ($log_level>0) { $self->private_api_log->debug("Exasteel::Controller::Private_API::removeVDC"); }

  my $vdcs_collection=$db->get_collection('vdcs');
  my $result=$vdcs_collection->remove({ _id => $self->value2oid($vdcid) });
  # TODO some checks...

  $self->respond_to(
    json => { json => { "description" => $status } }
  );
}

sub addVDCs {
  my $self     = shift;
  my $log_level=$self->log_level;
  my $db       = $self->db;
  my $vdcid    = $self->param('vdcid'); # this is the previous VDC display_name (the one in the db) or a new one
  my $status   = 'OK';

  my $params = $self->req->json;

  if ($log_level>0) { $self->private_api_log->debug("Exasteel::Controller::Private_API::addVDCs | params: ".Dumper($params)); }

  # TODO verify existing keys and update only those

  my $vdcs_collection=$self->db->get_collection('vdcs');
  $vdcs_collection->update(
      { "display_name" => $vdcs},      # where clause
      { '$set' => {                    # set new values received via post
          "display_name"      => $params->{'display_name'},
          "emoc_endpoint"     => $params->{'emoc_endpoint'},
          "emoc_username"     => $params->{'emoc_username'},
          "emoc_password"     => crypt($params->{'emoc_password'},$params->{'emoc_password'}),
          "asset_description" => $params->{'asset_description'},
          "tags"              => $params->{'tags'},
          "ignored_accounts"  => $params->{'ignored_accounts'},
        }
      },
      { 'upsert' => 1 }                 # update or insert
  );

  # TODO check for success

  if ($log_level>1) { $self->private_api_log->debug("Exasteel::Controller::Private_API::addVDCs | vDCs: ". Dumper(@vdcs)); }

  $self->respond_to(
    json => { json => { "status" => $status } }
  );
}

"Do you suppose the Ivory Tower is still standing? (Neverending Story, 1984)";
