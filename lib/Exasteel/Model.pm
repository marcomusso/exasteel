package Exasteel::Model;

use strict;
use warnings;
use MongoDB;
use MongoDB::OID;
use Mojo::Loader;
use Mojo::Log;

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/model.log', level => 'debug');
my $debug=1;

# Reloadable Model, for future implementation
my $modules = Mojo::Loader->search('Exasteel::Model');

for my $module (@$modules) {
  Mojo::Loader->load($module)
}

my $mongoclient;
my $mongodb;

sub init {
  my ($class, $config) = @_;

  $log->debug("No dbname was passed!") unless $config && $config->{dbname};

  unless ( $mongodb ) {
    $mongoclient=MongoDB::MongoClient->new(host => $config->{dbhost});
    $mongodb=$mongoclient->get_database($config->{dbname});
    if ($debug>0) { $log->debug('Exasteel::Model::init | Created new connection to MongoDB.'); }
  }

  if ($debug>1) { $log->debug('Exasteel::Model::init | Returned exiting connection to MongoDB.'); }

  return $mongodb;
}

sub db {
  return $mongodb if $mongodb;
  $log->debug("Exasteel::Model::db | You should init first!");
}

"Your db is served";
