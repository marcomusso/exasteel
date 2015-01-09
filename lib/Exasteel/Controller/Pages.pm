package Exasteel::Controller::Pages;

use strict;
use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use Data::Dumper;
use Mojo::Log;
use Mojo::Headers;

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/exasteel.log', level => 'debug');
my $debug=2;

# landing page
sub home {
  my $self = shift;
  $self->render('home')
}

# landing page
sub settings {
  my $self = shift;
  $self->render('pages/settings');
}
