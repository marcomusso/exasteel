package Exasteel::Controller::Public_API;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(url_unescape);
use Data::Dumper;
use DateTime;
use POSIX qw(strftime);
use boolean;

# render static docs
sub docs {
  my $self = shift;
  $self->render('api/v1/docs');
}

=head1 Exasteel API v1

This are the public API for Exasteel. You can call every method via an HTTP GET:

	http://<EXASTEEL_URL>/api/v1/<method>/<parameters...>

Example:

	http://<EXASTEEL_URL>/api/v1/vdckpi/<KPI>.csv

The HTTP response will be according to the extension requested (mostly supported: CSV and JSON).

Method list:

=head2 vdckpi

TBD

=cut
sub VDCKPI {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=2;

  my %hash=();
  my $csv_data='';

	my $ua=$self->req->headers->user_agent;
	my $ip=$self->tx->remote_address;
	if ($log_level>0) {
    my $user='';
    if ($self->session->{login} and $self->session->{login} ne '') {
      $user=' (logged user: '.$self->session->{login}.')';
    }
    $log->debug("Exasteel::Controller::Public_API::vdckpi | Request by $ua @ $ip".$user);
	}

  # get config from db

	$self->respond_to(
	  json =>	{ json => \%hash },
	  csv  =>	{ text => $csv_data }
	);
}

=head2 VDCAccounts

Returns the accounts defined in the VDC (basically a conversion from XML to JSON :).

You call this method like:

  /api/v1/vdcaccounts/<vdc>.json

Example:

  # curl "http://<EXASTEEL_URL>/api/v1/vdcaccounts/EL01.json"
  {
    "TEMPLATES": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": "Public templates"
    },
    "DEV": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": ""
    },
    "MANAGEMENT": {
      "description": "Management account",
      "id": "ACC-00000000-0000-0000-0000-000000000000"
    },
    "PERFORMANCE-TEST": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": "For performance testing vm"
    },
    "TEST": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": ""
    }
  }

=cut
sub VDCAccounts {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=$self->log_level;
  my $vdc=url_unescape($self->param('vdc'));

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Request by $ua @ $ip") if $log_level>0;

  my $emoc_ua = Mojo::UserAgent->new;

  my $now=time()*1000;      # I need millisecs
  my $expires=$now+600000;  # let's double the minimum according to http://docs.oracle.com/cd/E27363_01/doc.121/e25150/appendix.htm#OPCAC936

  # lookup vdc config ($username, $password, $emoc_endpoint) in mongodb
  my $vdcs_collection=$self->db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({"display_name" => $vdc});
  my @vdcs=$find_result->all;

  if (@vdcs) {
    $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Found vDC: ".Dumper(@vdcs)) if $log_level>1;
  }

  my $username=$vdcs[0]{emoc_username};
  my $password=$vdcs[0]{emoc_password};
  my $emoc_endpoint=$vdcs[0]{emoc_endpoint};
  # TODO further sanitize endpoint, ie no http, no URI part, only hostname:port
  $emoc_endpoint=~s/http[s]:\/\///g;
  my %accounts=();

  my $url='https://'.$username.':'.$password.'@'.$emoc_endpoint.'/akm/?Action=DescribeAccounts&Version=1&Timestamp='.$now.'&Expires='.$expires;

  $log->debug("Exasteel::Controller::Public_API::VDCAccounts | URL: ".$url) if $log_level>1;

  my $data=$emoc_ua->get($url);
  $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Result: ".Dumper($data)) if ($log_level>1);
  if (my $res = $data->success) {
    # force XML semantics
    $res->dom->xml(1);
    $res->dom->find('items')->each(
      sub {
        my $account_id='';
        my $account_name='';
        my $account_description='';
        if ($_->at('account')) { $account_id=$_->at('account')->text; }
        if ($_->at('name')) { $account_name=$_->at('name')->text; }
        if ($_->at('description')) {
          $account_description = $_->at('description')->text;
        }
        $accounts{$account_name}={
          "id" => $account_id,
          "description" => $account_description
        };
      }
    );
  } else {
    $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Error in request to EMOC");
    $accounts{'status'}="ERROR";
    $accounts{'description'}="Error in request to EMOC";
  }

  if ($log_level>0) {
    $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Result: ".Dumper(\%accounts));
  }

  $self->respond_to(
    json => { json => \%accounts }
  );
}

=head2 getVDCGuestsByCN

Returns all info

You call this method like:

  /api/v1/getvdcguestsbycn/<vdc>.json

Example:

  # curl "http://<EXASTEEL_URL>/api/v1/getvdcguestsbycn/EL01.json"

=cut
sub getVDCGuestsByCN {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=$self->log_level;
  my $vdc=url_unescape($self->param('vdc_name'));
  my %status=(status => 'OK', description => '' );

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | Request by $ua @ $ip") if $log_level>0;

  my $ovmm_ua = Mojo::UserAgent->new;
  # $ovmm_ua->connect_timeout(3);
  $ovmm_ua->request_timeout(6);

  # lookup vdc config (username, password, endpoint) in mongodb
  my $vdcs_collection=$db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({"display_name" => $vdc});
  my @vdcs=$find_result->all;

  my $username=$vdcs[0]{ovmm_username};
  my $password=$vdcs[0]{ovmm_password};
  my $ovmm_endpoint=$vdcs[0]{ovmm_endpoint};
  # prepare il risultato in un modo consono per D3 ma comunque leggibile umanamente
    my $temp_hash_ref;
    my %result=( name => $vdc, type=> 'vdc', children => []);

  my $url='https://'.$username.':'.$password.'@'.$ovmm_endpoint.'/ovm/core/wsapi/rest/Server';

  $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | URL: ".$url) if $log_level>1;

  my $data=$ovmm_ua->get($url => {Accept => 'application/json'});
  if (my $res = $data->success) {
    # copy returned JSON into local hash
    $temp_hash_ref=decode_json($res->body);
    # convert local hash into desired result hash
    $result{cnCount}=@{$temp_hash_ref->{'server'}};
    foreach my $server (@{$temp_hash_ref->{'server'}}) {
      my @guests;
      # the API returns an object and not an array when there is only one vm on a cn
      if (ref $server->{'vmIds'} eq 'ARRAY') {
        foreach my $guest (@{$server->{'vmIds'}}) {
          my $isRunning;
          if ($guest->{'name'} =~ /ExalogicControl/) {
            $isRunning=':'.(getVmIdDetails(@vdcs,$guest->{'uri'})->{'vmRunState'} ? '1' : '0');
          } else { $isRunning=''; }
          push @guests, {
                          name => $guest->{'name'}.$isRunning,
                          type => 'guest'
                        };
        }
      } else {
        my $guest=$server->{'vmIds'};
        my $isRunning='';
        if ($guest->{'name'}) {
          if ($guest->{'name'} =~ /ExalogicControl/) {
            $isRunning=':'.(getVmIdDetails(@vdcs,$guest->{'uri'})->{'vmRunState'} ? '1' : '0');
          }
          push @guests, {
                          name => $guest->{'name'}.$isRunning,
                          type => 'guest'
                        };
        }
      }

      push $result{'children'}, {
                                 name => $server->{'hostname'},
                                 type => 'compute-node',
                                 cpus => $server->{'totalProcessorCores'}*$server->{'threadsPerCore'},
                                 memory => $server->{'memory'},
                                 threadsPerCore => $server->{'threadsPerCore'},
                                 totalProcessorCores => $server->{'totalProcessorCores'},
                                 serverRunState => $server->{'serverRunState'},
                                 abilityMap => $server->{'abilityMap'},
                                 guestsCount => scalar @guests,
                                 children => \@guests
                                };
    }

    $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | Result: ".Dumper(\%result)) if ($log_level>1);
  } else {
    $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | Error in request to OVMM") if ($log_level>0);
    $status{'status'}="ERROR";
    $status{'description'}="Error in request to OVMM";
  }

  $self->respond_to(
    json => sub {
      if ($status{'status'} eq 'ERROR') {
        $self->render(json => \%status);
      } else {
        $self->render(json => \%result);
      }
    }
  );
}

=head2 getHostsPerService

Returns the association between a service and its servers

You call this method like:

  /api/v1/gethostsperservice.json

Example:

  # curl "http://<EXASTEEL_URL>/api/v1/gethostsperservice.json"

=cut
sub getHostsPerService {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=$self->log_level;
  my $env=uc($self->param('env'));

  my %status=(status => 'OK', description => '' );
  my %result;

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  $log->debug("Exasteel::Controller::Public_API::getHostsPerService | Request by $ua @ $ip") if $log_level>0;

  # get active CMDB from MongoDB
  my $cmdb_collection=$self->db->get_collection('cmdb');
  my $find_result=$cmdb_collection->find({"display_name" => 'CMDB Intesa Sanpaolo'});
  my @cmdb=$find_result->all;

  # there is at least one cmdb configured as active
  if ( @cmdb and (0+@cmdb)==1) {
    # basic auth
    my $cmdb_ua = Mojo::UserAgent->new;
    my $endpoint = $cmdb[0]->{'cmdb_endpoint'};
    $endpoint =~ s/{env}/$env/g;
    my $cmdb_url='http://'.$cmdb[0]->{'cmdb_username'}.':'.$cmdb[0]->{'cmdb_password'}.'@'.$endpoint;

    $log->debug("Exasteel::Controller::Public_API::getHostsPerService | URL: ".$cmdb_url) if $log_level>1;
    my $data=$cmdb_ua->get($cmdb_url);
    if (my $res = $data->success) {
      # $log->debug("Exasteel::Controller::Public_API::getHostsPerService | CSV: ".$res->body) if $log_level>1;
      # our CMDB returns a CSV like this:
      #  id;project.id;name;bank;environment.name;infrastructure;type;version;family;status;domain;userName;listenPort;listenHosts;adminURL;adminHost;adminPort;scriptName;wlsAdminPasswd;t3protocol;url;
      # "1684361";"MAUP0";"MAUP0";"MB";"PROD";"Intranet";"EXA-WEBLOGIC";"10.3.6";"J2EE-AS";"OPERATING";"mch1036Domain";"wl10";"7914";"saxstp016,saxstp017,saxstp014,saxstp015,";"http://saxncp013:7917/console";"7917";"saxncp013";"";"";"";"";

      # start converting a CSV into an hash
      my $record_number=0;
      my %index;
      my @fields;
      my $field;
      foreach my $line (split (/\n/, $res->body)) {
          # estraggo le intestazioni e le metto in un array associativo per usarle dopo
          if ($record_number==0) {
              my @header = split (';',$line);
              s/^"|"$//g foreach @header;     # elimino i doppi apici se presenti
              #per ogni field valorizzo l'array associativo
              my $head_index=0;
              foreach $field (@header) {
                  $index{"$field"}=$head_index;
                  $head_index+=1;
              }
          } else {
              @fields = split (';', $line);
              s/^"|"$//g foreach @fields; # elimino i doppi apici se presenti
              if (!$result{$fields[$index{'project.id'}]}) {
                $result{$fields[$index{'project.id'}]}{'listenHosts'}=[];
                $result{$fields[$index{'project.id'}]}{'version'}=$fields[$index{'version'}];
                $result{$fields[$index{'project.id'}]}{'listenPort'}=$fields[$index{'listenPort'}];
                $result{$fields[$index{'project.id'}]}{'domain'}=$fields[$index{'domain'}];
                $result{$fields[$index{'project.id'}]}{'adminURL'}=$fields[$index{'adminURL'}];
              }
              foreach my $host (split (',',$fields[$index{'listenHosts'}])) {
                push @{$result{$fields[$index{'project.id'}]}{'listenHosts'}}, $host;
              }
          }
          $record_number+=1;
      }
    } else {
      $log->debug("Exasteel::Controller::Public_API::getHostsPerService | Error in request to CMDB") if ($log_level>0);
      $status{'status'}="ERROR";
      $status{'description'}="Error in request to CMDB";
    }
  } else {
    $status{'status'}="ERROR";
    $status{'description'}="No active CMDB endpoint";
  }

  $log->debug("Exasteel::Controller::Public_API::getHostsPerService | Result: ".Dumper(\%result)) if ($log_level>1);

  $self->respond_to(
    json => sub {
      if ($status{'status'} eq 'ERROR') {
        $self->render(json => \%status, status => 404);
      } else {
        $self->render(json => \%result);
      }
    }
  );
}

sub getVmIdDetails() {
  my @vdcs=shift;
  my $url = shift;

  my $temp_hash_ref;
  my $username=$vdcs[0]{ovmm_username};
  my $password=$vdcs[0]{ovmm_password};

  my $ovmm_ua = Mojo::UserAgent->new;
  $ovmm_ua->request_timeout(6);

  $url =~ s/https:\/\//https:\/\/$username\:$password@/g;

  my $data=$ovmm_ua->get($url => {Accept => 'application/json'});
  if (my $res = $data->success) {
     $temp_hash_ref=decode_json($res->body);
  }

  return $temp_hash_ref;
}

"I came here to find the Southern Oracle (Neverending Story, 1984)";
