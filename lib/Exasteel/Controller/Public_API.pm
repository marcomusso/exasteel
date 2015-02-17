package Exasteel::Controller::Public_API;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(url_unescape);
use Data::Dumper;
use DateTime;
use POSIX qw(strftime);

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
  # my $log_level=$self->log_level;
  my $log_level=1;
  my $vdc=url_unescape($self->param('vdc_name'));
  my %status=(status => 'OK', description => '' );

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | Request by $ua @ $ip") if $log_level>0;

  my $ovmm_ua = Mojo::UserAgent->new;

  # lookup vdc config (username, password, endpoint) in mongodb
  my $vdcs_collection=$db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({"display_name" => $vdc});
  my @vdcs=$find_result->all;

  # if (@vdcs) {
  #   $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | Found VDC: ".Dumper(@vdcs)) if $log_level>1;
  # }

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
  } else {
    $log->debug("Exasteel::Controller::Public_API::getVDCGuestsByCN | Error in request to OVMM") if ($log_level>0);
    $status{'status'}="ERROR";
    $status{'description'}="Error in request to OVMM";
  }

  # convert local hash into desired result hash
  $result{cnCount}=@{$temp_hash_ref->{'server'}};
  foreach my $server (@{$temp_hash_ref->{'server'}}) {
    my @guests;
    foreach my $guest (@{$server->{'vmIds'}}) {
      push @guests, {
                      name => $guest->{'name'},
                      type => 'guest'
                    };
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

"I came here to find the Southern Oracle (Neverending Story, 1984)";
