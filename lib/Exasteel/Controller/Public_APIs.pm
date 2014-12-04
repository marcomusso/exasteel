package Exasteel::Controller::Public_APIs;

use Mojo::Base 'Mojolicious::Controller';
use DBI;
use Data::Dumper;
use Mojo::Log;
use DateTime;
use POSIX qw(strftime);

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/public_APIs.log', level => 'debug');
my $debug=2; # global log level, override in each sub if needed

# render static docs
sub docs {
  my $self = shift;
  $self->render('api/v1/docs');
}

=head1 Exasteel API v1

This are the public APIs for Exasteel. You can call every method via an HTTP GET:

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
		$log->debug("Exasteel::Controller::Public_APIs::getVCDKPI | Request by $ua @ $ip");
	}

	$self->respond_to(
	  json =>	{ json => \%hash },
	  csv  =>	{ text => $csv_data }
	);
}

sub getEMOCAccounts {
  my $self = shift;
  my $emoc = $self->param('emoc');
  my @accounts = ();

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  if ($debug>0) {
    $log->debug("Exasteel::Controller::Public_APIs::getEMOCAccounts | Request by $ua @ $ip");
  }

  my $emoc_ua = Mojo::UserAgent->new;

  # get EMOC parameters from db

  # for testing purposes
  my $user="";
  my $password="";
  my $emoc_endpoint="";

  my $data=$emoc_ua->get('https://'.$user.':'.$password.'@'.$emoc_endpoint.'/akm/?Action=DescribeAccounts&Version=1&Timestamp=1416930951&Expires=1436930951');
  if (my $res = $data->success) {
    # force XML semantics
    $res->dom->xml(1);
    if ($debug>1) {
      $log->debug("Exasteel::Controller::Public_APIs::getEMOCAccounts | # of accounts found: ".$res->dom->find('name')->text->size);
    }
    push @accounts,map {@$_} $res->dom->find('name')->text->uniq->to_array;
  } else {
    $log->debug("Exasteel::Controller::Public_APIs::getEMOCAccounts | Error in request to EMOC");
  }

  # lowercase & sort array
  @accounts = sort @accounts;
  if ($debug>0) {
    $log->debug("Exasteel::Controller::Public_APIs::getEMOCAccounts | Accounts: ".Dumper(@accounts));
  }

  $self->respond_to(
    json => { json => \@accounts }
  );
}

"I came here to find the Southern Oracle (Neverending Story, 1984)";
