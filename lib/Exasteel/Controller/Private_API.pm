package Exasteel::Controller::Private_API;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::UserAgent;
use Mojo::IOLoop;
use Mojo::Util qw(url_unescape);
use Data::Dumper;
use DateTime;
use POSIX qw(strftime locale_h);
use boolean;

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
  my $self=shift;
  my $log=$self->private_api_log;
  my $log_level=0;

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
                'units'       => 'IEC',
                'mapvisualization' => 'tree'
               );

  my $rua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($log_level>0) {
    $log->debug("Exasteel::Controller::Private_API::getSession | Request by $rua @ $ip");
  }

  # initialize from %defaults
    foreach my $key ( keys %defaults ) {
      if (!defined $self->session->{$key} or $self->session->{$key} eq '') {
        $self->session->{$key}=$defaults{$key};
      }
    }

  if ($log_level>1) { $log->debug("Exasteel::Controller::Private_API::getSession | Session: ". Dumper($self->session)); }

  $self->respond_to(
    json => { json => $self->session },
  );
}

sub setSession {
  my $self=shift;
  my $log=$self->private_api_log;
  my $log_level=0;

  my $rua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($log_level>0) {
    $log->debug("Exasteel::Controller::Private_API::setSession | Request by $rua @ $ip");
  }

  my $params = $self->req->json;

  # store known parameters in session!
  $self->session->{env_display}      = $params->{'env_display'};
  $self->session->{env_code}         = $params->{'env_code'};
  $self->session->{startepoch}       = $params->{'startepoch'};
  $self->session->{endepoch}         = $params->{'endepoch'};
  $self->session->{username}         = $params->{'username'};;
  $self->session->{theme}            = $params->{'theme'};
  $self->session->{units}            = $params->{'units'};
  $self->session->{mapvisualization} = $params->{'mapvisualization'};

  my ($sec,$min,$hour,$day,$month,$year) = (localtime($params->{'startepoch'}))[0,1,2,3,4,5];
  my $startlocale="$day/".($month+1)."/".($year+1900)." ".sprintf("%d",$hour).":".sprintf("%02d",$min);
  ($sec,$min,$hour,$day,$month,$year) = (localtime($params->{'endepoch'}))[0,1,2,3,4,5];
  my $endlocale="$day/".($month+1)."/".($year+1900)." ".sprintf("%d",$hour).":".sprintf("%02d",$min);

  $self->session->{startlocale} = $startlocale;
  $self->session->{endlocale}   = $endlocale;

  if ($log_level>1) { $log->debug("Exasteel::Controller::Private_API::setSession | Session: ".Dumper($self->session)); }

  $self->respond_to(
    json => { json => { status => 'OK'} },
    txt  => { text => 'OK' }
  );
}

sub getVDCs {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->private_api_log;
  my $log_level=$self->log_level;


  if ($log_level>0) { $log->debug("Exasteel::Controller::Private_API::getVDCs"); }

  my $vdcs_collection=$self->db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({});
  my @vdcs=$find_result->all;

  if ( @vdcs and (0+@vdcs)>0) {
      if ($log_level>0) { $log->debug("Exasteel::Controller::Private_API::getVDCs found ".($#vdcs+1)." VDCs"); }
  } else {
    # TODO no VDCs found
    $log->debug("Exasteel::Controller::Private_API::getVDCs | TODO: no VDCs found");
  }

  if ($log_level>1) { $log->debug("Exasteel::Controller::Private_API::getVDCs | vDCs: ".Dumper(@vdcs)); }

  $self->respond_to(
    json => { json => \@vdcs }
  );
}

sub removeVDC {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->private_api_log;
  my $log_level=$self->log_level;

  my $vdcid=url_unescape($self->param('vdcid'));

  my $status='OK';

  if ($log_level>0) { $log->debug("Exasteel::Controller::Private_API::removeVDC"); }

  my $vdcs_collection=$db->get_collection('vdcs');
  my $result=$vdcs_collection->remove({ _id => $self->value2oid($vdcid) });

  # TODO some checks...

  $self->respond_to(
    json => { json => { "status" => $status } }
  );
}

sub addVDC {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->private_api_log;
  my $log_level=$self->log_level;
  my $vdc_display_name=url_unescape($self->param('vdc_name')); # this is the previous VDC display_name (the one in the db) or a new one

  my $status='OK';
  my $description='';

  my $params=$self->req->json;

  if ($log_level>1) { $log->debug("Exasteel::Controller::Private_API::addVDCs | params: ".Dumper($params)); }

  if ($params->{'ovmm_endpoint'} !~ m/^(?!-)[A-Z\d-]{1,63}(?<!-):\d+/i) {
    $description='Invalid OVMM endpoint (should be hostname:port).';
    $status = 'ERROR';
    $params->{'ovmm_endpoint'}='';
  }
  if ($params->{'ovmm_username'} eq '' or $params->{'ovmm_password'} eq '') {
    $description='Invalid OVMM username/password (please fill both).';
    $status = 'ERROR';
    $params->{'ovmm_username'}='';
    $params->{'ovmm_password'}='';
  }
  if ($params->{'emoc_endpoint'} !~ m/^(?!-)[A-Z\d-]{1,63}(?<!-):\d+/i) {
    $description='Invalid EMOC endpoint (should be hostname:port).';
    $params->{'emoc_endpoint'}='';
  }
  if ($params->{'emoc_username'} eq '' or $params->{'emoc_password'} eq '') {
    $description='Invalid OVMM username/password (please fill both).';
    $status = 'ERROR';
    $params->{'emoc_username'}='';
    $params->{'emoc_password'}='';
  }

  if ( $description eq '' ) {
    my $vdcs_collection=$self->db->get_collection('vdcs');
    my $id = $vdcs_collection->update(
        { "display_name" => $vdc_display_name}, # where clause
        { '$set' => {                           # set new values received via post
            "display_name"      => $params->{'display_name'},
            "emoc_endpoint"     => $params->{'emoc_endpoint'},
            "emoc_username"     => $params->{'emoc_username'},
            "emoc_password"     => $params->{'emoc_password'},
            "ovmm_endpoint"     => $params->{'ovmm_endpoint'},
            "ovmm_username"     => $params->{'ovmm_username'},
            "ovmm_password"     => $params->{'ovmm_password'}, # TODO how can we hanle encryption & salt for this password since it's not a user-inserted one?
            "asset_description" => $params->{'asset_description'},
            "tags"              => $params->{'tags'},
            "ignored_accounts"  => $params->{'ignored_accounts'},
          }
        },
        { 'upsert' => 1 }                       # update or insert
    );
    $log->debug("Exasteel::Controller::Private_API::addVDCs | insert result: ".Dumper($id)) if ($log_level>0);
    if ($id->{'err'}) { $status = 'ERROR'; $description=$id->{'err'}; }
  }

  $self->respond_to(
    json => { json => { "status" => $status, "description" => $description } }
  );
}

sub getCMDBs {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->private_api_log;
  my $log_level=$self->log_level;
  my %status=(status => 'OK', description => '' );

  if ($log_level>0) { $log->debug("Exasteel::Controller::Private_API::getCMDBs"); }

  my $cmdb_collection=$self->db->get_collection('cmdbs');
  my $find_result=$cmdb_collection->find({});
  my @cmdb=$find_result->all;

  if ( @cmdb and (0+@cmdb)>0) {
      if ($log_level>0) { $log->debug("Exasteel::Controller::Private_API::getCMDBs found ".($#cmdb+1)." CMDBs"); }
  } else {
    $status{'status'}="ERROR";
    $status{'description'}="No CMDB endpoints";
  }

  if ($log_level>1) { $log->debug("Exasteel::Controller::Private_API::getCMDBs | vDCs: ".Dumper(@cmdb)); }

  $self->respond_to(
    json => sub {
      if ($status{'status'} eq 'ERROR') {
        $self->render(json => \%status, status => 404);
      } else {
        $self->render(json => \@cmdb);
      }
    }
  );
}

sub addCMDB {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->private_api_log;
  my $log_level=$self->log_level;
  $log_level = 2;

  my %status=(status => 'OK', description => '' );
  my $description='';

  my $params=$self->req->json;

  if ($log_level>0) { $log->debug("Exasteel::Controller::Private_API::addCMDB | params: ".Dumper($params)); }

  if ($params->{'cmdb_endpoint'} !~ m/^(?!-)[A-Z\d-]{1,63}(?<!-)(:\d+)?/i) {
    $description='Invalid CMDB endpoint (should be hostname[:port]).';
    $params->{'cmdb_endpoint'}='';
  }
  if ($params->{'cmdb_username'} eq '' or $params->{'cmdb_password'} eq '') {
    $description='Invalid CMDB username/password (please fill both).';
    $params->{'cmdb_username'}='';
    $params->{'cmdb_password'}='';
  }

  my $cmdbs_collection=$self->db->get_collection('cmdbs');
  my $id = $cmdbs_collection->update(
      { "display_name" => $params->{'display_name'} }, # where clause
      { '$set' => {                                    # set new values received via post
          "cmdb_endpoint"     => $params->{'cmdb_endpoint'},
          "cmdb_username"     => $params->{'cmdb_username'},
          "cmdb_password"     => $params->{'cmdb_password'},
          "description"       => $params->{'description'},
          "tags"              => $params->{'tags'},
          "active"            => $params->{'active'} eq "true" ? true : false,
        }
      },
      { 'upsert' => 1 }                               # update or insert
  );

  $log->debug("Exasteel::Controller::Private_API::addCMDB | insert result: ".Dumper($id)) if ($log_level>0);

  if ($id->{'err'}) {
    $status{'status'}="ERROR";
    $status{'description'}=$id->{'err'};
  }

  $self->respond_to(
    json => sub {
      if ($status{'status'} eq 'ERROR') {
        $self->render(json => \%status, status => 404);
      } else {
        $self->render(json => \%status);
      }
    }
  );
}

"Do you suppose the Ivory Tower is still standing? (Neverending Story, 1984)";
