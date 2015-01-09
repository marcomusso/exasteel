package Exasteel::Controller::Public_API;

use Mojo::Base 'Mojolicious::Controller';
use DBI;
use Data::Dumper;
use Mojo::Log;
use DateTime;
use POSIX qw(strftime);

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/public_API.log', level => 'debug');
my $debug=2; # global log level, override in each sub if needed

# render static docs
sub docs {
  my $self = shift;
  $self->render('api/v1/docs');
}

=head1 Exasteel API v1

This are the public API for Exasteel. You can call every method via an HTTP GET:

	http://<EXASTEEL_URL>/api/v1/<method>/<parameters...>

Example:

	http://<EXASTEEL_URL>/api/v1/getVCDKPI/<KPI>.csv

The HTTP response will be according to the extension requested (mostly supported: CSV and JSON).

Method list:

=head2 getVCDKPI

TBD

=cut
sub getVCDKPI {
	my $self = shift;
  my %hash = ();
  my $csv_data='';

	my $ua=$self->req->headers->user_agent;
	my $ip=$self->tx->remote_address;
	if ($debug>0) {
		$log->debug("Exasteel::Controller::Public_API::getVCDKPI | Request by $ua @ $ip");
	}

	$self->respond_to(
	  json =>	{ json => \%hash },
	  csv  =>	{ text => $csv_data }
	);
}

=head2 getEMOCAccounts

Returns the accounts defined in the VDC (basically a conversion from XML to JSON :).

You call this method like:

  /api/v1/getemocaccounts/<emocname>.json

Example:

  # curl "http://<EXASTEEL_URL>/api/v1/getemocaccounts/myemoc.json"
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
sub getEMOCAccounts {
  my $self = shift;
  my $emoc = $self->param('emoc');
  my %accounts=();

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($debug>0) {
    $log->debug("Exasteel::Controller::Public_API::getEMOCAccounts | Request by $ua @ $ip");
  }

  my $emoc_ua = Mojo::UserAgent->new;

  my $now=time()*1000;      # I need millisecs
  my $expires=$now+600000;  # let's double the minimum according to http://docs.oracle.com/cd/E27363_01/doc.121/e25150/appendix.htm#OPCAC936

  my $data=$emoc_ua->get('https://'.$username.':'.$password.'@'.$emoc_endpoint.'/akm/?Action=DescribeAccounts&Version=1&Timestamp='.$now.'&Expires='.$expires);
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
    $log->debug("Exasteel::Controller::Public_API::getEMOCAccounts | Error in request to EMOC");
  }

  if ($debug>0) {
    $log->debug("Exasteel::Controller::Public_API::getEMOCAccounts | Result: ".Dumper(\%accounts));
  }

  $self->respond_to(
    json => { json => \%accounts }
  );
}

"I came here to find the Southern Oracle (Neverending Story, 1984)";
